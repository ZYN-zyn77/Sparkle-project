import 'package:flutter/material.dart';
import 'package:sparkle/core/design/design_tokens.dart';

/// ScreenSize - 屏幕尺寸枚举
/// 用于响应式布局的断点判断
enum ScreenSize {
  /// 手机端: < 768px
  mobile,

  /// 平板端: 768px - 1024px
  tablet,

  /// 桌面端: 1024px - 1440px
  desktop,

  /// 宽屏: >= 1440px
  wide,
}

/// ScreenSize 扩展方法
extension ScreenSizeExtension on ScreenSize {
  /// 是否为手机端
  bool get isMobile => this == ScreenSize.mobile;

  /// 是否为平板端
  bool get isTablet => this == ScreenSize.tablet;

  /// 是否为桌面端 (包括 wide)
  bool get isDesktop => this == ScreenSize.desktop || this == ScreenSize.wide;

  /// 是否为宽屏
  bool get isWide => this == ScreenSize.wide;

  /// 是否使用底部导航栏
  bool get useBottomNav => this == ScreenSize.mobile;

  /// 是否使用 NavigationRail (侧边图标栏)
  bool get useRail => this == ScreenSize.tablet;

  /// 是否使用完整侧边栏
  bool get useSidebar => isDesktop;

  /// 是否为触摸设备布局 (手机或平板)
  bool get isTouchLayout => isMobile || isTablet;

  /// 是否为鼠标交互布局 (桌面或宽屏)
  bool get isPointerLayout => isDesktop;

  /// 获取内容区最大宽度
  double get contentMaxWidth {
    switch (this) {
      case ScreenSize.mobile:
        return AppDesignTokens.contentMaxWidthMobile;
      case ScreenSize.tablet:
        return AppDesignTokens.contentMaxWidthTablet;
      case ScreenSize.desktop:
        return AppDesignTokens.contentMaxWidthDesktop;
      case ScreenSize.wide:
        return AppDesignTokens.contentMaxWidthWide;
    }
  }

  /// 获取默认内边距
  EdgeInsets get defaultPadding {
    switch (this) {
      case ScreenSize.mobile:
        return const EdgeInsets.symmetric(horizontal: 16);
      case ScreenSize.tablet:
        return const EdgeInsets.symmetric(horizontal: 24);
      case ScreenSize.desktop:
        return const EdgeInsets.symmetric(horizontal: 32);
      case ScreenSize.wide:
        return const EdgeInsets.symmetric(horizontal: 48);
    }
  }

  /// 获取导航栏宽度 (0 表示使用底部导航)
  double get navigationWidth {
    switch (this) {
      case ScreenSize.mobile:
        return 0;
      case ScreenSize.tablet:
        return AppDesignTokens.railWidth;
      case ScreenSize.desktop:
      case ScreenSize.wide:
        return AppDesignTokens.sidebarWidth;
    }
  }

  /// 获取 Bento Grid 列数
  int get bentoGridColumns {
    switch (this) {
      case ScreenSize.mobile:
        return 4;
      case ScreenSize.tablet:
        return 6;
      case ScreenSize.desktop:
      case ScreenSize.wide:
        return 8;
    }
  }
}

/// 从 BuildContext 获取当前屏幕尺寸
ScreenSize getScreenSizeFromContext(BuildContext context) {
  final width = MediaQuery.of(context).size.width;

  if (width < AppDesignTokens.breakpointTablet) {
    return ScreenSize.mobile;
  } else if (width < AppDesignTokens.breakpointDesktop) {
    return ScreenSize.tablet;
  } else if (width < AppDesignTokens.breakpointWide) {
    return ScreenSize.desktop;
  } else {
    return ScreenSize.wide;
  }
}
