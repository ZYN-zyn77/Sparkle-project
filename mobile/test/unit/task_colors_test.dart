import 'package:flutter_test/flutter_test.dart';
import 'package:sparkle/core/design/tokens/task_colors.dart';
import 'package:sparkle/core/design/tokens_v2/theme_manager.dart' as ds;
import 'package:sparkle/data/models/task_model.dart';

void main() {
  group('TaskColors', () {
    test('uses design tokens for light and dark palettes', () {
      final lightTokens = ds.SparkleColors.light();
      final darkTokens = ds.SparkleColors.dark();

      final lightColors = TaskColors(colors: lightTokens);
      final darkColors = TaskColors(colors: darkTokens);

      expect(lightColors.getColor(TaskType.learning), lightTokens.taskLearning);
      expect(lightColors.getColor(TaskType.training), lightTokens.taskTraining);
      expect(lightColors.getColor(TaskType.errorFix), lightTokens.taskErrorFix);
      expect(lightColors.getColor(TaskType.reflection), lightTokens.taskReflection);
      expect(lightColors.getColor(TaskType.social), lightTokens.taskSocial);
      expect(lightColors.getColor(TaskType.planning), lightTokens.taskPlanning);

      expect(darkColors.getColor(TaskType.learning), darkTokens.taskLearning);
      expect(darkColors.getColor(TaskType.training), darkTokens.taskTraining);
      expect(darkColors.getColor(TaskType.errorFix), darkTokens.taskErrorFix);
      expect(darkColors.getColor(TaskType.reflection), darkTokens.taskReflection);
      expect(darkColors.getColor(TaskType.social), darkTokens.taskSocial);
      expect(darkColors.getColor(TaskType.planning), darkTokens.taskPlanning);
    });

    test('derives tint and border colors from the base color', () {
      final tokens = ds.SparkleColors.light();
      final colors = TaskColors(colors: tokens);

      final base = colors.getColor(TaskType.learning);
      expect(colors.getTint(TaskType.learning), base.withValues(alpha: 0.1));
      expect(colors.getBorder(TaskType.learning), base.withValues(alpha: 0.3));
    });
  });
}
