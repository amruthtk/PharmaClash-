import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Bar chart showing interaction check trends over the last 7 days.
/// Uses CustomPaint — zero external dependencies.
class InteractionTrendsChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const InteractionTrendsChart({super.key, required this.data});

  int get _maxCount {
    if (data.isEmpty) return 1;
    return data.map((d) => d['count'] as int).reduce(max).clamp(1, 999999);
  }

  int get _totalChecks {
    if (data.isEmpty) return 0;
    return data.map((d) => d['count'] as int).reduce((a, b) => a + b);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, color: AppColors.mintGreen, size: 18),
              const SizedBox(width: 8),
              Text(
                'Interaction Checks',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightText,
                ),
              ),
              const Spacer(),
              Text(
                '$_totalChecks this week',
                style: TextStyle(fontSize: 12, color: AppColors.mutedText),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (data.isEmpty || _totalChecks == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No interaction checks yet',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                ),
              ),
            )
          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxBarHeight = constraints.maxHeight - 36;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: data.map((d) {
                      final count = d['count'] as int;
                      final label = d['label'] as String;
                      final barHeight = (count / _maxCount) * maxBarHeight;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                count > 0 ? '$count' : '',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.mintGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                height: max(barHeight, count > 0 ? 6 : 2),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      AppColors.primaryTeal,
                                      AppColors.mintGreen,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.mutedText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
