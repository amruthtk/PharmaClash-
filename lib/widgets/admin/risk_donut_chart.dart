import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Donut chart showing risk distribution (Severe / Moderate / Mild).
/// Uses CustomPaint — zero external dependencies.
class RiskDonutChart extends StatelessWidget {
  final int severe;
  final int moderate;
  final int mild;

  const RiskDonutChart({
    super.key,
    required this.severe,
    required this.moderate,
    required this.mild,
  });

  int get _total => severe + moderate + mild;

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
              Icon(
                Icons.pie_chart_rounded,
                color: AppColors.mintGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Risk Distribution',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightText,
                ),
              ),
              const Spacer(),
              Text(
                '$_total rules',
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
                  'No interaction rules yet',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                ),
              ),
            )
          else
            Row(
              children: [
                // Chart
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CustomPaint(
                    painter: _DonutPainter(
                      severe: severe,
                      moderate: moderate,
                      mild: mild,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Legend
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legendItem('Severe', severe, Colors.red.shade400),
                      const SizedBox(height: 10),
                      _legendItem('Moderate', moderate, Colors.orange.shade400),
                      const SizedBox(height: 10),
                      _legendItem('Mild', mild, AppColors.accentGreen),
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

class _DonutPainter extends CustomPainter {
  final int severe;
  final int moderate;
  final int mild;

  _DonutPainter({
    required this.severe,
    required this.moderate,
    required this.mild,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = severe + moderate + mild;
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    const strokeWidth = 16.0;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    final segments = [
      _Segment(severe / total, Colors.red.shade400),
      _Segment(moderate / total, Colors.orange.shade400),
      _Segment(mild / total, const Color(0xFF10B981)),
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
      canvas.drawArc(rect, startAngle, sweepAngle - 0.04, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.severe != severe || old.moderate != moderate || old.mild != mild;
}

class _Segment {
  final double fraction;
  final Color color;
  _Segment(this.fraction, this.color);
}
