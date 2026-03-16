import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class BiometricAuthButton extends StatelessWidget {
  final bool biometricEnabled;
  final bool isAuthenticating;
  final VoidCallback onTap;

  const BiometricAuthButton({
    super.key,
    required this.biometricEnabled,
    required this.isAuthenticating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: biometricEnabled
          ? 'Login with biometric'
          : 'Set up biometric login in Profile after logging in',
      child: GestureDetector(
        onTap: isAuthenticating ? null : onTap,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: biometricEnabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryTeal, AppColors.deepTeal],
                  )
                : null,
            color: biometricEnabled
                ? null
                : AppColors.primaryTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: biometricEnabled
                ? null
                : Border.all(
                    color: AppColors.primaryTeal.withValues(alpha: 0.3),
                  ),
            boxShadow: biometricEnabled
                ? [
                    BoxShadow(
                      color: AppColors.primaryTeal.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isAuthenticating
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    Icons.fingerprint,
                    color: biometricEnabled
                        ? Colors.white
                        : AppColors.primaryTeal,
                    size: 28,
                  ),
          ),
        ),
      ),
    );
  }
}
