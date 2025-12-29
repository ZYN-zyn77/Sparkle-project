import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparkle/core/design/theme/sparkle_theme_extension.dart';
import 'package:sparkle/core/design/tokens/color_tokens_v2.dart' as design_tokens;
import 'package:sparkle/presentation/widgets/common/glass_card.dart';

Widget _wrapWithTheme(Widget child) => MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        extensions: const [SparkleThemeExtension.light()],
      ),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('GlassCard applies glass colors and sizing', (tester) async {
    const customColor = Colors.blue;
    await tester.pumpWidget(
      _wrapWithTheme(
        const GlassCard(
          width: 200,
          height: 120,
          color: customColor,
          child: Text('Glass'),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(GlassCard),
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.child is! InkWell,
        ),
      ),
    );
    expect(material.color, customColor.withValues(alpha: 0.1));

    final shape = material.shape as RoundedRectangleBorder;
    const tokens = design_tokens.SparkleColors(brightness: Brightness.light);
    expect(shape.side.color, tokens.neutral200.withValues(alpha: 0.2));

    final sizedBox = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(GlassCard),
        matching: find.byType(SizedBox),
      ),
    );
    expect(sizedBox.width, 200);
    expect(sizedBox.height, 120);
  });

  testWidgets('GlassCard routes tap through SparkleCard when tap effect is disabled', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrapWithTheme(
        GlassCard(
          child: const Text('Plain tap'),
          enableTapEffect: false,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.byType(InkWell), findsOneWidget);

    await tester.tap(find.text('Plain tap'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('GlassCard wraps tap with animation when tap effect is enabled', (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(
      _wrapWithTheme(
        GlassCard(
          child: const Text('Animated'),
          enableTapEffect: true,
          onTap: () => tapCount++,
        ),
      ),
    );

    expect(find.byType(ScaleTransition), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Animated')));
    await tester.pump(const Duration(milliseconds: 50));

    final scale = tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale as Animation<double>;
    expect(scale.value, lessThan(1.0));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(tapCount, 1);
    expect(scale.value, closeTo(1.0, 0.001));
  });
}
