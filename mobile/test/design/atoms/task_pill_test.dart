import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparkle/core/design/components/atoms/task_pill.dart';
import 'package:sparkle/core/design/design_system.dart';
import 'package:sparkle/core/design/theme/sparkle_theme_extension.dart';
import 'package:sparkle/core/design/tokens/task_colors.dart';

Widget _wrapWithTheme(Widget child) => MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        extensions: const [SparkleThemeExtension.light()],
      ),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('TaskPill uses tone colors when provided', (tester) async {
    await tester.pumpWidget(
      _wrapWithTheme(
        const TaskPill(
          type: TaskType.learning,
          label: 'Info',
          tone: TaskPillTone.info,
          icon: Icons.info,
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(TaskPill),
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.child is InkWell,
        ),
      ),
    );
    expect(material.color, DS.info.withValues(alpha: 0.1));

    final shape = material.shape as RoundedRectangleBorder;
    expect(shape.side.color, DS.info.withValues(alpha: 0.3));

    final text = tester.widget<Text>(find.text('Info'));
    expect(text.style?.color, DS.info);

    final icon = tester.widget<Icon>(find.byIcon(Icons.info));
    expect(icon.color, DS.info);
  });

  testWidgets('TaskPill falls back to task type colors when tone is null', (tester) async {
    await tester.pumpWidget(
      _wrapWithTheme(
        const TaskPill(
          type: TaskType.training,
          label: 'Training',
          icon: Icons.star,
        ),
      ),
    );

    const taskColors = TaskColors(brightness: Brightness.light);
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(TaskPill),
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.child is InkWell,
        ),
      ),
    );
    expect(material.color, taskColors.getTint(TaskType.training));

    final shape = material.shape as RoundedRectangleBorder;
    expect(shape.side.color, taskColors.getBorder(TaskType.training));

    final icon = tester.widget<Icon>(find.byIcon(Icons.star));
    expect(icon.color, taskColors.getIcon(TaskType.training));
  });

  testWidgets('TaskPill applies dense spacing and triggers tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrapWithTheme(
        TaskPill(
          type: TaskType.planning,
          label: 'Dense',
          dense: true,
          onTap: () => tapped = true,
        ),
      ),
    );

    final padding = tester.widget<Padding>(
      find.descendant(
        of: find.byType(TaskPill),
        matching: find.byType(Padding),
      ),
    );
    expect(padding.padding, const EdgeInsets.symmetric(horizontal: 8, vertical: 4));

    await tester.tap(find.text('Dense'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
