"""
Review Calibration Log Model

Phase 9: Tracks review history for personalized interval adjustment
"""
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, Integer, Float, Boolean, ForeignKey, DateTime
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship

from app.db.session import Base
from app.models.base import GUID


class ReviewCalibrationLog(Base):
    """
    Review Calibration Log Table

    Immutable log of review events for:
    - Pattern detection (consecutive hard/easy)
    - Interval adjustment decisions
    - Prediction accuracy tracking (Brier score)

    Note: Uses HardDeleteBaseModel pattern (no soft delete for logs)
    """
    __tablename__ = "review_calibration_logs"

    id = Column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
        nullable=False,
    )

    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    asset_id = Column(GUID(), ForeignKey("learning_assets.id", ondelete="SET NULL"), nullable=True, index=True)
    concept_id = Column(GUID(), ForeignKey("knowledge_nodes.id", ondelete="SET NULL"), nullable=True, index=True)

    # Review timing
    reviewed_at = Column(DateTime(timezone=True), nullable=False)

    # Core metrics
    difficulty = Column(String(16), nullable=False)  # easy/good/hard
    review_count = Column(Integer, nullable=False)

    # Prediction/accuracy tracking
    predicted_recall = Column(Float, nullable=True)
    actual_recall = Column(Boolean, nullable=True)  # True if user recalled correctly
    brier_error = Column(Float, nullable=True)  # (predicted - actual)^2

    # Interval tracking
    interval_days_before = Column(Integer, nullable=True)
    interval_days_after = Column(Integer, nullable=True)

    # Adjustment explanation
    explanation_code = Column(String(50), nullable=True)  # learning_difficulty_adjusted, mastery_accelerated, standard

    # Additional metadata
    metadata = Column(JSONB, nullable=True)

    # Timestamp (immutable log - no updated_at)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    user = relationship("User", backref="review_calibration_logs")
    asset = relationship("LearningAsset", backref="calibration_logs")
    concept = relationship("KnowledgeNode", backref="calibration_logs")

    def __repr__(self):
        return f"<ReviewCalibrationLog(asset={self.asset_id}, difficulty={self.difficulty}, count={self.review_count})>"
