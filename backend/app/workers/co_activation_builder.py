"""
Co-Activation Edge Builder

Phase 9: Builds user-specific co_activation edges between concepts.

Daily task that:
1. Analyzes user's recent asset-concept links
2. Creates co_activation edges between concepts accessed in same time window
3. Updates edge weights using exponential decay
"""
import asyncio
from datetime import datetime, timedelta, timezone
from typing import List, Tuple
from uuid import UUID
import logging

from celery import shared_task
from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import AsyncSessionLocal
from app.models.asset_concept_link import AssetConceptLink
from app.models.galaxy import NodeRelation

logger = logging.getLogger(__name__)


# === Configuration ===
CO_ACTIVATION_WINDOW_DAYS = 7  # Look back window for co-activation
INITIAL_EDGE_STRENGTH = 0.3   # Initial strength for new edges
STRENGTH_DECAY_FACTOR = 0.9   # Decay factor per day
STRENGTH_BOOST_FACTOR = 0.1   # Boost when edge is re-observed
MAX_EDGE_STRENGTH = 0.9       # Cap edge strength


async def _build_co_activation_edges_for_user(
    db: AsyncSession,
    user_id: UUID,
    window_days: int = CO_ACTIVATION_WINDOW_DAYS,
) -> int:
    """
    Build co_activation edges for a single user.

    Algorithm:
    1. Get all concept IDs from user's recent asset-concept links
    2. For each pair of concepts accessed in window, create/update edge
    3. Apply exponential decay to existing edge strengths

    Args:
        db: Database session
        user_id: User UUID
        window_days: Lookback window in days

    Returns:
        Number of edges created/updated
    """
    cutoff = datetime.now(timezone.utc) - timedelta(days=window_days)
    edges_modified = 0

    # 1. Get unique concepts from recent links
    query = select(AssetConceptLink.concept_id).where(
        and_(
            AssetConceptLink.user_id == user_id,
            AssetConceptLink.created_at >= cutoff,
            AssetConceptLink.deleted_at.is_(None),
        )
    ).distinct()

    result = await db.execute(query)
    concept_ids = [row[0] for row in result.fetchall()]

    if len(concept_ids) < 2:
        logger.debug(f"User {user_id}: fewer than 2 concepts in window, skipping")
        return 0

    # 2. Create/update edges between concept pairs
    for i, c1 in enumerate(concept_ids):
        for c2 in concept_ids[i + 1:]:
            # Ensure consistent ordering (smaller UUID first)
            source_id, target_id = (c1, c2) if str(c1) < str(c2) else (c2, c1)

            # Check for existing edge
            existing_query = select(NodeRelation).where(
                and_(
                    NodeRelation.source_node_id == source_id,
                    NodeRelation.target_node_id == target_id,
                    NodeRelation.user_id == user_id,
                    NodeRelation.relation_type == "co_activation",
                    NodeRelation.deleted_at.is_(None),
                )
            )
            existing_result = await db.execute(existing_query)
            existing = existing_result.scalar_one_or_none()

            if existing:
                # Boost existing edge strength
                new_strength = min(
                    existing.strength + STRENGTH_BOOST_FACTOR,
                    MAX_EDGE_STRENGTH
                )
                existing.strength = new_strength
                existing.updated_at = datetime.now(timezone.utc)
                logger.debug(
                    f"Updated co_activation edge {source_id} → {target_id}: "
                    f"strength={new_strength:.2f}"
                )
            else:
                # Create new edge
                edge = NodeRelation(
                    source_node_id=source_id,
                    target_node_id=target_id,
                    user_id=user_id,
                    relation_type="co_activation",
                    strength=INITIAL_EDGE_STRENGTH,
                    created_by="system",
                )
                db.add(edge)
                logger.debug(
                    f"Created co_activation edge {source_id} → {target_id}: "
                    f"strength={INITIAL_EDGE_STRENGTH}"
                )

            edges_modified += 1

    await db.flush()
    return edges_modified


async def _decay_old_edges(
    db: AsyncSession,
    user_id: UUID,
) -> int:
    """
    Apply decay to edges not observed recently.

    Edges not updated in the last window period have their strength decayed.
    """
    cutoff = datetime.now(timezone.utc) - timedelta(days=CO_ACTIVATION_WINDOW_DAYS)

    # Find edges that haven't been updated recently
    query = select(NodeRelation).where(
        and_(
            NodeRelation.user_id == user_id,
            NodeRelation.relation_type == "co_activation",
            NodeRelation.updated_at < cutoff,
            NodeRelation.deleted_at.is_(None),
        )
    )

    result = await db.execute(query)
    old_edges = list(result.scalars().all())

    decayed_count = 0
    for edge in old_edges:
        # Apply decay
        new_strength = edge.strength * STRENGTH_DECAY_FACTOR

        if new_strength < 0.1:
            # Soft delete very weak edges
            edge.deleted_at = datetime.now(timezone.utc)
            logger.debug(f"Soft deleted weak edge {edge.source_node_id} → {edge.target_node_id}")
        else:
            edge.strength = new_strength
            edge.updated_at = datetime.now(timezone.utc)

        decayed_count += 1

    await db.flush()
    return decayed_count


async def _run_co_activation_builder():
    """
    Main entry point for co-activation edge building.

    Processes all active users.
    """
    from sqlalchemy import select
    from app.models.user import User

    logger.info("Starting co-activation edge builder")

    async with AsyncSessionLocal() as db:
        try:
            # Get all active users with recent asset-concept links
            cutoff = datetime.now(timezone.utc) - timedelta(days=CO_ACTIVATION_WINDOW_DAYS)

            user_query = select(AssetConceptLink.user_id).where(
                and_(
                    AssetConceptLink.created_at >= cutoff,
                    AssetConceptLink.deleted_at.is_(None),
                )
            ).distinct()

            result = await db.execute(user_query)
            active_user_ids = [row[0] for row in result.fetchall()]

            logger.info(f"Found {len(active_user_ids)} users with recent activity")

            total_edges = 0
            total_decayed = 0

            for user_id in active_user_ids:
                try:
                    edges = await _build_co_activation_edges_for_user(db, user_id)
                    decayed = await _decay_old_edges(db, user_id)
                    total_edges += edges
                    total_decayed += decayed
                except Exception as e:
                    logger.error(f"Error processing user {user_id}: {e}")
                    continue

            await db.commit()

            logger.info(
                f"Co-activation builder completed: "
                f"{total_edges} edges created/updated, {total_decayed} edges decayed"
            )
            return total_edges

        except Exception as e:
            await db.rollback()
            logger.error(f"Error in co-activation builder: {e}")
            return 0


@shared_task(name="build_co_activation_edges")
def build_co_activation_edges():
    """
    Celery task to build co-activation edges.

    Should be scheduled to run daily (e.g., via Celery Beat).
    Processes all users with recent asset-concept link activity.
    """
    return asyncio.run(_run_co_activation_builder())
