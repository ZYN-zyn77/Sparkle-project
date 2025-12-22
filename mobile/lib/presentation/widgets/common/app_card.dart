import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sparkle/core/design/design_tokens.dart';
import 'package:sparkle/core/utils/responsive_utils.dart';
import 'package:sparkle/presentation/widgets/common/hover_card.dart';

/// AppCard - A standardized card component following Sparkle's design system.
/// Uses the 8px grid principle (padding/margin in multiples of 8).
/// Supports hover effects on desktop platforms.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Gradient? gradient;
  final Color? borderColor;
  final bool glassEffect;

  /// 是否启用悬停效果 (默认在桌面端自动启用)
  final bool enableHover;

  /// 悬停时的缩放比例
  final double hoverScale;

  /// 悬停时的阴影提升量
  final double hoverElevation;

  const AppCard({
    required this.child,
    super.key,
    this.onTap,
    this.padding,
    this.borderRadius,
    this.gradient,
    this.borderColor,
    this.glassEffect = true,
    this.enableHover = true,
    this.hoverScale = 1.02,
    this.hoverElevation = 8.0,
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

    // 在桌面端添加悬停效果
    final shouldEnableHover = enableHover &&
        (ResponsiveUtils.isDesktopPlatform || ResponsiveUtils.isWeb);

    if (shouldEnableHover && onTap != null) {
      return HoverCard(
        onTap: onTap,
        hoverScale: hoverScale,
        hoverElevation: hoverElevation,
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
