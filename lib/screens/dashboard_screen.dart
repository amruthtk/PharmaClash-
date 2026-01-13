import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 1;
  final FirebaseService _firebaseService = FirebaseService();

  // Premium pharma color palette
  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color deepTeal = Color(0xFF0F766E);
  static const Color mintGreen = Color(0xFF5EEAD4);
  static const Color darkBg = Color(0xFF0F172A);
  static const Color cardBg = Color(0xFF1E293B);
  static const Color lightText = Color(0xFFF1F5F9);
  static const Color mutedText = Color(0xFF94A3B8);
  static const Color accentGreen = Color(0xFF10B981);

  late AnimationController _pulseController;
  late AnimationController _floatController;
  late AnimationController _scanController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await _firebaseService.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  String get _userName {
    final user = _firebaseService.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!.split(' ').first;
    }
    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      body: Stack(
        children: [
          // Background gradient with floating elements
          _buildAnimatedBackground(),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Premium Header
                _buildHeader(),

                // Main content area
                Expanded(child: _buildCurrentTab()),
              ],
            ),
          ),
        ],
      ),

      // Premium Bottom Navigation
      bottomNavigationBar: _buildBottomNav(),

      // Floating Action Button for Scan
      floatingActionButton: _buildScanButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0: // Scan
        return Center(
          child: Text(
            'Scan Feature Coming Soon',
            style: TextStyle(
              color: lightText.withValues(alpha: 0.5),
              fontSize: 18,
            ),
          ),
        );
      case 1: // Schedule
        return _buildScheduleTab();
      case 2: // History
        return Center(
          child: Text(
            'History Coming Soon',
            style: TextStyle(
              color: lightText.withValues(alpha: 0.5),
              fontSize: 18,
            ),
          ),
        );
      case 3: // Profile
        return const ProfileScreen();
      default:
        return _buildScheduleTab();
    }
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
                darkBg,
                Color.lerp(
                  darkBg,
                  cardBg,
                  0.3 + (_floatController.value * 0.1),
                )!,
                darkBg,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Floating particles
              Positioned(
                top: 100 + (math.sin(_floatController.value * math.pi) * 15),
                right: 50,
                child: _buildFloatingPill(
                  30,
                  primaryTeal.withValues(alpha: 0.1),
                ),
              ),
              Positioned(
                top:
                    300 + (math.cos(_floatController.value * math.pi + 1) * 20),
                left: 30,
                child: _buildFloatingPill(
                  25,
                  mintGreen.withValues(alpha: 0.08),
                ),
              ),
              Positioned(
                bottom:
                    200 + (math.sin(_floatController.value * math.pi + 2) * 18),
                right: 80,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accentGreen.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingPill(double size, Color color) {
    return Transform.rotate(
      angle: _floatController.value * 0.3,
      child: Container(
        width: size * 1.5,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.5),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cardBg.withValues(alpha: 0.8),
            cardBg.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // User greeting
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $_userName! 👋',
                    style: const TextStyle(
                      fontSize: 15,
                      color: mutedText,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [primaryTeal, mintGreen],
                    ).createShader(bounds),
                    child: const Text(
                      'My Medicine Cabinet',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              // Action buttons
              Row(
                children: [
                  _buildHeaderButton(
                    icon: Icons.notifications_outlined,
                    hasNotification: true,
                    onTap: () {},
                  ),
                  const SizedBox(width: 12),
                  _buildHeaderButton(
                    icon: Icons.logout_rounded,
                    onTap: _handleLogout,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
    bool hasNotification = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: lightText, size: 22),
            if (hasNotification)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accentGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentGreen.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleTab() {
    return Column(
      children: [
        const SizedBox(height: 20),

        // Stats Cards Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Active',
                  '0',
                  Icons.medication_rounded,
                  primaryTeal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Today',
                  '0',
                  Icons.schedule_rounded,
                  accentGreen,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // Empty state
        Expanded(child: _buildEmptyState()),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardBg, cardBg.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Cabinet Icon
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [cardBg, cardBg.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: primaryTeal.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryTeal.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Medical cabinet illustration
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 10,
                            decoration: BoxDecoration(
                              color: lightText.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildCabinetDoor(),
                              const SizedBox(width: 8),
                              _buildCabinetDoor(),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 36),

          // Text
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [lightText, mutedText],
            ).createShader(bounds),
            child: const Text(
              'Your cabinet is empty!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Scan your first medicine to check for safety clashes and set up your schedule.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: mutedText, height: 1.5),
            ),
          ),
          const SizedBox(height: 48),

          // Animated scan indicator
          AnimatedBuilder(
            animation: _scanAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  0,
                  math.sin(_scanAnimation.value * math.pi * 2) * 12,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      color: primaryTeal.withValues(
                        alpha: 0.3 + (_scanAnimation.value * 0.3),
                      ),
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to scan',
                      style: TextStyle(
                        color: primaryTeal.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCabinetDoor() {
    return Container(
      width: 36,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: lightText.withValues(alpha: 0.6), width: 2.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: lightText.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return Container(
      width: 68,
      height: 68,
      margin: const EdgeInsets.only(top: 30),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryTeal, deepTeal],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryTeal.withValues(alpha: 0.5),
            blurRadius: 25,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _currentIndex = 0);
          },
          borderRadius: BorderRadius.circular(34),
          child: const Icon(
            Icons.qr_code_scanner_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scan',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.calendar_today_rounded,
                label: 'Schedule',
                index: 1,
              ),
              const SizedBox(width: 60), // Space for FAB
              _buildNavItem(
                icon: Icons.history_rounded,
                label: 'History',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    primaryTeal.withValues(alpha: 0.2),
                    primaryTeal.withValues(alpha: 0.1),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? primaryTeal : mutedText, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primaryTeal : mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
