import 'package:flutter/material.dart';
import 'package:sparkle/core/design/tokens_v2/theme_manager.dart' show SparkleColors;
import 'package:sparkle/data/models/task_model.dart' show TaskType;

export 'package:sparkle/data/models/task_model.dart' show TaskType;

/// Single source of truth for task colors.
///
/// DO NOT define task colors elsewhere in the UI layer.
@immutable
class TaskColors {
  const TaskColors({required this.colors});

  final SparkleColors colors;

  Color getColor(TaskType type) {
    switch (type) {
      case TaskType.learning:
        return colors.taskLearning;
      case TaskType.training:
        return colors.taskTraining;
      case TaskType.errorFix:
        return colors.taskErrorFix;
      case TaskType.reflection:
        return colors.taskReflection;
      case TaskType.social:
        return colors.taskSocial;
      case TaskType.planning:
        return colors.taskPlanning;
    }
  }

  Color getTint(TaskType type) => getColor(type).withValues(alpha: 0.1);
  Color getBorder(TaskType type) => getColor(type).withValues(alpha: 0.3);
  Color getIcon(TaskType type) => getColor(type);
  Color getLabel(TaskType type) => getColor(type);
}
