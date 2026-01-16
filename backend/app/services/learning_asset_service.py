"""
Learning Asset Service (学习资产服务)

Manages the lifecycle of learning assets (words, sentences, concepts).
Handles:
- Asset creation from translation lookups
- Suggestion generation with cooldown
- Event outbox integration for audit trail
- Inbox expiry and status transitions
"""
import json
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any, List, Tuple
from uuid import UUID

from sqlalchemy import select, and_, func, text, case
from sqlalchemy.ext.asyncio import AsyncSession
from loguru import logger

from app.models.learning_assets import (
    LearningAsset,
    AssetSuggestionLog,
    AssetStatus,
    AssetKind,
    SuggestionDecision,
    UserSuggestionResponse,
)
from app.core.fingerprint import (
    generate_fingerprints,
    normalize_with_hint,
    NORM_VERSION,
    DEFAULT_MATCH_PROFILE,
)
from app.core.fuzzy_match import find_provenance, build_provenance_json
from app.core.cache import cache_service
from app.services.embedding_service import embedding_service
from app.services.ab_test_service import ab_test_service


# === Configuration ===
INBOX_EXPIRY_DAYS = 7
SUGGESTION_COOLDOWN_MINUTES = 30
DISMISS_COOLDOWN_DAYS = 7
REPEAT_LOOKUP_THRESHOLD = 2  # Suggest after N lookups in session
SESSION_TTL_HOURS = 2


class LearningAssetService:
    """Service for managing learning assets and suggestions"""

    # === Redis Key Patterns ===
    @staticmethod
    def _session_lookup_key(session_id: str, selection_fp: str) -> str:
        """Key for tracking lookups in a session"""
        return f"sess:{session_id}:lookup:{selection_fp}"

    @staticmethod
    def _user_cooldown_key(user_id: UUID, policy_id: str) -> str:
        """Key for user-level cooldown"""
        return f"user:{user_id}:suggestion_cooldown:{policy_id}"

    # === Asset Creation ===

    async def create_asset_from_selection(
        self,
        db: AsyncSession,
        user_id: UUID,
        selected_text: str,
        translation: Optional[str] = None,
        definition: Optional[str] = None,
        example: Optional[str] = None,
        source_file_id: Optional[UUID] = None,
        context_before: Optional[str] = None,
        context_after: Optional[str] = None,
        page_no: Optional[int] = None,
        language_code: str = "en",
        asset_kind: AssetKind = AssetKind.WORD,
        initial_status: AssetStatus = AssetStatus.INBOX,
    ) -> LearningAsset:
        """
        Create a learning asset from a text selection.

        This is the primary entry point for explicit user collection.

        Args:
            db: Database session
            user_id: User UUID
            selected_text: The text user selected
            translation: Translated text (optional)
            definition: Definition or meaning (optional)
            example: Example sentence (optional)
            source_file_id: Source document UUID (optional)
            context_before: Text before selection (optional)
            context_after: Text after selection (optional)
            page_no: Page number (optional)
            language_code: Source language code
            asset_kind: Type of asset (WORD/SENTENCE/CONCEPT)
            initial_status: Starting status (default: INBOX)

        Returns:
            Created LearningAsset instance
        """
        # 1. Normalize and generate fingerprints
        norm_result = normalize_with_hint(selected_text)
        fp_result = generate_fingerprints(
            selected_text=selected_text,
            doc_id=source_file_id,
            context_before=context_before,
            context_after=context_after,
            page_no=page_no,
        )

        # 2. Build immutable snapshot
        snapshot = {
            "selected_text": selected_text,
            "context_before": context_before[:500] if context_before else None,
            "context_after": context_after[:500] if context_after else None,
            "page_no": page_no,
            "source_file_id": str(source_file_id) if source_file_id else None,
            "language_code": language_code,
            "ambiguity_hint": norm_result.ambiguity_hint,
            "norm_version": NORM_VERSION,
            "match_profile": DEFAULT_MATCH_PROFILE,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }

        # 3. Try to find provenance if source_file_id provided
        provenance = {}
        if source_file_id:
            try:
                match_result = await find_provenance(
                    db=db,
                    selected_text=selected_text,
                    file_id=source_file_id,
                    page_no=page_no,
                    user_id=user_id,
                    timeout_ms=200,  # Strict timeout for MVP
                )
                provenance = build_provenance_json(match_result)
            except Exception as e:
                logger.warning(f"Provenance matching failed: {e}")
                provenance = {
                    "match_strength": "ORPHAN",
                    "reason": f"match_error: {str(e)}"
                }

        # 4. Set inbox expiry if starting in INBOX
        inbox_expires_at = None
        if initial_status == AssetStatus.INBOX:
            inbox_expires_at = datetime.now(timezone.utc) + timedelta(days=INBOX_EXPIRY_DAYS)

        # 5. Create asset
        asset = LearningAsset(
            user_id=user_id,
            source_file_id=source_file_id,
            status=initial_status.value,
            asset_kind=asset_kind.value,
            headword=selected_text[:255],  # Truncate to fit column
            definition=definition,
            translation=translation,
            example=example,
            language_code=language_code,
            inbox_expires_at=inbox_expires_at,
            snapshot_json=snapshot,
            snapshot_schema_version=1,
            provenance_json=provenance,
            provenance_updated_at=datetime.now(timezone.utc) if provenance else None,
            selection_fp=fp_result.selection_fp,
            anchor_fp=fp_result.anchor_fp,
            doc_fp=fp_result.doc_fp,
            norm_version=fp_result.norm_version,
            match_profile=fp_result.match_profile,
        )

        db.add(asset)
        await db.flush()
        await db.refresh(asset)

        # 6. Write event to outbox
        await self._write_event_outbox(
            db=db,
            aggregate_type="learning_asset",
            aggregate_id=asset.id,
            event_type="asset_created",
            payload={
                "user_id": str(user_id),
                "asset_kind": asset_kind.value,
                "status": initial_status.value,
                "headword": asset.headword[:50],
                "has_provenance": bool(provenance.get("chunk_id")),
            }
        )

        logger.info(
            f"Created learning asset {asset.id} for user {user_id}: "
            f"kind={asset_kind.value}, status={initial_status.value}"
        )

        # 7. Generate concept links (Phase 9: Graph Flywheel)
        try:
            from app.services.asset_concept_link_service import asset_concept_link_service
            await asset_concept_link_service.generate_links_for_asset(db, asset)
        except Exception as e:
            # Link generation failure should not block asset creation
            logger.warning(f"Failed to generate concept links for asset {asset.id}: {e}")

        return asset

    async def check_existing_asset(
        self,
        db: AsyncSession,
        user_id: UUID,
        selection_fp: str,
    ) -> Optional[LearningAsset]:
        """
        Check if user already has an asset with this fingerprint.

        Args:
            db: Database session
            user_id: User UUID
            selection_fp: Selection fingerprint

        Returns:
            Existing asset or None
        """
        query = select(LearningAsset).where(
            and_(
                LearningAsset.user_id == user_id,
                LearningAsset.selection_fp == selection_fp,
                LearningAsset.deleted_at.is_(None),
            )
        )
        result = await db.execute(query)
        return result.scalar_one_or_none()

    # === Status Transitions ===

    async def activate_asset(self, db: AsyncSession, asset: LearningAsset) -> LearningAsset:
        """
        Move asset from INBOX to ACTIVE status.

        Args:
            db: Database session
            asset: Asset to activate

        Returns:
            Updated asset
        """
        if asset.status != AssetStatus.INBOX.value:
            raise ValueError(f"Can only activate INBOX assets, got {asset.status}")

        old_status = asset.status
        asset.activate()

        await self._write_event_outbox(
            db=db,
            aggregate_type="learning_asset",
            aggregate_id=asset.id,
            event_type="asset_status_changed",
            payload={
                "old_status": old_status,
                "new_status": asset.status,
                "triggered_by": "user_activate",
            }
        )

        await db.flush()
        return asset

    async def archive_asset(
        self,
        db: AsyncSession,
        asset: LearningAsset,
        reason: str = "user_archive"
    ) -> LearningAsset:
        """
        Archive an asset.

        Args:
            db: Database session
            asset: Asset to archive
            reason: Reason for archival

        Returns:
            Updated asset
        """
        old_status = asset.status
        asset.archive()

        await self._write_event_outbox(
            db=db,
            aggregate_type="learning_asset",
            aggregate_id=asset.id,
            event_type="asset_status_changed",
            payload={
                "old_status": old_status,
                "new_status": asset.status,
                "triggered_by": reason,
            }
        )

        await db.flush()
        return asset

    # === Suggestion System ===

    async def record_lookup(
        self,
        db: AsyncSession,
        user_id: UUID,
        session_id: str,
        selected_text: str,
        translation: Optional[str] = None,
        source_file_id: Optional[UUID] = None,
    ) -> Dict[str, Any]:
        """
        Record a translation lookup and evaluate suggestion.

        This is called after each translation to track repeated lookups
        and potentially suggest asset creation.

        Args:
            db: Database session
            user_id: User UUID
            session_id: Client session ID
            selected_text: Text that was translated
            translation: Translation result
            source_file_id: Source document if applicable

        Returns:
            Dict with suggest_asset flag and suggestion payload
        """
        # Generate fingerprint
        fp_result = generate_fingerprints(selected_text)
        selection_fp = fp_result.selection_fp

        # Check if asset already exists
        existing = await self.check_existing_asset(db, user_id, selection_fp)
        if existing:
            # Update lookup count
            existing.lookup_count += 1
            existing.last_seen_at = datetime.now(timezone.utc)
            await db.flush()
            return {
                "suggest_asset": False,
                "reason": "already_exists",
                "asset_id": str(existing.id),
            }

        # Increment session lookup counter (Redis with DB fallback)
        lookup_key = self._session_lookup_key(session_id, selection_fp)
        lookup_count = 0
        
        try:
            lookup_count = await cache_service.incr(lookup_key)
            await cache_service.expire(lookup_key, SESSION_TTL_HOURS * 3600)
        except Exception as e:
            logger.warning(f"Redis unavailable for lookup count, falling back to DB: {e}")
            # DB Fallback: Count recent logs for this session/fp
            # Optimization: We just need to know if it's >= threshold
            # Since we are about to insert a new log, we count existing ones + 1
            query = select(func.count(AssetSuggestionLog.id)).where(
                and_(
                    AssetSuggestionLog.user_id == user_id,
                    AssetSuggestionLog.session_id == session_id,
                    AssetSuggestionLog.evidence_json['selection_fp'].astext == selection_fp,
                    AssetSuggestionLog.created_at >= datetime.now(timezone.utc) - timedelta(hours=SESSION_TTL_HOURS)
                )
            )
            result = await db.execute(query)
            db_count = result.scalar() or 0
            lookup_count = db_count + 1

        # Evaluate suggestion
        should_suggest, decision, reason_dict = await self._evaluate_suggestion(
            db=db,
            user_id=user_id,
            session_id=session_id,
            selection_fp=selection_fp,
            lookup_count=lookup_count,
        )

        # Log suggestion decision
        log = AssetSuggestionLog(
            user_id=user_id,
            session_id=session_id,
            policy_id="repeat_lookup_v1",
            trigger_event="translation_lookup",
            evidence_json={
                "selection_fp": selection_fp,
                "lookup_count": lookup_count,
                "selected_text_preview": selected_text[:100],
            },
            decision=decision.value,
            decision_reason=reason_dict["display_text"],
        )
        db.add(log)
        await db.flush()

        if should_suggest:
            return {
                "suggest_asset": True,
                "suggestion_log_id": str(log.id),
                "selection_fp": selection_fp,
                "selected_text": selected_text,
                "translation": translation,
                "source_file_id": str(source_file_id) if source_file_id else None,
                "reason": reason_dict["display_text"],  # Legacy field
                "reason_code": reason_dict["reason_code"],
                "reason_params": reason_dict["reason_params"],
            }
        else:
            return {
                "suggest_asset": False,
                "reason": reason_dict["display_text"],  # Legacy field
                "reason_code": reason_dict["reason_code"],
                "reason_params": reason_dict["reason_params"],
            }

    async def _evaluate_suggestion(
        self,
        db: AsyncSession,
        user_id: UUID,
        session_id: str,
        selection_fp: str,
        lookup_count: int,
    ) -> Tuple[bool, SuggestionDecision, Dict[str, Any]]:
        """
        Evaluate whether to suggest asset creation.

        Rules:
        1. Must have looked up >= threshold times (A/B tested)
        2. Must not be in cooldown

        Returns:
            Tuple of (should_suggest, decision, reason_dict)
            reason_dict contains: reason_code, reason_params, display_text, variant_id
        """
        # Get threshold from A/B test (defaults to REPEAT_LOOKUP_THRESHOLD)
        threshold = ab_test_service.get_suggestion_threshold(user_id)
        variant_id = ab_test_service.get_variant_id_for_logging(
            user_id, "suggestion_threshold_v1"
        )

        # Check lookup threshold
        if lookup_count < threshold:
            return (
                False,
                SuggestionDecision.SKIPPED,
                {
                    "reason_code": "lookup_count_below_threshold",
                    "reason_params": {"lookup_count": lookup_count, "threshold": threshold},
                    "display_text": f"lookup_count_below_threshold ({lookup_count} < {threshold})",
                    "variant_id": variant_id,
                }
            )

        # Check cooldown
        cooldown_key = self._user_cooldown_key(user_id, "suggest_repeat_lookup")
        cooldown_until = await cache_service.get(cooldown_key)

        if cooldown_until:
            return (
                False,
                SuggestionDecision.NOT_SUGGESTED,
                {
                    "reason_code": "cooldown_active",
                    "reason_params": {"cooldown_until": cooldown_until},
                    "display_text": f"cooldown_active_until_{cooldown_until}",
                    "variant_id": variant_id,
                }
            )

        # All checks passed - get reason template style from A/B test
        template_style = ab_test_service.get_reason_template_style(user_id)
        reason_variant_id = ab_test_service.get_variant_id_for_logging(
            user_id, "reason_template_v1"
        )

        return (
            True,
            SuggestionDecision.SUGGESTED,
            {
                "reason_code": "repeated_lookup",
                "reason_params": {
                    "lookup_count": lookup_count,
                    "threshold": threshold,
                    "template_style": template_style,
                },
                "display_text": f"repeated_lookup_{lookup_count}_times",
                "variant_id": variant_id,
                "reason_variant_id": reason_variant_id,
            }
        )

    async def record_suggestion_feedback(
        self,
        db: AsyncSession,
        user_id: UUID,
        suggestion_log_id: UUID,
        response: UserSuggestionResponse,
        asset_id: Optional[UUID] = None,
    ) -> None:
        """
        Record user feedback on a suggestion.

        If dismissed, sets a cooldown to avoid re-suggesting.

        Args:
            db: Database session
            user_id: User UUID
            suggestion_log_id: ID of the suggestion log
            response: User's response (ACCEPT/DISMISS/IGNORE)
            asset_id: Created asset ID if accepted
        """
        # Get suggestion log
        log = await db.get(AssetSuggestionLog, suggestion_log_id)
        if not log or log.user_id != user_id:
            raise ValueError("Suggestion log not found or access denied")

        log.user_response = response.value
        log.response_at = datetime.now(timezone.utc)
        log.asset_id = asset_id

        # Set cooldown if dismissed
        if response == UserSuggestionResponse.DISMISS:
            cooldown_until = datetime.now(timezone.utc) + timedelta(days=DISMISS_COOLDOWN_DAYS)
            log.cooldown_until = cooldown_until

            cooldown_key = self._user_cooldown_key(user_id, "suggest_repeat_lookup")
            await cache_service.set(
                cooldown_key,
                cooldown_until.isoformat(),
                ttl=DISMISS_COOLDOWN_DAYS * 24 * 3600
            )

        await db.flush()

        logger.info(
            f"Recorded suggestion feedback: user={user_id}, "
            f"response={response.value}, cooldown_set={response == UserSuggestionResponse.DISMISS}"
        )

    # === Query Methods ===

    async def get_user_assets(
        self,
        db: AsyncSession,
        user_id: UUID,
        status: Optional[AssetStatus] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> List[LearningAsset]:
        """
        Get user's learning assets with optional status filter.

        Args:
            db: Database session
            user_id: User UUID
            status: Optional status filter
            limit: Max results
            offset: Pagination offset

        Returns:
            List of LearningAsset instances
        """
        query = select(LearningAsset).where(
            and_(
                LearningAsset.user_id == user_id,
                LearningAsset.deleted_at.is_(None),
            )
        )

        if status:
            query = query.where(LearningAsset.status == status.value)

        query = query.order_by(LearningAsset.created_at.desc())
        query = query.limit(limit).offset(offset)

        result = await db.execute(query)
        return list(result.scalars().all())

    async def get_asset_by_id(
        self,
        db: AsyncSession,
        asset_id: UUID,
        user_id: UUID,
    ) -> Optional[LearningAsset]:
        """
        Get a specific asset by ID, ensuring user ownership.

        Args:
            db: Database session
            asset_id: Asset UUID
            user_id: User UUID for ownership check

        Returns:
            LearningAsset or None
        """
        query = select(LearningAsset).where(
            and_(
                LearningAsset.id == asset_id,
                LearningAsset.user_id == user_id,
                LearningAsset.deleted_at.is_(None),
            )
        )
        result = await db.execute(query)
        return result.scalar_one_or_none()

    async def get_review_list(
        self,
        db: AsyncSession,
        user_id: UUID,
        limit: int = 50,
    ) -> List[LearningAsset]:
        """
        Get assets due for review.

        Args:
            db: Database session
            user_id: User UUID
            limit: Max results

        Returns:
            List of LearningAsset instances
        """
        now = datetime.now(timezone.utc)
        query = select(LearningAsset).where(
            and_(
                LearningAsset.user_id == user_id,
                LearningAsset.status == AssetStatus.ACTIVE.value,
                LearningAsset.review_due_at <= now,
                LearningAsset.deleted_at.is_(None),
            )
        ).order_by(LearningAsset.review_due_at.asc()).limit(limit)

        result = await db.execute(query)
        return list(result.scalars().all())

    async def get_inbox_stats(
        self,
        db: AsyncSession,
        user_id: UUID,
    ) -> Dict[str, Any]:
        """
        Get inbox statistics for user.
        
        Returns:
            dict with total_count, expiring_soon_count
        """
        now = datetime.now(timezone.utc)
        soon = now + timedelta(hours=24)
        
        query = select(
            func.count(LearningAsset.id).label("total"),
            func.sum(
                case(
                    (LearningAsset.inbox_expires_at <= soon, 1),
                    else_=0
                )
            ).label("expiring")
        ).where(
            and_(
                LearningAsset.user_id == user_id,
                LearningAsset.status == AssetStatus.INBOX.value,
                LearningAsset.deleted_at.is_(None),
            )
        )
        
        result = await db.execute(query)
        row = result.one()
        
        return {
            "total_count": row.total or 0,
            "expiring_soon_count": row.expiring or 0,
        }

    # === Inbox Decay ===

    async def process_inbox_expiry(self, db: AsyncSession) -> int:
        """
        Archive expired inbox items.

        Called by scheduled task to auto-archive stale inbox items.

        Returns:
            Number of assets archived
        """
        now = datetime.now(timezone.utc)

        # Find expired inbox items
        query = select(LearningAsset).where(
            and_(
                LearningAsset.status == AssetStatus.INBOX.value,
                LearningAsset.inbox_expires_at <= now,
                LearningAsset.deleted_at.is_(None),
            )
        ).limit(100)  # Process in batches

        result = await db.execute(query)
        expired_assets = result.scalars().all()

        count = 0
        for asset in expired_assets:
            await self.archive_asset(db, asset, reason="inbox_expired")
            count += 1

        if count > 0:
            logger.info(f"Processed inbox expiry: archived {count} assets")

        return count

    # === Event Outbox ===

    async def _write_event_outbox(
        self,
        db: AsyncSession,
        aggregate_type: str,
        aggregate_id: UUID,
        event_type: str,
        payload: Dict[str, Any],
    ) -> None:
        """
        Write event to outbox for async processing.

        Uses the existing event_outbox table from CQRS infrastructure.
        The sequence_number is computed as the next number for this aggregate.
        """
        # Get next sequence number for this aggregate
        # Use a dedicated counter table to avoid races and preserve monotonicity.
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
                "metadata": json.dumps({"service": "learning_asset_service"}),
            }
        )

    # === Spaced Repetition System (SRS) ===

    # Simplified SM-2 inspired intervals (in days)
    # Based on user self-assessment: easy/good/hard
    REVIEW_INTERVALS = {
        'easy': [1, 3, 7, 16, 35, 70],   # Fast progression
        'good': [1, 2, 5, 10, 21, 45],   # Standard progression
        'hard': [1, 1, 3, 7, 15, 30],    # Slow progression
    }

    async def record_review(
        self,
        db: AsyncSession,
        user_id: UUID,
        asset_id: UUID,
        difficulty: str,  # 'easy', 'good', 'hard'
    ) -> LearningAsset:
        """
        Record a review result and schedule next review.

        Implements simplified SM-2 algorithm with three difficulty levels.

        Args:
            db: Database session
            user_id: User UUID
            asset_id: Asset UUID
            difficulty: User's assessment ('easy', 'good', 'hard')

        Returns:
            Updated LearningAsset with new review_due_at

        Raises:
            ValueError: If difficulty is invalid or asset not found
        """
        if difficulty not in self.REVIEW_INTERVALS:
            raise ValueError(f"Invalid difficulty: {difficulty}. Must be 'easy', 'good', or 'hard'")

        # Get asset
        asset = await db.get(LearningAsset, asset_id)
        if not asset or asset.user_id != user_id or asset.deleted_at is not None:
            raise ValueError(f"Asset not found: {asset_id}")

        if asset.status != AssetStatus.ACTIVE.value:
            raise ValueError(f"Asset is not active: {asset_id}")

        # Get interval based on review count and difficulty
        intervals = self.REVIEW_INTERVALS[difficulty]
        interval_index = min(asset.review_count, len(intervals) - 1)
        days_until_next = intervals[interval_index]

        # Update review statistics
        now = datetime.now(timezone.utc)
        asset.review_count += 1
        asset.last_seen_at = now
        asset.review_due_at = now + timedelta(days=days_until_next)

        # Update success rate (simple moving average)
        # easy=1.0, good=0.7, hard=0.3
        success_score = {'easy': 1.0, 'good': 0.7, 'hard': 0.3}[difficulty]
        if asset.review_count == 1:
            asset.review_success_rate = success_score
        else:
            # Exponential moving average (alpha=0.3)
            alpha = 0.3
            asset.review_success_rate = (
                alpha * success_score + (1 - alpha) * asset.review_success_rate
            )

        await db.flush()

        logger.info(
            f"Review recorded: asset={asset_id}, difficulty={difficulty}, "
            f"next_review={asset.review_due_at}, count={asset.review_count}"
        )

        # Write event for audit
        await self._write_event_outbox(
            db=db,
            aggregate_type="learning_asset",
            aggregate_id=asset_id,
            event_type="review_recorded",
            payload={
                "asset_id": str(asset_id),
                "user_id": str(user_id),
                "difficulty": difficulty,
                "review_count": asset.review_count,
                "next_review_at": asset.review_due_at.isoformat(),
                "success_rate": asset.review_success_rate,
            },
        )

        return asset

    # === Phase 9: Review Calibration ===

    async def record_review_with_calibration(
        self,
        db: AsyncSession,
        user_id: UUID,
        asset_id: UUID,
        difficulty: str,
    ) -> Tuple[LearningAsset, Dict[str, Any]]:
        """
        Record review with personalized interval calibration.

        Analyzes recent review patterns and adjusts intervals accordingly:
        - Consecutive hard: Shorten intervals (learning difficulty)
        - Consecutive easy: Lengthen intervals (mastery acceleration)

        Returns:
            Tuple of (updated asset, calibration info dict)
        """
        from app.models.review_calibration import ReviewCalibrationLog

        if difficulty not in self.REVIEW_INTERVALS:
            raise ValueError(f"Invalid difficulty: {difficulty}")

        asset = await db.get(LearningAsset, asset_id)
        if not asset or asset.user_id != user_id or asset.deleted_at is not None:
            raise ValueError(f"Asset not found: {asset_id}")

        if asset.status != AssetStatus.ACTIVE.value:
            raise ValueError(f"Asset is not active: {asset_id}")

        # 1. Get interval before update
        interval_before = None
        if asset.review_due_at and asset.last_seen_at:
            interval_before = (asset.review_due_at - asset.last_seen_at).days

        # 2. Check calibration adjustment
        adjustment = await self._check_interval_adjustment(db, user_id, asset_id)

        # 3. Calculate base interval
        base_intervals = self.REVIEW_INTERVALS[difficulty]
        interval_index = min(asset.review_count, len(base_intervals) - 1)
        base_interval = base_intervals[interval_index]

        # 4. Apply adjustment if needed
        if adjustment["should_adjust"]:
            factor = adjustment.get("factor", 1.0)
            adjusted_interval = max(1, int(base_interval * factor))
        else:
            adjusted_interval = base_interval

        # 5. Update asset
        now = datetime.now(timezone.utc)
        asset.review_count += 1
        asset.last_seen_at = now
        asset.review_due_at = now + timedelta(days=adjusted_interval)

        # 6. Update success rate
        success_score = {'easy': 1.0, 'good': 0.7, 'hard': 0.3}[difficulty]
        alpha = 0.3
        if asset.review_count == 1:
            asset.review_success_rate = success_score
        else:
            asset.review_success_rate = alpha * success_score + (1 - alpha) * asset.review_success_rate

        # 7. Record calibration log
        calibration_log = ReviewCalibrationLog(
            user_id=user_id,
            asset_id=asset_id,
            reviewed_at=now,
            difficulty=difficulty,
            review_count=asset.review_count,
            interval_days_before=interval_before,
            interval_days_after=adjusted_interval,
            explanation_code=adjustment.get("explanation_code", "standard"),
            metadata={
                "base_interval": base_interval,
                "adjustment_factor": adjustment.get("factor", 1.0),
            },
        )
        db.add(calibration_log)

        await db.flush()

        # 8. Write event
        await self._write_event_outbox(
            db=db,
            aggregate_type="learning_asset",
            aggregate_id=asset_id,
            event_type="review_calibrated",
            payload={
                "asset_id": str(asset_id),
                "user_id": str(user_id),
                "difficulty": difficulty,
                "interval_days": adjusted_interval,
                "review_count": asset.review_count,
                "explanation_code": adjustment.get("explanation_code", "standard"),
                "adjustment_factor": adjustment.get("factor", 1.0),
            },
        )

        logger.info(
            f"Calibrated review: asset={asset_id}, difficulty={difficulty}, "
            f"interval={adjusted_interval}d, explanation={adjustment.get('explanation_code', 'standard')}"
        )

        return asset, {
            "interval_days": adjusted_interval,
            "explanation_code": adjustment.get("explanation_code", "standard"),
            "next_review_at": asset.review_due_at.isoformat(),
            "adjustment_factor": adjustment.get("factor", 1.0),
        }

    async def _check_interval_adjustment(
        self,
        db: AsyncSession,
        user_id: UUID,
        asset_id: UUID,
    ) -> Dict[str, Any]:
        """
        Check if interval adjustment is needed based on review patterns.

        Rules:
        - 3 consecutive hard → factor=0.5 (halve interval)
        - 3 consecutive easy → factor=1.5 (extend interval 50%)
        """
        from app.models.review_calibration import ReviewCalibrationLog

        query = select(ReviewCalibrationLog).where(
            and_(
                ReviewCalibrationLog.user_id == user_id,
                ReviewCalibrationLog.asset_id == asset_id,
            )
        ).order_by(ReviewCalibrationLog.reviewed_at.desc()).limit(5)

        result = await db.execute(query)
        recent_logs = list(result.scalars().all())

        if len(recent_logs) < 3:
            return {"should_adjust": False}

        # Check last 3 difficulties
        last_three = [log.difficulty for log in recent_logs[:3]]

        # Rule: 3 consecutive hard
        if last_three == ["hard", "hard", "hard"]:
            return {
                "should_adjust": True,
                "factor": 0.5,
                "explanation_code": "learning_difficulty_adjusted",
            }

        # Rule: 3 consecutive easy
        if last_three == ["easy", "easy", "easy"]:
            return {
                "should_adjust": True,
                "factor": 1.5,
                "explanation_code": "mastery_accelerated",
            }

        return {"should_adjust": False}

    def calculate_next_review(
        self,
        review_count: int,
        difficulty: str,
    ) -> int:
        """
        Calculate days until next review (pure function for testing).

        Args:
            review_count: Current number of successful reviews
            difficulty: User's assessment ('easy', 'good', 'hard')

        Returns:
            Number of days until next review
        """
        if difficulty not in self.REVIEW_INTERVALS:
            raise ValueError(f"Invalid difficulty: {difficulty}")

        intervals = self.REVIEW_INTERVALS[difficulty]
        interval_index = min(review_count, len(intervals) - 1)
        return intervals[interval_index]

    # === Semantic Search ===

    async def generate_asset_embedding(
        self,
        db: AsyncSession,
        asset: LearningAsset,
    ) -> bool:
        """
        Generate and store embedding for an asset.

        Uses the headword + definition + translation for semantic representation.
        Gracefully degrades if embedding service is unavailable.

        Args:
            db: Database session
            asset: LearningAsset to generate embedding for

        Returns:
            True if embedding was generated, False otherwise
        """
        try:
            # Build text for embedding
            parts = [asset.headword]
            if asset.definition:
                parts.append(asset.definition)
            if asset.translation:
                parts.append(asset.translation)
            text = " ".join(parts)

            # Generate embedding
            embedding = await embedding_service.get_embedding(text)

            # Store embedding
            asset.embedding = embedding
            asset.embedding_updated_at = datetime.now(timezone.utc)
            await db.flush()

            logger.debug(f"Generated embedding for asset {asset.id}")
            return True

        except Exception as e:
            logger.warning(f"Failed to generate embedding for asset {asset.id}: {e}")
            return False

    async def semantic_search(
        self,
        db: AsyncSession,
        user_id: UUID,
        query: str,
        limit: int = 20,
        status: Optional[AssetStatus] = None,
    ) -> List[LearningAsset]:
        """
        Search assets using semantic similarity.

        Falls back to text matching if embedding service is unavailable.

        Args:
            db: Database session
            user_id: User UUID
            query: Search query
            limit: Maximum results
            status: Optional status filter

        Returns:
            List of matching assets, ordered by relevance
        """
        try:
            # Generate query embedding
            query_embedding = await embedding_service.get_embedding(query)

            # Build conditions
            conditions = [
                LearningAsset.user_id == user_id,
                LearningAsset.deleted_at.is_(None),
                LearningAsset.embedding.isnot(None),
            ]
            if status:
                conditions.append(LearningAsset.status == status.value)

            # Semantic search using cosine distance
            # pgvector uses <=> for cosine distance (lower = more similar)
            query = select(LearningAsset).where(
                and_(*conditions)
            ).order_by(
                LearningAsset.embedding.cosine_distance(query_embedding)
            ).limit(limit)

            result = await db.execute(query)
            return list(result.scalars().all())

        except Exception as e:
            logger.warning(f"Semantic search failed, falling back to text search: {e}")
            return await self._fallback_text_search(db, user_id, query, limit, status)

    async def _fallback_text_search(
        self,
        db: AsyncSession,
        user_id: UUID,
        query: str,
        limit: int,
        status: Optional[AssetStatus] = None,
    ) -> List[LearningAsset]:
        """
        Fallback text search using ILIKE.

        Used when embedding service is unavailable.
        """
        conditions = [
            LearningAsset.user_id == user_id,
            LearningAsset.deleted_at.is_(None),
        ]
        if status:
            conditions.append(LearningAsset.status == status.value)

        # Text search on headword and definition
        search_pattern = f"%{query}%"
        text_conditions = [
            LearningAsset.headword.ilike(search_pattern),
            LearningAsset.definition.ilike(search_pattern),
            LearningAsset.translation.ilike(search_pattern),
        ]

        from sqlalchemy import or_
        query_stmt = select(LearningAsset).where(
            and_(*conditions, or_(*text_conditions))
        ).order_by(LearningAsset.updated_at.desc()).limit(limit)

        result = await db.execute(query_stmt)
        return list(result.scalars().all())

    async def batch_generate_embeddings(
        self,
        db: AsyncSession,
        user_id: UUID,
        batch_size: int = 50,
    ) -> int:
        """
        Generate embeddings for assets that don't have them.

        Called by background task to backfill embeddings.

        Args:
            db: Database session
            user_id: User UUID
            batch_size: Number of assets to process

        Returns:
            Number of embeddings generated
        """
        # Find assets without embeddings
        query = select(LearningAsset).where(
            and_(
                LearningAsset.user_id == user_id,
                LearningAsset.embedding.is_(None),
                LearningAsset.deleted_at.is_(None),
            )
        ).limit(batch_size)

        result = await db.execute(query)
        assets = list(result.scalars().all())

        count = 0
        for asset in assets:
            success = await self.generate_asset_embedding(db, asset)
            if success:
                count += 1

        if count > 0:
            logger.info(f"Generated {count} embeddings for user {user_id}")

        return count


# Singleton instance
learning_asset_service = LearningAssetService()
