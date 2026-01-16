"""
Phase 9 Integration Tests - Three Flywheels

Tests critical paths for:
1. Asset → Graph Flywheel (Provenance linking)
2. Review → Personalization Flywheel (SRS calibration)
3. Multi-device Sync Flywheel (Event replay)

Run with: pytest tests/integration/test_phase9_flywheels.py -v
"""
import json
import uuid
from datetime import datetime, timedelta, timezone
from typing import AsyncGenerator
from unittest.mock import AsyncMock, patch

import pytest
import pytest_asyncio
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

# Test configuration
DATABASE_URL = "postgresql+asyncpg://sparkle:sparkle@localhost:5432/sparkle_test"


# === Fixtures ===

@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Create a test database session with transaction rollback."""
    engine = create_async_engine(DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        # Start transaction
        async with session.begin():
            yield session
            # Rollback at end of test
            await session.rollback()


@pytest.fixture
def test_user_id() -> uuid.UUID:
    """Generate a consistent test user ID."""
    return uuid.uuid4()


@pytest.fixture
def test_asset_data(test_user_id: uuid.UUID) -> dict:
    """Sample asset data for testing."""
    return {
        "user_id": test_user_id,
        "headword": "photosynthesis",
        "translation": "光合作用",
        "definition": "The process by which plants convert light energy into chemical energy",
        "language_code": "en",
        "provenance_json": {
            "chunk_id": "chunk_123",
            "doc_id": "doc_456",
            "match_strength": "STRONG",
            "score": 0.92,
        },
    }


# === Flywheel 1: Asset → Graph Tests ===

class TestAssetGraphFlywheel:
    """Tests for Asset → Graph concept linking."""

    @pytest.mark.asyncio
    async def test_new_asset_creates_concept_link(
        self,
        db_session: AsyncSession,
        test_user_id: uuid.UUID,
        test_asset_data: dict,
    ):
        """
        AC1: Creating a new asset should automatically:
        1. Find or create a concept node
        2. Create a provenance link
        3. Write event to outbox
        """
        from app.models.learning_assets import LearningAsset
        from app.services.asset_concept_link_service import AssetConceptLinkService

        # Create asset
        asset = LearningAsset(**test_asset_data)
        db_session.add(asset)
        await db_session.flush()
        await db_session.refresh(asset)

        # Generate links
        service = AssetConceptLinkService()
        links = await service.generate_links_for_asset(db_session, asset)

        # Assertions
        assert len(links) == 1
        link = links[0]
        assert link.asset_id == asset.id
        assert link.concept_id is not None
        assert link.link_type == "provenance"
        assert link.confidence == 0.9  # STRONG → 0.9

        # Verify event was written
        result = await db_session.execute(
            text("""
                SELECT event_type, payload FROM event_outbox
                WHERE aggregate_type = 'asset_concept_link'
                ORDER BY created_at DESC LIMIT 1
            """)
        )
        event = result.fetchone()
        assert event is not None
        assert event[0] == "link_upserted"

    @pytest.mark.asyncio
    async def test_concept_reuse_on_duplicate_headword(
        self,
        db_session: AsyncSession,
        test_user_id: uuid.UUID,
        test_asset_data: dict,
    ):
        """
        AC2: Two assets with same headword should link to the same concept.
        """
        from app.models.learning_assets import LearningAsset
        from app.services.asset_concept_link_service import AssetConceptLinkService

        service = AssetConceptLinkService()

        # Create first asset
        asset1 = LearningAsset(**test_asset_data)
        db_session.add(asset1)
        await db_session.flush()
        links1 = await service.generate_links_for_asset(db_session, asset1)

        # Create second asset with same headword
        asset2_data = {**test_asset_data, "translation": "植物光合作用"}
        asset2 = LearningAsset(**asset2_data)
        db_session.add(asset2)
        await db_session.flush()
        links2 = await service.generate_links_for_asset(db_session, asset2)

        # Same concept should be reused
        assert links1[0].concept_id == links2[0].concept_id

    @pytest.mark.asyncio
    async def test_metadata_size_guardrail(
        self,
        db_session: AsyncSession,
        test_user_id: uuid.UUID,
    ):
        """
        AC3: Metadata exceeding 2KB should be truncated.
        """
        from app.models.learning_assets import LearningAsset
        from app.services.asset_concept_link_service import AssetConceptLinkService

        # Create asset with large provenance
        large_provenance = {
            "chunk_id": "chunk_123",
            "doc_id": "doc_456",
            "match_strength": "STRONG",
            "large_field": "x" * 3000,  # Exceeds 2KB
        }

        asset = LearningAsset(
            user_id=test_user_id,
            headword="test",
            language_code="en",
            provenance_json=large_provenance,
        )
        db_session.add(asset)
        await db_session.flush()

        service = AssetConceptLinkService()
        links = await service.generate_links_for_asset(db_session, asset)

        # Metadata should be truncated
        link = links[0]
        metadata_size = len(json.dumps(link.metadata or {}))
        assert metadata_size <= 2048


# === Flywheel 2: Review → Personalization Tests ===

class TestReviewPersonalizationFlywheel:
    """Tests for Review → Personalization SRS calibration."""

    @pytest.mark.asyncio
    async def test_consecutive_hard_triggers_calibration(
        self,
        db_session: AsyncSession,
        test_user_id: uuid.UUID,
        test_asset_data: dict,
    ):
        """
        AC4: 3 consecutive hard reviews should log calibration event.
        """
        from app.models.learning_assets import LearningAsset
        from app.services.learning_asset_service import LearningAssetService

        # Create asset
        asset = LearningAsset(**test_asset_data)
        asset.status = "ACTIVE"
        asset.current_interval_days = 7
        db_session.add(asset)
        await db_session.flush()
        await db_session.refresh(asset)

        service = LearningAssetService(db_session)

        # Simulate 3 consecutive hard reviews
        for i in range(3):
            await service.record_review_with_calibration(
                asset_id=asset.id,
                response_quality=2,  # hard
            )

        # Check calibration log was created
        result = await db_session.execute(
            text("""
                SELECT action_taken, old_interval, new_interval
                FROM review_calibration_logs
                WHERE asset_id = :asset_id
                ORDER BY created_at DESC LIMIT 1
            """),
            {"asset_id": asset.id}
        )
        calibration = result.fetchone()

        assert calibration is not None
        assert calibration[0] == "interval_reduced"
        # New interval should be less than old
        assert calibration[2] < calibration[1]

    @pytest.mark.asyncio
    async def test_consecutive_easy_extends_interval(
        self,
        db_session: AsyncSession,
        test_user_id: uuid.UUID,
        test_asset_data: dict,
    ):
        """
        AC5: 3 consecutive easy reviews should extend interval.
        """
        from app.models.learning_assets import LearningAsset
        from app.services.learning_asset_service import LearningAssetService

        # Create asset
        asset = LearningAsset(**test_asset_data)
        asset.status = "ACTIVE"
        asset.current_interval_days = 3
        db_session.add(asset)
        await db_session.flush()
        await db_session.refresh(asset)

        service = LearningAssetService(db_session)

        # Simulate 3 consecutive easy reviews
        for i in range(3):
            await service.record_review_with_calibration(
                asset_id=asset.id,
                response_quality=5,  # easy
            )

        # Check calibration log
        result = await db_session.execute(
            text("""
                SELECT action_taken, old_interval, new_interval
                FROM review_calibration_logs
                WHERE asset_id = :asset_id
                ORDER BY created_at DESC LIMIT 1
            """),
            {"asset_id": asset.id}
        )
        calibration = result.fetchone()

        assert calibration is not None
        assert calibration[0] == "interval_extended"
        # New interval should be greater than old
        assert calibration[2] > calibration[1]


# === Flywheel 3: Multi-device Sync Tests ===

class TestSyncFlywheel:
    """Tests for Multi-device Sync event replay."""

    @pytest.mark.asyncio
    async def test_events_have_monotonic_sequence(
        self,
        db_session: AsyncSession,
        test_user_id: uuid.UUID,
    ):
        """
        AC6: Events for same aggregate should have monotonically increasing sequences.
        """
        from app.services.asset_concept_link_service import AssetConceptLinkService

        service = AssetConceptLinkService()
        aggregate_id = uuid.uuid4()

        # Write multiple events
        for i in range(5):
            await service._write_event(
                db=db_session,
                aggregate_type="test_aggregate",
                aggregate_id=aggregate_id,
                event_type=f"test_event_{i}",
                payload={"index": i},
            )

        # Verify monotonic sequences
        result = await db_session.execute(
            text("""
                SELECT sequence_number FROM event_outbox
                WHERE aggregate_type = 'test_aggregate' AND aggregate_id = :agg_id
                ORDER BY sequence_number ASC
            """),
            {"agg_id": aggregate_id}
        )
        sequences = [row[0] for row in result.fetchall()]

        assert sequences == [1, 2, 3, 4, 5]

    @pytest.mark.asyncio
    async def test_idempotent_event_application(
        self,
        db_session: AsyncSession,
        test_user_id: uuid.UUID,
    ):
        """
        AC7: Applying same event twice should be idempotent.
        """
        # Simulate processed_events table behavior
        event_id = str(uuid.uuid4())

        # First application
        await db_session.execute(
            text("""
                INSERT INTO processed_events (event_id, aggregate_id, sequence_number, occurred_at, processed_at)
                VALUES (:event_id, :agg_id, 1, :occurred_at, :processed_at)
                ON CONFLICT (event_id) DO NOTHING
            """),
            {
                "event_id": event_id,
                "agg_id": str(uuid.uuid4()),
                "occurred_at": datetime.now(timezone.utc),
                "processed_at": datetime.now(timezone.utc),
            }
        )

        # Second application should be no-op
        result = await db_session.execute(
            text("""
                INSERT INTO processed_events (event_id, aggregate_id, sequence_number, occurred_at, processed_at)
                VALUES (:event_id, :agg_id, 1, :occurred_at, :processed_at)
                ON CONFLICT (event_id) DO NOTHING
                RETURNING event_id
            """),
            {
                "event_id": event_id,
                "agg_id": str(uuid.uuid4()),
                "occurred_at": datetime.now(timezone.utc),
                "processed_at": datetime.now(timezone.utc),
            }
        )

        # Should not return anything (no insert happened)
        second_insert = result.fetchone()
        assert second_insert is None

    @pytest.mark.asyncio
    async def test_cursor_based_pagination(
        self,
        db_session: AsyncSession,
        test_user_id: uuid.UUID,
    ):
        """
        AC8: Events should be retrievable via cursor-based pagination.
        """
        aggregate_id = uuid.uuid4()

        # Insert multiple events
        for i in range(10):
            await db_session.execute(
                text("""
                    INSERT INTO event_outbox
                    (aggregate_type, aggregate_id, event_type, event_version, sequence_number, payload, metadata)
                    VALUES ('test', :agg_id, 'test_event', 1, :seq, '{}', '{}')
                """),
                {"agg_id": aggregate_id, "seq": i + 1}
            )

        # Paginate with limit
        result = await db_session.execute(
            text("""
                SELECT id, sequence_number FROM event_outbox
                WHERE aggregate_type = 'test' AND aggregate_id = :agg_id
                ORDER BY sequence_number ASC
                LIMIT 5
            """),
            {"agg_id": aggregate_id}
        )
        first_page = result.fetchall()

        assert len(first_page) == 5
        last_cursor = first_page[-1][1]  # sequence_number

        # Get next page
        result = await db_session.execute(
            text("""
                SELECT id, sequence_number FROM event_outbox
                WHERE aggregate_type = 'test' AND aggregate_id = :agg_id
                AND sequence_number > :cursor
                ORDER BY sequence_number ASC
                LIMIT 5
            """),
            {"agg_id": aggregate_id, "cursor": last_cursor}
        )
        second_page = result.fetchall()

        assert len(second_page) == 5


# === Galaxy Layout Tests ===

class TestGalaxyLayout:
    """Tests for incremental Galaxy positioning."""

    @pytest.mark.asyncio
    async def test_new_concept_gets_position(
        self,
        db_session: AsyncSession,
        test_user_id: uuid.UUID,
    ):
        """
        AC9: New concepts should receive an incremental position.
        """
        from app.models.galaxy import KnowledgeNode
        from app.services.galaxy_layout_service import GalaxyLayoutService

        # Create node without position
        node = KnowledgeNode(
            name="test_concept",
            source_type="user_created",
            status="published",
            position_x=None,
            position_y=None,
        )
        db_session.add(node)
        await db_session.flush()
        await db_session.refresh(node)

        # Compute position
        service = GalaxyLayoutService(db_session)
        x, y = await service.compute_position_for_concept(node.id)

        # Should have valid position
        assert x is not None
        assert y is not None
        assert isinstance(x, float)
        assert isinstance(y, float)

        # Node should be updated
        await db_session.refresh(node)
        assert node.position_x == x
        assert node.position_y == y
        assert node.position_updated_at is not None

    @pytest.mark.asyncio
    async def test_position_cooldown_enforced(
        self,
        db_session: AsyncSession,
        test_user_id: uuid.UUID,
    ):
        """
        AC10: Position should not be updated within 24-hour cooldown.
        """
        from app.models.galaxy import KnowledgeNode
        from app.services.galaxy_layout_service import GalaxyLayoutService

        # Create node with recent position update
        recent_time = datetime.now(timezone.utc) - timedelta(hours=1)
        node = KnowledgeNode(
            name="test_concept",
            source_type="user_created",
            status="published",
            position_x=100.0,
            position_y=200.0,
            position_updated_at=recent_time,
        )
        db_session.add(node)
        await db_session.flush()
        await db_session.refresh(node)

        original_x, original_y = node.position_x, node.position_y

        # Try to update position
        service = GalaxyLayoutService(db_session)
        x, y = await service.compute_position_for_concept(node.id)

        # Should return existing position (cooldown active)
        assert x == original_x
        assert y == original_y

        # Verify locked status
        is_locked = await service.is_position_locked(node.id)
        assert is_locked is True


# === Co-activation Tests ===

class TestCoActivation:
    """Tests for co-activation edge building."""

    @pytest.mark.asyncio
    async def test_co_activation_link_creation(
        self,
        db_session: AsyncSession,
        test_user_id: uuid.UUID,
    ):
        """
        AC11: Co-activation links should be created between
        assets and concepts accessed in same session.
        """
        from app.models.galaxy import KnowledgeNode
        from app.models.learning_assets import LearningAsset
        from app.services.asset_concept_link_service import AssetConceptLinkService

        # Create concept
        concept = KnowledgeNode(
            name="test_concept",
            source_type="seed",
            status="published",
        )
        db_session.add(concept)

        # Create asset
        asset = LearningAsset(
            user_id=test_user_id,
            headword="test_word",
            language_code="en",
        )
        db_session.add(asset)
        await db_session.flush()
        await db_session.refresh(concept)
        await db_session.refresh(asset)

        # Create co-activation link
        service = AssetConceptLinkService()
        link = await service.create_co_activation_link(
            db=db_session,
            user_id=test_user_id,
            asset_id=asset.id,
            concept_id=concept.id,
            session_id="session_123",
        )

        assert link.link_type == "co_activation"
        assert link.confidence == 0.5
        assert link.metadata["session_id"] == "session_123"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
