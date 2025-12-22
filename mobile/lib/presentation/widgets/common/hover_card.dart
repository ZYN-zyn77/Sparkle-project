import 'package:flutter/material.dart';
import 'package:sparkle/core/design/design_tokens.dart';
import 'package:sparkle/core/utils/responsive_utils.dart';

/// HoverCard - 支持鼠标悬停效果的卡片包装器
///
/// 仅在桌面端启用悬停效果，移动端直接显示子组件。
/// 悬停时卡片会轻微放大并增加阴影，提供视觉反馈。
///
/// 使用示例:
/// ```dart
/// HoverCard(
///   onTap: () => print('Tapped'),
///   child: MyCardContent(),
/// )
/// ```
class HoverCard extends StatefulWidget {
  /// 子组件
  final Widget child;

  /// 点击回调
  final VoidCallback? onTap;

  /// 悬停时的阴影提升量
  final double hoverElevation;

  /// 悬停时的缩放比例
  final double hoverScale;

  /// 是否强制启用悬停效果 (默认仅桌面端启用)
  final bool forceEnabled;

  /// 边框圆角
  final BorderRadius? borderRadius;

  const HoverCard({
    required this.child,
    super.key,
    this.onTap,
    this.hoverElevation = 8.0,
    this.hoverScale = 1.02,
    this.forceEnabled = false,
    this.borderRadius,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppDesignTokens.durationFast,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.hoverScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppDesignTokens.curveEaseOut,
    ),);

    _elevationAnimation = Tween<double>(
      begin: 0.0,
      end: widget.hoverElevation,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppDesignTokens.curveEaseOut,
    ),);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _shouldEnableHover {
    if (widget.forceEnabled) return true;
    return ResponsiveUtils.isDesktopPlatform || ResponsiveUtils.isWeb;
  }

  void _onEnter(PointerEvent event) {
    if (!_shouldEnableHover) return;
    _controller.forward();
  }

  void _onExit(PointerEvent event) {
    if (!_shouldEnableHover) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // 移动端: 直接返回可点击的子组件
    if (!_shouldEnableHover) {
      return GestureDetector(
        onTap: widget.onTap,
        child: widget.child,
      );
    }

    // 桌面端: 添加悬停效果
    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius ?? AppDesignTokens.borderRadius16,
                boxShadow: _elevationAnimation.value > 0
                    ? [
                        BoxShadow(
                          color: Colors.black.withAlpha(25), // 0.1 * 255 = 25.5
                          blurRadius: _elevationAnimation.value * 2,
                          offset: Offset(0, _elevationAnimation.value / 2),
                        ),
                      ]
                    : null,
              ),
              child: child,
            ),
          );
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: widget.child,
        ),
      ),
    );
  }
}

/// HoverableWidget - 简化的悬停状态包装器
///
/// 提供更简单的 API，仅返回悬停状态，不处理动画。
/// 适用于需要自定义悬停效果的场景。
///
/// 使用示例:
/// ```dart
/// HoverableWidget(
///   builder: (context, isHovered) => Container(
///     color: isHovered ? Colors.blue : Colors.grey,
///   ),
/// )
/// ```
class HoverableWidget extends StatefulWidget {
  /// 构建器，接收悬停状态
  final Widget Function(BuildContext context, bool isHovered) builder;

  /// 点击回调
  final VoidCallback? onTap;

  /// 是否强制启用
  final bool forceEnabled;

  const HoverableWidget({
    required this.builder,
    super.key,
    this.onTap,
    this.forceEnabled = false,
  });

  @override
  State<HoverableWidget> createState() => _HoverableWidgetState();
}

class _HoverableWidgetState extends State<HoverableWidget> {
  bool _isHovered = false;

  bool get _shouldEnable {
    if (widget.forceEnabled) return true;
    return ResponsiveUtils.isDesktopPlatform || ResponsiveUtils.isWeb;
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.builder(context, _isHovered);

    if (!_shouldEnable) {
      return GestureDetector(
        onTap: widget.onTap,
        child: child,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: child,
      ),
    );
  }
}
