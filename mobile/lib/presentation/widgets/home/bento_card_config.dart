import 'package:sparkle/core/design/design_tokens.dart';
import 'package:sparkle/core/utils/screen_size.dart';

/// BentoCardLayout - 单个卡片的布局配置
class BentoCardLayout {
  /// 横向占用的列数
  final double crossAxisCellCount;

  /// 纵向占用的行数
  final double mainAxisCellCount;

  const BentoCardLayout({
    required this.crossAxisCellCount,
    required this.mainAxisCellCount,
  });

  /// 创建 FocusCard 布局
  factory BentoCardLayout.focus(double cross, double main) {
    return BentoCardLayout(crossAxisCellCount: cross, mainAxisCellCount: main);
  }

  /// 创建 PrismCard 布局
  factory BentoCardLayout.prism(double cross, double main) {
    return BentoCardLayout(crossAxisCellCount: cross, mainAxisCellCount: main);
  }

  /// 创建 SprintCard 布局
  factory BentoCardLayout.sprint(double cross, double main) {
    return BentoCardLayout(crossAxisCellCount: cross, mainAxisCellCount: main);
  }

  /// 创建 NextActionsCard 布局
  factory BentoCardLayout.actions(double cross, double main) {
    return BentoCardLayout(crossAxisCellCount: cross, mainAxisCellCount: main);
  }
}

/// BentoGridConfig - Bento Grid 的完整配置
class BentoGridConfig {
  /// 网格列数
  final int crossAxisCount;

  /// 各卡片的布局配置
  final List<BentoCardLayout> layouts;

  /// 网格间距
  final double spacing;

  const BentoGridConfig({
    required this.crossAxisCount,
    required this.layouts,
    this.spacing = AppDesignTokens.bentoGridSpacing,
  });

  /// FocusCard 的布局
  BentoCardLayout get focusLayout => layouts.isNotEmpty ? layouts[0] : const BentoCardLayout(crossAxisCellCount: 2, mainAxisCellCount: 2);

  /// PrismCard 的布局
  BentoCardLayout get prismLayout => layouts.length > 1 ? layouts[1] : const BentoCardLayout(crossAxisCellCount: 1, mainAxisCellCount: 1);

  /// SprintCard 的布局
  BentoCardLayout get sprintLayout => layouts.length > 2 ? layouts[2] : const BentoCardLayout(crossAxisCellCount: 1, mainAxisCellCount: 1);

  /// NextActionsCard 的布局
  BentoCardLayout get actionsLayout => layouts.length > 3 ? layouts[3] : const BentoCardLayout(crossAxisCellCount: 4, mainAxisCellCount: 1.5);
}

/// BentoCardConstraints - Bento 卡片尺寸约束
class BentoCardConstraints {
  BentoCardConstraints._();

  /// 最小单元格尺寸
  static const double minCellSize = AppDesignTokens.bentoGridMinCellSize;

  /// 最大单元格尺寸
  static const double maxCellSize = AppDesignTokens.bentoGridMaxCellSize;

  /// 网格间距
  static const double spacing = AppDesignTokens.bentoGridSpacing;

  /// 根据屏幕尺寸获取网格配置
  ///
  /// | 屏幕尺寸 | 列数 | FocusCard | PrismCard | SprintCard | StatsCard | StreakCard | NextActions |
  /// |---------|------|-----------|-----------|------------|-----------|------------|-------------|
  /// | Mobile  | 4    | 2x2       | 1x1       | 1x1        | -         | -          | 4x1.5       |
  /// | Tablet  | 6    | 3x2       | 1.5x1     | 1.5x1      | 1.5x1     | 1.5x1      | 6x1.5       |
  /// | Desktop | 8    | 4x2       | 2x1       | 2x1        | 2x1       | 2x1        | 8x1.5       |
  static BentoGridConfig getConfig(ScreenSize size) {
    switch (size) {
      case ScreenSize.mobile:
        return const BentoGridConfig(
          crossAxisCount: 4,
          layouts: [
            BentoCardLayout(crossAxisCellCount: 2, mainAxisCellCount: 2),     // FocusCard: 2x2
            BentoCardLayout(crossAxisCellCount: 1, mainAxisCellCount: 1),     // PrismCard: 1x1
            BentoCardLayout(crossAxisCellCount: 1, mainAxisCellCount: 1),     // SprintCard: 1x1
            BentoCardLayout(crossAxisCellCount: 4, mainAxisCellCount: 1.5),   // NextActions: 4x1.5
          ],
        );
      case ScreenSize.tablet:
        return const BentoGridConfig(
          crossAxisCount: 6,
          layouts: [
            BentoCardLayout(crossAxisCellCount: 3, mainAxisCellCount: 2),     // FocusCard: 3x2
            BentoCardLayout(crossAxisCellCount: 1.5, mainAxisCellCount: 1),   // PrismCard: 1.5x1
            BentoCardLayout(crossAxisCellCount: 1.5, mainAxisCellCount: 1),   // SprintCard: 1.5x1
            BentoCardLayout(crossAxisCellCount: 1.5, mainAxisCellCount: 1),   // StatsCard: 1.5x1
            BentoCardLayout(crossAxisCellCount: 1.5, mainAxisCellCount: 1),   // StreakCard: 1.5x1
            BentoCardLayout(crossAxisCellCount: 6, mainAxisCellCount: 1.5),   // NextActions: 6x1.5
          ],
        );
      case ScreenSize.desktop:
      case ScreenSize.wide:
        return const BentoGridConfig(
          crossAxisCount: 8,
          layouts: [
            BentoCardLayout(crossAxisCellCount: 4, mainAxisCellCount: 2),     // FocusCard: 4x2
            BentoCardLayout(crossAxisCellCount: 2, mainAxisCellCount: 1),     // PrismCard: 2x1
            BentoCardLayout(crossAxisCellCount: 2, mainAxisCellCount: 1),     // SprintCard: 2x1
            BentoCardLayout(crossAxisCellCount: 2, mainAxisCellCount: 1),     // StatsCard: 2x1
            BentoCardLayout(crossAxisCellCount: 2, mainAxisCellCount: 1),     // StreakCard: 2x1
            BentoCardLayout(crossAxisCellCount: 8, mainAxisCellCount: 1.5),   // NextActions: 8x1.5
          ],
        );
    }
  }

  /// 计算单元格大小
  ///
  /// 基于可用宽度和列数计算合适的单元格大小，
  /// 确保不超过最大/最小约束。
  static double calculateCellSize(double availableWidth, int crossAxisCount) {
    final totalSpacing = spacing * (crossAxisCount - 1);
    final cellSize = (availableWidth - totalSpacing) / crossAxisCount;

    // 应用尺寸约束
    return cellSize.clamp(minCellSize, maxCellSize);
  }
}
