import asyncio
import os
import pytest
from uuid import uuid4
from unittest.mock import patch
from datetime import datetime, timezone, timedelta
from sqlalchemy import select, text, delete

from app.db.session import AsyncSessionLocal
from app.models.user import User
from app.services.learning_asset_service import learning_asset_service, AssetStatus
from app.models.learning_assets import LearningAsset, AssetSuggestionLog
from app.core.cache import cache_service

def _integration_enabled() -> bool:
    return os.getenv("SPARKLE_INTEGRATION", "").lower() in {"1", "true", "yes"}

@pytest.mark.asyncio
async def test_soft_delete_unique_constraint():
    if not _integration_enabled():
        pytest.skip("SPARKLE_INTEGRATION not enabled")

    async with AsyncSessionLocal() as db:
        # Setup User
        user_id = uuid4()
        user = User(
            id=user_id,
            username=f"test_sd_{user_id.hex[:8]}",
            email=f"sd_{user_id.hex[:8]}@example.com",
            hashed_password="test",
        )
        db.add(user)
        await db.commit()

        try:
            text_content = "Unique Test Phrase"
            
            # 1. Create first asset
            asset1 = await learning_asset_service.create_asset_from_selection(
                db=db,
                user_id=user_id,
                selected_text=text_content,
                initial_status=AssetStatus.INBOX
            )
            fp = asset1.selection_fp
            assert fp is not None
            
            # 2. Try to create duplicate (should fail or return existing depending on service logic)
            existing = await learning_asset_service.check_existing_asset(
                db=db,
                user_id=user_id,
                selection_fp=fp
            )
            assert existing is not None
            assert existing.id == asset1.id
            
            # 3. Soft delete the asset
            await asset1.delete(db)
            
            # 4. Verify it's deleted
            deleted_asset = await LearningAsset.get_by_id(db, asset1.id, include_deleted=True)
            assert deleted_asset.deleted_at is not None
            
            # 5. Create same asset again
            # Service should NOT find the deleted one
            existing_after_delete = await learning_asset_service.check_existing_asset(
                db=db,
                user_id=user_id,
                selection_fp=fp
            )
            assert existing_after_delete is None
            
            # Create new one
            asset2 = await learning_asset_service.create_asset_from_selection(
                db=db,
                user_id=user_id,
                selected_text=text_content,
                initial_status=AssetStatus.INBOX
            )
            
            assert asset2.id != asset1.id
            assert asset2.selection_fp == fp
            assert asset2.deleted_at is None
            
            # 6. Verify database state (both exist, one deleted)
            result = await db.execute(
                select(LearningAsset).where(LearningAsset.selection_fp == fp)
            )
            all_assets = result.scalars().all()
            assert len(all_assets) >= 2

        finally:
            # Cleanup
            await db.execute(delete(LearningAsset).where(LearningAsset.user_id == user_id))
            await db.execute(delete(User).where(User.id == user_id))
            await db.commit()


@pytest.mark.asyncio
async def test_redis_fallback_logic():
    if not _integration_enabled():
        pytest.skip("SPARKLE_INTEGRATION not enabled")

    async with AsyncSessionLocal() as db:
        # Setup User
        user_id = uuid4()
        user = User(
            id=user_id,
            username=f"test_rf_{user_id.hex[:8]}",
            email=f"rf_{user_id.hex[:8]}@example.com",
            hashed_password="test",
        )
        db.add(user)
        await db.commit()

        try:
            session_id = "test_session_fallback"
            text_content = "Fallback Test Phrase"
            
            # Mock cache_service.incr to raise exception
            with patch.object(cache_service, 'incr', side_effect=Exception("Redis Down")):
                # 1. First lookup
                res1 = await learning_asset_service.record_lookup(
                    db=db,
                    user_id=user_id,
                    session_id=session_id,
                    selected_text=text_content
                )
                
                # Verify log created
                result = await db.execute(
                    select(AssetSuggestionLog).where(
                        AssetSuggestionLog.user_id == user_id,
                        AssetSuggestionLog.session_id == session_id
                    )
                )
                logs = result.scalars().all()
                assert len(logs) == 1
                # Check DB fallback logic (should be 1)
                assert logs[0].evidence_json['lookup_count'] == 1
                
                # 2. Second lookup
                res2 = await learning_asset_service.record_lookup(
                    db=db,
                    user_id=user_id,
                    session_id=session_id,
                    selected_text=text_content
                )
                
                # Verify second log
                result = await db.execute(
                    select(AssetSuggestionLog).where(
                        AssetSuggestionLog.user_id == user_id,
                        AssetSuggestionLog.session_id == session_id
                    ).order_by(AssetSuggestionLog.created_at.desc())
                )
                logs = result.scalars().all()
                assert len(logs) == 2
                assert logs[0].evidence_json['lookup_count'] == 2
                
                # Check if suggestion triggered
                assert res2['suggest_asset'] is True
        
        finally:
            await db.execute(delete(AssetSuggestionLog).where(AssetSuggestionLog.user_id == user_id))
            await db.execute(delete(User).where(User.id == user_id))
            await db.commit()


@pytest.mark.asyncio
async def test_provenance_timeout_handling():
    # This is a unit test really, doesn't strictly need DB if mocked properly, 
    # but we will use the async structure.
    
    from app.core.fuzzy_match import find_provenance
    
    # Mock asyncio.wait_for to raise TimeoutError
    with patch('asyncio.wait_for', side_effect=asyncio.TimeoutError):
        # We need a dummy DB session object, doesn't need to be real for this test 
        # as long as execute is mocked or we don't reach it before timeout.
        # But our implementation calls execute inside _search which is awaited inside wait_for.
        # So we can pass a mock DB.
        
        mock_db = AsyncSessionLocal() # Just a shell, or use AsyncMock
        
        try:
             match = await find_provenance(
                db=mock_db, # passing real or mock, wait_for intercepts
                selected_text="Some text",
                file_id=uuid4(),
                timeout_ms=100
            )
             
             assert match.best_match is None
             assert match.search_params.get("error") == "timeout"
             assert match.search_params.get("timeout_ms") == 100
        finally:
            await mock_db.close()


@pytest.mark.asyncio
async def test_sequence_number_concurrency():
    if not _integration_enabled():
        pytest.skip("SPARKLE_INTEGRATION not enabled")

    async with AsyncSessionLocal() as db:
        aggregate_id = uuid4()
        
        # Create counter row first to avoid "relation does not exist" if migration not run (but it should be)
        # Actually the service creates it on fly.
        
        for i in range(5):
            await learning_asset_service._write_event_outbox(
                db=db,
                aggregate_type="test_agg",
                aggregate_id=aggregate_id,
                event_type="test_event",
                payload={"i": i}
            )
            
        # Verify sequence
        result = await db.execute(
            text("SELECT next_sequence FROM event_sequence_counters WHERE aggregate_id = :id"),
            {"id": aggregate_id}
        )
        val = result.scalar()
        assert val == 5
        
        # Cleanup
        await db.execute(text("DELETE FROM event_sequence_counters WHERE aggregate_id = :id"), {"id": aggregate_id})
        await db.execute(text("DELETE FROM event_outbox WHERE aggregate_id = :id"), {"id": aggregate_id})
        await db.commit()