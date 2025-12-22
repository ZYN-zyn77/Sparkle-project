import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/design/design_tokens.dart';
import 'package:sparkle/presentation/providers/dashboard_provider.dart';
import 'package:sparkle/presentation/widgets/common/app_card.dart';

/// SprintCard - Sprint Progress Card for v2.3 dashboard
/// Updated with AppCard standardization.
class SprintCard extends ConsumerWidget {
  final VoidCallback? onTap;

  const SprintCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final sprint = dashboardState.sprint;

    return AppCard(
      onTap: onTap,
      child: sprint != null
          ? _buildSprintContent(sprint)
          : _buildEmptyState(),
    );
  }

  Widget _buildSprintContent(SprintData sprint) {
    final progress = sprint.progress;
    final daysLeft = sprint.daysLeft;
    final isUrgent = daysLeft <= 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            const Text(
              '冲刺',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),

            Expanded(
              child: Center(
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(70, 70),
                        painter: _CircularProgressPainter(
                          progress: progress,
                          isUrgent: isUrgent,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$daysLeft',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isUrgent ? Colors.red : Colors.white,
                            ),
                          ),
                          Text(
                            '天',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withAlpha(180),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Sprint name
            Text(
              sprint.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${(progress * 100).toInt()}% 完成',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withAlpha(150),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.flash_on_rounded,
            color: Colors.white54,
            size: 20,
          ),
        ),

        const Spacer(),

        const Text(
          '无冲刺计划',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '点击创建',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withAlpha(120),
          ),
        ),
      ],
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final bool isUrgent;

  _CircularProgressPainter({
    required this.progress,
    required this.isUrgent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background circle
    final bgPaint = Paint()
      ..color = Colors.white.withAlpha(30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = isUrgent ? Colors.red : AppDesignTokens.primaryBase
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isUrgent != isUrgent;
  }
}
