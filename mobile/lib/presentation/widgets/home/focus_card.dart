import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/design/design_tokens.dart';
import 'package:sparkle/presentation/providers/dashboard_provider.dart';
import 'package:sparkle/presentation/widgets/common/app_card.dart';
import 'package:sparkle/presentation/widgets/galaxy/flame_core.dart';

/// FocusCard - Deep Dive Entry Card for Project Cockpit
/// Updated with FlameCore shader and AppCard standardization.
class FocusCard extends ConsumerWidget {
  final VoidCallback? onTap;

  const FocusCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final todayMinutes = dashboardState.flame.todayFocusMinutes;
    final flameLevel = dashboardState.flame.level;
    final intensity = (todayMinutes / 120.0).clamp(0.0, 1.0); // Normalize intensity based on 2h goal

    return AppCard(
      onTap: onTap,
      gradient: LinearGradient(
        colors: [
          AppDesignTokens.flameCore.withAlpha(60),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '专注核心',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.flameCore.withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Lv.$flameLevel',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: FlameCore(intensity: intensity),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatFocusTime(todayMinutes),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '今日专注时长',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dashboardState.weather.type == 'sunny' ? '心流状态' : '进入驾驶舱',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 14),
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

  String _formatFocusTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}
