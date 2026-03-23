import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class DashboardHeader extends StatelessWidget {
  final String userName;
  final String title;
  final bool hasNotifications;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;
  final VoidCallback? onBackTap;

  const DashboardHeader({
    super.key,
    required this.userName,
    required this.title,
    required this.hasNotifications,
    required this.onNotificationTap,
    required this.onProfileTap,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.95),
                Colors.white.withValues(alpha: 0.8),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryTeal.withValues(alpha: 0.1),
                blurRadius: 25,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button + User greeting/Title
                  Expanded(
                    child: Row(
                      children: [
                        if (onBackTap != null) ...[
                          _buildGlassButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: onBackTap!,
                            isSmall: true,
                          ),
                          const SizedBox(width: 16),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, $userName! 👋',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.grayText.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 1),
                              ShaderMask(
                                shaderCallback:
                                    (bounds) => const LinearGradient(
                                      colors: [
                                        Color(0xFF0F766E),
                                        Color(0xFF0D9488),
                                        Color(0xFF14B8A6),
                                      ],
                                    ).createShader(bounds),
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action buttons
                  Row(
                    children: [
                      _buildGlassButton(
                        icon: Icons.notifications_outlined,
                        hasNotification: hasNotifications,
                        onTap: onNotificationTap,
                      ),
                      const SizedBox(width: 10),
                      _buildGlassButton(
                        icon: Icons.person_rounded,
                        onTap: onProfileTap,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    bool hasNotification = false,
    bool isSmall = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSmall ? 10 : 14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: isSmall ? 38 : 44,
            height: isSmall ? 38 : 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.7),
                  Colors.white.withValues(alpha: 0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(isSmall ? 10 : 14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  color: AppColors.darkText.withOpacity(0.8),
                  size: 21,
                ),
                if (hasNotification)
                  Positioned(
                    right: 9,
                    top: 9,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
