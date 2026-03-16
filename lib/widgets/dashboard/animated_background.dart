import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class AnimatedDashboardBackground extends StatelessWidget {
  final AnimationController floatController;

  const AnimatedDashboardBackground({super.key, required this.floatController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: floatController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white, // Pure white at top so status bar icons are visible
                const Color(0xFFF0FDFA), // Teal-50 starts below status bar
                Color.lerp(
                  const Color(0xFFCCFBF1), // Teal-100
                  Colors.white,
                  0.65 + (floatController.value * 0.15),
                )!,
                Color.lerp(
                  const Color(0xFFE0E7FF), // Indigo-100
                  Colors.white,
                  0.8 + (floatController.value * 0.1),
                )!,
              ],
              stops: const [0.0, 0.15, 0.6, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Large soft teal orb — pushed below status bar
              Positioned(
                top: 40 + (math.sin(floatController.value * math.pi) * 20),
                right: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryTeal.withOpacity(0.12),
                        AppColors.primaryTeal.withOpacity(0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Floating pill shape
              Positioned(
                top: 140 + (math.sin(floatController.value * math.pi) * 18),
                right: 50,
                child: _buildFloatingPill(
                  32,
                  AppColors.primaryTeal.withOpacity(0.12),
                ),
              ),

              // Floating mint pill
              Positioned(
                top: 350 + (math.cos(floatController.value * math.pi + 1) * 22),
                left: 20,
                child: _buildFloatingPill(
                  26,
                  AppColors.mintGreen.withOpacity(0.1),
                ),
              ),

              // Indigo soft orb
              Positioned(
                top:
                    250 +
                    (math.sin(floatController.value * math.pi + 1.5) * 15),
                left: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF6366F1).withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom emerald glow
              Positioned(
                bottom:
                    150 + (math.sin(floatController.value * math.pi + 2) * 20),
                right: 60,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accentGreen.withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Small floating circle
              Positioned(
                bottom:
                    300 + (math.cos(floatController.value * math.pi + 3) * 12),
                left: 100,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryTeal.withOpacity(0.08),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingPill(double size, Color color) {
    return Transform.rotate(
      angle: floatController.value * 0.3,
      child: Container(
        width: size * 1.5,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.5),
        ),
      ),
    );
  }
}
