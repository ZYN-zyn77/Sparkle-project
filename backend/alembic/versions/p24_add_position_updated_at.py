"""Add position_updated_at to knowledge_nodes for layout cooldown

Phase 9 M5: Galaxy incremental layout with 24-hour position cooldown

Revision ID: p24_position_updated_at
Revises: p23_review_calibration
Create Date: 2025-01-16
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'p24_position_updated_at'
down_revision = 'p23_review_calibration'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add position_updated_at for 24-hour layout cooldown enforcement
    op.add_column(
        'knowledge_nodes',
        sa.Column('position_updated_at', sa.DateTime(timezone=True), nullable=True)
    )

    # Index for efficient cooldown queries
    op.create_index(
        'ix_knowledge_nodes_position_updated_at',
        'knowledge_nodes',
        ['position_updated_at'],
        postgresql_where=sa.text('position_updated_at IS NOT NULL')
    )


def downgrade() -> None:
    op.drop_index('ix_knowledge_nodes_position_updated_at', table_name='knowledge_nodes')
    op.drop_column('knowledge_nodes', 'position_updated_at')
