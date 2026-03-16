import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class LoginBackground extends StatelessWidget {
  final Animation<double> floatAnimation;

  const LoginBackground({super.key, required this.floatAnimation});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: floatAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              // Top right gradient circle - kept inside viewport
              Positioned(
                top: 60 + (math.sin(floatAnimation.value * math.pi) * 10),
                right: 30,
                child: Opacity(
                  opacity: 0.4,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [AppColors.lightMint, Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom left gradient circle
              Positioned(
                bottom: 150 + (math.cos(floatAnimation.value * math.pi) * 15),
                left: 20,
                child: Opacity(
                  opacity: 0.3,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.mintGreen.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Small pill decoration
              Positioned(
                top: 180 + (math.sin(floatAnimation.value * math.pi + 1) * 8),
                right: 50,
                child: Opacity(
                  opacity: 0.1,
                  child: Transform.rotate(
                    angle: floatAnimation.value * 0.2 + 0.3,
                    child: Container(
                      width: 35,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
