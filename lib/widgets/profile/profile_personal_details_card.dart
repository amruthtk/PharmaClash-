import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'profile_info_card.dart';
import 'profile_detail_row.dart';

class ProfilePersonalDetailsCard extends StatelessWidget {
  final String fullName;
  final String email;
  final String dob;
  final String gender;

  const ProfilePersonalDetailsCard({
    super.key,
    required this.fullName,
    required this.email,
    required this.dob,
    required this.gender,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileInfoCard(
      child: Column(
        children: [
          ProfileDetailRow(
            label: 'Full Name',
            value: fullName,
            icon: Icons.person_outline,
          ),
          _buildDivider(),
          ProfileDetailRow(
            label: 'Email',
            value: email,
            icon: Icons.email_outlined,
          ),
          _buildDivider(),
          _buildDivider(),
          ProfileDetailRow(
            label: 'Date of Birth',
            value: dob,
            icon: Icons.cake_outlined,
          ),
          _buildDivider(),
          ProfileDetailRow(
            label: 'Gender',
            value: gender,
            icon: Icons.wc_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 1, color: AppColors.lightBorderColor);
  }
}
