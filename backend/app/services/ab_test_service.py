"""
A/B Test Service (A/B 测试服务)

Provides infrastructure for running controlled experiments with safety guardrails.

Features:
- Fixed user bucketing (deterministic assignment)
- Kill-switch support (disable experiments instantly)
- Configuration-driven (no hardcoded experiments)
- Experiment result tracking
"""
import hashlib
from datetime import datetime, timezone
from typing import Optional, Dict, Any, List
from uuid import UUID
from enum import Enum
from dataclasses import dataclass, field

from loguru import logger

from app.core.cache import cache_service


class ExperimentStatus(str, Enum):
    """Experiment lifecycle status"""
    DRAFT = "draft"       # Not yet active
    RUNNING = "running"   # Currently running
    PAUSED = "paused"     # Temporarily stopped
    COMPLETED = "completed"  # Finished


@dataclass
class Variant:
    """A variant in an experiment"""
    name: str
    weight: int = 50  # Percentage weight (0-100)
    config: Dict[str, Any] = field(default_factory=dict)


@dataclass
class Experiment:
    """An A/B test experiment configuration"""
    id: str
    name: str
    description: str
    status: ExperimentStatus = ExperimentStatus.DRAFT
    variants: List[Variant] = field(default_factory=list)
    target_percentage: int = 100  # What % of users are in experiment
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    kill_switch: bool = False  # Emergency stop flag


class ABTestService:
    """
    A/B Testing service with safety guardrails.

    Key principles:
    - Deterministic assignment: Same user always gets same variant
    - Kill-switch: Can instantly disable any experiment
    - Gradual rollout: Control percentage of users in experiment
    - Configuration-driven: No code changes needed for new experiments
    """

    # In-memory experiment registry (in production, load from DB/config)
    _experiments: Dict[str, Experiment] = {}

    # Redis key patterns
    @staticmethod
    def _experiment_key(experiment_id: str) -> str:
        return f"ab:experiment:{experiment_id}"

    @staticmethod
    def _assignment_key(user_id: UUID, experiment_id: str) -> str:
        return f"ab:assignment:{user_id}:{experiment_id}"

    def __init__(self):
        """Initialize with default experiments"""
        self._register_default_experiments()

    def _register_default_experiments(self):
        """Register Phase 8 experiments"""
        # Experiment 1: Suggestion threshold (2 vs 3 lookups)
        self._experiments["suggestion_threshold_v1"] = Experiment(
            id="suggestion_threshold_v1",
            name="Suggestion Lookup Threshold",
            description="Test whether 2 or 3 lookups is optimal for triggering suggestions",
            status=ExperimentStatus.DRAFT,  # Not running yet
            variants=[
                Variant(name="control", weight=50, config={"threshold": 2}),
                Variant(name="treatment", weight=50, config={"threshold": 3}),
            ],
            target_percentage=100,
            kill_switch=False,
        )

        # Experiment 2: Cooldown duration (30 vs 60 minutes)
        self._experiments["cooldown_duration_v1"] = Experiment(
            id="cooldown_duration_v1",
            name="Suggestion Cooldown Duration",
            description="Test optimal cooldown period after dismissing a suggestion",
            status=ExperimentStatus.DRAFT,
            variants=[
                Variant(name="control", weight=50, config={"cooldown_minutes": 30}),
                Variant(name="treatment", weight=50, config={"cooldown_minutes": 60}),
            ],
            target_percentage=100,
            kill_switch=False,
        )

        # Experiment 3: Reason template style
        self._experiments["reason_template_v1"] = Experiment(
            id="reason_template_v1",
            name="Suggestion Reason Templates",
            description="Test different wording for suggestion reasons",
            status=ExperimentStatus.DRAFT,
            variants=[
                Variant(
                    name="informative",
                    weight=50,
                    config={"template_style": "informative"}  # "在本次会话中查询了 2 次"
                ),
                Variant(
                    name="encouraging",
                    weight=50,
                    config={"template_style": "encouraging"}  # "这个词值得记住！你已经查过 2 次了"
                ),
            ],
            target_percentage=100,
            kill_switch=False,
        )

    def get_experiment(self, experiment_id: str) -> Optional[Experiment]:
        """Get experiment by ID"""
        return self._experiments.get(experiment_id)

    def list_experiments(self) -> List[Experiment]:
        """List all registered experiments"""
        return list(self._experiments.values())

    def _compute_bucket(self, user_id: UUID, experiment_id: str) -> int:
        """
        Compute deterministic bucket for user in experiment.

        Uses SHA256 hash of (user_id + experiment_id) to ensure:
        1. Same user always gets same bucket for same experiment
        2. Different experiments can have different assignments

        Returns:
            Bucket number 0-99
        """
        hash_input = f"{user_id}:{experiment_id}".encode()
        hash_bytes = hashlib.sha256(hash_input).digest()
        # Use first 4 bytes as unsigned int, mod 100
        bucket = int.from_bytes(hash_bytes[:4], 'big') % 100
        return bucket

    def is_in_experiment(
        self,
        user_id: UUID,
        experiment_id: str,
    ) -> bool:
        """
        Check if user is enrolled in an experiment.

        Returns False if:
        - Experiment doesn't exist
        - Experiment is not running
        - Kill-switch is enabled
        - User bucket is outside target percentage
        """
        experiment = self._experiments.get(experiment_id)
        if not experiment:
            return False

        # Check kill-switch
        if experiment.kill_switch:
            logger.debug(f"Experiment {experiment_id} kill-switch is ON")
            return False

        # Check status
        if experiment.status != ExperimentStatus.RUNNING:
            return False

        # Check bucket
        bucket = self._compute_bucket(user_id, experiment_id)
        return bucket < experiment.target_percentage

    def get_variant(
        self,
        user_id: UUID,
        experiment_id: str,
    ) -> Optional[Variant]:
        """
        Get the variant assigned to a user for an experiment.

        Returns None if user is not in the experiment.
        """
        if not self.is_in_experiment(user_id, experiment_id):
            return None

        experiment = self._experiments[experiment_id]

        # Compute which variant based on bucket
        bucket = self._compute_bucket(user_id, experiment_id)

        # Map bucket to variant based on weights
        cumulative = 0
        for variant in experiment.variants:
            cumulative += variant.weight
            if (bucket % 100) < cumulative:
                return variant

        # Fallback to first variant
        return experiment.variants[0] if experiment.variants else None

    def get_config_value(
        self,
        user_id: UUID,
        experiment_id: str,
        config_key: str,
        default: Any = None,
    ) -> Any:
        """
        Get a config value for a user in an experiment.

        Returns default if user is not in experiment or key doesn't exist.
        """
        variant = self.get_variant(user_id, experiment_id)
        if not variant:
            return default
        return variant.config.get(config_key, default)

    # === Experiment Management ===

    def start_experiment(self, experiment_id: str) -> bool:
        """Start an experiment (set status to RUNNING)"""
        experiment = self._experiments.get(experiment_id)
        if not experiment:
            return False

        experiment.status = ExperimentStatus.RUNNING
        experiment.start_date = datetime.now(timezone.utc)
        experiment.kill_switch = False
        logger.info(f"Started experiment: {experiment_id}")
        return True

    def stop_experiment(self, experiment_id: str) -> bool:
        """Stop an experiment (set kill-switch)"""
        experiment = self._experiments.get(experiment_id)
        if not experiment:
            return False

        experiment.kill_switch = True
        logger.info(f"Stopped experiment (kill-switch): {experiment_id}")
        return True

    def pause_experiment(self, experiment_id: str) -> bool:
        """Pause an experiment"""
        experiment = self._experiments.get(experiment_id)
        if not experiment:
            return False

        experiment.status = ExperimentStatus.PAUSED
        logger.info(f"Paused experiment: {experiment_id}")
        return True

    def complete_experiment(self, experiment_id: str) -> bool:
        """Mark experiment as completed"""
        experiment = self._experiments.get(experiment_id)
        if not experiment:
            return False

        experiment.status = ExperimentStatus.COMPLETED
        experiment.end_date = datetime.now(timezone.utc)
        logger.info(f"Completed experiment: {experiment_id}")
        return True

    def set_target_percentage(self, experiment_id: str, percentage: int) -> bool:
        """
        Set target percentage for gradual rollout.

        Args:
            experiment_id: Experiment ID
            percentage: 0-100, percentage of users to include

        Returns:
            True if successful
        """
        if not 0 <= percentage <= 100:
            return False

        experiment = self._experiments.get(experiment_id)
        if not experiment:
            return False

        experiment.target_percentage = percentage
        logger.info(f"Set experiment {experiment_id} target percentage to {percentage}%")
        return True

    # === Integration Helpers ===

    def get_suggestion_threshold(self, user_id: UUID) -> int:
        """Get suggestion threshold for a user (experiment-aware)"""
        value = self.get_config_value(
            user_id=user_id,
            experiment_id="suggestion_threshold_v1",
            config_key="threshold",
            default=2,  # Default threshold
        )
        return int(value)

    def get_cooldown_minutes(self, user_id: UUID) -> int:
        """Get cooldown duration for a user (experiment-aware)"""
        value = self.get_config_value(
            user_id=user_id,
            experiment_id="cooldown_duration_v1",
            config_key="cooldown_minutes",
            default=30,  # Default cooldown
        )
        return int(value)

    def get_reason_template_style(self, user_id: UUID) -> str:
        """Get reason template style for a user (experiment-aware)"""
        value = self.get_config_value(
            user_id=user_id,
            experiment_id="reason_template_v1",
            config_key="template_style",
            default="informative",  # Default style
        )
        return str(value)

    def get_variant_id_for_logging(self, user_id: UUID, experiment_id: str) -> Optional[str]:
        """
        Get variant identifier for logging/analytics.

        Returns None if user is not in experiment.
        """
        variant = self.get_variant(user_id, experiment_id)
        if variant:
            return f"{experiment_id}:{variant.name}"
        return None


# Singleton instance
ab_test_service = ABTestService()
