import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Adherence Streak Card — shows the user's current dose-logging streak
/// and a 7-day activity heatmap, with liquid glass style
class AdherenceStreakCard extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final List<double> weeklyAdherence; // 7 values, 0.0 to 1.0 (Mon–Sun)
  final VoidCallback? onTap;

  const AdherenceStreakCard({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.weeklyAdherence,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final streakEmoji = _getStreakEmoji(currentStreak);
    final streakMessage = _getStreakMessage(currentStreak);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.8),
                  Colors.white.withOpacity(0.5),
                  AppColors.lightMint.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryTeal.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Streak fire badge
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: currentStreak > 0
                              ? [
                                  const Color(0xFFFF6B35),
                                  const Color(0xFFFF8E53),
                                ]
                              : [Colors.grey.shade300, Colors.grey.shade400],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: currentStreak > 0
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF6B35,
                                  ).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Text(
                        streakEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '$currentStreak',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: currentStreak > 0
                                      ? AppColors.darkText
                                      : AppColors.grayText,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'day${currentStreak == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.grayText,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            streakMessage,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.grayText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Best streak badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primaryTeal.withOpacity(0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Best',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.grayText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$longestStreak',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 7-day adherence heatmap
                _buildWeeklyHeatmap(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyHeatmap() {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        final adherence = index < weeklyAdherence.length
            ? weeklyAdherence[index]
            : 0.0;
        final isToday = index == (DateTime.now().weekday - 1);

        return _buildDayDot(days[index], adherence, isToday);
      }),
    );
  }

  Widget _buildDayDot(String label, double adherence, bool isToday) {
    Color dotColor;
    if (adherence >= 1.0) {
      dotColor = AppColors.accentGreen;
    } else if (adherence > 0) {
      dotColor = Colors.orange;
    } else {
      dotColor = Colors.grey.shade300;
    }

    return Column(
      children: [
        // Day label
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? AppColors.primaryTeal : AppColors.grayText,
          ),
        ),
        const SizedBox(height: 6),
        // Adherence dot
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isToday ? 32 : 28,
          height: isToday ? 32 : 28,
          decoration: BoxDecoration(
            color: dotColor.withOpacity(adherence > 0 ? 1.0 : 0.3),
            borderRadius: BorderRadius.circular(8),
            border: isToday
                ? Border.all(color: AppColors.primaryTeal, width: 2)
                : null,
            boxShadow: adherence >= 1.0
                ? [
                    BoxShadow(
                      color: AppColors.accentGreen.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: adherence >= 1.0
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : adherence > 0
                ? Text(
                    '${(adherence * 100).round()}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  String _getStreakEmoji(int streak) {
    if (streak >= 30) return '👑';
    if (streak >= 14) return '💎';
    if (streak >= 7) return '🔥';
    if (streak >= 3) return '⚡';
    if (streak >= 1) return '✨';
    return '💤';
  }

  String _getStreakMessage(int streak) {
    if (streak >= 30) return 'Legendary! A whole month!';
    if (streak >= 14) return 'Two weeks strong! 💪';
    if (streak >= 7) return 'One week streak! Keep going!';
    if (streak >= 3) return 'Building momentum!';
    if (streak >= 1) return 'Great start! Stay consistent.';
    return 'Log a dose to start your streak';
  }
}
