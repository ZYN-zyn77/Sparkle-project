"""
Knowledge Asset Bridge Service

Bridges the gap between the legacy KnowledgeNode system (Galaxy) and the new LearningAsset system.
Ensures that when KnowledgeNodes are created (e.g., via translation), corresponding LearningAssets are created/synced.
"""
from uuid import UUID
from typing import Optional
from loguru import logger
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.galaxy import KnowledgeNode
from app.models.learning_assets import AssetStatus, AssetKind
from app.services.learning_asset_service import learning_asset_service

class KnowledgeAssetBridgeService:
    """Service to bridge KnowledgeNodes and LearningAssets."""

    def __init__(self, db_session: AsyncSession):
        self.db = db_session

    async def sync_node_to_asset(self, node: KnowledgeNode, user_id: UUID) -> None:
        """
        Sync a KnowledgeNode to a LearningAsset.
        
        If the LearningAsset doesn't exist, it creates one.
        Updates status based on KnowledgeNode status.
        """
        try:
            # Determine target status
            # Phase 1 fixed KnowledgeNode to 'published', so we map that to ACTIVE
            # If we revert to 'draft', map to INBOX
            target_status = AssetStatus.ACTIVE if node.status == "published" else AssetStatus.INBOX
            
            # Check existence via LearningAssetService logic (fingerprint based)
            # We generate fingerprint from node.name
            from app.core.fingerprint import generate_fingerprints
            fp_result = generate_fingerprints(node.name)
            
            existing_asset = await learning_asset_service.check_existing_asset(
                self.db, 
                user_id, 
                fp_result.selection_fp
            )

            if existing_asset:
                # Update status if needed
                if existing_asset.status != target_status.value:
                    # Only upgrade INBOX -> ACTIVE, never downgrade ACTIVE -> INBOX automatically
                    if existing_asset.status == AssetStatus.INBOX.value and target_status == AssetStatus.ACTIVE:
                        await learning_asset_service.activate_asset(self.db, existing_asset)
                        logger.info(f"🔄 Bridged: Activated asset {existing_asset.id} for node {node.id}")
                return

            # Extract context/translation from description
            # Description format: "**中文译文**: translation\n\n**使用场景**:\ncontext..."
            # Simple parsing or just pass full description as definition/context
            
            # For MVP, we pass available data
            # context is harder to extract reliably without parsing, but we can try basic heuristics
            # or just rely on what we have.
            
            # Actually, create_vocabulary_node has the raw inputs. 
            # But here we only have the Node. 
            # Ideally, the Bridge should be called with the raw data if possible, 
            # OR we parse the description.
            
            # Let's try to extract translation from description if possible
            translation = None
            if node.description and "**中文译文**: " in node.description:
                try:
                    part = node.description.split("**中文译文**: ")[1]
                    translation = part.split("\n")[0].strip()
                except IndexError:
                    pass

            await learning_asset_service.create_asset_from_selection(
                db=self.db,
                user_id=user_id,
                selected_text=node.name,
                translation=translation,
                definition=node.description, # Use full description as definition backup
                source_file_id=node.source_file_id,
                initial_status=target_status,
                asset_kind=AssetKind.WORD, # Default to WORD for vocabulary nodes
            )
            logger.info(f"🌉 Bridged: Created LearningAsset for node {node.id} ({node.name})")

        except Exception as e:
            logger.error(f"Failed to sync node {node.id} to asset: {e}")
            # Don't raise, bridging failure shouldn't block main flow

