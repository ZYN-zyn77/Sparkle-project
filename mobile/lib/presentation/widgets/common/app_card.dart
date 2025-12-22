import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sparkle/core/design/design_tokens.dart';

/// AppCard - A standardized card component following Sparkle's design system.
/// Uses the 8px grid principle (padding/margin in multiples of 8).
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Gradient? gradient;
  final Color? borderColor;
  final bool glassEffect;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius,
    this.gradient,
    this.borderColor,
    this.glassEffect = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = BorderRadius.circular(borderRadius ?? 20.0);
    final effectivePadding = padding ?? const EdgeInsets.all(AppDesignTokens.spacing16);

    Widget cardContent = Container(
      padding: effectivePadding,
      decoration: BoxDecoration(
        gradient: gradient ??
            (glassEffect
                ? LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.1),
                      AppDesignTokens.glassBackground,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null),
        color: !glassEffect && gradient == null ? Colors.white : null,
        borderRadius: effectiveBorderRadius,
        border: Border.all(
          color: borderColor ?? AppDesignTokens.glassBorder,
          width: 0.5,
        ),
        boxShadow: glassEffect ? null : AppDesignTokens.shadowSm,
      ),
      child: child,
    );

    if (glassEffect) {
      cardContent = ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: cardContent,
        ),
      );
    } else {
      cardContent = ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: cardContent,
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
