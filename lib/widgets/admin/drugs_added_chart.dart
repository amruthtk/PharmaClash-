import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Area chart showing how the drug database has grown month-over-month.
/// Uses CustomPaint — zero external dependencies.
class DrugsAddedChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const DrugsAddedChart({super.key, required this.data});

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
              Icon(Icons.inventory_2_rounded, color: Colors.purple.shade300, size: 18),
              const SizedBox(width: 8),
              Text(
                'Drug Database Growth',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightText,
                ),
              ),
              const Spacer(),
              if (data.isNotEmpty)
                Text(
                  '${data.last['total']} total',
                  style: TextStyle(fontSize: 12, color: AppColors.mutedText),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (data.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No timeline data',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: CustomPaint(
                      size: const Size(double.infinity, double.infinity),
                      painter: _AreaChartPainter(data: data),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: data.map((d) {
                      return Text(
                        d['label'] as String,
                        style: TextStyle(fontSize: 9, color: AppColors.mutedText),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  _AreaChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final values = data.map((d) => (d['total'] as int).toDouble()).toList();
    final maxVal = values.reduce(max).clamp(1.0, double.infinity);
    final minVal = values.reduce(min).clamp(0.0, maxVal - 1);
    final range = (maxVal - minVal).clamp(1.0, double.infinity);

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - minVal) / range) * (size.height - 10);
      points.add(Offset(x, y));
    }

    // Draw area fill
    final areaPath = Path()..moveTo(0, size.height);
    for (final p in points) {
      areaPath.lineTo(p.dx, p.dy);
    }
    areaPath.lineTo(size.width, size.height);
    areaPath.close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.purple.shade300.withValues(alpha: 0.3),
          Colors.purple.shade300.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(areaPath, areaPaint);

    // Draw line
    final linePath = Path();
    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        linePath.moveTo(points[i].dx, points[i].dy);
      } else {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
    }

    final linePaint = Paint()
      ..color = Colors.purple.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // Draw dots
    final dotPaint = Paint()..color = Colors.purple.shade300;
    final dotBorderPaint = Paint()
      ..color = AppColors.cardBg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final p in points) {
      canvas.drawCircle(p, 4, dotPaint);
      canvas.drawCircle(p, 4, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter old) => true;
}
