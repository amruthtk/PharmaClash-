import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_medicine_model.dart';
import 'medicine_inventory_service.dart';

/// Represents a single missed dose that the user hasn't logged.
class MissedDose {
  final UserMedicine medicine;
  final String scheduledTime; // e.g. "08:00"
  final DateTime scheduledDate; // The date the dose was scheduled for

  MissedDose({
    required this.medicine,
    required this.scheduledTime,
    required this.scheduledDate,
  });

  /// Unique key for deduplication
  String get key =>
      '${medicine.id}|$scheduledTime|${scheduledDate.year}-${scheduledDate.month}-${scheduledDate.day}';

  /// Formatted display time (e.g. "8:00 AM")
  String get displayTime {
    final parts = scheduledTime.split(':');
    if (parts.length < 2) return scheduledTime;
    int hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Formatted display date (e.g. "Yesterday", "Mar 10")
  String get displayDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final doseDay = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );
    final diff = today.difference(doseDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[scheduledDate.month - 1]} ${scheduledDate.day}';
  }
}

/// Service that detects missed doses and tracks which ones have been
/// shown to the user. Missed doses are ones that were scheduled but
/// never logged, and the scheduled time has already passed.
class MissedDoseService {
  final MedicineInventoryService _inventoryService = MedicineInventoryService();

  static const String _lastCheckKey = 'missed_dose_last_check';
  static const String _dismissedKeysKey = 'missed_dose_dismissed';

  /// Get all missed doses that haven't been dismissed yet.
  /// Checks the current day (past time slots) and the previous day.
  Future<List<MissedDose>> getMissedDoses(String uid) async {
    try {
      final medicines = await _inventoryService.getUserMedicines(uid);
      final scheduledMedicines = medicines
          .where((m) => m.scheduleTimes.isNotEmpty)
          .toList();

      if (scheduledMedicines.isEmpty) return [];

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      // Get dose logs for today and yesterday
      final todayLogs = await _inventoryService.getTodayDoseLogs(uid);
      final yesterdayLogs = await _inventoryService.getDoseLogsForDate(
        uid,
        yesterday,
      );

      // Build set of already-logged dose keys
      final loggedKeys = <String>{};
      for (final log in todayLogs) {
        final medId = log['medicineId'];
        final schTime = log['scheduledTime'];
        if (medId != null && schTime != null) {
          loggedKeys.add('$medId|$schTime|${today.year}-${today.month}-${today.day}');
        }
      }
      for (final log in yesterdayLogs) {
        final medId = log['medicineId'];
        final schTime = log['scheduledTime'];
        if (medId != null && schTime != null) {
          loggedKeys.add('$medId|$schTime|${yesterday.year}-${yesterday.month}-${yesterday.day}');
        }
      }

      // Load dismissed keys from local storage
      final dismissedKeys = await _getDismissedKeys();

      final List<MissedDose> missedDoses = [];

      for (final medicine in scheduledMedicines) {
        if (medicine.id == null) continue;

        // Check if this medicine is supposed to be taken on yesterday/today
        // based on doseIntervalDays
        final addedDay = DateTime(
          medicine.addedAt.year,
          medicine.addedAt.month,
          medicine.addedAt.day,
        );

        // --- Check YESTERDAY's doses ---
        // Skip if medicine was added today or later — it didn't exist yesterday
        if (addedDay.isBefore(today) && _isDoseDay(medicine, addedDay, yesterday)) {
          for (final time in medicine.scheduleTimes) {
            final missedDose = MissedDose(
              medicine: medicine,
              scheduledTime: time,
              scheduledDate: yesterday,
            );

            if (!loggedKeys.contains(missedDose.key) &&
                !dismissedKeys.contains(missedDose.key)) {
              missedDoses.add(missedDose);
            }
          }
        }

        // --- Check TODAY's past doses ---
        if (_isDoseDay(medicine, addedDay, today)) {
          for (final time in medicine.scheduleTimes) {
            // Only include doses whose time has already passed
            final parts = time.split(':');
            if (parts.length >= 2) {
              final hour = int.tryParse(parts[0]) ?? 0;
              final minute = int.tryParse(parts[1]) ?? 0;
              final slotTime = DateTime(
                now.year, now.month, now.day, hour, minute,
              );

              // Only flag if at least 30 minutes have passed since scheduled time
              if (now.difference(slotTime).inMinutes >= 30) {
                final missedDose = MissedDose(
                  medicine: medicine,
                  scheduledTime: time,
                  scheduledDate: today,
                );

                if (!loggedKeys.contains(missedDose.key) &&
                    !dismissedKeys.contains(missedDose.key)) {
                  missedDoses.add(missedDose);
                }
              }
            }
          }
        }
      }

      // Sort: yesterday first, then by time
      missedDoses.sort((a, b) {
        final dateCmp = a.scheduledDate.compareTo(b.scheduledDate);
        if (dateCmp != 0) return dateCmp;
        return a.scheduledTime.compareTo(b.scheduledTime);
      });

      return missedDoses;
    } catch (e) {
      debugPrint('Error getting missed doses: $e');
      return [];
    }
  }

  /// Check if a medicine should be taken on the given date
  /// based on its doseIntervalDays.
  bool _isDoseDay(UserMedicine medicine, DateTime addedDay, DateTime checkDate) {
    if (medicine.doseIntervalDays <= 0) return true; // Daily
    final daysSinceAdded = checkDate.difference(addedDay).inDays;
    if (daysSinceAdded < 0) return false;
    return daysSinceAdded % (medicine.doseIntervalDays + 1) == 0;
  }

  /// Mark a missed dose as "taken" — logs it with the original scheduled date
  /// and time as the takenAt timestamp (not the current time).
  /// This ensures the dose appears in the correct day's schedule and
  /// adherence streak.
  Future<void> markAsTaken(String uid, MissedDose missedDose) async {
    if (missedDose.medicine.id == null) return;

    try {
      // Build the historical takenAt from scheduled date + time
      // e.g., if dose was scheduled for yesterday at 08:00,
      // takenAt = yesterday at 08:00
      final parts = missedDose.scheduledTime.split(':');
      final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

      final historicalTakenAt = DateTime(
        missedDose.scheduledDate.year,
        missedDose.scheduledDate.month,
        missedDose.scheduledDate.day,
        hour,
        minute,
      );

      await _inventoryService.logDose(
        uid: uid,
        medicineId: missedDose.medicine.id!,
        medicineName: missedDose.medicine.medicineName,
        quantity: 1,
        scheduledTime: missedDose.scheduledTime,
        takenAt: historicalTakenAt,
      );
    } catch (e) {
      debugPrint('Error marking missed dose as taken: $e');
      rethrow;
    }
  }

  /// Dismiss a missed dose — user confirms they did NOT take it.
  /// We store the key locally so it won't show again.
  Future<void> dismissMissedDose(MissedDose missedDose) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_dismissedKeysKey) ?? [];
      existing.add(missedDose.key);

      // Only keep keys from last 3 days to prevent unbounded growth
      final now = DateTime.now();
      final cutoff = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 3));
      final filtered = existing.where((key) {
        final parts = key.split('|');
        if (parts.length < 3) return false;
        final dateParts = parts[2].split('-');
        if (dateParts.length < 3) return false;
        try {
          final keyDate = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
          );
          return keyDate.isAfter(cutoff) || keyDate.isAtSameMomentAs(cutoff);
        } catch (_) {
          return false;
        }
      }).toList();

      await prefs.setStringList(_dismissedKeysKey, filtered);
    } catch (e) {
      debugPrint('Error dismissing missed dose: $e');
    }
  }

  /// Dismiss all current missed doses at once.
  Future<void> dismissAll(List<MissedDose> missedDoses) async {
    for (final dose in missedDoses) {
      await dismissMissedDose(dose);
    }
  }

  /// Check if we should show the missed dose prompt.
  /// Returns true at most once per app session (cold start).
  Future<bool> shouldShowPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString(_lastCheckKey);
      final now = DateTime.now();
      final sessionKey =
          '${now.year}-${now.month}-${now.day}-${now.hour}';

      if (lastCheck == sessionKey) return false;

      await prefs.setString(_lastCheckKey, sessionKey);
      return true;
    } catch (e) {
      return true; // Default to showing if preferences fail
    }
  }

  /// Get dismissed keys from local storage
  Future<Set<String>> _getDismissedKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getStringList(_dismissedKeysKey) ?? [];
      return keys.toSet();
    } catch (e) {
      return {};
    }
  }

  /// Clear old dismissed keys (housekeeping)
  Future<void> clearOldDismissedKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_dismissedKeysKey) ?? [];

      final now = DateTime.now();
      final cutoff = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 3));

      final filtered = existing.where((key) {
        final parts = key.split('|');
        if (parts.length < 3) return false;
        final dateParts = parts[2].split('-');
        if (dateParts.length < 3) return false;
        try {
          final keyDate = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
          );
          return keyDate.isAfter(cutoff) || keyDate.isAtSameMomentAs(cutoff);
        } catch (_) {
          return false;
        }
      }).toList();

      await prefs.setStringList(_dismissedKeysKey, filtered);
    } catch (e) {
      debugPrint('Error clearing old dismissed keys: $e');
    }
  }
}
