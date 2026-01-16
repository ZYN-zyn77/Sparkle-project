#!/usr/bin/env python3
"""
Phase 9 Flywheel Verification Script

Manual verification script for the three Phase 9 flywheels.
Run this after database migrations to verify the infrastructure is correct.

Usage:
    cd backend
    python scripts/verify_phase9_flywheels.py

Prerequisites:
    - PostgreSQL running
    - Database migrations applied (alembic upgrade head)
"""
import asyncio
import json
import sys
from datetime import datetime, timezone
from uuid import uuid4

import asyncpg

# Configuration
DATABASE_URL = "postgresql://sparkle:sparkle@localhost:5432/sparkle"


async def verify_database_schema():
    """Verify all required Phase 9 tables and indexes exist."""
    conn = await asyncpg.connect(DATABASE_URL)

    print("=" * 60)
    print("Phase 9 Database Schema Verification")
    print("=" * 60)

    required_tables = [
        ("asset_concept_links", "M1: Asset-Concept link table"),
        ("review_calibration_logs", "M1: Review calibration logs"),
        ("event_outbox", "M3: Event outbox for sync"),
        ("event_sequence_counters", "M3: Sequence counters"),
        ("processed_events", "M3: Idempotency tracking"),
    ]

    all_passed = True
    for table, description in required_tables:
        exists = await conn.fetchval(
            "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = $1)",
            table
        )
        status = "✓" if exists else "✗"
        if not exists:
            all_passed = False
        print(f"  {status} {table}: {description}")

    # Check specific columns
    print("\nColumn Verification:")
    column_checks = [
        ("node_relations", "user_id", "M1: User-private edges"),
        ("knowledge_nodes", "position_updated_at", "M5: Layout cooldown"),
    ]

    for table, column, description in column_checks:
        exists = await conn.fetchval(
            """
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name = $1 AND column_name = $2
            )
            """,
            table, column
        )
        status = "✓" if exists else "✗"
        if not exists:
            all_passed = False
        print(f"  {status} {table}.{column}: {description}")

    # Check indexes
    print("\nIndex Verification:")
    index_checks = [
        ("ix_asset_concept_links_user_asset", "Unique link per user/asset/concept"),
        ("ix_knowledge_nodes_position_updated_at", "Position cooldown queries"),
    ]

    for index_name, description in index_checks:
        exists = await conn.fetchval(
            "SELECT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = $1)",
            index_name
        )
        status = "✓" if exists else "?"
        print(f"  {status} {index_name}: {description}")

    await conn.close()
    return all_passed


async def verify_event_sequence_monotonicity():
    """Verify event sequence counters are working correctly."""
    conn = await asyncpg.connect(DATABASE_URL)

    print("\n" + "=" * 60)
    print("Event Sequence Monotonicity Test")
    print("=" * 60)

    test_aggregate_id = str(uuid4())

    # Insert 5 events and verify monotonic sequences
    sequences = []
    for i in range(5):
        seq = await conn.fetchval(
            """
            INSERT INTO event_sequence_counters (aggregate_type, aggregate_id, next_sequence)
            VALUES ('test_verification', $1, 1)
            ON CONFLICT (aggregate_type, aggregate_id)
            DO UPDATE SET next_sequence = event_sequence_counters.next_sequence + 1
            RETURNING next_sequence
            """,
            test_aggregate_id
        )
        sequences.append(seq)

    # Cleanup
    await conn.execute(
        "DELETE FROM event_sequence_counters WHERE aggregate_type = 'test_verification'"
    )

    is_monotonic = sequences == sorted(sequences) and len(set(sequences)) == len(sequences)
    status = "✓" if is_monotonic else "✗"
    print(f"  {status} Sequence monotonicity: {sequences}")

    await conn.close()
    return is_monotonic


async def verify_event_outbox_structure():
    """Verify event outbox can store and retrieve events correctly."""
    conn = await asyncpg.connect(DATABASE_URL)

    print("\n" + "=" * 60)
    print("Event Outbox Structure Test")
    print("=" * 60)

    test_id = uuid4()
    test_payload = {"test": True, "timestamp": datetime.now(timezone.utc).isoformat()}

    try:
        # Insert test event
        await conn.execute(
            """
            INSERT INTO event_outbox
            (aggregate_type, aggregate_id, event_type, event_version, sequence_number, payload, metadata)
            VALUES ('test_verification', $1, 'test_event', 1, 1, $2, '{}')
            """,
            test_id, json.dumps(test_payload)
        )

        # Retrieve and verify
        row = await conn.fetchrow(
            """
            SELECT aggregate_type, event_type, payload
            FROM event_outbox
            WHERE aggregate_id = $1
            """,
            test_id
        )

        # Cleanup
        await conn.execute(
            "DELETE FROM event_outbox WHERE aggregate_type = 'test_verification'"
        )

        success = (
            row is not None
            and row['aggregate_type'] == 'test_verification'
            and row['event_type'] == 'test_event'
        )
        status = "✓" if success else "✗"
        print(f"  {status} Event insert and retrieval: Working")

    except Exception as e:
        print(f"  ✗ Event outbox error: {e}")
        success = False

    await conn.close()
    return success


async def verify_processed_events_idempotency():
    """Verify processed_events table supports idempotent operations."""
    conn = await asyncpg.connect(DATABASE_URL)

    print("\n" + "=" * 60)
    print("Idempotency (processed_events) Test")
    print("=" * 60)

    test_event_id = str(uuid4())
    test_aggregate_id = str(uuid4())
    now = datetime.now(timezone.utc)

    try:
        # First insert should succeed
        result1 = await conn.fetchval(
            """
            INSERT INTO processed_events (event_id, aggregate_id, sequence_number, occurred_at, processed_at)
            VALUES ($1, $2, 1, $3, $3)
            ON CONFLICT (event_id) DO NOTHING
            RETURNING event_id
            """,
            test_event_id, test_aggregate_id, now
        )

        # Second insert should be no-op
        result2 = await conn.fetchval(
            """
            INSERT INTO processed_events (event_id, aggregate_id, sequence_number, occurred_at, processed_at)
            VALUES ($1, $2, 1, $3, $3)
            ON CONFLICT (event_id) DO NOTHING
            RETURNING event_id
            """,
            test_event_id, str(uuid4()), now  # Different aggregate_id
        )

        # Cleanup
        await conn.execute(
            "DELETE FROM processed_events WHERE event_id = $1",
            test_event_id
        )

        first_succeeded = result1 == test_event_id
        second_was_noop = result2 is None

        status1 = "✓" if first_succeeded else "✗"
        status2 = "✓" if second_was_noop else "✗"
        print(f"  {status1} First insert succeeded: {first_succeeded}")
        print(f"  {status2} Second insert was no-op: {second_was_noop}")

        success = first_succeeded and second_was_noop

    except Exception as e:
        print(f"  ✗ Idempotency test error: {e}")
        success = False

    await conn.close()
    return success


async def print_summary(results: dict):
    """Print verification summary."""
    print("\n" + "=" * 60)
    print("Phase 9 Verification Summary")
    print("=" * 60)

    all_passed = all(results.values())

    for test_name, passed in results.items():
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"  {status}: {test_name}")

    print("\n" + "-" * 60)
    if all_passed:
        print("  ✓ All Phase 9 flywheel infrastructure verified!")
        print("  Ready for integration testing.")
    else:
        print("  ✗ Some verifications failed.")
        print("  Please check database migrations and configuration.")
    print("-" * 60)

    return all_passed


async def main():
    """Run all verification checks."""
    print("\n🚀 Phase 9 Flywheel Verification Starting...\n")

    results = {}

    try:
        results["Database Schema"] = await verify_database_schema()
        results["Event Sequence Monotonicity"] = await verify_event_sequence_monotonicity()
        results["Event Outbox Structure"] = await verify_event_outbox_structure()
        results["Idempotency"] = await verify_processed_events_idempotency()
    except Exception as e:
        print(f"\n❌ Verification failed with error: {e}")
        print("   Make sure PostgreSQL is running and DATABASE_URL is correct.")
        sys.exit(1)

    success = await print_summary(results)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
