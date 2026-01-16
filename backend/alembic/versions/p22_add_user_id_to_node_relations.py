"""Add user_id to node_relations for private edges

Revision ID: p22_add_user_id_to_node_relations
Revises: p21_add_asset_concept_links
Create Date: 2026-01-16

Phase 9: User Private Edge Support
- Adds user_id column to node_relations table
- user_id IS NULL = global edge (seed/system generated)
- user_id IS NOT NULL = user private edge (co_activation/co_review)
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision = 'p22_add_user_id_to_node_relations'
down_revision = 'p21_add_asset_concept_links'
branch_labels = None
depends_on = None


def upgrade():
    # Add user_id column (nullable to support global edges)
    op.add_column(
        'node_relations',
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=True)
    )

    # Add foreign key constraint
    op.create_foreign_key(
        'fk_node_relations_user',
        'node_relations',
        'users',
        ['user_id'],
        ['id'],
        ondelete='CASCADE'
    )

    # Index for querying user's private relations
    op.create_index(
        'idx_nr_user_relation',
        'node_relations',
        ['user_id', 'relation_type'],
        postgresql_where=sa.text('deleted_at IS NULL')
    )

    # Index for querying all relations for a user (including global where user_id IS NULL)
    op.create_index(
        'idx_nr_user_id',
        'node_relations',
        ['user_id'],
        postgresql_where=sa.text('deleted_at IS NULL')
    )


def downgrade():
    op.drop_index('idx_nr_user_id', table_name='node_relations')
    op.drop_index('idx_nr_user_relation', table_name='node_relations')
    op.drop_constraint('fk_node_relations_user', 'node_relations', type_='foreignkey')
    op.drop_column('node_relations', 'user_id')
