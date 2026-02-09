import '../models/user_medicine_model.dart';
import 'medicine_inventory_service.dart';
import 'notification_service.dart';

/// Alert levels for medicine expiry status
enum ExpiryAlertLevel {
  none, // No expiry date set
  safe, // More than 30 days until expiry
  expiringSoon, // 30 days or less until expiry (Yellow Alert)
  expired, // Past expiry date (Red Alert)
}

/// Represents an expiry alert for a medicine
class ExpiryAlert {
  final UserMedicine medicine;
  final ExpiryAlertLevel level;
  final int daysRemaining;

  ExpiryAlert({
    required this.medicine,
    required this.level,
    required this.daysRemaining,
  });

  /// Get alert message based on level
  String get message {
    switch (level) {
      case ExpiryAlertLevel.expired:
        final daysPast = daysRemaining.abs();
        return 'Expired ${daysPast == 0 ? "today" : "$daysPast days ago"}';
      case ExpiryAlertLevel.expiringSoon:
        return 'Expires in $daysRemaining days';
      case ExpiryAlertLevel.safe:
        return 'Valid for $daysRemaining more days';
      case ExpiryAlertLevel.none:
        return 'No expiry date set';
    }
  }

  /// Get color-coded severity (for UI)
  String get severity {
    switch (level) {
      case ExpiryAlertLevel.expired:
        return 'critical';
      case ExpiryAlertLevel.expiringSoon:
        return 'warning';
      case ExpiryAlertLevel.safe:
        return 'safe';
      case ExpiryAlertLevel.none:
        return 'unknown';
    }
  }
}

/// ExpiryAlertService - The 5th Algorithm (Temporal Logic)
///
/// Implements date-difference calculation to check medicine expiry status
/// and determine appropriate alert levels for user safety.
class ExpiryAlertService {
  static final ExpiryAlertService _instance = ExpiryAlertService._internal();
  factory ExpiryAlertService() => _instance;
  ExpiryAlertService._internal();

  final MedicineInventoryService _inventoryService = MedicineInventoryService();

  /// Threshold for "expiring soon" alert (30 days)
  static const int expiringThresholdDays = 30;

  // ==================== Core Algorithm ====================

  /// Check the expiry status of a medicine based on its expiry date
  /// This is the core temporal logic algorithm
  ExpiryAlertLevel checkExpiryStatus(DateTime? expiryDate) {
    if (expiryDate == null) {
      return ExpiryAlertLevel.none;
    }

    final now = DateTime.now();
    final daysUntilExpiry = expiryDate.difference(now).inDays;

    if (daysUntilExpiry < 0) {
      // Medicine is expired (RED ALERT)
      return ExpiryAlertLevel.expired;
    } else if (daysUntilExpiry <= expiringThresholdDays) {
      // Medicine expiring soon (YELLOW ALERT)
      return ExpiryAlertLevel.expiringSoon;
    } else {
      // Medicine is safe (GREEN)
      return ExpiryAlertLevel.safe;
    }
  }

  /// Create an ExpiryAlert object for a medicine
  ExpiryAlert createAlert(UserMedicine medicine) {
    final level = checkExpiryStatus(medicine.expiryDate);
    return ExpiryAlert(
      medicine: medicine,
      level: level,
      daysRemaining: medicine.daysUntilExpiry,
    );
  }

  // ==================== "Nag & Flag" Pattern Logic ====================

  /// Check if the blocking modal should be shown (first detection only)
  bool shouldShowBlockingModal(UserMedicine medicine) {
    return medicine.isExpired && !medicine.expiryAlertShown;
  }

  /// Check if dose marking should be blocked for this medicine
  /// Always block if medicine is expired, regardless of modal state
  bool shouldBlockDoseMarking(UserMedicine medicine) {
    return medicine.isExpired;
  }

  /// Check if the persistent banner should be shown on dashboard
  bool shouldShowExpiryBanner(List<UserMedicine> medicines) {
    return medicines.any((m) => m.isExpired);
  }

  // ==================== Batch Checking Methods ====================

  /// Check all medicines for a user and return alerts
  Future<List<ExpiryAlert>> checkAllMedicines(String uid) async {
    final medicines = await _inventoryService.getUserMedicines(uid);
    return medicines
        .map((m) => createAlert(m))
        .where((alert) => alert.level != ExpiryAlertLevel.none)
        .toList()
      ..sort((a, b) {
        // Sort by severity: expired first, then expiring soon
        final severityOrder = {
          ExpiryAlertLevel.expired: 0,
          ExpiryAlertLevel.expiringSoon: 1,
          ExpiryAlertLevel.safe: 2,
          ExpiryAlertLevel.none: 3,
        };
        final levelCompare = severityOrder[a.level]!.compareTo(
          severityOrder[b.level]!,
        );
        if (levelCompare != 0) return levelCompare;
        // Same level: sort by days remaining
        return a.daysRemaining.compareTo(b.daysRemaining);
      });
  }

  /// Get medicines that need first-time blocking modal
  Future<List<UserMedicine>> getMedicinesNeedingModal(String uid) async {
    final medicines = await _inventoryService.getUserMedicines(uid);
    return medicines.where((m) => shouldShowBlockingModal(m)).toList();
  }

  /// Get count of expired medicines
  Future<int> getExpiredCount(String uid) async {
    return await _inventoryService.getExpiredCount(uid);
  }

  /// Get count of medicines expiring soon
  Future<int> getExpiringSoonCount(String uid) async {
    final medicines = await _inventoryService.getExpiringSoonMedicines(uid);
    return medicines.length;
  }

  // ==================== Helper Methods ====================

  /// Get a summary of medicine cabinet status
  Future<CabinetStatusSummary> getCabinetStatus(String uid) async {
    final medicines = await _inventoryService.getUserMedicines(uid);

    return CabinetStatusSummary(
      totalMedicines: medicines.length,
      expiredCount: medicines.where((m) => m.isExpired).length,
      expiringSoonCount: medicines.where((m) => m.isExpiringSoon).length,
      lowStockCount: medicines.where((m) => m.isLowStock).length,
      needsAttention: medicines.any((m) => m.isExpired || m.isExpiringSoon),
    );
  }

  /// Mark a medicine's expiry alert as shown
  Future<void> markAlertShown(String uid, String medicineId) async {
    await _inventoryService.markExpiryAlertShown(uid, medicineId);
  }

  // ==================== Push Notifications ====================

  final NotificationService _notificationService = NotificationService();

  /// Check cabinet status and trigger push notifications if needed
  /// Call this when user opens the app or on a periodic schedule
  Future<void> triggerStockNotifications(String uid) async {
    final status = await getCabinetStatus(uid);

    // Show expiry notification if any medicines expired or expiring soon
    if (status.expiredCount > 0 || status.expiringSoonCount > 0) {
      await _notificationService.showExpiryAlert(
        expiredCount: status.expiredCount,
        expiringSoonCount: status.expiringSoonCount,
      );
    }

    // Show low-stock notification if any medicines running low
    if (status.lowStockCount > 0) {
      final lowStockMeds = await _inventoryService.getLowStockMedicines(uid);
      final names = lowStockMeds.map((m) => m.medicineName).toList();
      await _notificationService.showLowStockAlert(
        lowStockCount: status.lowStockCount,
        medicineNames: names,
      );
    }
  }
}

/// Summary of the user's medicine cabinet status
class CabinetStatusSummary {
  final int totalMedicines;
  final int expiredCount;
  final int expiringSoonCount;
  final int lowStockCount;
  final bool needsAttention;

  CabinetStatusSummary({
    required this.totalMedicines,
    required this.expiredCount,
    required this.expiringSoonCount,
    required this.lowStockCount,
    required this.needsAttention,
  });

  /// Total count of medicines needing attention
  int get attentionCount => expiredCount + expiringSoonCount + lowStockCount;

  @override
  String toString() {
    return 'Cabinet: $totalMedicines total, $expiredCount expired, $expiringSoonCount expiring soon';
  }
}
