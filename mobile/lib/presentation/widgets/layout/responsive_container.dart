import 'package:flutter/material.dart';
import 'package:sparkle/core/utils/screen_size.dart';
import 'package:sparkle/core/utils/responsive_utils.dart';

/// ResponsiveContainer - 响应式内容容器
///
/// 根据屏幕尺寸自动调整最大宽度和内边距，替代 MobileConstrainedBox。
/// 在宽屏设备上居中显示内容，两侧自动留白。
///
/// 使用示例:
/// ```dart
/// ResponsiveContainer(
///   child: MyContent(),
/// )
/// ```
class ResponsiveContainer extends StatelessWidget {
  /// 子组件
  final Widget child;

  /// 自定义最大宽度 (覆盖默认值)
  final double? maxWidth;

  /// 自定义内边距 (覆盖默认值)
  final EdgeInsets? padding;

  /// 是否居中显示内容
  final bool centerContent;

  /// 背景颜色
  final Color? backgroundColor;

  /// 是否使用屏幕尺寸的默认内边距
  final bool applyDefaultPadding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.backgroundColor,
    this.centerContent = true,
    this.applyDefaultPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = ResponsiveUtils.getScreenSize(context);
    final effectiveMaxWidth = maxWidth ?? screenSize.contentMaxWidth;
    final effectivePadding = padding ?? (applyDefaultPadding ? screenSize.defaultPadding : EdgeInsets.zero);

    Widget content = child;

    // 应用内边距
    if (effectivePadding != EdgeInsets.zero) {
      content = Padding(
        padding: effectivePadding,
        child: content,
      );
    }

    // 应用最大宽度约束
    content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
      child: content,
    );

    // 居中显示
    if (centerContent) {
      content = Center(child: content);
    }

    // 应用背景色
    if (backgroundColor != null) {
      content = Container(
        color: backgroundColor,
        child: content,
      );
    }

    return content;
  }

  /// 获取指定屏幕尺寸的默认最大宽度
  static double getMaxWidth(ScreenSize size) => size.contentMaxWidth;

  /// 获取指定屏幕尺寸的默认内边距
  static EdgeInsets getPadding(ScreenSize size) => size.defaultPadding;
}

/// ResponsiveBuilder - 响应式构建器
///
/// 提供 ScreenSize 参数的便捷构建器，用于需要根据屏幕尺寸
/// 显示完全不同布局的场景。
///
/// 使用示例:
/// ```dart
/// ResponsiveBuilder(
///   mobile: (context) => MobileLayout(),
///   tablet: (context) => TabletLayout(),
///   desktop: (context) => DesktopLayout(),
/// )
/// ```
class ResponsiveBuilder extends StatelessWidget {
  /// 手机端布局构建器
  final Widget Function(BuildContext context) mobile;

  /// 平板端布局构建器 (可选，默认使用 mobile)
  final Widget Function(BuildContext context)? tablet;

  /// 桌面端布局构建器 (可选，默认使用 tablet 或 mobile)
  final Widget Function(BuildContext context)? desktop;

  const ResponsiveBuilder({
    required this.mobile,
    super.key,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = ResponsiveUtils.getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.mobile:
        return mobile(context);
      case ScreenSize.tablet:
        return (tablet ?? mobile)(context);
      case ScreenSize.desktop:
      case ScreenSize.wide:
        return (desktop ?? tablet ?? mobile)(context);
    }
  }
}

/// ResponsiveValue - 响应式值选择器
///
/// 根据屏幕尺寸返回不同的值，用于简化响应式属性设置。
///
/// 使用示例:
/// ```dart
/// final columns = ResponsiveValue<int>(
///   context: context,
///   mobile: 2,
///   tablet: 3,
///   desktop: 4,
/// ).value;
/// ```
class ResponsiveValue<T> {
  final BuildContext context;
  final T mobile;
  final T? tablet;
  final T? desktop;

  const ResponsiveValue({
    required this.context,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  /// 获取当前屏幕尺寸对应的值
  T get value {
    final screenSize = ResponsiveUtils.getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.mobile:
        return mobile;
      case ScreenSize.tablet:
        return tablet ?? mobile;
      case ScreenSize.desktop:
      case ScreenSize.wide:
        return desktop ?? tablet ?? mobile;
    }
  }
}
