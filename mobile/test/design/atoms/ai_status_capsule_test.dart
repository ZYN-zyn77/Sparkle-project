import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparkle/core/design/components/atoms/ai_status_capsule.dart';
import 'package:sparkle/core/design/theme/sparkle_theme_extension.dart';
import 'package:sparkle/core/design/tokens/color_tokens_v2.dart' as design_tokens;

Widget _wrapWithTheme(Widget child) => MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        extensions: const [SparkleThemeExtension.light()],
      ),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('AiStatusCapsule uses brand colors by default', (tester) async {
    await tester.pumpWidget(
      _wrapWithTheme(
        const AiStatusCapsule(
          label: 'Ready',
          icon: Icons.bolt,
        ),
      ),
    );

    const tokens = design_tokens.SparkleColors(brightness: Brightness.light);
    final baseColor = tokens.brandPrimary;

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AiStatusCapsule),
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.child is InkWell,
        ),
      ),
    );

    expect(material.color, baseColor.withValues(alpha: 0.12));

    final shape = material.shape as RoundedRectangleBorder;
    expect(shape.side.color, baseColor.withValues(alpha: 0.3));

    final text = tester.widget<Text>(find.text('Ready'));
    expect(text.style?.color, baseColor);

    final icon = tester.widget<Icon>(find.byIcon(Icons.bolt));
    expect(icon.color, baseColor);
  });

  testWidgets('AiStatusCapsule respects custom color and dense spacing', (tester) async {
    const customColor = Colors.green;

    await tester.pumpWidget(
      _wrapWithTheme(
        const AiStatusCapsule(
          label: 'Compact',
          color: customColor,
          dense: true,
        ),
      ),
    );

    final padding = tester.widget<Padding>(
      find.descendant(
        of: find.byType(AiStatusCapsule),
        matching: find.byType(Padding),
      ),
    );
    expect(padding.padding, const EdgeInsets.symmetric(horizontal: 8, vertical: 4));

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AiStatusCapsule),
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.child is InkWell,
        ),
      ),
    );

    expect(material.color, customColor.withValues(alpha: 0.12));

    final shape = material.shape as RoundedRectangleBorder;
    expect(shape.side.color, customColor.withValues(alpha: 0.3));
  });

  testWidgets('AiStatusCapsule triggers tap handler', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrapWithTheme(
        AiStatusCapsule(
          label: 'Tap me',
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Tap me'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
