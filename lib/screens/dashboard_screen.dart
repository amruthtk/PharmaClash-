import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_medicine_model.dart';
import '../services/firebase_service.dart';
import '../services/medicine_inventory_service.dart';
import '../services/expiry_alert_service.dart';
import '../services/notification_service.dart';
import '../services/caregiver_notification_service.dart';
import '../services/missed_dose_service.dart';
import '../widgets/expiry_alert_modal.dart';
import '../widgets/expiry_banner.dart';
import '../widgets/new_strip_form.dart';
import '../widgets/missed_dose_reminder_sheet.dart';
import 'profile_screen.dart';
import 'scan/scan_screen.dart';
import 'medicine_cabinet_screen.dart';
import 'history_screen.dart';
import '../widgets/dashboard/animated_background.dart';
import '../widgets/dashboard/medicine_schedule_card.dart';
import '../widgets/dashboard/quick_dose_sheet.dart';
import '../widgets/dashboard/notification_panel.dart';
import '../widgets/dashboard/stat_card.dart';
import '../widgets/dashboard/dashboard_header.dart';
import '../widgets/dashboard/dashboard_bottom_nav.dart';
import '../widgets/dashboard/empty_cabinet_state.dart';
import '../widgets/dashboard/adherence_streak_card.dart';
import 'interaction_checker_screen.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 1;
  final FirebaseService _firebaseService = FirebaseService();
  final MedicineInventoryService _inventoryService = MedicineInventoryService();
  final ExpiryAlertService _expiryService = ExpiryAlertService();
  final CaregiverNotificationService _caregiverService =
      CaregiverNotificationService();
  final MissedDoseService _missedDoseService = MissedDoseService();

  // Track if missed dose prompt has been shown this session
  bool _missedDosePromptShown = false;

  // NIGHTLY 10 PM IN-APP CHECK
  Timer? _nightlyCheckTimer;
  bool _nightlyCheckShown = false;

  // Stream subscription for real-time cabinet updates
  StreamSubscription<List<UserMedicine>>? _medicineSubscription;

  // User info
  String _userName = 'User';

  // Expiry tracking
  int _expiredCount = 0;
  int _expiringSoonCount = 0;

  // Low stock and expiring soon tracking
  int _lowStockCount = 0;
  int _outOfStockCount = 0;
  // Schedule expand state
  bool _showAllSchedule = false;

  // Date navigation
  DateTime _selectedDate = DateTime.now();

  // Logged dose keys for selected date (format: "medicineId|scheduledTime")
  List<String> _loggedDoseKeys = [];

  // Adherence data
  Map<String, dynamic> _adherenceData = {
    'currentStreak': 0,
    'longestStreak': 0,
    'weeklyAdherence': List.filled(7, 0.0),
  };

  late AnimationController _pulseController;
  late AnimationController _floatController;
  late AnimationController _scanController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardData();
    _initMedicineStream();
    _scheduleNightlyInAppCheck();

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

    // Start caregiver notification listener
    _caregiverService.startListening();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // When user returns to the app, check if it's past 10 PM
      _checkNightlyOnResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nightlyCheckTimer?.cancel();
    _medicineSubscription?.cancel();
    _pulseController.dispose();
    _floatController.dispose();
    _scanController.dispose();
    _caregiverService.stopListening();
    super.dispose();
  }

  void _initMedicineStream() {
    final user = _firebaseService.currentUser;
    if (user == null) return;

    _medicineSubscription = _inventoryService
        .streamUserMedicines(user.uid)
        .listen((medicines) {
          if (mounted) {
            final lowStock = medicines
                .where(
                  (m) =>
                      m.isLowStock &&
                      !m.lowStockAlertShown &&
                      m.tabletCount > 0 &&
                      !m.isExpired,
                )
                .toList();
            final outOfStock = medicines
                .where((m) => m.tabletCount == 0 && !m.lowStockAlertShown)
                .toList();
            final expiringSoon = medicines
                .where((m) => m.isExpiringSoon && !m.expiringSoonAlertShown)
                .toList();
            final expired = medicines
                .where((m) => m.isExpired && !m.expiryAlertShown)
                .toList();

            setState(() {
              _expiredCount = expired.length;
              _expiringSoonCount = expiringSoon.length;
              _lowStockCount = lowStock.length;
              _outOfStockCount = outOfStock.length;
            });
          }
        });
  }

  /// Load all dashboard data with a single UI refresh
  Future<void> _loadDashboardData() async {
    final user = _firebaseService.currentUser;
    if (user == null) return;

    try {
      // Run independent Firestore reads in parallel:
      // These helpers now return values instead of calling setState internally
      final results = await Future.wait([
        _inventoryService.getUserMedicines(user.uid), // [0]
        _getLoggedDoseKeysFromServer(user.uid), // [1] returns List<String>
        _getUserFirstName(user), // [2] returns String
      ]);

      final medicines = results[0] as List<UserMedicine>;
      final keys = results[1] as List<String>;
      final firstName = results[2] as String;

      // 4) Get adherence data using already fetched medicines
      final adherence = await _inventoryService.getAdherenceData(
        user.uid,
        medicines: medicines,
      );

      final needingModal = medicines
          .where((m) => _expiryService.shouldShowBlockingModal(m))
          .toList();

      if (mounted) {
        setState(() {
          _adherenceData = adherence;
          _loggedDoseKeys = keys;
          _userName = firstName;
        });

        // Show first-time modal for first medicine needing it
        if (needingModal.isNotEmpty) {
          _showExpiryModal(needingModal.first);
        }

        // 5) Sync notifications with the local cabinet
        // This ensures a device swap or fresh install has all reminders scheduled
        final NotificationService notifs = NotificationService();
        await notifs.requestPermissions();
        await notifs.syncWithCabinet(medicines);

        // 6) Check for missed doses and prompt user
        if (!_missedDosePromptShown && needingModal.isEmpty) {
          _checkForMissedDoses(user.uid);
        }
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    }
  }

  /// Internal helper to fetch keys without triggering setState
  Future<List<String>> _getLoggedDoseKeysFromServer(String uid) async {
    try {
      final logs = await _inventoryService.getTodayDoseLogs(uid);
      return logs
          .where(
            (log) => log['medicineId'] != null && log['scheduledTime'] != null,
          )
          .map((log) => '${log['medicineId']}|${log['scheduledTime']}')
          .toList();
    } catch (e) {
      debugPrint('Error fetching dose keys: $e');
      return [];
    }
  }

  /// Load dose keys for a specific date
  Future<void> _loadDoseKeysForDate(DateTime date) async {
    final user = _firebaseService.currentUser;
    if (user == null) return;

    try {
      final logs = await _inventoryService.getDoseLogsForDate(user.uid, date);
      final keys = logs
          .where(
            (log) => log['medicineId'] != null && log['scheduledTime'] != null,
          )
          .map((log) => '${log['medicineId']}|${log['scheduledTime']}')
          .toList();

      if (mounted) {
        setState(() {
          _loggedDoseKeys = keys;
        });
      }
    } catch (e) {
      debugPrint('Error loading dose keys for date: $e');
    }
  }

  /// Check if a date is today
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Format the selected date for the schedule header
  String _getScheduleHeaderTitle() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final diff = selected.difference(today).inDays;

    if (diff == 0) return "Today's Schedule";
    if (diff == -1) return "Yesterday's Schedule";
    if (diff == 1) return "Tomorrow's Schedule";
    return DateFormat('EEE, MMM d').format(_selectedDate);
  }

  /// Internal helper to get first name without triggering setState
  Future<String> _getUserFirstName(User user) async {
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!.split(' ').first;
    }
    try {
      final profile = await _firebaseService.getUserProfile(user.uid);
      if (profile != null && profile['fullName'] != null) {
        final fullName = profile['fullName'] as String;
        if (fullName.isNotEmpty) {
          return fullName.split(' ').first;
        }
      }
    } catch (e) {
      debugPrint('Error fetching username: $e');
    }
    return 'User';
  }

  /// Total notification count
  int get _totalNotificationCount =>
      _expiredCount + _expiringSoonCount + _lowStockCount + _outOfStockCount;

  void _showNotificationPanel() {
    final user = _firebaseService.currentUser;
    if (user == null) return;

    NotificationPanel.show(
      context: context,
      userId: user.uid,
      inventoryService: _inventoryService,
      expiryService: _expiryService,
      onGoToCabinet: () async {
        // Close panel before navigating
        if (Navigator.canPop(context)) Navigator.pop(context);
        // If they go to cabinet from the panel, we assume they are addressing alerts
        await _inventoryService.markAllAlertsShown(user.uid);
        _loadDashboardData();
        _goToCabinet();
      },
      onDismiss: (med, type) async {
        if (type == 'expired_all') {
          // For expired, we mark ALL currently expired ones as shown
          final medicines = await _inventoryService.getUserMedicines(user.uid);
          for (final m in medicines.where((m) => m.isExpired)) {
            await _inventoryService.markExpiryAlertShown(user.uid, m.id!);
          }
        } else if (type == 'soon') {
          await _inventoryService.markExpiringSoonAlertShown(user.uid, med.id!);
        } else if (type == 'stock') {
          await _inventoryService.markLowStockAlertShown(user.uid, med.id!);
        }
        _loadDashboardData();
      },
      onClearAll: () async {
        await _inventoryService.markAllAlertsShown(user.uid);
        _loadDashboardData();
      },
    );
  }

  /// Show expiry alert modal for a medicine
  void _showExpiryModal(UserMedicine medicine) {
    ExpiryAlertModal.show(
      context,
      medicine: medicine,
      onRemove: () async {
        final user = _firebaseService.currentUser;
        if (user == null || medicine.id == null) return;

        // Check if there are any valid strips remaining
        final hasValidStrips = medicine.strips.any((s) => !s.isExpired);

        if (hasValidStrips) {
          // Only clear the expired parts
          try {
            await _inventoryService.clearExpiredBatches(user.uid, medicine.id!);
            _loadDashboardData();
          } catch (e) {
            debugPrint('Failed to clear expired batches: $e');
          }
        } else {
          // Everything is expired — full removal
          try {
            await _inventoryService.removeMedicine(user.uid, medicine.id!);
            _loadDashboardData();
          } catch (e) {
            debugPrint('Failed to remove medicine: $e');
          }
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
              _loadDashboardData(); // Refresh
            }
          },
        );
      },
      onDismiss: () async {
        // Mark alert as shown
        final user = _firebaseService.currentUser;
        if (user != null && medicine.id != null) {
          await _expiryService.markAlertShown(user.uid, medicine.id!);
          _loadDashboardData(); // Check for more
        }
      },
    );
  }

  /// Check for unlogged doses and show the reminder sheet
  Future<void> _checkForMissedDoses(String uid) async {
    try {
      final missedDoses = await _missedDoseService.getMissedDoses(uid);
      if (missedDoses.isEmpty || !mounted) return;

      _missedDosePromptShown = true;

      // Slight delay so the dashboard is visible first
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      MissedDoseReminderSheet.show(
        context: context,
        missedDoses: missedDoses,
        userId: uid,
        onComplete: () {
          // Refresh dashboard data after user responds
          _loadDashboardData();
        },
      );
    } catch (e) {
      debugPrint('Error checking for missed doses: $e');
    }
  }

  // ==================== Nightly 10 PM In-App Check ====================

  /// Schedule an in-app timer that fires at 10 PM to show the missed dose
  /// reminder one last time before the user sleeps.
  void _scheduleNightlyInAppCheck() {
    _nightlyCheckTimer?.cancel();

    final now = DateTime.now();
    final tonight10pm = DateTime(now.year, now.month, now.day, 22, 0);

    if (now.isBefore(tonight10pm)) {
      // Schedule a one-shot timer for 10 PM tonight
      final duration = tonight10pm.difference(now);
      _nightlyCheckTimer = Timer(duration, () {
        _triggerNightlyCheck();
      });
    }
    // If it's already past 10 PM, the resume handler will catch it
  }

  /// Called when the app is resumed from background — if it's past 10 PM
  /// and we haven't shown the nightly check yet, show it now.
  void _checkNightlyOnResume() {
    final now = DateTime.now();
    if (now.hour >= 22 && !_nightlyCheckShown) {
      _triggerNightlyCheck();
    }
  }

  /// Actually show the missed dose sheet for the nightly check
  Future<void> _triggerNightlyCheck() async {
    if (_nightlyCheckShown || !mounted) return;
    _nightlyCheckShown = true;

    final user = _firebaseService.currentUser;
    if (user == null) return;

    try {
      final missedDoses = await _missedDoseService.getMissedDoses(user.uid);
      if (missedDoses.isEmpty || !mounted) return;

      // Small delay so the UI is stable
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      MissedDoseReminderSheet.show(
        context: context,
        missedDoses: missedDoses,
        userId: user.uid,
        onComplete: () {
          _loadDashboardData();
        },
      );
    } catch (e) {
      debugPrint('Error in nightly missed dose check: $e');
    }
  }

  /// Navigate to cabinet screen
  void _goToCabinet() {
    setState(() => _currentIndex = 4);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      extendBody: true, // Let body extend behind nav
      body: Stack(
        children: [
          // Background gradient with floating elements
          _buildAnimatedBackground(),

          // Main content
          SafeArea(
            bottom: false, // Don't add safe area at bottom — nav handles it
            child: Column(
              children: [
                // Premium Header
                _buildHeader(),

                // Main content area
                Expanded(child: _buildCurrentTab()),
              ],
            ),
          ),

          // Frosted glass bottom nav — overlaid on content
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNav()),
        ],
      ),

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
      case 3: // Interaction Checker
        return const InteractionCheckerScreen();
      case 4: // Medicine Cabinet
        return const MedicineCabinetScreen();
      default:
        return _buildScheduleTab();
    }
  }

  Widget _buildAnimatedBackground() {
    return AnimatedDashboardBackground(floatController: _floatController);
  }

  Widget _buildHeader() {
    String title = 'Medicine App';
    switch (_currentIndex) {
      case 1:
        title = _isToday(_selectedDate)
            ? 'Daily Schedule'
            : DateFormat('EEE, MMM d').format(_selectedDate);
        break;
      case 2:
        title = 'Dose History';
        break;
      case 3:
        title = 'Interactions';
        break;
      case 4:
        title = 'My Cabinet';
        break;
      case 0:
        title = 'Quick Scan';
        break;
    }

    return DashboardHeader(
      userName: _userName,
      title: title,
      hasNotifications: _totalNotificationCount > 0,
      onNotificationTap: _showNotificationPanel,
      onDebugTap: kDebugMode ? () async {
        final user = _firebaseService.currentUser;
        if (user != null) {
          final medicines = await _inventoryService.getUserMedicines(user.uid);
          await NotificationService().showImmediateDailyHealthCheck(medicines);
        }
      } : null,
      onProfileTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      ),
    );
  }

  // Header button helper removed as it is now inside DashboardHeader

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
            .where((m) => m.scheduleTimes.isNotEmpty)
            .toList();

        // Filter by dose interval for the selected date
        final selectedDayOnly = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
        final filteredMedicines = scheduledMedicines.where((m) {
          if (m.doseIntervalDays <= 0) return true; // Daily — always show
          final addedDay = DateTime(
            m.addedAt.year,
            m.addedAt.month,
            m.addedAt.day,
          );
          final daysSinceAdded = selectedDayOnly.difference(addedDay).inDays;
          if (daysSinceAdded < 0) return true; // Future of addedAt — show
          return daysSinceAdded % (m.doseIntervalDays + 1) == 0;
        }).toList();

        if (scheduledMedicines.isEmpty) {
          return _buildEmptyState();
        }

        // Group medicines by time slot (only filtered ones)
        final timeSlots = _groupByTimeSlot(filteredMedicines);
        final activeMedicines = scheduledMedicines.length;
        final todayDoses = timeSlots.values.expand((e) => e).length;
        final isViewingToday = _isToday(_selectedDate);
        final isViewingFuture =
            DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
            ).isAfter(
              DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              ),
            );

        final loggedTimes = _loggedDoseKeys;

        // Show only first 2 time slots (morning doses), expand on "See All"
        final previewCount = 2;
        final slotEntries = timeSlots.entries.toList();
        final hasMore = slotEntries.length > previewCount;

        return Column(
          children: [
            const SizedBox(height: 12),

            // Expiry Banner
            CabinetAlertBanner(
              expiredCount: _expiredCount,
              expiringSoonCount: _expiringSoonCount,
              outOfStockCount: _outOfStockCount,
              onTap: _goToCabinet,
            ),

            // Scrollable content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: 100, // Extra bottom for overlaid nav
                ),
                children: [
                  // 1) ADHERENCE STREAK — top
                  AdherenceStreakCard(
                    currentStreak: _adherenceData['currentStreak'] ?? 0,
                    longestStreak: _adherenceData['longestStreak'] ?? 0,
                    weeklyAdherence: List<double>.from(
                      _adherenceData['weeklyAdherence'] ?? List.filled(7, 0.0),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2) STATS CARDS — Active & Today's Doses
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Active',
                          '$activeMedicines',
                          Icons.medication_rounded,
                          AppColors.primaryTeal,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildStatCard(
                          'Today\'s Doses',
                          '${loggedTimes.length} / $todayDoses',
                          loggedTimes.length >= todayDoses && todayDoses > 0
                              ? Icons.check_circle_rounded
                              : Icons.pending_actions_rounded,
                          loggedTimes.length >= todayDoses && todayDoses > 0
                              ? AppColors.accentGreen
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 3) SCHEDULE HEADER
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.timeline_rounded,
                          size: 16,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Title
                      Text(
                        _getScheduleHeaderTitle(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Dose count
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$todayDoses doses',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryTeal,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Date selector dropdown
                      GestureDetector(
                        onTap: () => _showDatePicker(user.uid),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isViewingToday
                                ? Colors.grey.shade100
                                : AppColors.primaryTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: !isViewingToday
                                ? Border.all(
                                    color: AppColors.primaryTeal.withOpacity(
                                      0.3,
                                    ),
                                  )
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 13,
                                color: isViewingToday
                                    ? AppColors.grayText
                                    : AppColors.primaryTeal,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isViewingToday
                                    ? DateFormat('d MMM').format(DateTime.now())
                                    : DateFormat('d MMM').format(_selectedDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isViewingToday
                                      ? AppColors.darkText
                                      : AppColors.primaryTeal,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: isViewingToday
                                    ? AppColors.grayText
                                    : AppColors.primaryTeal,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // View-only banner for non-today dates
                  if (!isViewingToday) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isViewingFuture
                            ? Colors.blue.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isViewingFuture
                                ? Icons.event_rounded
                                : Icons.history_rounded,
                            size: 14,
                            color: isViewingFuture
                                ? Colors.blue.shade600
                                : AppColors.grayText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isViewingFuture
                                ? 'Upcoming schedule — view only'
                                : 'Past schedule — view only',
                            style: TextStyle(
                              fontSize: 12,
                              color: isViewingFuture
                                  ? Colors.blue.shade600
                                  : AppColors.grayText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Schedule timeline — show first few only
                  ...((_showAllSchedule
                          ? slotEntries
                          : slotEntries.take(previewCount))
                      .map((entry) {
                        return _buildTimeSlot(
                          time: entry.key,
                          medicines: entry.value,
                          loggedTimes: loggedTimes,
                          userId: user.uid,
                        );
                      })),

                  // "See All" / "Show Less" button
                  if (hasMore)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GestureDetector(
                        onTap: () => setState(
                          () => _showAllSchedule = !_showAllSchedule,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryTeal.withOpacity(0.08),
                                AppColors.primaryTeal.withOpacity(0.03),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primaryTeal.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _showAllSchedule
                                    ? 'Show Less'
                                    : 'See All ${slotEntries.length} Time Slots',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryTeal,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                _showAllSchedule
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.primaryTeal,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 80), // Bottom padding for FAB
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ==================== Date Picker ====================

  Future<void> _showDatePicker(String userId) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryTeal,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.darkText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _showAllSchedule = false;
      });

      if (_isToday(picked)) {
        _loadDashboardData();
      } else {
        _loadDoseKeysForDate(picked);
      }
    }
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

  /// Build a time slot with its medicines
  Widget _buildTimeSlot({
    required String time,
    required List<UserMedicine> medicines,
    required List<String> loggedTimes,
    required String userId,
  }) {
    final now = DateTime.now();
    final isViewingToday = _isToday(_selectedDate);
    final isViewingFuture = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    ).isAfter(DateTime(now.year, now.month, now.day));

    final timeParts = time.split(':');
    final slotHour = int.parse(timeParts[0]);
    final slotMinute = int.parse(timeParts[1]);
    final slotTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      slotHour,
      slotMinute,
    );

    // For non-today dates: past days are always "past", future days never "past"
    final bool isPast;
    final bool isCurrent;
    if (isViewingToday) {
      isPast = slotTime.isBefore(now);
      isCurrent = (now.difference(slotTime).inMinutes.abs() < 30);
    } else if (isViewingFuture) {
      isPast = false;
      isCurrent = false;
    } else {
      // Past day — all slots are "past"
      isPast = true;
      isCurrent = false;
    }

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
                final isLogged = loggedTimes.contains('${med.id}|$time');
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

  Widget _buildMedicineCard({
    required UserMedicine medicine,
    required String time,
    required bool isLogged,
    required bool isPast,
    required String userId,
  }) {
    final isViewingToday = _isToday(_selectedDate);

    return MedicineScheduleCard(
      medicine: medicine,
      time: time,
      isLogged: isLogged,
      isPast: isPast,
      userId: userId,
      onTap: () {
        // Non-today dates are read-only
        if (!isViewingToday) return;

        if (isLogged) return;

        // Check locking again for the snackbar
        final now = DateTime.now();
        final cleanTime = time.replaceAll(RegExp(r'[^0-9:]'), '');
        final parts = cleanTime.split(':');
        bool isLocked = false;
        if (parts.length >= 2) {
          int hour = int.parse(parts[0]);
          int minute = int.parse(parts[1]);
          if (time.toUpperCase().contains('PM') && hour < 12) hour += 12;
          if (time.toUpperCase().contains('AM') && hour == 12) hour = 0;
          final scheduledDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            hour,
            minute,
          );
          isLocked = scheduledDateTime.difference(now).inMinutes >= 60;
        }

        if (isLocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Too early! You can only log doses within 1 hour of schedule.',
              ),
              backgroundColor: Colors.blueGrey,
            ),
          );
        } else if (medicine.isExpired) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '⚠️ This medicine is expired! Please replace it before taking.',
              ),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (medicine.tabletCount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Out of stock! Refill needed to log dose.'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          _showQuickDose(medicine, time, userId);
        }
      },
    );
  }

  void _showQuickDose(UserMedicine medicine, String time, String userId) {
    QuickDoseSheet.show(
      context: context,
      medicine: medicine,
      time: time,
      userId: userId,
      onLogDose: (med, medTime) async {
        await _inventoryService.logDose(
          uid: userId,
          medicineId: med.id!,
          medicineName: med.medicineName,
          quantity: 1,
          scheduledTime: medTime,
        );
        // Immediately update local state so UI reflects the logged dose
        if (mounted) {
          setState(() {
            _loggedDoseKeys.add('${med.id}|$medTime');
          });

          // Refresh background counts and adherence WITHOUT triggering multiple state flashes
          _loadDashboardData();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ ${med.medicineName} logged'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return StatCard(label: label, value: value, icon: icon, color: color);
  }

  Widget _buildEmptyState() {
    return EmptyCabinetState(
      pulseAnimation: _pulseAnimation,
      scanAnimation: _scanAnimation,
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
          colors: [AppColors.primaryTeal, AppColors.deepTeal],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryTeal.withValues(alpha: 0.4),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ScanScreen()),
            );
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
    return DashboardBottomNav(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
    );
  }
}
