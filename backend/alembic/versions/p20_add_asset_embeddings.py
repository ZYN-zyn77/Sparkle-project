"""Add embedding columns to learning_assets table

Revision ID: p20_add_asset_embeddings
Revises: p19_fix_phase6_gaps
Create Date: 2025-01-16

Phase 8 Preparation: Asset Semantic Search
- Adds embedding column (vector 1536) for semantic search
- Adds embedding_updated_at for tracking freshness
"""

from alembic import op
import sqlalchemy as sa
from pgvector.sqlalchemy import Vector


# revision identifiers, used by Alembic.
revision = 'p20_add_asset_embeddings'
down_revision = 'p19_fix_phase6_gaps'
branch_labels = None
depends_on = None


def upgrade():
    # Add embedding column for semantic search
    op.add_column(
        'learning_assets',
        sa.Column('embedding', Vector(1536), nullable=True)
    )
    op.add_column(
        'learning_assets',
        sa.Column('embedding_updated_at', sa.DateTime(), nullable=True)
    )

    # Create HNSW index for fast similarity search
    # Using cosine distance (default for text embeddings)
    op.execute("""
        CREATE INDEX IF NOT EXISTS idx_learning_assets_embedding_hnsw
        ON learning_assets
        USING hnsw (embedding vector_cosine_ops)
        WITH (m = 16, ef_construction = 64)
        WHERE embedding IS NOT NULL
    """)


def downgrade():
    # Drop index first
    op.execute("DROP INDEX IF EXISTS idx_learning_assets_embedding_hnsw")

    # Drop columns
    op.drop_column('learning_assets', 'embedding_updated_at')
    op.drop_column('learning_assets', 'embedding')
