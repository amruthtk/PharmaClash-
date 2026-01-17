import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../widgets/google_icon.dart';
import '../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _floatController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Main entrance animation
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _mainController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    // Floating animation for background elements
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Pulse animation for logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final result = await _firebaseService.signInWithGoogle();
      if (result != null && mounted) {
        // Clear all routes and go to the root (AuthWrapper will decide where to go)
        // We DON'T set _isLoading to false here so the loader stays until the transition
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        return; // Skip the finally block's isLoading = false
      } else if (result == null && mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Gradient Background
          _buildAnimatedBackground(),

          // Floating Medical Elements
          ..._buildFloatingElements(),

          // Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Animated Logo
                  _buildAnimatedLogo(),
                  const SizedBox(height: 32),

                  // Title with fade animation
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [AppColors.deepTeal, AppColors.primaryTeal],
                            ).createShader(bounds),
                            child: const Text(
                              'PharmaClash',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your intelligent medicine safety\ncompanion',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.grayText,
                              height: 1.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Buttons
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          // Google Sign In Button with Glassmorphism
                          _buildGlassButton(
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.darkText,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      GoogleIcon(size: 22),
                                      SizedBox(width: 14),
                                      Text(
                                        'Continue with Google',
                                        style: TextStyle(
                                          color: AppColors.darkText,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 20),

                          // Divider
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.grey.shade300,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  'or',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.grey.shade300,
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Login & Register Buttons
                          Row(
                            children: [
                              Expanded(
                                child: _buildOutlinedButton(
                                  label: 'Login',
                                  onPressed: () =>
                                      Navigator.pushNamed(context, '/login'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildGradientButton(
                                  label: 'Register',
                                  onPressed: () =>
                                      Navigator.pushNamed(context, '/register'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.softWhite,
                Colors.white,
                Color.lerp(
                  AppColors.lightMint,
                  Colors.white,
                  0.7 + (_floatController.value * 0.1),
                )!,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildFloatingElements() {
    return [
      // Floating pill 1
      AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          return Positioned(
            top: 80 + (math.sin(_floatController.value * math.pi) * 15),
            right: 30,
            child: Opacity(
              opacity: 0.15,
              child: Transform.rotate(
                angle: _floatController.value * 0.2,
                child: _buildPillIcon(50),
              ),
            ),
          );
        },
      ),
      // Floating capsule
      AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          return Positioned(
            top: 200 + (math.cos(_floatController.value * math.pi) * 20),
            left: 20,
            child: Opacity(
              opacity: 0.12,
              child: Transform.rotate(
                angle: -_floatController.value * 0.3 + 0.5,
                child: _buildCapsuleIcon(40),
              ),
            ),
          );
        },
      ),
      // Floating cross
      AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          return Positioned(
            bottom: 250 + (math.sin(_floatController.value * math.pi + 1) * 12),
            right: 50,
            child: Opacity(opacity: 0.1, child: _buildMedicalCross(35)),
          );
        },
      ),
      // DNA Helix element
      AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          return Positioned(
            bottom: 180 + (math.cos(_floatController.value * math.pi) * 18),
            left: 40,
            child: Opacity(
              opacity: 0.08,
              child: Transform.rotate(
                angle: _floatController.value * 0.4,
                child: _buildDNAHelix(45),
              ),
            ),
          );
        },
      ),
    ];
  }

  Widget _buildPillIcon(double size) {
    return Container(
      width: size,
      height: size * 0.4,
      decoration: BoxDecoration(
        color: AppColors.primaryTeal,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
    );
  }

  Widget _buildCapsuleIcon(double size) {
    return Container(
      width: size,
      height: size * 0.4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        gradient: const LinearGradient(colors: [AppColors.primaryTeal, AppColors.mintGreen]),
      ),
    );
  }

  Widget _buildMedicalCross(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.35,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.primaryTeal,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Container(
            width: size,
            height: size * 0.35,
            decoration: BoxDecoration(
              color: AppColors.primaryTeal,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDNAHelix(double size) {
    return Icon(Icons.biotech_outlined, size: size, color: AppColors.primaryTeal);
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _pulseController]),
      builder: (context, child) {
        final pulseScale = 1.0 + (_pulseController.value * 0.03);
        return Transform.scale(
          scale: _scaleAnimation.value * pulseScale,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryTeal, AppColors.deepTeal],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryTeal.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: AppColors.deepTeal.withValues(alpha: 0.2),
                  blurRadius: 60,
                  offset: const Offset(0, 20),
                  spreadRadius: -10,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Inner glow
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // Icon
                const Icon(
                  Icons.medical_services_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassButton({
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryTeal, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryTeal.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primaryTeal,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryTeal, AppColors.deepTeal],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryTeal.withValues(alpha: 0.35),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


