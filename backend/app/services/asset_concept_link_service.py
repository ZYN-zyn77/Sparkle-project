"""
Asset-Concept Link Service

Phase 9: Graph Flywheel - Automatically links learning assets to knowledge graph concepts.

Core Responsibilities:
1. Generate provenance links when assets are created
2. Match headword to existing concepts or create new ones
3. Write events to outbox for downstream processing
"""
import json
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from uuid import UUID

from sqlalchemy import select, and_, text
from sqlalchemy.ext.asyncio import AsyncSession
from loguru import logger

from app.models.asset_concept_link import AssetConceptLink, LinkType
from app.models.learning_assets import LearningAsset
from app.models.galaxy import KnowledgeNode


# === Guardrail Constants ===
MAX_METADATA_BYTES = 2048


class AssetConceptLinkService:
    """
    Asset-Concept Link Service

    Connects LearningAsset (user vocabulary) to KnowledgeNode (knowledge graph concepts).
    This is the core of the "Asset → Graph" flywheel in Phase 9.
    """

    async def generate_links_for_asset(
        self,
        db: AsyncSession,
        asset: LearningAsset,
    ) -> List[AssetConceptLink]:
        """
        Generate concept links for a newly created asset.

        Rules:
        1. Use provenance.match_strength to determine confidence
        2. Try to match existing concept by headword, create if not exists
        3. Write event to outbox for downstream processing

        Args:
            db: Database session
            asset: The LearningAsset to link

        Returns:
            List of created AssetConceptLink instances
        """
        links = []

        # 1. Get or create concept node
        concept = await self._get_or_create_concept(
            db=db,
            headword=asset.headword,
            user_id=asset.user_id,
            language_code=asset.language_code,
        )

        # 2. Calculate confidence from provenance
        provenance = asset.provenance_json or {}
        match_strength = provenance.get("match_strength", "ORPHAN")
        confidence = self._strength_to_confidence(match_strength)

        # 3. Build limited metadata (guardrail: < 2KB)
        metadata = self._build_limited_metadata(provenance)

        # 4. Upsert link
        link = await self._upsert_link(
            db=db,
            user_id=asset.user_id,
            asset_id=asset.id,
            concept_id=concept.id,
            link_type=LinkType.PROVENANCE,
            confidence=confidence,
            metadata=metadata,
        )
        links.append(link)

        logger.info(
            f"Generated {len(links)} link(s) for asset {asset.id} → concept {concept.id} "
            f"(confidence={confidence:.2f}, type=provenance)"
        )

        return links

    async def create_co_activation_link(
        self,
        db: AsyncSession,
        user_id: UUID,
        asset_id: UUID,
        concept_id: UUID,
        session_id: Optional[str] = None,
    ) -> AssetConceptLink:
        """
        Create a co-activation link when asset and concept are accessed in same session.

        Args:
            db: Database session
            user_id: User UUID
            asset_id: Asset UUID
            concept_id: Concept UUID
            session_id: Optional session identifier for metadata

        Returns:
            Created AssetConceptLink
        """
        metadata = {"session_id": session_id} if session_id else None

        link = await self._upsert_link(
            db=db,
            user_id=user_id,
            asset_id=asset_id,
            concept_id=concept_id,
            link_type=LinkType.CO_ACTIVATION,
            confidence=0.5,  # Default co-activation confidence
            metadata=metadata,
        )

        logger.debug(f"Created co_activation link: asset={asset_id} → concept={concept_id}")
        return link

    async def create_manual_link(
        self,
        db: AsyncSession,
        user_id: UUID,
        asset_id: UUID,
        concept_id: UUID,
    ) -> AssetConceptLink:
        """
        Create a user-explicit manual link.

        Args:
            db: Database session
            user_id: User UUID
            asset_id: Asset UUID
            concept_id: Concept UUID

        Returns:
            Created AssetConceptLink
        """
        link = await self._upsert_link(
            db=db,
            user_id=user_id,
            asset_id=asset_id,
            concept_id=concept_id,
            link_type=LinkType.MANUAL,
            confidence=1.0,  # User manual = high confidence
            metadata={"source": "user_explicit"},
        )

        logger.info(f"Created manual link: asset={asset_id} → concept={concept_id}")
        return link

    async def get_links_for_asset(
        self,
        db: AsyncSession,
        user_id: UUID,
        asset_id: UUID,
    ) -> List[AssetConceptLink]:
        """Get all concept links for an asset."""
        query = select(AssetConceptLink).where(
            and_(
                AssetConceptLink.user_id == user_id,
                AssetConceptLink.asset_id == asset_id,
                AssetConceptLink.deleted_at.is_(None),
            )
        )
        result = await db.execute(query)
        return list(result.scalars().all())

    async def get_links_for_concept(
        self,
        db: AsyncSession,
        user_id: UUID,
        concept_id: UUID,
    ) -> List[AssetConceptLink]:
        """Get all asset links for a concept."""
        query = select(AssetConceptLink).where(
            and_(
                AssetConceptLink.user_id == user_id,
                AssetConceptLink.concept_id == concept_id,
                AssetConceptLink.deleted_at.is_(None),
            )
        )
        result = await db.execute(query)
        return list(result.scalars().all())

    async def delete_link(
        self,
        db: AsyncSession,
        user_id: UUID,
        link_id: UUID,
    ) -> bool:
        """Soft delete a link."""
        query = select(AssetConceptLink).where(
            and_(
                AssetConceptLink.id == link_id,
                AssetConceptLink.user_id == user_id,
                AssetConceptLink.deleted_at.is_(None),
            )
        )
        result = await db.execute(query)
        link = result.scalar_one_or_none()

        if not link:
            return False

        link.deleted_at = datetime.now(timezone.utc)
        await db.flush()

        # Write delete event
        await self._write_event(
            db=db,
            aggregate_type="asset_concept_link",
            aggregate_id=link_id,
            event_type="link_deleted",
            payload={
                "asset_id": str(link.asset_id),
                "concept_id": str(link.concept_id),
            },
        )

        return True

    # === Private Methods ===

    async def _get_or_create_concept(
        self,
        db: AsyncSession,
        headword: str,
        user_id: UUID,
        language_code: str,
    ) -> KnowledgeNode:
        """
        Get existing concept by headword or create a minimal new one.

        Strategy:
        1. Exact match on name (case-sensitive for now)
        2. If not found, create a minimal "user_created" node
        3. Compute incremental position using GalaxyLayoutService
        """
        # Try exact match first
        query = select(KnowledgeNode).where(
            and_(
                KnowledgeNode.name == headword,
                KnowledgeNode.deleted_at.is_(None),
            )
        ).limit(1)

        result = await db.execute(query)
        existing = result.scalar_one_or_none()

        if existing:
            logger.debug(f"Found existing concept for headword '{headword}': {existing.id}")
            return existing

        # Create minimal node
        node = KnowledgeNode(
            name=headword,
            source_type="user_created",
            status="published",
            # Position will be set by GalaxyLayoutService below
            position_x=None,
            position_y=None,
        )
        db.add(node)
        await db.flush()
        await db.refresh(node)

        # Compute incremental position using kNN
        from app.services.galaxy_layout_service import GalaxyLayoutService
        layout_service = GalaxyLayoutService(db)
        await layout_service.compute_position_for_concept(node.id)

        # Write node_created event
        await self._write_event(
            db=db,
            aggregate_type="knowledge_node",
            aggregate_id=node.id,
            event_type="node_created",
            payload={
                "name": headword[:100],  # Truncate for event
                "source": "asset_link",
                "source_type": "user_created",
            },
        )

        logger.info(f"Created new concept node for headword '{headword}': {node.id}")
        return node

    def _strength_to_confidence(self, strength: str) -> float:
        """
        Convert match strength to confidence score.

        STRONG: High-quality provenance match (0.9)
        WEAK: Partial match or uncertain (0.6)
        ORPHAN: No provenance (0.4)
        """
        mapping = {
            "STRONG": 0.9,
            "WEAK": 0.6,
            "ORPHAN": 0.4,
        }
        return mapping.get(strength, 0.4)

    def _build_limited_metadata(self, provenance: dict) -> Optional[dict]:
        """
        Build metadata dict with size guardrail.

        Only includes key provenance fields, not full text.
        Truncates if exceeds MAX_METADATA_BYTES.
        """
        if not provenance:
            return None

        # Only keep essential fields (no full text content)
        allowed_keys = [
            "chunk_id",
            "doc_id",
            "page_no",
            "score",
            "match_strength",
            "match_profile",
        ]
        filtered = {k: v for k, v in provenance.items() if k in allowed_keys}

        if not filtered:
            return None

        # Check size limit
        serialized = json.dumps(filtered)
        if len(serialized) <= MAX_METADATA_BYTES:
            return filtered

        # Truncate by removing largest fields
        filtered["truncated"] = True
        filtered["original_size"] = len(serialized)

        while len(json.dumps(filtered)) > MAX_METADATA_BYTES and len(filtered) > 2:
            # Find and remove largest non-essential field
            largest_key = max(
                (k for k in filtered.keys() if k not in ["truncated", "original_size"]),
                key=lambda k: len(str(filtered.get(k, ""))),
                default=None,
            )
            if largest_key:
                del filtered[largest_key]
            else:
                break

        return filtered

    async def _upsert_link(
        self,
        db: AsyncSession,
        user_id: UUID,
        asset_id: UUID,
        concept_id: UUID,
        link_type: LinkType,
        confidence: float,
        metadata: Optional[dict],
    ) -> AssetConceptLink:
        """
        Upsert a link (partial unique index friendly).

        If link exists: update confidence and metadata
        If link doesn't exist: create new
        """
        # Check for existing link
        query = select(AssetConceptLink).where(
            and_(
                AssetConceptLink.user_id == user_id,
                AssetConceptLink.asset_id == asset_id,
                AssetConceptLink.concept_id == concept_id,
                AssetConceptLink.link_type == link_type.value,
                AssetConceptLink.deleted_at.is_(None),
            )
        )
        result = await db.execute(query)
        existing = result.scalar_one_or_none()

        now = datetime.now(timezone.utc)

        if existing:
            # Update existing
            existing.confidence = confidence
            existing.metadata = metadata
            existing.updated_at = now
            link = existing
            is_new = False
        else:
            # Create new
            link = AssetConceptLink(
                user_id=user_id,
                asset_id=asset_id,
                concept_id=concept_id,
                link_type=link_type.value,
                confidence=confidence,
                metadata=metadata,
            )
            db.add(link)
            is_new = True

        await db.flush()
        if is_new:
            await db.refresh(link)

        # Write upsert event
        await self._write_event(
            db=db,
            aggregate_type="asset_concept_link",
            aggregate_id=link.id,
            event_type="link_upserted",
            payload={
                "asset_id": str(asset_id),
                "concept_id": str(concept_id),
                "link_type": link_type.value,
                "confidence": confidence,
                "is_update": not is_new,
            },
        )

        return link

    async def _write_event(
        self,
        db: AsyncSession,
        aggregate_type: str,
        aggregate_id: UUID,
        event_type: str,
        payload: dict,
    ) -> None:
        """
        Write event to outbox (reuses existing CQRS infrastructure).

        Uses the same pattern as LearningAssetService._write_event_outbox.
        """
        # Get next sequence number (atomic upsert)
        seq_result = await db.execute(
            text("""
                INSERT INTO event_sequence_counters (aggregate_type, aggregate_id, next_sequence)
                VALUES (:aggregate_type, :aggregate_id, 1)
                ON CONFLICT (aggregate_type, aggregate_id)
                DO UPDATE SET next_sequence = event_sequence_counters.next_sequence + 1
                RETURNING next_sequence
            """),
            {"aggregate_type": aggregate_type, "aggregate_id": aggregate_id}
        )
        sequence_number = seq_result.scalar()

        # Write event
        await db.execute(
            text("""
                INSERT INTO event_outbox
                (aggregate_type, aggregate_id, event_type, event_version, sequence_number, payload, metadata)
                VALUES (:aggregate_type, :aggregate_id, :event_type, 1, :sequence_number, :payload, :metadata)
            """),
            {
                "aggregate_type": aggregate_type,
                "aggregate_id": aggregate_id,
                "event_type": event_type,
                "sequence_number": sequence_number,
                "payload": json.dumps(payload),
                "metadata": json.dumps({"service": "asset_concept_link_service"}),
            }
        )


# Singleton instance
asset_concept_link_service = AssetConceptLinkService()
