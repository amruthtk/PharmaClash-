import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/user_medicine_model.dart';

/// Service for managing dose reminder notifications
/// - 15 min before scheduled dose time
/// - Follow-up every 30 min if dose not logged
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();

    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _isInitialized = true;
  }

  /// Request notification permissions (Android 13+)
  Future<bool> requestPermissions() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true; // iOS handles this during initialization
  }

  /// Schedule pre-dose reminder (15 min before)
  Future<void> scheduleDoseReminder({
    required String medicineId,
    required String medicineName,
    required String scheduledTime, // e.g., "08:00"
    required int doseIndex, // 0, 1, 2, 3 for different times
  }) async {
    final notificationId = _generateNotificationId(medicineId, doseIndex);

    // Parse time
    final parts = scheduledTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    // Calculate 15 min before
    final now = DateTime.now();
    var scheduledDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).subtract(const Duration(minutes: 15));

    // If time has passed today, schedule for tomorrow
    if (scheduledDateTime.isBefore(now)) {
      scheduledDateTime = scheduledDateTime.add(const Duration(days: 1));
    }

    final tzScheduledDate = tz.TZDateTime.from(scheduledDateTime, tz.local);

    await _notifications.zonedSchedule(
      notificationId,
      '💊 Time for your medicine!',
      '$medicineName dose in 15 minutes',
      tzScheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'dose_reminders',
          'Dose Reminders',
          channelDescription: 'Reminds you 15 min before dose time',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      payload: '$medicineId|$doseIndex|pre',
    );
  }

  /// Schedule follow-up reminder (30 min after dose time if not logged)
  Future<void> scheduleFollowUpReminder({
    required String medicineId,
    required String medicineName,
    required String scheduledTime,
    required int doseIndex,
  }) async {
    final notificationId =
        _generateNotificationId(medicineId, doseIndex) + 10000;

    // Parse time
    final parts = scheduledTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    // Calculate 30 min after
    final now = DateTime.now();
    var scheduledDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).add(const Duration(minutes: 30));

    // If time has passed today, schedule for tomorrow
    if (scheduledDateTime.isBefore(now)) {
      scheduledDateTime = scheduledDateTime.add(const Duration(days: 1));
    }

    final tzScheduledDate = tz.TZDateTime.from(scheduledDateTime, tz.local);

    await _notifications.zonedSchedule(
      notificationId,
      '⏰ Missed dose reminder',
      'Did you take $medicineName? Tap to log.',
      tzScheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'dose_followups',
          'Missed Dose Reminders',
          channelDescription: 'Reminds you if dose was not logged',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '$medicineId|$doseIndex|followup',
    );
  }

  /// Schedule all reminders for a medicine
  Future<void> scheduleMedicineReminders(UserMedicine medicine) async {
    if (medicine.id == null) return;

    for (int i = 0; i < medicine.scheduleTimes.length; i++) {
      final time = medicine.scheduleTimes[i];

      // Schedule pre-dose reminder (15 min before)
      await scheduleDoseReminder(
        medicineId: medicine.id!,
        medicineName: medicine.medicineName,
        scheduledTime: time,
        doseIndex: i,
      );

      // Schedule follow-up reminder (30 min after)
      await scheduleFollowUpReminder(
        medicineId: medicine.id!,
        medicineName: medicine.medicineName,
        scheduledTime: time,
        doseIndex: i,
      );
    }
  }

  /// Cancel follow-up reminder when dose is logged
  Future<void> cancelFollowUp({
    required String medicineId,
    required int doseIndex,
  }) async {
    final notificationId =
        _generateNotificationId(medicineId, doseIndex) + 10000;
    await _notifications.cancel(notificationId);
  }

  /// Cancel all reminders for a medicine
  Future<void> cancelMedicineReminders(String medicineId) async {
    // Cancel pre-dose reminders (indices 0-3)
    for (int i = 0; i < 4; i++) {
      await _notifications.cancel(_generateNotificationId(medicineId, i));
      await _notifications.cancel(
        _generateNotificationId(medicineId, i) + 10000,
      );
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Generate unique notification ID from medicine ID and dose index
  int _generateNotificationId(String medicineId, int doseIndex) {
    // Use hash of medicine ID + dose index
    return (medicineId.hashCode.abs() % 100000) + doseIndex;
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    // Payload format: "medicineId|doseIndex|type"
    // Can be used to navigate to specific screen
    final payload = response.payload;
    if (payload != null) {
      final parts = payload.split('|');
      if (parts.length >= 2) {
        // TODO: Navigate to take dose screen for this medicine
        debugPrint(
          'Notification tapped: medicineId=${parts[0]}, doseIndex=${parts[1]}',
        );
      }
    }
  }

  /// Show immediate notification (for testing)
  Future<void> showTestNotification() async {
    await _notifications.show(
      0,
      '💊 Test Notification',
      'Dose reminders are working!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'test',
          'Test Notifications',
          channelDescription: 'For testing',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ==================== Expiry & Low-Stock Alerts ====================

  /// Show expiry warning notification
  /// Called when medicines are expiring or already expired
  Future<void> showExpiryAlert({
    required int expiredCount,
    required int expiringSoonCount,
  }) async {
    if (expiredCount == 0 && expiringSoonCount == 0) return;

    String title;
    String body;

    if (expiredCount > 0 && expiringSoonCount > 0) {
      title = '⚠️ Medicine Alert';
      body =
          '$expiredCount expired, $expiringSoonCount expiring soon. Tap to review.';
    } else if (expiredCount > 0) {
      title = '🚨 Expired Medicine';
      body =
          '$expiredCount medicine${expiredCount > 1 ? 's have' : ' has'} expired. Time to replace!';
    } else {
      title = '📅 Expiring Soon';
      body =
          '$expiringSoonCount medicine${expiringSoonCount > 1 ? 's' : ''} expiring within 30 days.';
    }

    await _notifications.show(
      99001, // Fixed ID for expiry alerts
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'expiry_alerts',
          'Expiry Alerts',
          channelDescription: 'Alerts about expiring medicines',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'expiry_alert',
    );
  }

  /// Show low-stock warning notification
  Future<void> showLowStockAlert({
    required int lowStockCount,
    required List<String> medicineNames,
  }) async {
    if (lowStockCount == 0) return;

    final namesPreview = medicineNames.take(2).join(', ');
    final moreText = lowStockCount > 2 ? ' +${lowStockCount - 2} more' : '';

    await _notifications.show(
      99002, // Fixed ID for low-stock alerts
      '📦 Running Low on Meds',
      '$namesPreview$moreText — time to restock!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'low_stock_alerts',
          'Low Stock Alerts',
          channelDescription: 'Alerts when medicine stock is running low',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'low_stock_alert',
    );
  }

  /// Schedule daily health check notification (9 AM)
  Future<void> scheduleDailyHealthCheck() async {
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 9, 0);

    // If 9 AM has passed, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final tzScheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

    await _notifications.zonedSchedule(
      99000, // Fixed ID for daily check
      '🌅 Good Morning!',
      'Review your medicine cabinet for today.',
      tzScheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_check',
          'Daily Health Check',
          channelDescription: 'Daily reminder to check your medicines',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      payload: 'daily_check',
    );
  }
}
