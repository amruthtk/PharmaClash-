import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_medicine_model.dart';
import 'notification_service.dart';

/// Service for managing user's medicine cabinet in Firestore
/// Collection structure: users/{uid}/medicines/{medicineId}
class MedicineInventoryService {
  static final MedicineInventoryService _instance =
      MedicineInventoryService._internal();
  factory MedicineInventoryService() => _instance;
  MedicineInventoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Get the medicines subcollection reference for a user
  CollectionReference<Map<String, dynamic>> _medicinesCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('medicines');
  }

  // ==================== CRUD Operations ====================

  /// Get all medicines in user's cabinet
  Future<List<UserMedicine>> getUserMedicines(String uid) async {
    try {
      final snapshot = await _medicinesCollection(
        uid,
      ).orderBy('addedAt', descending: true).get();

      return snapshot.docs
          .map((doc) => UserMedicine.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Failed to load medicines: $e';
    }
  }

  /// Stream user's medicines for real-time updates
  Stream<List<UserMedicine>> streamUserMedicines(String uid) {
    return _medicinesCollection(uid)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserMedicine.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Add a new medicine to cabinet
  Future<String> addMedicine(String uid, UserMedicine medicine) async {
    try {
      final docRef = await _medicinesCollection(uid).add(medicine.toMap());

      // Schedule dose reminders for this medicine
      if (medicine.scheduleTimes.isNotEmpty) {
        final medicineWithId = medicine.copyWith(id: docRef.id);
        await _notificationService.scheduleMedicineReminders(medicineWithId);
      }

      return docRef.id;
    } catch (e) {
      throw 'Failed to add medicine: $e';
    }
  }

  /// Update an existing medicine
  Future<void> updateMedicine(String uid, UserMedicine medicine) async {
    if (medicine.id == null) throw 'Medicine ID is required for update';

    try {
      await _medicinesCollection(uid).doc(medicine.id).update({
        ...medicine.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update medicine: $e';
    }
  }

  /// Remove a medicine from cabinet
  Future<void> removeMedicine(String uid, String medicineId) async {
    try {
      // Cancel all notifications for this medicine
      await _notificationService.cancelMedicineReminders(medicineId);
      await _medicinesCollection(uid).doc(medicineId).delete();
    } catch (e) {
      throw 'Failed to remove medicine: $e';
    }
  }

  // ==================== Expiry-Specific Methods ====================

  /// Get all expired medicines
  Future<List<UserMedicine>> getExpiredMedicines(String uid) async {
    final medicines = await getUserMedicines(uid);
    return medicines.where((m) => m.isExpired).toList();
  }

  /// Get medicines expiring within 30 days
  Future<List<UserMedicine>> getExpiringSoonMedicines(String uid) async {
    final medicines = await getUserMedicines(uid);
    return medicines.where((m) => m.isExpiringSoon).toList();
  }

  /// Get medicines that need attention (expired or expiring soon)
  Future<List<UserMedicine>> getMedicinesNeedingAttention(String uid) async {
    final medicines = await getUserMedicines(uid);
    return medicines.where((m) => m.isExpired || m.isExpiringSoon).toList()
      ..sort((a, b) {
        // Expired first, then by days remaining
        if (a.isExpired && !b.isExpired) return -1;
        if (!a.isExpired && b.isExpired) return 1;
        return a.daysUntilExpiry.compareTo(b.daysUntilExpiry);
      });
  }

  /// Mark that the expiry alert modal has been shown for a medicine
  Future<void> markExpiryAlertShown(String uid, String medicineId) async {
    try {
      await _medicinesCollection(uid).doc(medicineId).update({
        'expiryAlertShown': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update alert status: $e';
    }
  }

  /// Update medicine with a new strip (new expiry date + add quantity)
  Future<void> updateStrip(
    String uid,
    String medicineId, {
    required DateTime newExpiryDate,
    required int addQuantity,
  }) async {
    try {
      // Get current medicine to add to existing count
      final doc = await _medicinesCollection(uid).doc(medicineId).get();
      final currentCount = doc.data()?['tabletCount'] ?? 0;

      await _medicinesCollection(uid).doc(medicineId).update({
        'expiryDate': Timestamp.fromDate(newExpiryDate),
        'tabletCount': currentCount + addQuantity,
        'expiryAlertShown': false, // Reset alert status for new strip
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update strip: $e';
    }
  }

  /// Update tablet count (for dose tracking)
  Future<void> updateTabletCount(
    String uid,
    String medicineId,
    int newCount,
  ) async {
    try {
      await _medicinesCollection(uid).doc(medicineId).update({
        'tabletCount': newCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update tablet count: $e';
    }
  }

  /// Decrement tablet count by 1 (when marking dose as taken)
  Future<void> decrementTabletCount(String uid, String medicineId) async {
    try {
      final doc = await _medicinesCollection(uid).doc(medicineId).get();
      final currentCount = doc.data()?['tabletCount'] ?? 0;

      if (currentCount > 0) {
        await _medicinesCollection(uid).doc(medicineId).update({
          'tabletCount': currentCount - 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw 'Failed to decrement tablet count: $e';
    }
  }

  // ==================== Helper Methods ====================

  /// Check if a medicine already exists in cabinet (by drugId)
  Future<UserMedicine?> findMedicineByDrugId(String uid, String drugId) async {
    try {
      final snapshot = await _medicinesCollection(
        uid,
      ).where('drugId', isEqualTo: drugId).limit(1).get();

      if (snapshot.docs.isEmpty) return null;
      return UserMedicine.fromMap(
        snapshot.docs.first.data(),
        snapshot.docs.first.id,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get count of medicines in cabinet
  Future<int> getMedicineCount(String uid) async {
    try {
      final snapshot = await _medicinesCollection(uid).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get count of expired medicines
  Future<int> getExpiredCount(String uid) async {
    final expired = await getExpiredMedicines(uid);
    return expired.length;
  }

  /// Get medicines with low stock (5 or fewer tablets)
  Future<List<UserMedicine>> getLowStockMedicines(String uid) async {
    try {
      final allMedicines = await getUserMedicines(uid);
      return allMedicines
          .where((med) => med.tabletCount <= 5 && med.tabletCount > 0)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get count of low stock medicines
  Future<int> getLowStockCount(String uid) async {
    final lowStock = await getLowStockMedicines(uid);
    return lowStock.length;
  }

  // ==================== Dose Logging ====================

  /// Get the dose_logs subcollection reference for a user
  CollectionReference<Map<String, dynamic>> _doseLogsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('dose_logs');
  }

  /// Log a dose when user marks medicine as taken
  /// Also decrements the tablet count
  Future<void> logDose({
    required String uid,
    required String medicineId,
    required String medicineName,
    required int quantity,
    String? scheduledTime,
  }) async {
    try {
      // Log the dose
      await _doseLogsCollection(uid).add({
        'medicineId': medicineId,
        'medicineName': medicineName,
        'takenAt': FieldValue.serverTimestamp(),
        'scheduledTime': scheduledTime,
        'quantityTaken': quantity,
      });

      // Cancel follow-up reminder since dose was logged
      // Find which dose index this corresponds to
      if (scheduledTime != null) {
        final doc = await _medicinesCollection(uid).doc(medicineId).get();
        final scheduleTimes = List<String>.from(
          doc.data()?['scheduleTimes'] ?? [],
        );
        final doseIndex = scheduleTimes.indexOf(scheduledTime);
        if (doseIndex >= 0) {
          await _notificationService.cancelFollowUp(
            medicineId: medicineId,
            doseIndex: doseIndex,
          );
        }
      }

      // Decrement tablet count
      final doc = await _medicinesCollection(uid).doc(medicineId).get();
      final currentCount = doc.data()?['tabletCount'] ?? 0;

      if (currentCount <= 0) {
        throw 'Cannot log dose: Stock is empty';
      }

      final newCount = (currentCount - quantity).clamp(0, 9999);

      await _medicinesCollection(uid).doc(medicineId).update({
        'tabletCount': newCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to log dose: $e';
    }
  }

  /// Get all dose logs for a user (most recent first)
  Future<List<Map<String, dynamic>>> getDoseLogs(
    String uid, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _doseLogsCollection(
        uid,
      ).orderBy('takenAt', descending: true).limit(limit).get();

      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      throw 'Failed to get dose logs: $e';
    }
  }

  /// Get dose logs for today (simplified - just gets recent logs and filters locally)
  Future<List<Map<String, dynamic>>> getTodayDoseLogs(String uid) async {
    try {
      // Simple query - just get recent logs and filter by date locally
      // This avoids the Firestore composite index requirement
      final snapshot = await _doseLogsCollection(uid)
          .orderBy('takenAt', descending: true)
          .limit(100) // Get recent logs
          .get();

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Filter to today's logs locally
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).where((
        log,
      ) {
        final takenAt = log['takenAt'];
        if (takenAt == null) return false;
        final logDate = takenAt.toDate();
        return logDate.isAfter(startOfDay) ||
            logDate.isAtSameMomentAs(startOfDay);
      }).toList();
    } catch (e) {
      throw 'Failed to get today dose logs: $e';
    }
  }

  /// Get dose logs for a specific medicine
  Future<List<Map<String, dynamic>>> getMedicineDoseLogs(
    String uid,
    String medicineId, {
    int limit = 20,
  }) async {
    try {
      final snapshot = await _doseLogsCollection(uid)
          .where('medicineId', isEqualTo: medicineId)
          .orderBy('takenAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      throw 'Failed to get medicine dose logs: $e';
    }
  }
}
