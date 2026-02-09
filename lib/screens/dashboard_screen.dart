import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/user_medicine_model.dart';
import '../services/firebase_service.dart';
import '../services/medicine_inventory_service.dart';
import '../services/expiry_alert_service.dart';
import '../widgets/expiry_alert_modal.dart';
import '../widgets/expiry_banner.dart';
import '../widgets/new_strip_form.dart';
import '../widgets/safety_confirmation_modal.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';
import 'medicine_cabinet_screen.dart';
import 'history_screen.dart';
import '../theme/app_colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 1;
  final FirebaseService _firebaseService = FirebaseService();
  final MedicineInventoryService _inventoryService = MedicineInventoryService();
  final ExpiryAlertService _expiryService = ExpiryAlertService();

  // User info
  String _userName = 'User';

  // Expiry tracking
  int _expiredCount = 0;
  int _expiringSoonCount = 0;
  List<UserMedicine> _medicinesNeedingModal = [];

  // Low stock tracking
  int _lowStockCount = 0;
  List<UserMedicine> _lowStockMedicines = [];

  late AnimationController _pulseController;
  late AnimationController _floatController;
  late AnimationController _scanController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _checkExpiryAlerts();
    _checkLowStock();

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

  Future<void> _loadUserName() async {
    final user = _firebaseService.currentUser;
    if (user == null) return;

    try {
      // First try to get fullName from Firestore profile
      final profile = await _firebaseService.getUserProfile(user.uid);
      if (profile != null && profile['fullName'] != null) {
        final fullName = profile['fullName'] as String;
        if (mounted && fullName.isNotEmpty) {
          setState(() {
            _userName = fullName.split(' ').first;
          });
          return;
        }
      }

      // Fallback to displayName from Firebase Auth
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        if (mounted) {
          setState(() {
            _userName = user.displayName!.split(' ').first;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user name: $e');
    }
  }

  /// Check for expired medicines on app startup (Nag & Flag pattern)
  Future<void> _checkExpiryAlerts() async {
    final user = _firebaseService.currentUser;
    if (user == null) return;

    try {
      // Get medicines that need first-time modal
      final needingModal = await _expiryService.getMedicinesNeedingModal(
        user.uid,
      );
      final status = await _expiryService.getCabinetStatus(user.uid);

      if (mounted) {
        setState(() {
          _expiredCount = status.expiredCount;
          _expiringSoonCount = status.expiringSoonCount;
          _medicinesNeedingModal = needingModal;
        });

        // Show first-time modal for first medicine needing it
        if (_medicinesNeedingModal.isNotEmpty) {
          _showExpiryModal(_medicinesNeedingModal.first);
        }
      }
    } catch (e) {
      debugPrint('Error checking expiry alerts: $e');
    }
  }

  /// Check for low stock medicines
  Future<void> _checkLowStock() async {
    final user = _firebaseService.currentUser;
    if (user == null) return;

    try {
      final lowStock = await _inventoryService.getLowStockMedicines(user.uid);
      if (mounted) {
        setState(() {
          _lowStockCount = lowStock.length;
          _lowStockMedicines = lowStock;
        });
      }
    } catch (e) {
      debugPrint('Error checking low stock: $e');
    }
  }

  /// Total notification count
  int get _totalNotificationCount =>
      _expiredCount + _expiringSoonCount + _lowStockCount;

  /// Show notification panel with all alerts
  void _showNotificationPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_rounded,
                      color: AppColors.primaryTeal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Notifications',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText,
                    ),
                  ),
                  const Spacer(),
                  if (_totalNotificationCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_totalNotificationCount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Notification list
            Flexible(
              child: _totalNotificationCount == 0
                  ? _buildEmptyNotifications()
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        // Expired medicines
                        ..._buildExpiredSection(),
                        // Low stock medicines
                        ..._buildLowStockSection(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyNotifications() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 64,
            color: AppColors.accentGreen.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'All clear!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No notifications at this time',
            style: TextStyle(fontSize: 14, color: AppColors.grayText),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExpiredSection() {
    if (_expiredCount == 0 && _expiringSoonCount == 0) return [];

    return [
      _buildSectionHeader(
        'Expiry Alerts',
        Icons.warning_amber_rounded,
        Colors.red,
      ),
      if (_expiredCount > 0)
        _buildNotificationItem(
          icon: Icons.error_rounded,
          iconColor: Colors.red,
          title:
              '$_expiredCount Expired Medicine${_expiredCount > 1 ? 's' : ''}',
          subtitle: 'Remove or replace these medicines',
          onTap: _goToCabinet,
        ),
      if (_expiringSoonCount > 0)
        _buildNotificationItem(
          icon: Icons.schedule_rounded,
          iconColor: Colors.orange,
          title: '$_expiringSoonCount Expiring Soon',
          subtitle: 'These will expire within 30 days',
          onTap: _goToCabinet,
        ),
    ];
  }

  List<Widget> _buildLowStockSection() {
    if (_lowStockMedicines.isEmpty) return [];

    return [
      _buildSectionHeader(
        'Low Stock',
        Icons.inventory_2_rounded,
        Colors.orange,
      ),
      ..._lowStockMedicines.map(
        (med) => _buildNotificationItem(
          icon: Icons.medication_rounded,
          iconColor: Colors.orange,
          title: med.medicineName,
          subtitle:
              'Only ${med.tabletCount} tablet${med.tabletCount == 1 ? '' : 's'} left',
          onTap: () {
            Navigator.pop(context);
            _goToCabinet();
          },
        ),
      ),
    ];
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: AppColors.grayText),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.grayText),
          ],
        ),
      ),
    );
  }

  /// Show expiry alert modal for a medicine
  void _showExpiryModal(UserMedicine medicine) {
    ExpiryAlertModal.show(
      context,
      medicine: medicine,
      onRemove: () async {
        final user = _firebaseService.currentUser;
        if (user != null && medicine.id != null) {
          await _inventoryService.removeMedicine(user.uid, medicine.id!);
          _checkExpiryAlerts(); // Refresh
        }
      },
      onNewStrip: () {
        NewStripForm.show(
          context,
          medicineName: medicine.medicineName,
          onSubmit: (expiryDate, quantity) async {
            final user = _firebaseService.currentUser;
            if (user != null && medicine.id != null) {
              await _inventoryService.updateStrip(
                user.uid,
                medicine.id!,
                newExpiryDate: expiryDate,
                addQuantity: quantity,
              );
              _checkExpiryAlerts(); // Refresh
            }
          },
        );
      },
      onDismiss: () async {
        // Mark alert as shown
        final user = _firebaseService.currentUser;
        if (user != null && medicine.id != null) {
          await _expiryService.markAlertShown(user.uid, medicine.id!);
          _checkExpiryAlerts(); // Check for more
        }
      },
    );
  }

  /// Navigate to cabinet screen
  void _goToCabinet() {
    setState(() => _currentIndex = 4);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
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
        return const ScanScreen();
      case 1: // Schedule
        return _buildScheduleTab();
      case 2: // History
        return const HistoryScreen();
      case 3: // Profile
        return const ProfileScreen();
      case 4: // Medicine Cabinet
        return const MedicineCabinetScreen();
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
          child: Stack(
            children: [
              // Floating particles
              Positioned(
                top: 100 + (math.sin(_floatController.value * math.pi) * 15),
                right: 50,
                child: _buildFloatingPill(
                  30,
                  AppColors.primaryTeal.withValues(alpha: 0.15),
                ),
              ),
              Positioned(
                top:
                    300 + (math.cos(_floatController.value * math.pi + 1) * 20),
                left: 30,
                child: _buildFloatingPill(
                  25,
                  AppColors.mintGreen.withValues(alpha: 0.12),
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
                        AppColors.accentGreen.withValues(alpha: 0.2),
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
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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
                      color: AppColors.grayText,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.deepTeal, AppColors.primaryTeal],
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
                    hasNotification: _totalNotificationCount > 0,
                    onTap: _showNotificationPanel,
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
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lightBorderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: AppColors.darkText, size: 22),
            if (hasNotification)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGreen.withValues(alpha: 0.5),
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
    final user = _firebaseService.currentUser;
    if (user == null) return _buildEmptyState();

    return StreamBuilder<List<UserMedicine>>(
      stream: _inventoryService.streamUserMedicines(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final medicines = snapshot.data ?? [];
        final scheduledMedicines = medicines
            .where((m) => m.scheduleTimes.isNotEmpty && !m.isExpired)
            .toList();

        if (scheduledMedicines.isEmpty) {
          return _buildEmptyState();
        }

        // Group medicines by time slot
        final timeSlots = _groupByTimeSlot(scheduledMedicines);
        final activeMedicines = scheduledMedicines.length;
        final todayDoses = timeSlots.values.expand((e) => e).length;

        return FutureBuilder<List<String>>(
          future: _getTodayLoggedTimes(user.uid),
          builder: (context, logsSnapshot) {
            final loggedTimes = logsSnapshot.data ?? [];

            return Column(
              children: [
                const SizedBox(height: 20),

                // Expiry Banner
                CabinetAlertBanner(
                  expiredCount: _expiredCount,
                  expiringSoonCount: _expiringSoonCount,
                  onTap: _goToCabinet,
                ),

                // Stats Cards with real data
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Active',
                          '$activeMedicines',
                          Icons.medication_rounded,
                          AppColors.primaryTeal,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Today',
                          '$todayDoses doses',
                          Icons.schedule_rounded,
                          AppColors.accentGreen,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Timeline Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timeline_rounded,
                        size: 18,
                        color: AppColors.primaryTeal,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Today's Schedule",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Timeline List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: timeSlots.length,
                    itemBuilder: (context, index) {
                      final time = timeSlots.keys.elementAt(index);
                      final meds = timeSlots[time]!;
                      return _buildTimeSlot(
                        time: time,
                        medicines: meds,
                        loggedTimes: loggedTimes,
                        userId: user.uid,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Group medicines by their scheduled times
  Map<String, List<UserMedicine>> _groupByTimeSlot(
    List<UserMedicine> medicines,
  ) {
    final Map<String, List<UserMedicine>> slots = {};

    for (final med in medicines) {
      for (final time in med.scheduleTimes) {
        slots.putIfAbsent(time, () => []);
        slots[time]!.add(med);
      }
    }

    // Sort by time
    final sortedKeys = slots.keys.toList()..sort((a, b) => a.compareTo(b));

    return {for (final key in sortedKeys) key: slots[key]!};
  }

  /// Get logged dose times for today
  Future<List<String>> _getTodayLoggedTimes(String uid) async {
    try {
      final logs = await _inventoryService.getTodayDoseLogs(uid);
      return logs
          .where((log) => log['scheduledTime'] != null)
          .map((log) => log['scheduledTime'] as String)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Build a time slot with its medicines
  Widget _buildTimeSlot({
    required String time,
    required List<UserMedicine> medicines,
    required List<String> loggedTimes,
    required String userId,
  }) {
    final now = DateTime.now();
    final timeParts = time.split(':');
    final slotHour = int.parse(timeParts[0]);
    final slotMinute = int.parse(timeParts[1]);
    final slotTime = DateTime(
      now.year,
      now.month,
      now.day,
      slotHour,
      slotMinute,
    );

    final isPast = slotTime.isBefore(now);
    final isCurrent = (now.difference(slotTime).inMinutes.abs() < 30);

    // Format time for display
    final hour = slotHour > 12
        ? slotHour - 12
        : (slotHour == 0 ? 12 : slotHour);
    final period = slotHour >= 12 ? 'PM' : 'AM';
    final displayTime = '$hour:${timeParts[1]} $period';

    // Get time emoji
    String emoji = '🌅'; // Morning
    if (slotHour >= 12 && slotHour < 17) {
      emoji = '☀️'; // Afternoon
    } else if (slotHour >= 17 && slotHour < 21) {
      emoji = '🌆'; // Evening
    } else if (slotHour >= 21 || slotHour < 5) {
      emoji = '🌙'; // Night
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Column
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(
                  displayTime,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isCurrent
                        ? AppColors.primaryTeal
                        : (isPast ? AppColors.grayText : AppColors.darkText),
                  ),
                ),
              ],
            ),
          ),

          // Timeline Line
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent
                        ? AppColors.primaryTeal
                        : (isPast
                              ? AppColors.grayText.withValues(alpha: 0.3)
                              : AppColors.lightMint),
                    border: Border.all(
                      color: isCurrent
                          ? AppColors.primaryTeal
                          : AppColors.grayText.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                ),
                Container(
                  width: 2,
                  height: medicines.length * 80.0,
                  color: AppColors.grayText.withValues(alpha: 0.15),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Medicine Cards
          Expanded(
            child: Column(
              children: medicines.map((med) {
                final isLogged = loggedTimes.contains(time);
                return _buildMedicineCard(
                  medicine: med,
                  time: time,
                  isLogged: isLogged,
                  isPast: isPast,
                  userId: userId,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual medicine card in timeline
  Widget _buildMedicineCard({
    required UserMedicine medicine,
    required String time,
    required bool isLogged,
    required bool isPast,
    required String userId,
  }) {
    final statusColor = isLogged
        ? Colors.green
        : (isPast ? Colors.orange : AppColors.primaryTeal);
    final statusIcon = isLogged
        ? Icons.check_circle_rounded
        : (isPast ? Icons.access_time_rounded : Icons.radio_button_unchecked);
    final statusText = isLogged ? 'Taken' : (isPast ? 'Overdue' : 'Upcoming');

    // Locked logic: Dose is more than 2 hours in the future
    bool isLocked = false;
    if (!isLogged && !isPast) {
      try {
        final now = DateTime.now();
        // Handle "HH:mm" or "HH:mm AM/PM" or other common formats
        final cleanTime = time.replaceAll(RegExp(r'[^0-9:]'), '');
        final parts = cleanTime.split(':');
        if (parts.length >= 2) {
          int hour = int.parse(parts[0]);
          int minute = int.parse(parts[1]);

          // Simple AM/PM detection if original string has it
          if (time.toUpperCase().contains('PM') && hour < 12) hour += 12;
          if (time.toUpperCase().contains('AM') && hour == 12) hour = 0;

          final scheduledDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            hour,
            minute,
          );
          // Lock if scheduled more than 1 hour from now
          isLocked = scheduledDateTime.difference(now).inMinutes >= 60;
        }
      } catch (e) {
        debugPrint('Error parsing schedule time "$time": $e');
        isLocked = false; // Default to unlocked if parsing fails
      }
    }

    final displayColor = isLocked ? Colors.grey : statusColor;

    return GestureDetector(
      onTap: isLogged
          ? null
          : (isLocked
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(
                              Icons.lock_clock_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Too early! For your safety, you can only log doses within 1 hour of schedule.',
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.blueGrey,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                : (medicine.tabletCount <= 0
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Out of stock! Refill needed to log dose.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      : () => _showQuickDose(medicine, time, userId))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLogged
                ? Colors.green.withValues(alpha: 0.3)
                : (isLocked
                      ? Colors.grey.withValues(alpha: 0.2)
                      : AppColors.lightBorderColor),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Medicine icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: displayColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isLocked
                    ? Icons.lock_rounded
                    : (medicine.tabletCount <= 0
                          ? Icons.error_outline_rounded
                          : Icons.medication_rounded),
                color: medicine.tabletCount <= 0 && !isLogged && !isLocked
                    ? Colors.orange
                    : displayColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Medicine info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.medicineName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isLogged || isLocked
                          ? AppColors.grayText
                          : AppColors.darkText,
                      decoration: isLogged ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isLocked ? Icons.lock_clock_rounded : statusIcon,
                        size: 14,
                        color: displayColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isLocked
                            ? 'Locked until later'
                            : (medicine.tabletCount <= 0 && !isLogged
                                  ? 'Out of Stock'
                                  : statusText),
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              medicine.tabletCount <= 0 &&
                                  !isLogged &&
                                  !isLocked
                              ? Colors.orange
                              : displayColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (medicine.tabletCount <= 5) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${medicine.tabletCount} left',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Action button
            if (!isLogged)
              Icon(
                isLocked
                    ? Icons.lock_outline_rounded
                    : (medicine.tabletCount <= 0
                          ? Icons.warning_amber_rounded
                          : Icons.chevron_right_rounded),
                color: isLocked
                    ? Colors.grey
                    : (medicine.tabletCount <= 0
                          ? Colors.orange
                          : AppColors.grayText),
              ),
          ],
        ),
      ),
    );
  }

  /// Show quick dose confirmation
  void _showQuickDose(UserMedicine medicine, String time, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Icon(
              Icons.medication_rounded,
              size: 48,
              color: AppColors.primaryTeal,
            ),
            const SizedBox(height: 16),
            Text(
              'Take ${medicine.medicineName}?',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scheduled for $time',
              style: TextStyle(fontSize: 14, color: AppColors.grayText),
            ),
            if (medicine.foodWarnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ Food restriction applies',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: medicine.tabletCount <= 0
                        ? null
                        : () async {
                            // LAYER 2 DEFENSE: Check for Food Warnings
                            if (medicine.foodWarnings.isNotEmpty) {
                              // Close the quick sheet first
                              Navigator.pop(context);
                              // Open the BLOCKING Safety Modal
                              await SafetyConfirmationModal.show(
                                context: context,
                                medicine: medicine,
                                onConfirmed: () async {
                                  // Only log after user confirms safe conditions
                                  await _inventoryService.logDose(
                                    uid: userId,
                                    medicineId: medicine.id!,
                                    medicineName: medicine.medicineName,
                                    quantity: 1,
                                    scheduledTime: time,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '✓ ${medicine.medicineName} logged safely',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                              );
                            } else {
                              // No warnings? Log immediately (Standard flow)
                              Navigator.pop(context);
                              await _inventoryService.logDose(
                                uid: userId,
                                medicineId: medicine.id!,
                                medicineName: medicine.medicineName,
                                quantity: 1,
                                scheduledTime: time,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '✓ ${medicine.medicineName} logged',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      medicine.tabletCount <= 0 ? 'Out of Stock' : 'Take Dose',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
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
        color: Colors.white,
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
              color: color.withValues(alpha: 0.1),
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
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.grayText,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: AppColors.primaryTeal.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryTeal.withValues(alpha: 0.15),
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
                              color: AppColors.primaryTeal.withValues(
                                alpha: 0.6,
                              ),
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
              colors: [AppColors.deepTeal, AppColors.primaryTeal],
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
              style: TextStyle(
                fontSize: 15,
                color: AppColors.grayText,
                height: 1.5,
              ),
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
                      color: AppColors.primaryTeal.withValues(
                        alpha: 0.3 + (_scanAnimation.value * 0.3),
                      ),
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to scan',
                      style: TextStyle(
                        color: AppColors.primaryTeal.withValues(alpha: 0.6),
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
        border: Border.all(
          color: AppColors.primaryTeal.withValues(alpha: 0.5),
          width: 2.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primaryTeal.withValues(alpha: 0.5),
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
          colors: [AppColors.primaryTeal, AppColors.deepTeal],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryTeal.withValues(alpha: 0.4),
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
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
                icon: Icons.calendar_today_rounded,
                label: 'Schedule',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.history_rounded,
                label: 'History',
                index: 2,
              ),
              const SizedBox(width: 68), // Space for FAB
              _buildNavItem(
                icon: Icons.medication_rounded,
                label: 'Cabinet',
                index: 4,
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
                    AppColors.primaryTeal.withValues(alpha: 0.15),
                    AppColors.primaryTeal.withValues(alpha: 0.05),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaryTeal : AppColors.grayText,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryTeal : AppColors.grayText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
