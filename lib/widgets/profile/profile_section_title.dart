import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class ProfileSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const ProfileSectionTitle({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.grayText, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.grayText,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
