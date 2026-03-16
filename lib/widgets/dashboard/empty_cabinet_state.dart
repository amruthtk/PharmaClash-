import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class EmptyCabinetState extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final Animation<double> scanAnimation;

  const EmptyCabinetState({
    super.key,
    required this.pulseAnimation,
    required this.scanAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Cabinet Icon
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: pulseAnimation.value,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: AppColors.primaryTeal.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryTeal.withValues(alpha: 0.15),
                        blurRadius: 30,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Medical cabinet illustration
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.primaryTeal.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildCabinetDoor(),
                              const SizedBox(width: 8),
                              _buildCabinetDoor(),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 36),

          // Text
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.deepTeal, AppColors.primaryTeal],
            ).createShader(bounds),
            child: const Text(
              'Your cabinet is empty!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: const Text(
              'Scan your first medicine to check for safety clashes and set up your schedule.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.grayText,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Animated scan indicator
          AnimatedBuilder(
            animation: scanAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  0,
                  math.sin(scanAnimation.value * math.pi * 2) * 12,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      color: AppColors.primaryTeal.withValues(
                        alpha: 0.3 + (scanAnimation.value * 0.3),
                      ),
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to scan',
                      style: TextStyle(
                        color: AppColors.primaryTeal.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCabinetDoor() {
    return Container(
      width: 45,
      height: 55,
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primaryTeal.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primaryTeal.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
