import 'package:flutter/material.dart';
import 'package:sparkle/core/design/design_tokens.dart';
import 'package:sparkle/presentation/widgets/common/hover_card.dart';

/// SidebarItem - 侧边栏导航项配置
class SidebarItem {
  /// 图标
  final IconData icon;

  /// 选中时的图标 (可选)
  final IconData? selectedIcon;

  /// 标签文本
  final String label;

  /// 路由路径
  final String route;

  /// 是否显示徽章
  final bool showBadge;

  /// 徽章数量 (0 表示仅显示红点)
  final int badgeCount;

  const SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    this.selectedIcon,
    this.showBadge = false,
    this.badgeCount = 0,
  });
}

/// AppSidebar - 桌面端侧边栏
///
/// 用于桌面端的主导航，支持图标 + 标签、悬停效果、徽章显示。
/// 采用深空主题风格。
///
/// 使用示例:
/// ```dart
/// AppSidebar(
///   selectedIndex: 0,
///   onDestinationSelected: (index) => setState(() => _selectedIndex = index),
///   items: [
///     SidebarItem(icon: Icons.home, label: '驾驶舱', route: '/home'),
///     SidebarItem(icon: Icons.auto_awesome, label: '星图', route: '/galaxy'),
///   ],
/// )
/// ```
class AppSidebar extends StatelessWidget {
  /// 当前选中的索引
  final int selectedIndex;

  /// 选中项变化回调
  final ValueChanged<int> onDestinationSelected;

  /// 导航项列表
  final List<SidebarItem> items;

  /// 侧边栏宽度
  final double width;

  /// 是否显示标签文本
  final bool showLabels;

  /// 顶部额外内容 (如 Logo)
  final Widget? header;

  /// 底部额外内容 (如设置按钮)
  final Widget? footer;

  const AppSidebar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
    super.key,
    this.width = AppDesignTokens.sidebarWidth,
    this.showLabels = true,
    this.header,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppDesignTokens.deepSpaceStart,
        border: Border(
          right: BorderSide(
            color: AppDesignTokens.glassBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header (Logo)
          if (header != null) header!,
          if (header == null) _buildDefaultHeader(),

          // Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDesignTokens.spacing12,
                vertical: AppDesignTokens.spacing8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _SidebarNavItem(
                  item: items[index],
                  isSelected: selectedIndex == index,
                  showLabel: showLabels,
                  onTap: () => onDestinationSelected(index),
                );
              },
            ),
          ),

          // Footer
          if (footer != null) footer!,
        ],
      ),
    );
  }

  Widget _buildDefaultHeader() {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(AppDesignTokens.spacing16),
      child: Row(
        children: [
          // Logo
          Container(
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
          if (showLabels) ...[
            const SizedBox(width: AppDesignTokens.spacing12),
            const Text(
              'Sparkle',
              style: TextStyle(
                color: Colors.white,
                fontSize: AppDesignTokens.fontSizeLg,
                fontWeight: AppDesignTokens.fontWeightBold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// _SidebarNavItem - 单个侧边栏导航项
class _SidebarNavItem extends StatelessWidget {
  final SidebarItem item;
  final bool isSelected;
  final bool showLabel;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.item,
    required this.isSelected,
    required this.showLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing4),
      child: HoverableWidget(
        onTap: onTap,
        builder: (context, isHovered) {
          return AnimatedContainer(
            duration: AppDesignTokens.durationFast,
            padding: EdgeInsets.symmetric(
              horizontal: AppDesignTokens.spacing12,
              vertical: showLabel ? AppDesignTokens.spacing12 : AppDesignTokens.spacing16,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppDesignTokens.primaryBase.withAlpha(30)
                  : isHovered
                      ? Colors.white.withAlpha(10)
                      : Colors.transparent,
              borderRadius: AppDesignTokens.borderRadius12,
              border: isSelected
                  ? Border.all(
                      color: AppDesignTokens.primaryBase.withAlpha(50),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Icon with badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? (item.selectedIcon ?? item.icon) : item.icon,
                      color: isSelected
                          ? AppDesignTokens.primaryBase
                          : isHovered
                              ? Colors.white
                              : Colors.white70,
                      size: AppDesignTokens.iconSizeBase,
                    ),
                    if (item.showBadge)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: _buildBadge(),
                      ),
                  ],
                ),

                // Label
                if (showLabel) ...[
                  const SizedBox(width: AppDesignTokens.spacing12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : isHovered
                                ? Colors.white
                                : Colors.white70,
                        fontSize: AppDesignTokens.fontSizeSm,
                        fontWeight: isSelected
                            ? AppDesignTokens.fontWeightSemibold
                            : AppDesignTokens.fontWeightRegular,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadge() {
    if (item.badgeCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: AppDesignTokens.error,
          borderRadius: AppDesignTokens.borderRadiusFull,
        ),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        child: Text(
          item.badgeCount > 99 ? '99+' : '${item.badgeCount}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // 仅显示红点
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppDesignTokens.error,
        shape: BoxShape.circle,
      ),
    );
  }
}
