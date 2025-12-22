import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/design/design_tokens.dart';
import 'package:sparkle/presentation/providers/dashboard_provider.dart';
import 'package:sparkle/presentation/widgets/common/app_card.dart';

/// StreakCard - 学习条纹卡片
/// 显示连续学习天数
class StreakCard extends ConsumerWidget {
  final VoidCallback? onTap;

  const StreakCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakDays = 7; // 模拟数据

    return AppCard(
      onTap: onTap,
      gradient: LinearGradient(
        colors: [
          AppDesignTokens.warning.withAlpha(60),
          AppDesignTokens.glassBackground,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppDesignTokens.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '连续打卡',
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$streakDays',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.warning,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '天',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Center(
                child: Text(
                  '继续保持!',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withAlpha(150),
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
