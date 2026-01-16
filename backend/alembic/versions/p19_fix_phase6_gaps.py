"""fix phase6 gaps

Revision ID: p19_fix_phase6_gaps
Revises: p18_event_sequence_counters
Create Date: 2026-01-16 14:00:00.000000

Fixes:
- Change selection_fp index to partial unique (deleted_at IS NULL)
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from app.utils.migration_helpers import get_inspector, index_exists

# revision identifiers, used by Alembic.
revision: str = 'p19_fix_phase6_gaps'
down_revision: Union[str, None] = 'p18_event_sequence_counters'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Apply fixes for Phase 6 gaps"""
    inspector = get_inspector()

    # 1. Fix learning_assets unique constraint
    # Drop old non-unique index if exists
    if index_exists(inspector, "learning_assets", "idx_learning_assets_selection_fp"):
        op.drop_index("idx_learning_assets_selection_fp", table_name="learning_assets")

    # Create new partial unique index
    op.execute("""
        CREATE UNIQUE INDEX idx_learning_assets_selection_fp
        ON learning_assets (user_id, selection_fp)
        WHERE deleted_at IS NULL
    """)


def downgrade() -> None:
    """Revert changes"""
    inspector = get_inspector()

    # Revert learning_assets index
    op.execute("DROP INDEX IF EXISTS idx_learning_assets_selection_fp")
    
    if not index_exists(inspector, "learning_assets", "idx_learning_assets_selection_fp"):
        op.create_index(
            'idx_learning_assets_selection_fp',
            'learning_assets',
            ['user_id', 'selection_fp'],
            unique=False
        )
