import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class AdminFunnelChart extends StatelessWidget {
  final int installs;
  final int interactions;
  final int patients;

  const AdminFunnelChart({
    super.key,
    required this.installs,
    required this.interactions,
    required this.patients,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFunnelStage(
          label: 'Stage 1: App Installs',
          count: installs,
          color: Colors.blue.shade400,
          widthFactor: 1.0,
        ),
        _buildConnector(),
        _buildFunnelStage(
          label: 'Stage 2: Guest Interactions',
          count: interactions,
          color: AppColors.primaryTeal,
          widthFactor: installs > 0 ? (interactions / installs).clamp(0.2, 0.8) : 0.8,
          percentage: installs > 0 ? (interactions / installs * 100).toInt() : 0,
        ),
        _buildConnector(),
        _buildFunnelStage(
          label: 'Stage 3: Registered Patients',
          count: patients,
          color: Colors.orange.shade400,
          widthFactor: interactions > 0 ? (patients / interactions).clamp(0.1, 0.6) : 0.6,
          percentage: interactions > 0 ? (patients / interactions * 100).toInt() : 0,
        ),
      ],
    );
  }

  Widget _buildFunnelStage({
    required String label,
    required int count,
    required Color color,
    required double widthFactor,
    int? percentage,
  }) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  width: (widthFactor * 300), // Approximate max width
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color.darker(),
                          ),
                        ),
                        if (percentage != null)
                          Text(
                            '$percentage% conversion',
                            style: TextStyle(
                              fontSize: 10,
                              color: color.darker().withOpacity(0.7),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: color.darker(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnector() {
    return Container(
      width: 2,
      height: 20,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.borderColor,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

extension ColorExtension on Color {
  Color darker() {
    final hsv = HSVColor.fromColor(this);
    return hsv.withValue((hsv.value - 0.2).clamp(0, 1)).toColor();
  }
}
