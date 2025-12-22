import 'package:flutter/material.dart';
import 'package:sparkle/core/design/design_tokens.dart';
import 'package:sparkle/core/design/app_theme.dart';
import 'package:sparkle/core/utils/screen_size.dart';
import 'package:sparkle/core/utils/responsive_utils.dart';
import 'package:sparkle/presentation/widgets/layout/app_sidebar.dart';

/// NavigationDestinationData - 导航目标数据
class NavigationDestinationData {
  /// 图标
  final IconData icon;

  /// 选中时的图标
  final IconData selectedIcon;

  /// 标签文本
  final String label;

  /// 路由路径 (可选)
  final String? route;

  /// 是否显示徽章
  final bool showBadge;

  /// 徽章数量
  final int badgeCount;

  const NavigationDestinationData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.route,
    this.showBadge = false,
    this.badgeCount = 0,
  });

  /// 从 NavigationDestination 创建
  factory NavigationDestinationData.fromDestination(NavigationDestination dest) {
    return NavigationDestinationData(
      icon: (dest.icon as Icon).icon!,
      selectedIcon: (dest.selectedIcon as Icon?)?.icon ?? (dest.icon as Icon).icon!,
      label: dest.label,
    );
  }

  /// 转换为 SidebarItem
  SidebarItem toSidebarItem() {
    return SidebarItem(
      icon: icon,
      selectedIcon: selectedIcon,
      label: label,
      route: route ?? '',
      showBadge: showBadge,
      badgeCount: badgeCount,
    );
  }

  /// 转换为 NavigationDestination
  NavigationDestination toNavigationDestination() {
    return NavigationDestination(
      icon: Icon(icon),
      selectedIcon: Icon(selectedIcon),
      label: label,
    );
  }

  /// 转换为 NavigationRailDestination
  NavigationRailDestination toRailDestination() {
    return NavigationRailDestination(
      icon: showBadge
          ? Badge(
              isLabelVisible: badgeCount > 0,
              label: badgeCount > 0 ? Text('$badgeCount') : null,
              child: Icon(icon),
            )
          : Icon(icon),
      selectedIcon: Icon(selectedIcon),
      label: Text(label),
    );
  }
}

/// AdaptiveNavigation - 自适应导航组件
///
/// 根据屏幕尺寸自动选择合适的导航形式：
/// - Mobile: BottomNavigationBar
/// - Tablet: NavigationRail
/// - Desktop: AppSidebar
///
/// 使用示例:
/// ```dart
/// AdaptiveNavigation(
///   selectedIndex: _selectedIndex,
///   onDestinationSelected: (index) => setState(() => _selectedIndex = index),
///   destinations: [
///     NavigationDestinationData(
///       icon: Icons.home_outlined,
///       selectedIcon: Icons.home,
///       label: '驾驶舱',
///     ),
///     // ...
///   ],
///   body: _screens[_selectedIndex],
/// )
/// ```
class AdaptiveNavigation extends StatelessWidget {
  /// 当前选中的索引
  final int selectedIndex;

  /// 选中项变化回调
  final ValueChanged<int> onDestinationSelected;

  /// 导航目标列表
  final List<NavigationDestinationData> destinations;

  /// 主体内容
  final Widget body;

  /// 侧边栏顶部内容 (仅桌面端)
  final Widget? sidebarHeader;

  /// 侧边栏底部内容 (仅桌面端)
  final Widget? sidebarFooter;

  const AdaptiveNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    super.key,
    this.sidebarHeader,
    this.sidebarFooter,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = ResponsiveUtils.getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.mobile:
        return _buildMobileLayout(context);
      case ScreenSize.tablet:
        return _buildTabletLayout(context);
      case ScreenSize.desktop:
      case ScreenSize.wide:
        return _buildDesktopLayout(context);
    }
  }

  /// 移动端布局: 底部导航栏
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: body,
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  /// 平板端布局: NavigationRail
  Widget _buildTabletLayout(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            backgroundColor: AppTheme.getBackgroundColor(brightness),
            indicatorColor: AppDesignTokens.primaryBase.withAlpha(30),
            selectedIconTheme: IconThemeData(
              color: AppDesignTokens.primaryBase,
            ),
            unselectedIconTheme: const IconThemeData(
              color: Colors.white70,
            ),
            selectedLabelTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppDesignTokens.flameGradient,
                  borderRadius: AppDesignTokens.borderRadius12,
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            destinations: destinations.map((d) => d.toRailDestination()).toList(),
          ),
          // 分隔线
          Container(
            width: 1,
            color: AppDesignTokens.glassBorder,
          ),
          // 主体内容
          Expanded(child: body),
        ],
      ),
    );
  }

  /// 桌面端布局: 完整侧边栏
  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            items: destinations.map((d) => d.toSidebarItem()).toList(),
            header: sidebarHeader,
            footer: sidebarFooter,
          ),
          // 主体内容
          Expanded(child: body),
        ],
      ),
    );
  }

  /// 构建底部导航栏
  Widget _buildBottomNavigationBar(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getBackgroundColor(brightness).withAlpha(216), // 0.85 * 255
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: BottomNavigationBar(
        items: destinations.map((d) {
          if (d.showBadge) {
            return BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: d.badgeCount > 0,
                label: d.badgeCount > 0 ? Text('${d.badgeCount}') : null,
                child: Icon(d.icon),
              ),
              activeIcon: Icon(d.selectedIcon),
              label: d.label,
            );
          }
          return BottomNavigationBarItem(
            icon: Icon(d.icon),
            activeIcon: Icon(d.selectedIcon),
            label: d.label,
          );
        }).toList(),
        currentIndex: selectedIndex,
        onTap: onDestinationSelected,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        unselectedItemColor: Colors.white54,
        selectedItemColor: AppDesignTokens.primaryBase,
        selectedFontSize: 10,
        unselectedFontSize: 10,
      ),
    );
  }
}
