import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/biometric_service.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';

class BiometricLockScreen extends StatefulWidget {
  final Widget? onUnlocked;

  const BiometricLockScreen({super.key, this.onUnlocked});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with TickerProviderStateMixin {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticating = false;
  String? _errorMessage;

  late AnimationController _blobController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Auto-trigger biometric prompt on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  @override
  void dispose() {
    _blobController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final authenticated = await _biometricService
          .authenticateAndGetCredentials();

      if (authenticated != null) {
        BiometricService.isSessionUnlocked = true;
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
      } else {
        setState(() {
          _errorMessage = "Authentication failed. Please try again.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "An error occurred: $e";
      });
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // Animated Background Blobs
          _buildAnimatedBackground(),

          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glass Card Container
                    ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 48,
                            horizontal: 24,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Stylized Lock Icon with Pulse
                              _buildAnimatedIcon(),
                              const SizedBox(height: 32),

                              // Text Section
                              const Text(
                                'Security Check',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Please verify your identity to access your medical records',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 48),

                              if (_isAuthenticating)
                                const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primaryTeal,
                                    strokeWidth: 3,
                                  ),
                                )
                              else
                                Column(
                                  children: [
                                    if (_errorMessage != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 24,
                                        ),
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),

                                    // Primary Unlock Button
                                    _buildUnlockButton(),

                                    const SizedBox(height: 24),

                                    // Fallback Link
                                    TextButton(
                                      onPressed: _showLogoutConfirmation,
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white
                                            .withValues(alpha: 0.5),
                                      ),
                                      child: const Text(
                                        'Unable to unlock with biometrics?',
                                        style: TextStyle(
                                          fontSize: 14,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _blobController,
      builder: (context, child) {
        return Stack(
          children: [
            // Blob 1
            Positioned(
              top: -100 + (math.sin(_blobController.value * 2 * math.pi) * 50),
              left: -50 + (math.cos(_blobController.value * 2 * math.pi) * 30),
              child: _buildBlob(
                300,
                AppColors.primaryTeal.withValues(alpha: 0.15),
              ),
            ),
            // Blob 2
            Positioned(
              bottom:
                  50 + (math.cos(_blobController.value * 2 * math.pi) * 100),
              right:
                  -100 + (math.sin(_blobController.value * 2 * math.pi) * 40),
              child: _buildBlob(400, AppColors.deepTeal.withValues(alpha: 0.1)),
            ),
            // Blob 3 (Central Glow)
            Center(
              child: Opacity(
                opacity: 0.05,
                child: Container(
                  width: 500,
                  height: 500,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [AppColors.primaryTeal, Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildAnimatedIcon() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.05);
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryTeal,
                  AppColors.primaryTeal.withValues(alpha: 0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryTeal.withValues(
                    alpha: 0.3 * _pulseController.value,
                  ),
                  blurRadius: 20 * _pulseController.value,
                  spreadRadius: 5 * _pulseController.value,
                ),
              ],
            ),
            child: const Icon(
              Icons.fingerprint_rounded,
              size: 56,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnlockButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.primaryTeal, AppColors.deepTeal],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryTeal.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _authenticate,
          borderRadius: BorderRadius.circular(16),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_open_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text(
                  'Unlock Now',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Unlock Failed?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'If you cannot use biometrics, you can sign out and sign in again with your password.',
          style: TextStyle(color: AppColors.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.mutedText),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseService().signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.redAccent,
              elevation: 0,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
