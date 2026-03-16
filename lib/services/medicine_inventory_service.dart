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
  /// If the same drug already exists (matched by drugId), merges:
  ///   - tabletCount is added to existing count
  ///   - expiryDate keeps the later (fresher) date
  ///   - schedule/interval/warnings are updated to the new values
  Future<String> addDrugToCabinet(
    String uid,
    DrugModel drug, {
    int? tabletCount,
    List<String>? scheduleTimes,
    DateTime? expiryDate,
    int doseIntervalDays = 0,
  }) async {
    try {
      final drugId = drug.id ?? '';
      final newCount = tabletCount ?? 10;
      final newSchedule = scheduleTimes ?? [];
      final newFoodWarnings = drug.hasDietaryWarning
          ? drug.foodInteractions
                .map((f) => "[${f.severity}] ${f.food}: ${f.description}")
                .toList()
          : <String>[];

      // Check if this drug already exists in the cabinet
      final existing = drugId.isNotEmpty
          ? await findMedicineByDrugId(uid, drugId)
          : null;

      if (existing != null && existing.id != null) {
        // --- Merge into existing entry using strip logic ---
        // We reuse updateStrip to ensure strips are correctly handled
        await updateStrip(
          uid,
          existing.id!,
          newExpiryDate: expiryDate ?? existing.expiryDate ?? DateTime.now().add(const Duration(days: 365)),
          addQuantity: newCount,
        );

        // Fetch again to get updated object for notifications/other updates
        final updatedDoc = await _medicinesCollection(uid).doc(existing.id).get();
        final updated = UserMedicine.fromMap(updatedDoc.data()!, existing.id!);
        
        // Update schedule/warnings if they were provided new in this scan
        if (newSchedule.isNotEmpty || doseIntervalDays != existing.doseIntervalDays) {
           await _medicinesCollection(uid).doc(existing.id).update({
             'scheduleTimes': newSchedule.isNotEmpty ? newSchedule : existing.scheduleTimes,
             'doseIntervalDays': doseIntervalDays,
             'foodWarnings': newFoodWarnings.isNotEmpty ? newFoodWarnings : existing.foodWarnings,
             'updatedAt': FieldValue.serverTimestamp(),
           });
        }

        // Reschedule notifications
        if (updated.scheduleTimes.isNotEmpty) {
          await _notificationService.cancelMedicineReminders(existing.id!);
          await _notificationService.scheduleMedicineReminders(updated);
        }

        return existing.id!;
      }

      // --- No existing entry: create new ---
      final initialStrip = StripBatch(
        expiryDate: expiryDate ?? DateTime.now().add(const Duration(days: 365)),
        quantity: newCount,
      );

      final medicine = UserMedicine(
        drugId: drugId,
        medicineName: drug.matchedBrandName ?? drug.displayName,
        category: drug.category,
        tabletCount: newCount,
        scheduleTimes: newSchedule,
        expiryDate: expiryDate,
        doseIntervalDays: doseIntervalDays,
        foodWarnings: newFoodWarnings,
        strips: [initialStrip],
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

  /// Mark that the low stock alert has been dismissed for a medicine
  Future<void> markLowStockAlertShown(String uid, String medicineId) async {
    try {
      await _medicinesCollection(uid).doc(medicineId).update({
        'lowStockAlertShown': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update low stock alert status: $e';
    }
  }

  /// Mark that the expiring soon alert has been dismissed for a medicine
  Future<void> markExpiringSoonAlertShown(String uid, String medicineId) async {
    try {
      await _medicinesCollection(uid).doc(medicineId).update({
        'expiringSoonAlertShown': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update expiring soon alert status: $e';
    }
  }

  /// Mark that the user has acknowledged pre-dose safety warnings for a medicine.
  /// After this, the safety modal is no longer shown for this medicine.
  Future<void> markSafetyAcknowledged(String uid, String medicineId) async {
    try {
      await _medicinesCollection(uid).doc(medicineId).update({
        'safetyAcknowledged': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update safety acknowledged status: $e';
    }
  }

  /// Mark all active alerts as dismissed for all medicines
  Future<void> markAllAlertsShown(String uid) async {
    try {
      final medicines = await getUserMedicines(uid);
      final batch = _firestore.batch();
      int count = 0;

      for (final med in medicines) {
        if (med.id == null) continue;
        bool needsUpdate = false;
        final updates = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (med.isExpired && !med.expiryAlertShown) {
          updates['expiryAlertShown'] = true;
          needsUpdate = true;
        }
        if (med.isExpiringSoon && !med.expiringSoonAlertShown) {
          updates['expiringSoonAlertShown'] = true;
          needsUpdate = true;
        }
        if (med.isLowStock && !med.lowStockAlertShown) {
          updates['lowStockAlertShown'] = true;
          needsUpdate = true;
        }

        if (needsUpdate) {
          batch.update(_medicinesCollection(uid).doc(med.id), updates);
          count++;
        }
      }

      if (count > 0) {
        await batch.commit();
      }
    } catch (e) {
      throw 'Failed to clear all alerts: $e';
    }
  }

  /// Update medicine with a new strip (appends a new batch)
  /// Recomputes summary fields (expiryDate, tabletCount) from all batches.
  Future<void> updateStrip(
    String uid,
    String medicineId, {
    required DateTime newExpiryDate,
    required int addQuantity,
  }) async {
    try {
      final doc = await _medicinesCollection(uid).doc(medicineId).get();
      final data = doc.data();
      if (data == null) throw 'Medicine not found';

      // Parse existing strips or migrate from legacy
      List<Map<String, dynamic>> existingStrips = [];
      final rawStrips = data['strips'] as List<dynamic>?;
      if (rawStrips != null && rawStrips.isNotEmpty) {
        existingStrips = rawStrips
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
      } else {
        // Legacy migration: create strip from old fields
        final legacyExpiry = data['expiryDate'] as Timestamp?;
        final legacyCount = data['tabletCount'] ?? 0;
        if (legacyExpiry != null && legacyCount > 0) {
          existingStrips.add({
            'expiryDate': legacyExpiry,
            'quantity': legacyCount,
            'addedAt': data['addedAt'] ?? Timestamp.now(),
          });
        }
      }

      // Append new batch
      existingStrips.add({
        'expiryDate': Timestamp.fromDate(newExpiryDate),
        'quantity': addQuantity,
        'addedAt': Timestamp.now(),
      });

      // Recompute summary fields from all batches
      int totalCount = 0;
      DateTime? earliestExpiry;
      for (final strip in existingStrips) {
        final qty = strip['quantity'] as int? ?? 0;
        totalCount += qty;
        if (qty > 0) {
          final exp = (strip['expiryDate'] as Timestamp).toDate();
          if (earliestExpiry == null || exp.isBefore(earliestExpiry)) {
            earliestExpiry = exp;
          }
        }
      }

      await _medicinesCollection(uid).doc(medicineId).update({
        'strips': existingStrips,
        'expiryDate': earliestExpiry != null
            ? Timestamp.fromDate(earliestExpiry)
            : data['expiryDate'],
        'tabletCount': totalCount,
        'expiryAlertShown': false,
        'expiringSoonAlertShown': false,
        'lowStockAlertShown': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update strip: $e';
    }
  }

  /// Removes specifically the expired batches/strips from a medicine
  /// while keeping any valid ones. If NO valid batches remain, the caller
  /// should decide whether to keep the empty record or delete it.
  Future<void> clearExpiredBatches(String uid, String medicineId) async {
    try {
      final doc = await _medicinesCollection(uid).doc(medicineId).get();
      final data = doc.data();
      if (data == null) throw 'Medicine not found';

      final rawStrips = data['strips'] as List<dynamic>?;
      if (rawStrips == null || rawStrips.isEmpty) {
        // Legacy or single expiry — just clear the stock if it's expired
        final expiry = (data['expiryDate'] as Timestamp?)?.toDate();
        if (expiry != null && expiry.isBefore(DateTime.now())) {
          await _medicinesCollection(uid).doc(medicineId).update({
            'tabletCount': 0,
            'expiryAlertShown': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        return;
      }

      // Multi-strip: Filter out expired ones
      final now = DateTime.now();
      final updatedStrips = rawStrips.where((s) {
        final exp = (s['expiryDate'] as Timestamp).toDate();
        return exp.isAfter(now);
      }).toList();

      // Recompute summary fields from remaining VALID batches
      int totalCount = 0;
      DateTime? nextExpiry;
      for (final strip in updatedStrips) {
        final qty = strip['quantity'] as int? ?? 0;
        totalCount += qty;
        final exp = (strip['expiryDate'] as Timestamp).toDate();
        if (nextExpiry == null || exp.isBefore(nextExpiry)) {
          nextExpiry = exp;
        }
      }

      await _medicinesCollection(uid).doc(medicineId).update({
        'strips': updatedStrips,
        'tabletCount': totalCount,
        'expiryDate': nextExpiry != null ? Timestamp.fromDate(nextExpiry) : null,
        'expiryAlertShown': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to clear expired batches: $e';
    }
  }

  /// Selectively remove a specific strip (batch) by its index in the list
  Future<void> removeStrip(String uid, String medicineId, int stripIndex) async {
    try {
      final doc = await _medicinesCollection(uid).doc(medicineId).get();
      final data = doc.data();
      if (data == null) throw 'Medicine not found';

      final rawStrips = data['strips'] as List<dynamic>?;
      List<Map<String, dynamic>> updatedStrips = [];

      if (rawStrips != null && rawStrips.isNotEmpty) {
        updatedStrips = rawStrips
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
      } else {
        // Legacy migration: create a strip from top-level fields
        final legacyExpiry = data['expiryDate'] as Timestamp?;
        final legacyCount = data['tabletCount'] ?? 0;
        if (legacyExpiry != null && legacyCount > 0) {
          updatedStrips.add({
            'expiryDate': legacyExpiry,
            'quantity': legacyCount,
            'addedAt': data['addedAt'] ?? Timestamp.now(),
          });
        }
      }

      if (stripIndex < updatedStrips.length) {
        updatedStrips.removeAt(stripIndex);
      }

      // Recompute summary fields
      int totalCount = 0;
      DateTime? nextExpiry;
      for (final strip in updatedStrips) {
        final qty = strip['quantity'] as int? ?? 0;
        totalCount += qty;
        final exp = (strip['expiryDate'] as Timestamp).toDate();
        if (nextExpiry == null || exp.isBefore(nextExpiry)) {
          nextExpiry = exp;
        }
      }

      await _medicinesCollection(uid).doc(medicineId).update({
        'strips': updatedStrips,
        'tabletCount': totalCount,
        'expiryDate': nextExpiry != null ? Timestamp.fromDate(nextExpiry) : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to remove strip: $e';
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
  /// Deducts from earliest-expiring strip first (FEFO)
  /// If [takenAt] is provided, the dose log is recorded with that timestamp
  /// (used for retroactive missed dose logging). Otherwise uses server time.
  Future<void> logDose({
    required String uid,
    required String medicineId,
    required String medicineName,
    required int quantity,
    String? scheduledTime,
    DateTime? takenAt,
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

      // Parse strips for FEFO deduction
      List<Map<String, dynamic>> strips = [];
      final rawStrips = medData['strips'] as List<dynamic>?;
      if (rawStrips != null && rawStrips.isNotEmpty) {
        strips = rawStrips
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
        // Sort by expiry date ascending (earliest first)
        strips.sort((a, b) {
          final expA = (a['expiryDate'] as Timestamp).toDate();
          final expB = (b['expiryDate'] as Timestamp).toDate();
          return expA.compareTo(expB);
        });

        // Deduct from earliest-expiring strips first
        int remaining = quantity;
        for (final strip in strips) {
          if (remaining <= 0) break;
          final qty = strip['quantity'] as int? ?? 0;
          if (qty <= 0) continue;
          final deduct = remaining > qty ? qty : remaining;
          strip['quantity'] = qty - deduct;
          remaining -= deduct;
        }

        // Remove depleted strips
        strips.removeWhere((s) => (s['quantity'] as int? ?? 0) <= 0);
      }

      // Recompute summary fields
      int totalCount = strips.isEmpty
          ? (currentCount - quantity).clamp(0, 9999)
          : strips.fold<int>(0, (sum, s) => sum + (s['quantity'] as int? ?? 0));

      DateTime? earliestExpiry;
      for (final strip in strips) {
        final qty = strip['quantity'] as int? ?? 0;
        if (qty > 0) {
          final exp = (strip['expiryDate'] as Timestamp).toDate();
          if (earliestExpiry == null || exp.isBefore(earliestExpiry)) {
            earliestExpiry = exp;
          }
        }
      }

      // Perform all server updates in a single batch
      final batch = _firestore.batch();

      // 1. Add log entry
      // Use provided takenAt for retroactive logging, otherwise server time
      batch.set(logDocRef, {
        'medicineId': medicineId,
        'medicineName': medicineName,
        'takenAt': takenAt != null
            ? Timestamp.fromDate(takenAt)
            : FieldValue.serverTimestamp(),
        'scheduledTime': scheduledTime,
        'quantityTaken': quantity,
      });

      // 2. Update medicine with new strip state and summary
      final updateData = <String, dynamic>{
        'tabletCount': totalCount,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (strips.isNotEmpty || rawStrips != null) {
        updateData['strips'] = strips;
        if (earliestExpiry != null) {
          updateData['expiryDate'] = Timestamp.fromDate(earliestExpiry);
        }
      }
      batch.update(medDocRef, updateData);

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
      // Primary attempt: indexed query
      final snapshot = await _doseLogsCollection(
        uid,
      ).orderBy('takenAt', descending: true).limit(limit).get();

      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      debugPrint("Indexed history query failed, falling back: $e");
      // Fallback: simple query (no order by avoids index requirement)
      // Then sort locally for the user
      final snapshot = await _doseLogsCollection(uid).limit(limit * 2).get();

      final logs = snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();

      logs.sort((a, b) {
        final tA = a['takenAt'] as Timestamp?;
        final tB = b['takenAt'] as Timestamp?;
        if (tA == null || tB == null) return 0;
        return tB.compareTo(tA); // Descending
      });

      return logs.take(limit).toList();
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

  /// Get dose logs for a specific date
  Future<List<Map<String, dynamic>>> getDoseLogsForDate(
    String uid,
    DateTime date,
  ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _doseLogsCollection(uid)
          .where(
            'takenAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('takenAt', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('takenAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      // Fallback: fetch recent and filter locally (avoids composite index issues)
      try {
        final snapshot = await _doseLogsCollection(
          uid,
        ).orderBy('takenAt', descending: true).limit(200).get();

        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).where((
          log,
        ) {
          final takenAt = log['takenAt'];
          if (takenAt == null) return false;
          final logDate = (takenAt as Timestamp).toDate();
          return logDate.isAfter(startOfDay) && logDate.isBefore(endOfDay) ||
              logDate.isAtSameMomentAs(startOfDay);
        }).toList();
      } catch (e2) {
        throw 'Failed to get dose logs for date: $e2';
      }
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
          .where((m) => m.scheduleTimes.isNotEmpty)
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
      final thirtyFiveDaysAgo = today.subtract(const Duration(days: 35));

      // 1. Fetch logs for the last 35 days
      final snapshot = await _doseLogsCollection(uid)
          .where(
            'takenAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyFiveDaysAgo),
          )
          .orderBy('takenAt', descending: true)
          .get();

      final logs = snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();

      // 2. Build set of active medicine IDs so we only count logs for
      //    medicines that are CURRENTLY in the cabinet.
      final activeMedicineIds = scheduledMedicines
          .where((m) => m.id != null)
          .map((m) => m.id!)
          .toSet();

      // 3. Map unique doses taken per day (only for active medicines)
      // Key: dateKey (String), Value: Set of "medicineId|scheduledTime"
      final Map<String, Set<String>> takenDosesPerDay = {};
      for (final log in logs) {
        final takenAt = log['takenAt'] as Timestamp?;
        final medId = log['medicineId'] as String?;
        final schTime = log['scheduledTime'] as String?;

        if (takenAt == null || medId == null || schTime == null) continue;

        // Skip logs for medicines that are no longer in the cabinet
        if (!activeMedicineIds.contains(medId)) continue;

        final logDate = takenAt.toDate();
        final dateKey = '${logDate.year}-${logDate.month}-${logDate.day}';

        takenDosesPerDay.putIfAbsent(dateKey, () => <String>{});
        takenDosesPerDay[dateKey]!.add('$medId|$schTime');
      }

      // 4. Calculate expected doses (assuming same schedule for past 30 days for simplicity)
      final expectedDosesPerDay = scheduledMedicines.fold<int>(
        0,
        (total, m) => total + m.scheduleTimes.length,
      );

      // 5. Calculate Current and Longest Streak
      int currentStreak = 0;
      int longestStreak = 0;
      int runningStreak = 0;
      bool isCurrentStreakBroken = false;

      // Check last 30 days backwards
      for (int i = 0; i <= 30; i++) {
        final checkDate = today.subtract(Duration(days: i));
        final dateKey = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
        final takenCount = takenDosesPerDay[dateKey]?.length ?? 0;

        // Adherence for this day
        final adherence = takenCount / expectedDosesPerDay;
        final isSuccessful = adherence >= 0.8;

        if (isSuccessful) {
          runningStreak++;
        } else {
          // Special handling for today: if no doses taken yet, don't break the streak
          // unless it's past all scheduled times (we'll keep it simple for now)
          if (i == 0 && takenCount == 0) {
            // Keep streak alive but don't increment runningStreak for today yet
          } else {
            // Streak is broken
            if (!isCurrentStreakBroken) {
              currentStreak = runningStreak;
              isCurrentStreakBroken = true;
            }
            runningStreak = 0;
          }
        }

        if (runningStreak > longestStreak) longestStreak = runningStreak;

        // If we reached the end of the 30 days and the current streak hasn't been "broken" (recorded)
        if (i == 30 && !isCurrentStreakBroken) {
          currentStreak = runningStreak;
        }
      }

      // 6. Calculate 7-day Weekly Adherence Heatmap (Mon-Sun)
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      final List<double> weeklyAdherence = List.filled(7, 0.0);

      for (int i = 0; i < 7; i++) {
        final dayDate = weekStart.add(Duration(days: i));
        // If it's a future day, leave it at 0.0
        if (dayDate.isAfter(today)) {
          weeklyAdherence[i] = 0.0;
          continue;
        }

        final dateKey = '${dayDate.year}-${dayDate.month}-${dayDate.day}';
        final takenCount = takenDosesPerDay[dateKey]?.length ?? 0;

        // Heatmap adherence
        weeklyAdherence[i] = (takenCount / expectedDosesPerDay).clamp(0.0, 1.0);
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
