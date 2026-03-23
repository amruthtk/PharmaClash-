import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Horizontal bar chart showing the top drug pairs checked across all users.
class TopDrugPairsChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const TopDrugPairsChart({super.key, required this.data});

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
              Icon(Icons.compare_arrows_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text(
                'Top Drug Pairs',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightText,
                ),
              ),
              const Spacer(),
              Text(
                '${data.length} pairs',
                style: TextStyle(fontSize: 12, color: AppColors.mutedText),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (data.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No drug pair data yet',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                ),
              ),
            )
          else
            ...data.take(5).map((item) {
              final pair = item['pair'] as String;
              final count = item['count'] as int;
              final maxCount = data.first['count'] as int;
              final fraction = maxCount > 0 ? count / maxCount : 0.0;

              // Color gradient based on ranking
              final index = data.indexOf(item);
              final color = [
                Colors.amber,
                Colors.orange.shade400,
                AppColors.primaryTeal,
                Colors.blue.shade400,
                Colors.purple.shade300,
              ][index.clamp(0, 4)];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            pair,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$count',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        color: color,
                        minHeight: 6,
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
