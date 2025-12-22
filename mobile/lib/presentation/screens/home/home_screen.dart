import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sparkle/core/design/app_theme.dart';
import 'package:sparkle/core/utils/screen_size.dart';
import 'package:sparkle/core/utils/responsive_utils.dart';
import 'package:sparkle/presentation/providers/dashboard_provider.dart';
import 'package:sparkle/presentation/providers/task_provider.dart';
import 'package:sparkle/presentation/screens/chat/chat_screen.dart';
import 'package:sparkle/presentation/screens/galaxy_screen.dart';
import 'package:sparkle/presentation/screens/community/community_screen.dart';
import 'package:sparkle/presentation/screens/profile/profile_screen.dart';
import 'package:sparkle/presentation/widgets/home/weather_header.dart';
import 'package:sparkle/presentation/widgets/home/focus_card.dart';
import 'package:sparkle/presentation/widgets/home/prism_card.dart';
import 'package:sparkle/presentation/widgets/home/sprint_card.dart';
import 'package:sparkle/presentation/widgets/home/stats_card.dart';
import 'package:sparkle/presentation/widgets/home/streak_card.dart';
import 'package:sparkle/presentation/widgets/home/next_actions_card.dart';
import 'package:sparkle/presentation/widgets/home/omnibar.dart';
import 'package:sparkle/presentation/widgets/home/responsive_bento_grid.dart';
import 'package:sparkle/presentation/widgets/layout/responsive_container.dart';
import 'package:sparkle/presentation/widgets/layout/responsive_shell.dart';
import 'package:sparkle/presentation/widgets/layout/adaptive_navigation.dart';

/// HomeScreen v2.4 - The Cockpit with Responsive Multi-platform Support
///
/// 支持 Mobile / Tablet / Desktop 三种布局模式：
/// - Mobile: 底部导航栏 + 4列 Bento Grid
/// - Tablet: NavigationRail + 6列 Bento Grid
/// - Desktop: 侧边栏 + 8列 Bento Grid
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveShell(
      destinations: const [
        NavigationDestinationData(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: '驾驶舱',
          route: '/home',
        ),
        NavigationDestinationData(
          icon: Icons.auto_awesome_outlined,
          selectedIcon: Icons.auto_awesome,
          label: '星图',
          route: '/galaxy',
        ),
        NavigationDestinationData(
          icon: Icons.forum_outlined,
          selectedIcon: Icons.forum,
          label: '对话',
          route: '/chat',
        ),
        NavigationDestinationData(
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups,
          label: '社群',
          route: '/community',
        ),
        NavigationDestinationData(
          icon: Icons.person_outlined,
          selectedIcon: Icons.person,
          label: '我的',
          route: '/profile',
        ),
      ],
      screens: const [
        _DashboardScreen(),
        GalaxyScreen(),
        ChatScreen(),
        CommunityScreen(),
        ProfileScreen(),
      ],
    );
  }
}

/// _DashboardScreen - 驾驶舱主界面
///
/// 采用响应式 Bento Grid 布局，自动适应不同屏幕尺寸。
class _DashboardScreen extends ConsumerWidget {
  const _DashboardScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听 dashboardProvider 以触发刷新
    ref.watch(dashboardProvider);
    final screenSize = ResponsiveUtils.getScreenSize(context);
    final brightness = Theme.of(context).brightness;

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.getBackgroundGradient(brightness),
      ),
      child: ResponsiveContainer(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            // Layer 1: Weather Header (Background particles and status)
            const WeatherHeader(),

            // Layer 2: Dashboard Content
            SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref.read(dashboardProvider.notifier).refresh();
                  await ref.read(taskListProvider.notifier).refreshTasks();
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Spacer for Weather Header content area
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: ResponsiveValue<double>(
                          context: context,
                          mobile: 140,
                          tablet: 120,
                          desktop: 100,
                        ).value,
                      ),
                    ),

                    // Responsive Bento Grid
                    SliverPadding(
                      padding: screenSize.defaultPadding,
                      sliver: SliverToBoxAdapter(
                        child: ResponsiveBentoGrid(
                          focusCard: FocusCard(onTap: () => context.push('/focus')),
                          prismCard: const PrismCard(),
                          sprintCard: SprintCard(onTap: () => context.push('/plans')),
                          statsCard: const StatsCard(),
                          streakCard: const StreakCard(),
                          actionsCard: NextActionsCard(onViewAll: () => context.push('/tasks')),
                        ),
                      ),
                    ),

                    // Extra padding for OmniBar (only on mobile)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: screenSize.isMobile ? 160 : 80,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Layer 3: Omni-Bar (positioned differently based on screen size)
            _buildOmniBar(context, screenSize),
          ],
        ),
      ),
    );
  }

  /// 构建 OmniBar，根据屏幕尺寸调整位置
  Widget _buildOmniBar(BuildContext context, ScreenSize screenSize) {
    // 桌面端: OmniBar 在内容区底部居中
    // 移动端: OmniBar 在底部导航栏上方

    final horizontalPadding = ResponsiveValue<double>(
      context: context,
      mobile: 16,
      tablet: 24,
      desktop: 32,
    ).value;

    final bottomOffset = ResponsiveValue<double>(
      context: context,
      mobile: 110, // 底部导航栏上方
      tablet: 24,
      desktop: 24,
    ).value;

    return Positioned(
      left: horizontalPadding,
      right: horizontalPadding,
      bottom: bottomOffset,
      child: const OmniBar(),
    );
  }
}
