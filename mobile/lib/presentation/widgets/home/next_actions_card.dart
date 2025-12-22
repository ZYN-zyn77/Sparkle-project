import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/design/design_tokens.dart';
import 'package:sparkle/presentation/providers/dashboard_provider.dart';
import 'package:sparkle/presentation/providers/task_provider.dart';
import 'package:sparkle/presentation/widgets/common/app_card.dart';

/// NextActionsCard - Next Actions Card (Wide 2xN)
/// Updated with AppCard standardization.
class NextActionsCard extends ConsumerWidget {
  final VoidCallback? onViewAll;

  const NextActionsCard({super.key, this.onViewAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final nextActions = dashboardState.nextActions;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.playlist_add_check_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    '下一步行动',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              if (onViewAll != null)
                GestureDetector(
                  onTap: onViewAll,
                  child: Text(
                    '全部',
                    style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(150)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Compact List
          if (nextActions.isEmpty)
            _buildEmptyState()
          else
            ...nextActions.take(3).map((task) => _NextActionItem(task: task)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          '目前没有紧急任务',
          style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(100)),
        ),
      ),
    );
  }
}

class _NextActionItem extends ConsumerWidget {
  final TaskData task;
  const _NextActionItem({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              task.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              await ref.read(taskListProvider.notifier).completeTask(task.id, task.estimatedMinutes, null);
              ref.read(dashboardProvider.notifier).refresh();
            },
            child: Icon(Icons.check_circle_outline_rounded, color: Colors.white.withAlpha(150), size: 18),
          ),
        ],
      ),
    );
  }
}
