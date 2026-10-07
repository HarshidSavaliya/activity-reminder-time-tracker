import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/routes/app_routes.dart';
import 'calendar/calendar_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'profile/profile_screen.dart';
import 'settings/settings_screen.dart';

/// MainNavigationShell provides an ultra-modern floating pill bottom navigation bar
/// with balanced proportions, sleek active indicators, and quick action launcher.
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  // The 4 main screens (Home, Calendar, Settings, Profile)
  final List<Widget> _screens = const [
    DashboardScreen(),
    CalendarScreen(),
    SettingsScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.floatingNavBg,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  label: 'Home',
                  isSelected: _currentIndex == 0,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.calendar_month_outlined,
                  activeIcon: Icons.calendar_month_rounded,
                  label: 'Calendar',
                  isSelected: _currentIndex == 1,
                ),
                _buildCenterAddButton(),
                _buildNavItem(
                  index: 2,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Settings',
                  isSelected: _currentIndex == 2,
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: _currentIndex == 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
  }) {
    final activeBg = AppColors.primary;
    const inactiveColor = Color(0xFF9E9CAE);

    return Expanded(
      child: Center(
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            decoration: BoxDecoration(
              color: isSelected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeBg.withValues(alpha: 0.38),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 20,
                  color: isSelected ? Colors.white : inactiveColor,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : inactiveColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterAddButton() {
    return Container(
      width: 42,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: AppColors.statusTodo,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.statusTodo.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 24,
        ),
        tooltip: 'Add New Activity',
        onPressed: () {
          Navigator.of(context).pushNamed(AppRoutes.activityForm);
        },
      ),
    );
  }
}
