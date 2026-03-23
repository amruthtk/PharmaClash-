import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Donut chart showing active vs inactive users (last 30 days).
class ActiveInactiveChart extends StatelessWidget {
  final int active;
  final int inactive;

  const ActiveInactiveChart({
    super.key,
    required this.active,
    required this.inactive,
  });

  int get _total => active + inactive;

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
              Icon(Icons.people_alt_rounded, color: Colors.blue.shade400, size: 18),
              const SizedBox(width: 8),
              Text(
                'User Engagement',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightText,
                ),
              ),
              const Spacer(),
              Text(
                'Last 30 days',
                style: TextStyle(fontSize: 12, color: AppColors.mutedText),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_total == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No user data yet',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                ),
              ),
            )
          else
            Row(
              children: [
                // Donut chart
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CustomPaint(
                    painter: _EngagementDonutPainter(
                      active: active,
                      inactive: inactive,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_total',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.lightText,
                            ),
                          ),
                          Text(
                            'users',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Legend
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legendItem(
                        'Active',
                        active,
                        Colors.green.shade400,
                      ),
                      const SizedBox(height: 12),
                      _legendItem(
                        'Inactive',
                        inactive,
                        Colors.grey.shade500,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, int count, Color color) {
    final pct = _total > 0 ? (count / _total * 100).round() : 0;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.lightText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          '$count ($pct%)',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.mutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EngagementDonutPainter extends CustomPainter {
  final int active;
  final int inactive;

  _EngagementDonutPainter({required this.active, required this.inactive});

  @override
  void paint(Canvas canvas, Size size) {
    final total = active + inactive;
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    const strokeWidth = 14.0;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    final segments = [
      _Segment(active / total, Colors.green.shade400),
      _Segment(inactive / total, Colors.grey.shade600),
    ];

    double startAngle = -pi / 2;
    for (final seg in segments) {
      if (seg.fraction <= 0) continue;
      final sweepAngle = 2 * pi * seg.fraction;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweepAngle - 0.06, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _EngagementDonutPainter old) =>
      old.active != active || old.inactive != inactive;
}

class _Segment {
  final double fraction;
  final Color color;
  _Segment(this.fraction, this.color);
}
