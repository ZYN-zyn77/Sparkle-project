import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:sparkle/core/utils/responsive_utils.dart';
import 'package:sparkle/presentation/widgets/home/bento_card_config.dart';

/// ResponsiveBentoGrid - 响应式 Bento 网格
///
/// 根据屏幕尺寸自动调整列数和卡片大小，解决卡片重叠和比例变形问题。
///
/// 使用示例:
/// ```dart
/// ResponsiveBentoGrid(
///   focusCard: FocusCard(onTap: () => context.push('/focus')),
///   prismCard: const PrismCard(),
///   sprintCard: SprintCard(onTap: () => context.push('/plans')),
///   statsCard: const StatsCard(),
///   streakCard: const StreakCard(),
///   actionsCard: NextActionsCard(onViewAll: () => context.push('/tasks')),
/// )
/// ```
class ResponsiveBentoGrid extends StatelessWidget {
  /// 专注核心卡片 (2x2 on mobile)
  final Widget focusCard;

  /// 认知棱镜卡片 (1x1 on mobile)
  final Widget prismCard;

  /// 冲刺进度卡片 (1x1 on mobile)
  final Widget sprintCard;

  /// 学习统计卡片 (tablet/desktop only)
  final Widget? statsCard;

  /// 学习条纹卡片 (tablet/desktop only)
  final Widget? streakCard;

  /// 下一步行动卡片 (4x1.5 on mobile)
  final Widget actionsCard;

  /// 额外的卡片 (可选)
  final List<BentoGridItem>? extraCards;

  const ResponsiveBentoGrid({
    required this.focusCard,
    required this.prismCard,
    required this.sprintCard,
    required this.actionsCard,
    super.key,
    this.statsCard,
    this.streakCard,
    this.extraCards,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = ResponsiveUtils.getScreenSize(context);
        final config = BentoCardConstraints.getConfig(screenSize);

        return StaggeredGrid.count(
          crossAxisCount: config.crossAxisCount,
          mainAxisSpacing: config.spacing,
          crossAxisSpacing: config.spacing,
          children: _buildGridTiles(config),
        );
      },
    );
  }

  List<Widget> _buildGridTiles(BentoGridConfig config) {
    final tiles = <Widget>[
      // FocusCard
      StaggeredGridTile.count(
        crossAxisCellCount: config.layouts[0].crossAxisCellCount.round(),
        mainAxisCellCount: config.layouts[0].mainAxisCellCount,
        child: focusCard,
      ),

      // PrismCard
      StaggeredGridTile.count(
        crossAxisCellCount: config.layouts[1].crossAxisCellCount.round(),
        mainAxisCellCount: config.layouts[1].mainAxisCellCount,
        child: prismCard,
      ),

      // SprintCard
      StaggeredGridTile.count(
        crossAxisCellCount: config.layouts[2].crossAxisCellCount.round(),
        mainAxisCellCount: config.layouts[2].mainAxisCellCount,
        child: sprintCard,
      ),
    ];

    // 根据布局配置动态添加卡片
    if (config.layouts.length >= 6) {
      // Tablet/Desktop: 添加 StatsCard 和 StreakCard
      if (statsCard != null) {
        tiles.add(
          StaggeredGridTile.count(
            crossAxisCellCount: config.layouts[3].crossAxisCellCount.round(),
            mainAxisCellCount: config.layouts[3].mainAxisCellCount,
            child: statsCard!,
          ),
        );
      }
      if (streakCard != null) {
        tiles.add(
          StaggeredGridTile.count(
            crossAxisCellCount: config.layouts[4].crossAxisCellCount.round(),
            mainAxisCellCount: config.layouts[4].mainAxisCellCount,
            child: streakCard!,
          ),
        );
      }
      // NextActionsCard (最后一个)
      tiles.add(
        StaggeredGridTile.count(
          crossAxisCellCount: config.layouts[5].crossAxisCellCount.round(),
          mainAxisCellCount: config.layouts[5].mainAxisCellCount,
          child: actionsCard,
        ),
      );
    } else {
      // Mobile: 只有4个卡片
      tiles.add(
        StaggeredGridTile.count(
          crossAxisCellCount: config.layouts[3].crossAxisCellCount.round(),
          mainAxisCellCount: config.layouts[3].mainAxisCellCount,
          child: actionsCard,
        ),
      );
    }

    // 添加额外的卡片
    if (extraCards != null) {
      for (final item in extraCards!) {
        tiles.add(
          StaggeredGridTile.count(
            crossAxisCellCount: item.crossAxisCellCount,
            mainAxisCellCount: item.mainAxisCellCount,
            child: item.child,
          ),
        );
      }
    }

    return tiles;
  }
}

/// BentoGridItem - Bento 网格的单个项目
class BentoGridItem {
  /// 横向占用的列数
  final int crossAxisCellCount;

  /// 纵向占用的行数
  final double mainAxisCellCount;

  /// 子组件
  final Widget child;

  const BentoGridItem({
    required this.crossAxisCellCount,
    required this.mainAxisCellCount,
    required this.child,
  });
}

/// SimpleBentoGrid - 简化版 Bento 网格
///
/// 接受任意数量的 BentoGridItem，不限定卡片类型。
/// 适用于自定义布局场景。
class SimpleBentoGrid extends StatelessWidget {
  /// 网格项目列表
  final List<BentoGridItem> items;

  /// 自定义列数 (可选，默认根据屏幕尺寸自动选择)
  final int? crossAxisCount;

  /// 自定义间距 (可选)
  final double? spacing;

  const SimpleBentoGrid({
    required this.items,
    super.key,
    this.crossAxisCount,
    this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = ResponsiveUtils.getScreenSize(context);
    final effectiveCrossAxisCount = crossAxisCount ?? BentoCardConstraints.getConfig(screenSize).crossAxisCount;
    final effectiveSpacing = spacing ?? BentoCardConstraints.spacing;

    return StaggeredGrid.count(
      crossAxisCount: effectiveCrossAxisCount,
      mainAxisSpacing: effectiveSpacing,
      crossAxisSpacing: effectiveSpacing,
      children: items.map((item) {
        return StaggeredGridTile.count(
          crossAxisCellCount: item.crossAxisCellCount,
          mainAxisCellCount: item.mainAxisCellCount,
          child: item.child,
        );
      }).toList(),
    );
  }
}
