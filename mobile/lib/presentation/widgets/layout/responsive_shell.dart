import 'package:flutter/material.dart';
import 'package:sparkle/presentation/widgets/layout/adaptive_navigation.dart';

/// ResponsiveShell - 响应式应用外壳
///
/// 整合自适应导航和屏幕切换，提供统一的响应式布局入口。
/// 自动处理不同屏幕尺寸下的导航形式切换。
///
/// 使用示例:
/// ```dart
/// ResponsiveShell(
///   destinations: [
///     NavigationDestinationData(
///       icon: Icons.home_outlined,
///       selectedIcon: Icons.home,
///       label: '驾驶舱',
///     ),
///     // ...
///   ],
///   screens: [
///     DashboardScreen(),
///     GalaxyScreen(),
///     // ...
///   ],
/// )
/// ```
class ResponsiveShell extends StatefulWidget {
  /// 导航目标列表
  final List<NavigationDestinationData> destinations;

  /// 各标签对应的屏幕
  final List<Widget> screens;

  /// 初始选中索引
  final int initialIndex;

  /// 选中项变化回调 (可选)
  final ValueChanged<int>? onDestinationSelected;

  /// 侧边栏顶部内容 (仅桌面端)
  final Widget? sidebarHeader;

  /// 侧边栏底部内容 (仅桌面端)
  final Widget? sidebarFooter;

  const ResponsiveShell({
    required this.destinations,
    required this.screens,
    super.key,
    this.initialIndex = 0,
    this.onDestinationSelected,
    this.sidebarHeader,
    this.sidebarFooter,
  }) : assert(destinations.length == screens.length,
            'destinations and screens must have the same length');

  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
    widget.onDestinationSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveNavigation(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onDestinationSelected,
      destinations: widget.destinations,
      body: IndexedStack(
        index: _selectedIndex,
        children: widget.screens,
      ),
      sidebarHeader: widget.sidebarHeader,
      sidebarFooter: widget.sidebarFooter,
    );
  }
}

/// ResponsiveShellWithRouter - 使用 go_router 的响应式外壳
///
/// 与 go_router 的 ShellRoute 配合使用，支持 URL 同步。
/// 导航状态由路由管理，而非本地状态。
///
/// 使用示例:
/// ```dart
/// // 在 routes.dart 中
/// ShellRoute(
///   builder: (context, state, child) {
///     return ResponsiveShellWithRouter(
///       destinations: [...],
///       currentPath: state.uri.path,
///       child: child,
///     );
///   },
///   routes: [...],
/// )
/// ```
class ResponsiveShellWithRouter extends StatelessWidget {
  /// 导航目标列表
  final List<NavigationDestinationData> destinations;

  /// 当前路由路径
  final String currentPath;

  /// 子组件 (由路由提供)
  final Widget child;

  /// 路由导航回调
  final void Function(String route)? onNavigate;

  /// 侧边栏顶部内容 (仅桌面端)
  final Widget? sidebarHeader;

  /// 侧边栏底部内容 (仅桌面端)
  final Widget? sidebarFooter;

  const ResponsiveShellWithRouter({
    required this.destinations,
    required this.currentPath,
    required this.child,
    super.key,
    this.onNavigate,
    this.sidebarHeader,
    this.sidebarFooter,
  });

  int get _selectedIndex {
    for (int i = 0; i < destinations.length; i++) {
      if (destinations[i].route != null &&
          currentPath.startsWith(destinations[i].route!)) {
        return i;
      }
    }
    return 0;
  }

  void _onDestinationSelected(int index) {
    final route = destinations[index].route;
    if (route != null && onNavigate != null) {
      onNavigate!(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveNavigation(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onDestinationSelected,
      destinations: destinations,
      body: child,
      sidebarHeader: sidebarHeader,
      sidebarFooter: sidebarFooter,
    );
  }
}
