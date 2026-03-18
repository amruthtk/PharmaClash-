import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class AdminFunnelChart extends StatelessWidget {
  final int interactions;
  final int patients;

  const AdminFunnelChart({
    super.key,
    required this.interactions,
    required this.patients,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            label: 'Active Guests',
            value: interactions,
            icon: Icons.person_search_rounded,
            color: AppColors.primaryTeal,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            label: 'Patients',
            value: patients,
            icon: Icons.how_to_reg_rounded,
            color: Colors.blue.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.lightText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.mutedText,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
