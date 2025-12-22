import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:sparkle/core/design/design_tokens.dart';
import 'package:sparkle/core/utils/responsive_utils.dart';
import 'package:sparkle/presentation/providers/auth_provider.dart';
import 'package:sparkle/presentation/providers/dashboard_provider.dart';
import 'package:sparkle/presentation/providers/task_provider.dart';
import 'package:sparkle/presentation/providers/plan_provider.dart';
import 'package:sparkle/presentation/screens/chat/chat_screen.dart';
import 'package:sparkle/presentation/screens/galaxy_screen.dart';
import 'package:sparkle/presentation/screens/community/community_screen.dart';
import 'package:sparkle/presentation/screens/profile/profile_screen.dart';
import 'package:sparkle/presentation/widgets/home/weather_header.dart';
import 'package:sparkle/presentation/widgets/home/focus_card.dart';
import 'package:sparkle/presentation/widgets/home/prism_card.dart';
import 'package:sparkle/presentation/widgets/home/sprint_card.dart';
import 'package:sparkle/presentation/widgets/home/next_actions_card.dart';
import 'package:sparkle/presentation/widgets/home/omnibar.dart';
import 'package:sparkle/presentation/widgets/layout/mobile_constrained_box.dart';

/// HomeScreen v2.3 - The Cockpit with Multi-tab support
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  List<Widget> get _screens => [
        const _DashboardScreen(),
        const GalaxyScreen(),
        const ChatScreen(),
        const CommunityScreen(),
        const ProfileScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Allows content to flow under the BottomNavigationBar
      body: _screens[_selectedIndex],
      bottomNavigationBar: _buildNavigationBar(),
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A).withOpacity(0.85),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: '驾驶舱'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_outlined), activeIcon: Icon(Icons.auto_awesome), label: '星图'),
          BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), activeIcon: Icon(Icons.forum), label: '对话'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), activeIcon: Icon(Icons.groups), label: '社群'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outlined), activeIcon: Icon(Icons.person), label: '我的'),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        unselectedItemColor: Colors.white54,
        selectedItemColor: AppDesignTokens.primaryBase,
        selectedFontSize: 10,
        unselectedFontSize: 10,
      ),
    );
  }
}

class _DashboardScreen extends ConsumerWidget {
  const _DashboardScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: AppDesignTokens.deepSpaceGradient,
      ),
      child: MobileConstrainedBox(
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
                  const SliverToBoxAdapter(child: SizedBox(height: 140)),

                  // Bento Grid
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: _buildBentoGrid(context, dashboardState),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 160)), // Extra padding for OmniBar
                ],
              ),
            ),
          ),

            // Layer 3: Omni-Bar
            Positioned(
              left: 16,
              right: 16,
              bottom: 110, // Positioned above the BottomNavigationBar
              child: const OmniBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoGrid(BuildContext context, DashboardState state) {
    final spacing = 12.0;

    return StaggeredGrid.count(
      crossAxisCount: 4,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      children: [
        // 🔥 Focus Card (2x2)
        StaggeredGridTile.count(
          crossAxisCellCount: 2,
          mainAxisCellCount: 2,
          child: FocusCard(onTap: () => context.push('/focus')),
        ),
        
        // 💎 Prism Card (1x1)
        StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1,
          child: const PrismCard(),
        ),

        // 🏃 Sprint Card (1x1)
        StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1,
          child: SprintCard(onTap: () => context.push('/plans')),
        ),

        // 📝 Next Actions (4xN - Wide across full width)
        StaggeredGridTile.count(
          crossAxisCellCount: 4,
          mainAxisCellCount: 1.5,
          child: NextActionsCard(onViewAll: () => context.push('/tasks')),
        ),
      ],
    );
  }
}
