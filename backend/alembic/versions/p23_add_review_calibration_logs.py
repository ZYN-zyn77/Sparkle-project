"""Add review_calibration_logs table

Revision ID: p23_add_review_calibration_logs
Revises: p22_add_user_id_to_node_relations
Create Date: 2026-01-16

Phase 9: Review Calibration Logging
- Tracks review history for personalized interval adjustment
- Enables pattern detection (consecutive hard/easy)
- Supports Brier score calculation for prediction accuracy
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision = 'p23_add_review_calibration_logs'
down_revision = 'p22_add_user_id_to_node_relations'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'review_calibration_logs',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('asset_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('learning_assets.id', ondelete='SET NULL'), nullable=True),
        sa.Column('concept_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('knowledge_nodes.id', ondelete='SET NULL'), nullable=True),

        # Review timing
        sa.Column('reviewed_at', sa.DateTime(timezone=True), nullable=False),

        # Core metrics
        sa.Column('difficulty', sa.String(16), nullable=False),  # easy/good/hard
        sa.Column('review_count', sa.Integer, nullable=False),

        # Prediction/accuracy tracking
        sa.Column('predicted_recall', sa.Float, nullable=True),
        sa.Column('actual_recall', sa.Boolean, nullable=True),
        sa.Column('brier_error', sa.Float, nullable=True),  # (predicted - actual)^2

        # Interval tracking
        sa.Column('interval_days_before', sa.Integer, nullable=True),
        sa.Column('interval_days_after', sa.Integer, nullable=True),

        # Adjustment explanation
        sa.Column('explanation_code', sa.String(50), nullable=True),  # learning_difficulty_adjusted, mastery_accelerated, standard

        # Additional metadata
        sa.Column('metadata', postgresql.JSONB, nullable=True),

        # Timestamp (no updated_at, this is immutable log)
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    )

    # Index for user review history queries
    op.create_index(
        'idx_rcl_user_reviewed',
        'review_calibration_logs',
        ['user_id', 'reviewed_at']
    )

    # Index for asset-specific history
    op.create_index(
        'idx_rcl_asset',
        'review_calibration_logs',
        ['asset_id']
    )

    # Index for concept-specific history
    op.create_index(
        'idx_rcl_concept',
        'review_calibration_logs',
        ['concept_id']
    )

    # Index for pattern detection (recent reviews per asset)
    op.create_index(
        'idx_rcl_user_asset_reviewed',
        'review_calibration_logs',
        ['user_id', 'asset_id', 'reviewed_at']
    )


def downgrade():
    op.drop_index('idx_rcl_user_asset_reviewed', table_name='review_calibration_logs')
    op.drop_index('idx_rcl_concept', table_name='review_calibration_logs')
    op.drop_index('idx_rcl_asset', table_name='review_calibration_logs')
    op.drop_index('idx_rcl_user_reviewed', table_name='review_calibration_logs')
    op.drop_table('review_calibration_logs')
