import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/design/design_tokens.dart';
import 'package:sparkle/presentation/providers/dashboard_provider.dart';
import 'package:sparkle/presentation/widgets/common/app_card.dart';

/// StatsCard - 学习统计卡片
/// 显示本周学习数据
class StatsCard extends ConsumerWidget {
  final VoidCallback? onTap;

  const StatsCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final weeklyMinutes = dashboardState.flame.todayFocusMinutes * 7; // 模拟数据
    final weeklyTasks = 12; // 模拟数据

    return AppCard(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.success.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      color: AppDesignTokens.success,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '本周',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),

              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(weeklyMinutes / 60).toStringAsFixed(1)}h',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$weeklyTasks 任务',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
