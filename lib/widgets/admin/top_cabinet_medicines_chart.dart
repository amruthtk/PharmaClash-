import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Horizontal bar chart showing the top medicines stored across all user cabinets.
class TopCabinetMedicinesChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const TopCabinetMedicinesChart({super.key, required this.data});

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
              Icon(Icons.medication_liquid_rounded, color: AppColors.mintGreen, size: 18),
              const SizedBox(width: 8),
              Text(
                'Top Cabinet Medicines',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (data.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No medicine cabinet data yet',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                ),
              ),
            )
          else
            ...data.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final name = item['name'] as String;
              final count = item['count'] as int;
              final maxCount = data.first['count'] as int;
              final fraction = maxCount > 0 ? count / maxCount : 0.0;

              // Gradient color palette
              final colors = [
                AppColors.mintGreen,
                AppColors.primaryTeal,
                Colors.blue.shade400,
                Colors.indigo.shade300,
                Colors.purple.shade300,
                Colors.pink.shade300,
                Colors.orange.shade400,
                Colors.amber,
              ];
              final color = colors[index % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    // Rank badge
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Name + bar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '$count ${count == 1 ? 'user' : 'users'}',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: fraction,
                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                              color: color,
                              minHeight: 5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
