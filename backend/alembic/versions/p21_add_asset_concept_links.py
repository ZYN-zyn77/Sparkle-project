"""Add asset_concept_links table

Revision ID: p21_add_asset_concept_links
Revises: p20_add_asset_embeddings
Create Date: 2026-01-16

Phase 9: Asset-Concept Link Table
- Links LearningAsset (user vocabulary) to KnowledgeNode (knowledge graph concepts)
- Supports provenance/co_activation/manual link types
- Partial unique index for soft-delete compatibility
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision = 'p21_add_asset_concept_links'
down_revision = 'p20_add_asset_embeddings'
branch_labels = None
depends_on = None


def upgrade():
    # Create asset_concept_links table
    op.create_table(
        'asset_concept_links',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('asset_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('learning_assets.id', ondelete='CASCADE'), nullable=False),
        sa.Column('concept_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('knowledge_nodes.id', ondelete='CASCADE'), nullable=False),
        sa.Column('link_type', sa.String(32), nullable=False),  # provenance | co_activation | manual
        sa.Column('confidence', sa.Float, nullable=False, server_default='1.0'),
        sa.Column('metadata', postgresql.JSONB, nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
    )

    # Partial unique index (soft-delete friendly)
    # Ensures uniqueness only for non-deleted records
    op.create_index(
        'uix_asset_concept_link_unique',
        'asset_concept_links',
        ['user_id', 'asset_id', 'concept_id', 'link_type'],
        unique=True,
        postgresql_where=sa.text('deleted_at IS NULL')
    )

    # Performance indexes for common query patterns
    op.create_index(
        'idx_acl_user_asset',
        'asset_concept_links',
        ['user_id', 'asset_id'],
        postgresql_where=sa.text('deleted_at IS NULL')
    )

    op.create_index(
        'idx_acl_user_concept',
        'asset_concept_links',
        ['user_id', 'concept_id'],
        postgresql_where=sa.text('deleted_at IS NULL')
    )

    op.create_index(
        'idx_acl_link_type',
        'asset_concept_links',
        ['link_type'],
        postgresql_where=sa.text('deleted_at IS NULL')
    )


def downgrade():
    op.drop_index('idx_acl_link_type', table_name='asset_concept_links')
    op.drop_index('idx_acl_user_concept', table_name='asset_concept_links')
    op.drop_index('idx_acl_user_asset', table_name='asset_concept_links')
    op.drop_index('uix_asset_concept_link_unique', table_name='asset_concept_links')
    op.drop_table('asset_concept_links')
