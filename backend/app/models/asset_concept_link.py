"""
Asset-Concept Link Model

Phase 9: Links LearningAsset (user vocabulary/sentences) to KnowledgeNode (knowledge graph concepts)
"""
import enum
from datetime import datetime, timezone

from sqlalchemy import Column, String, Float, ForeignKey
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship

from app.models.base import BaseModel, GUID


class LinkType(str, enum.Enum):
    """Asset-Concept link types"""
    PROVENANCE = "provenance"        # From document traceability
    CO_ACTIVATION = "co_activation"  # Same session activation
    MANUAL = "manual"                # User manual association


class AssetConceptLink(BaseModel):
    """
    Asset-Concept Link Table

    Connects LearningAsset (user's collected words/sentences) to KnowledgeNode (knowledge graph concepts).

    Semantic:
    - provenance: Asset was extracted from a document related to the concept
    - co_activation: Asset and concept were accessed in the same session
    - manual: User explicitly linked asset to concept

    Constraints:
    - Unique (user_id, asset_id, concept_id, link_type) for non-deleted records
    - Soft delete support via BaseModel
    """
    __tablename__ = "asset_concept_links"

    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    asset_id = Column(GUID(), ForeignKey("learning_assets.id", ondelete="CASCADE"), nullable=False, index=True)
    concept_id = Column(GUID(), ForeignKey("knowledge_nodes.id", ondelete="CASCADE"), nullable=False, index=True)

    link_type = Column(String(32), nullable=False)
    confidence = Column(Float, nullable=False, default=1.0)
    metadata = Column(JSONB, nullable=True)

    # Relationships
    asset = relationship("LearningAsset", backref="concept_links")
    concept = relationship("KnowledgeNode", backref="asset_links")
    user = relationship("User", backref="asset_concept_links")

    def __repr__(self):
        return f"<AssetConceptLink(asset={self.asset_id}, concept={self.concept_id}, type={self.link_type})>"

    @classmethod
    def get_link_type_enum(cls, link_type_str: str) -> LinkType:
        """Convert string to LinkType enum"""
        return LinkType(link_type_str)
