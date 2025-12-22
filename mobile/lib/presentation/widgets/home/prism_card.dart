import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sparkle/core/design/design_tokens.dart';
import 'package:sparkle/presentation/providers/dashboard_provider.dart';
import 'package:sparkle/presentation/widgets/common/app_card.dart';

/// PrismCard - Cognitive Prism Card (1x1)
/// Updated with AppCard standardization.
class PrismCard extends ConsumerWidget {
  const PrismCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final cognitive = dashboardState.cognitive;
    final weeklyPattern = cognitive.weeklyPattern;

    return AppCard(
      onTap: () => context.go('/cognitive/patterns'),
      gradient: LinearGradient(
        colors: [
          AppDesignTokens.prismPurple.withAlpha(60),
          AppDesignTokens.glassBackground,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      padding: const EdgeInsets.all(AppDesignTokens.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.diamond_outlined, color: Colors.white, size: 16),
              if (cognitive.hasNewInsight)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppDesignTokens.prismPurple,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            weeklyPattern != null ? '#$weeklyPattern' : '认知棱镜',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '发现定式',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }
}
