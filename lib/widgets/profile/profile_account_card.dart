import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'profile_action_tile.dart';

class ProfileAccountCard extends StatelessWidget {
  final bool canUseBiometrics;
  final bool biometricEnabled;
  final ValueChanged<bool> onBiometricChanged;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

  const ProfileAccountCard({
    super.key,
    required this.canUseBiometrics,
    required this.biometricEnabled,
    required this.onBiometricChanged,
    required this.onRefresh,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (canUseBiometrics) ...[_buildBiometricTile(), _buildDivider()],
          ProfileActionTile(
            icon: Icons.refresh_rounded,
            title: 'Refresh Profile',
            subtitle: 'Reload your profile data',
            onTap: onRefresh,
          ),
          _buildDivider(),
          ProfileActionTile(
            icon: Icons.logout_rounded,
            title: 'Sign Out',
            subtitle: 'Log out of your account',
            isDestructive: true,
            onTap: onSignOut,
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricTile() {
    return ProfileActionTile(
      icon: Icons.fingerprint_rounded,
      title: 'Biometric Login',
      subtitle: biometricEnabled
          ? 'Securely login using your biometric'
          : 'Enable faster login with biometrics',
      onTap: () {},
      trailing: Switch.adaptive(
        value: biometricEnabled,
        activeColor: AppColors.primaryTeal,
        onChanged: onBiometricChanged,
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 1, color: AppColors.lightBorderColor);
  }
}
