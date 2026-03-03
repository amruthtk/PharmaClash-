import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_medicine_model.dart';
import '../models/drug_model.dart';
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

  /// Add a DrugModel to cabinet (from scanning flow)
  Future<String> addDrugToCabinet(
    String uid,
    DrugModel drug, {
    int? tabletCount,
    List<String>? scheduleTimes,
    DateTime? expiryDate,
  }) async {
    try {
      final medicine = UserMedicine(
        drugId: drug.id ?? '',
        medicineName: drug.matchedBrandName ?? drug.displayName,
        category: drug.category,
        tabletCount: tabletCount ?? 10,
        scheduleTimes: scheduleTimes ?? [],
        expiryDate:
            expiryDate ??
            DateTime.now().add(const Duration(days: 730)), // Default 2yr
        foodWarnings: drug.hasDietaryWarning
            ? drug.foodInteractions
                  .map((f) => "[${f.severity}] ${f.food}: ${f.description}")
                  .toList()
            : [],
      );

      return await addMedicine(uid, medicine);
    } catch (e) {
      throw 'Failed to add drug to cabinet: $e';
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
      final medDocRef = _medicinesCollection(uid).doc(medicineId);
      final logDocRef = _doseLogsCollection(uid).doc(); // New random ID

      // Fetch medicine once to check stock and schedule
      final medDoc = await medDocRef.get();
      final medData = medDoc.data();
      if (medData == null) throw 'Medicine not found';

      final currentCount = medData['tabletCount'] ?? 0;
      if (currentCount <= 0) {
        throw 'Cannot log dose: Stock is empty';
      }

      final newCount = (currentCount - quantity).clamp(0, 9999);

      // Perform all server updates in a single batch
      final batch = _firestore.batch();

      // 1. Add log entry
      batch.set(logDocRef, {
        'medicineId': medicineId,
        'medicineName': medicineName,
        'takenAt': FieldValue.serverTimestamp(),
        'scheduledTime': scheduledTime,
        'quantityTaken': quantity,
      });

      // 2. Update tablet count
      batch.update(medDocRef, {
        'tabletCount': newCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Commit early so user sees result
      await batch.commit();

      // 3. Cancel follow-up reminder (runs in background)
      if (scheduledTime != null) {
        final scheduleTimes = List<String>.from(medData['scheduleTimes'] ?? []);
        final doseIndex = scheduleTimes.indexOf(scheduledTime);
        if (doseIndex >= 0) {
          _notificationService.cancelFollowUp(
            medicineId: medicineId,
            doseIndex: doseIndex,
          );
        }
      }
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

  /// Calculate adherence streak and 7-day data.
  /// Returns a map with keys: currentStreak, longestStreak, weeklyAdherence.
  Future<Map<String, dynamic>> getAdherenceData(
    String uid, {
    List<UserMedicine>? medicines,
  }) async {
    try {
      final allMedicines = medicines ?? await getUserMedicines(uid);
      final scheduledMedicines = allMedicines
          .where((m) => m.scheduleTimes.isNotEmpty && !m.isExpired)
          .toList();

      if (scheduledMedicines.isEmpty) {
        return {
          'currentStreak': 0,
          'longestStreak': 0,
          'weeklyAdherence': List.filled(7, 0.0),
        };
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final thirtyDaysAgo = today.subtract(const Duration(days: 35));

      // Get logs only for the last 35 days (focused query)
      final snapshot = await _doseLogsCollection(uid)
          .where(
            'takenAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo),
          )
          .orderBy('takenAt', descending: true)
          .get();

      final logs = snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();

      // Total expected doses per day
      final expectedDosesPerDay = scheduledMedicines.fold<int>(
        0,
        (total, m) => total + m.scheduleTimes.length,
      );

      if (expectedDosesPerDay == 0) {
        return {
          'currentStreak': 0,
          'longestStreak': 0,
          'weeklyAdherence': List.filled(7, 0.0),
        };
      }

      // Count unique scheduled doses per day
      // Key: dateKey, Value: Set of "medicineId|scheduledTime"
      final Map<String, Set<String>> uniqueDosesPerDay = {};

      for (final log in logs) {
        final takenAt = log['takenAt'];
        final medicineId = log['medicineId'] as String?;
        final schTime = log['scheduledTime'] as String?;

        if (takenAt == null || medicineId == null || schTime == null) continue;

        final logDate = (takenAt as Timestamp).toDate();
        final dateKey = '${logDate.year}-${logDate.month}-${logDate.day}';

        uniqueDosesPerDay.putIfAbsent(dateKey, () => <String>{});
        uniqueDosesPerDay[dateKey]!.add('$medicineId|$schTime');
      }

      // Calculate current streak (consecutive days with >= 80% adherence)
      int currentStreak = 0;
      int longestStreak = 0;
      int tempStreak = 0;

      for (int i = 0; i < 30; i++) {
        final checkDate = today.subtract(Duration(days: i));
        final dateKey = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
        final dosesTakenCount = uniqueDosesPerDay[dateKey]?.length ?? 0;
        final adherence = dosesTakenCount / expectedDosesPerDay;

        if (adherence >= 0.8) {
          tempStreak++;
          if (i == currentStreak) {
            currentStreak = tempStreak;
          }
        } else {
          // If it's today and we haven't failed yet (0 doses taken), don't break streak
          if (i == 0 && dosesTakenCount == 0) {
            continue;
          }
          // If it's today and we've taken some but not all, check if it's still early?
          // For now, let's keep it simple: only break if adherence is truly low and it's not "early today"
          if (i == 0 && adherence < 0.8) {
            // Don't break streak FOR TODAY if it's early, but also don't increment it
            // Tweak: if adherence is > 0 but < 80% today, we don't break but we don't count it as a "full day" yet
            continue;
          }
          tempStreak = 0;
        }
        longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;
      }

      // Calculate 7-day adherence heatmap (Mon=0, Sun=6)
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      final List<double> weeklyAdherence = List.filled(7, 0.0);

      for (int i = 0; i < 7; i++) {
        final dayDate = weekStart.add(Duration(days: i));
        if (dayDate.isAfter(today)) break;

        final dateKey = '${dayDate.year}-${dayDate.month}-${dayDate.day}';
        final dosesTakenCount = uniqueDosesPerDay[dateKey]?.length ?? 0;

        // Final adherence value for the heatmap
        weeklyAdherence[i] = (dosesTakenCount / expectedDosesPerDay).clamp(
          0.0,
          1.0,
        );
      }

      return {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'weeklyAdherence': weeklyAdherence,
      };
    } catch (e) {
      debugPrint('Error in getAdherenceData: $e');
      return {
        'currentStreak': 0,
        'longestStreak': 0,
        'weeklyAdherence': List.filled(7, 0.0),
      };
    }
  }
}
