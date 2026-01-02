import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparkle/core/design/components/atoms/sparkle_pressable.dart';
import 'package:sparkle/core/design/components/atoms/task_pill.dart';
import 'package:sparkle/core/design/design_system.dart';
import 'package:sparkle/core/design/theme/sparkle_theme_extension.dart';
import 'package:sparkle/core/design/tokens_v2/theme_manager.dart' as ds;
import 'package:sparkle/data/models/task_model.dart';

void main() {
  ThemeData _themeWithTokens(ThemeData base, SparkleThemeExtension extension) =>
      base.copyWith(extensions: <ThemeExtension<dynamic>>[
        ...base.extensions.values,
        extension,
      ]);

  testWidgets('TaskPill renders task token colors for backgrounds and borders', (WidgetTester tester) async {
    final expectedTokens = ds.SparkleColors.light();
    final theme = _themeWithTokens(AppThemes.lightTheme, SparkleThemeExtension.light());

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: Center(
            child: TaskPill(
              type: TaskType.learning,
              label: 'Learn',
              icon: Icons.school,
            ),
          ),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(SparklePressable),
        matching: find.byType(Material),
      ),
    );

    final expectedBase = expectedTokens.taskLearning;
    expect(material.color, expectedBase.withValues(alpha: 0.1));

    final RoundedRectangleBorder shape = material.shape! as RoundedRectangleBorder;
    expect(shape.side.color, expectedBase.withValues(alpha: 0.3));
  });
}
