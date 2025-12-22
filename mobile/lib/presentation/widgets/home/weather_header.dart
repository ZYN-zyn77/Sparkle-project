import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/presentation/providers/dashboard_provider.dart';
import 'package:sparkle/presentation/providers/auth_provider.dart';
import 'package:sparkle/core/design/design_tokens.dart';

/// WeatherHeader - Inner Weather Header for v2.3
class WeatherHeader extends ConsumerWidget {
  const WeatherHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final user = ref.watch(currentUserProvider);

    return Container(
      width: double.infinity,
      height: 200, // Fixed height for header area
      decoration: BoxDecoration(
        gradient: _getWeatherGradient(dashboardState.weather.type),
      ),
      child: Stack(
        children: [
          // Background effects
          const _StarField(),
          _buildWeatherEffects(dashboardState.weather.type),

          // Content Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: User & Weather Status
                  Row(
                    children: [
                      // User Info
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                        backgroundColor: AppDesignTokens.primaryBase,
                        child: user?.avatarUrl == null ? Text((user?.nickname ?? 'U')[0].toUpperCase()) : null,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.nickname ?? '探索者',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'Lv.${user?.flameLevel ?? 1}',
                            style: const TextStyle(fontSize: 10, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Weather Status
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getWeatherTitle(dashboardState.weather.type),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(width: 6),
                              _buildWeatherIcon(dashboardState.weather.type),
                            ],
                          ),
                          Text(
                            dashboardState.weather.condition,
                            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  // AI Comment / Today's Focus
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      _getAIComment(dashboardState.weather.type),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getAIComment(String type) {
    switch (type) {
      case 'sunny': return '晴空万里，适合攻克难题';
      case 'cloudy': return '薄雾弥漫，此时宜静心复盘';
      case 'rainy': return '风雨欲来，请保持专注，莫被焦虑左右';
      case 'meteor': return '繁星入梦，今日之成就已成星火';
      default: return '保持好奇，探索未知';
    }
  }

  LinearGradient _getWeatherGradient(String type) {
    switch (type) {
      case 'sunny':
        return const LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'cloudy':
        return const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF2C3E50), Color(0xFF4B5D67)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'rainy':
        return const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'meteor':
        return const LinearGradient(
          colors: [Color(0xFF1A0B2E), Color(0xFF2D1B4E), Color(0xFF4A148C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
    }
  }

  Widget _buildWeatherIcon(String type) {
    IconData icon;
    switch (type) {
      case 'sunny': icon = Icons.wb_sunny_rounded; break;
      case 'cloudy': icon = Icons.cloud_rounded; break;
      case 'rainy': icon = Icons.thunderstorm_rounded; break;
      case 'meteor': icon = Icons.auto_awesome_rounded; break;
      default: icon = Icons.wb_sunny_rounded;
    }
    return Icon(icon, color: Colors.white, size: 18);
  }

  String _getWeatherTitle(String type) {
    switch (type) {
      case 'sunny': return '晴空万里';
      case 'cloudy': return '薄雾弥漫';
      case 'rainy': return '风雨欲来';
      case 'meteor': return '繁星入梦';
      default: return '晴空万里';
    }
  }

  Widget _buildWeatherEffects(String type) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _WeatherParticlePainter(type),
        ),
      ),
    );
  }
}

class _StarField extends StatelessWidget {
  const _StarField();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _StarPainter(),
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final stars = [
      Offset(size.width * 0.1, size.height * 0.15),
      Offset(size.width * 0.3, size.height * 0.08),
      Offset(size.width * 0.5, size.height * 0.12),
      Offset(size.width * 0.7, size.height * 0.05),
      Offset(size.width * 0.85, size.height * 0.18),
      Offset(size.width * 0.15, size.height * 0.25),
      Offset(size.width * 0.6, size.height * 0.22),
      Offset(size.width * 0.9, size.height * 0.28),
    ];

    for (var i = 0; i < stars.length; i++) {
      final opacity = 0.2 + (i % 3) * 0.1;
      final radius = 0.5 + (i % 2) * 0.5;
      paint.color = Colors.white.withAlpha((opacity * 255).toInt());
      canvas.drawCircle(stars[i], radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WeatherParticlePainter extends CustomPainter {
  final String type;
  _WeatherParticlePainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05);

    switch (type) {
      case 'sunny':
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 1;
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.2), 20 + i * 30.0, paint);
        }
        break;
      case 'cloudy':
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.1), 40, paint);
        canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.3), 50, paint);
        break;
      case 'rainy':
        paint.style = PaintingStyle.fill;
        paint.color = Colors.white.withOpacity(0.1);
        for (int i = 0; i < 20; i++) {
          final x = (size.width * 0.1) + (i % 6) * 60;
          final y = (size.height * 0.1) + (i ~/ 6) * 40;
          canvas.drawRect(Rect.fromLTWH(x, y, 1, 10), paint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
