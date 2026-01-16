"""
Galaxy Layout Service - Incremental Concept Positioning

Phase 9 M5.2: 为新概念计算增量位置
- kNN neighbor centroid calculation
- 24-hour position cooldown
- No full graph re-layout (incremental only)
"""
import random
from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple, List
from uuid import UUID

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from loguru import logger

from app.models.galaxy import KnowledgeNode


# Configuration
POSITION_COOLDOWN_HOURS = 24
KNN_NEIGHBORS = 5
DEFAULT_SPREAD_RADIUS = 50.0
GALAXY_CENTER = (0.0, 0.0)
POSITION_JITTER = 10.0  # Random offset to prevent overlap


class GalaxyLayoutService:
    """
    Service for incremental galaxy layout calculations.

    Design principles:
    1. Never trigger full graph re-layout
    2. Use kNN neighbor centroid for new nodes
    3. Respect 24-hour position update cooldown
    4. Fall back to random positioning when no neighbors exist
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    async def compute_position_for_concept(
        self,
        concept_id: UUID,
        embedding: Optional[List[float]] = None,
        force: bool = False
    ) -> Tuple[float, float]:
        """
        Compute incremental position for a concept node.

        Algorithm:
        1. Check if position already set and not in cooldown
        2. Find k nearest neighbors by embedding similarity
        3. Compute centroid of neighbor positions
        4. Add small jitter to prevent overlap
        5. Update node position with cooldown timestamp

        Args:
            concept_id: The concept node ID
            embedding: Optional embedding vector (if not provided, uses node's embedding)
            force: Bypass cooldown check

        Returns:
            Tuple of (position_x, position_y)
        """
        # 1. Get the concept node
        node = await self.db.get(KnowledgeNode, concept_id)
        if not node:
            logger.warning(f"Node {concept_id} not found for positioning")
            return self._random_position()

        # 2. Check cooldown
        if not force and node.position_updated_at:
            cooldown_end = node.position_updated_at + timedelta(hours=POSITION_COOLDOWN_HOURS)
            if datetime.now(timezone.utc) < cooldown_end:
                logger.debug(f"Node {concept_id} in position cooldown until {cooldown_end}")
                return (node.position_x or 0.0, node.position_y or 0.0)

        # 3. Use provided embedding or node's embedding
        search_embedding = embedding
        if search_embedding is None and node.embedding is not None:
            search_embedding = list(node.embedding)

        # 4. Find kNN neighbors with positions
        neighbors = await self._find_positioned_neighbors(
            concept_id,
            search_embedding,
            limit=KNN_NEIGHBORS
        )

        # 5. Compute position
        if neighbors:
            position_x, position_y = self._compute_centroid(neighbors)
            # Add jitter to prevent exact overlap
            position_x += random.uniform(-POSITION_JITTER, POSITION_JITTER)
            position_y += random.uniform(-POSITION_JITTER, POSITION_JITTER)
        else:
            # No neighbors - use random position
            position_x, position_y = self._random_position()

        # 6. Update node position
        node.position_x = position_x
        node.position_y = position_y
        node.position_updated_at = datetime.now(timezone.utc)

        self.db.add(node)
        await self.db.flush()

        logger.info(f"Positioned node {concept_id} at ({position_x:.2f}, {position_y:.2f})")
        return (position_x, position_y)

    async def _find_positioned_neighbors(
        self,
        exclude_id: UUID,
        embedding: Optional[List[float]],
        limit: int = KNN_NEIGHBORS
    ) -> List[Tuple[float, float]]:
        """
        Find k nearest neighbors that have positions set.

        Uses pgvector cosine similarity for embedding-based search.
        Falls back to random positioned nodes if no embedding.
        """
        if embedding is None:
            # No embedding - return random positioned nodes
            query = (
                select(KnowledgeNode.position_x, KnowledgeNode.position_y)
                .where(KnowledgeNode.id != exclude_id)
                .where(KnowledgeNode.position_x.isnot(None))
                .where(KnowledgeNode.position_y.isnot(None))
                .where(KnowledgeNode.deleted_at.is_(None))
                .order_by(KnowledgeNode.created_at.desc())
                .limit(limit)
            )
            result = await self.db.execute(query)
            rows = result.fetchall()
            return [(float(row[0]), float(row[1])) for row in rows]

        # Use pgvector similarity search
        # Note: Using raw SQL for pgvector <=> operator
        embedding_str = "[" + ",".join(str(v) for v in embedding) + "]"

        query = text("""
            SELECT position_x, position_y,
                   embedding <=> :embedding::vector AS distance
            FROM knowledge_nodes
            WHERE id != :exclude_id
              AND position_x IS NOT NULL
              AND position_y IS NOT NULL
              AND embedding IS NOT NULL
              AND deleted_at IS NULL
            ORDER BY distance ASC
            LIMIT :limit
        """)

        result = await self.db.execute(query, {
            "embedding": embedding_str,
            "exclude_id": str(exclude_id),
            "limit": limit
        })
        rows = result.fetchall()
        return [(float(row[0]), float(row[1])) for row in rows]

    def _compute_centroid(self, positions: List[Tuple[float, float]]) -> Tuple[float, float]:
        """Compute centroid of given positions."""
        if not positions:
            return GALAXY_CENTER

        sum_x = sum(p[0] for p in positions)
        sum_y = sum(p[1] for p in positions)
        n = len(positions)

        return (sum_x / n, sum_y / n)

    def _random_position(self) -> Tuple[float, float]:
        """Generate random position in galaxy space."""
        # Random angle and radius for polar distribution
        import math
        angle = random.uniform(0, 2 * math.pi)
        radius = random.uniform(0, DEFAULT_SPREAD_RADIUS)

        x = GALAXY_CENTER[0] + radius * math.cos(angle)
        y = GALAXY_CENTER[1] + radius * math.sin(angle)

        return (x, y)

    async def batch_position_new_concepts(
        self,
        concept_ids: List[UUID]
    ) -> dict[UUID, Tuple[float, float]]:
        """
        Batch position multiple new concepts.
        Processes sequentially to avoid overlap issues.

        Args:
            concept_ids: List of concept IDs to position

        Returns:
            Dict mapping concept_id to (x, y) position
        """
        results = {}
        for concept_id in concept_ids:
            position = await self.compute_position_for_concept(concept_id)
            results[concept_id] = position
        return results

    async def is_position_locked(self, concept_id: UUID) -> bool:
        """
        Check if a concept's position is locked (in cooldown).

        Args:
            concept_id: The concept node ID

        Returns:
            True if position is locked, False otherwise
        """
        node = await self.db.get(KnowledgeNode, concept_id)
        if not node or not node.position_updated_at:
            return False

        cooldown_end = node.position_updated_at + timedelta(hours=POSITION_COOLDOWN_HOURS)
        return datetime.now(timezone.utc) < cooldown_end

    async def get_cooldown_remaining(self, concept_id: UUID) -> Optional[timedelta]:
        """
        Get remaining cooldown time for position updates.

        Args:
            concept_id: The concept node ID

        Returns:
            Remaining cooldown time, or None if not locked
        """
        node = await self.db.get(KnowledgeNode, concept_id)
        if not node or not node.position_updated_at:
            return None

        cooldown_end = node.position_updated_at + timedelta(hours=POSITION_COOLDOWN_HOURS)
        now = datetime.now(timezone.utc)

        if now >= cooldown_end:
            return None

        return cooldown_end - now
