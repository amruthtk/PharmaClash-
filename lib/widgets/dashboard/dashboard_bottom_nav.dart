import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// iOS-style liquid glass bottom navigation bar.
/// Uses BackdropFilter to blur content scrolling beneath it.
/// Must be overlaid on content (via Stack + Positioned), NOT
/// placed in Scaffold.bottomNavigationBar, for blur to work.
class DashboardBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const DashboardBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      // ClipRect so BackdropFilter only affects this widget's area
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            // Translucent glass - content visible through it
            color: Colors.white.withOpacity(0.55),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.4), width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    icon: Icons.calendar_today_rounded,
                    label: 'Schedule',
                    index: 1,
                  ),
                  _buildNavItem(
                    icon: Icons.history_rounded,
                    label: 'History',
                    index: 2,
                  ),
                  const SizedBox(width: 68), // Space for FAB
                  _buildNavItem(
                    icon: Icons.flash_on_rounded,
                    label: 'Checker',
                    index: 3,
                  ),
                  _buildNavItem(
                    icon: Icons.medication_rounded,
                    label: 'Cabinet',
                    index: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryTeal.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaryTeal : AppColors.grayText,
              size: 23,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryTeal : AppColors.grayText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
