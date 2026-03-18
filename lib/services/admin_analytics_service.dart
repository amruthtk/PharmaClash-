import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/drug_model.dart';

/// Service providing analytics and audit logging for the Admin Dashboard.
///
/// Data sources:
///   - `users` collection → user count
///   - `drugs` collection (via DrugModel list) → risk distribution, interaction rule count
///   - `admin_audit_logs` collection → audit trail
class AdminAnalyticsService {
  // Singleton
  static final AdminAnalyticsService _instance =
      AdminAnalyticsService._internal();
  factory AdminAnalyticsService() => _instance;
  AdminAnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== User Stats ====================

  /// Total registered users.
  Future<int> getTotalUsers() async {
    try {
      final snapshot = await _firestore.collection('users').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('AdminAnalytics: getTotalUsers error: $e');
      return 0;
    }
  }

  // ==================== Risk Distribution ====================

  /// Computes risk distribution from the interaction data embedded in drugs.
  /// Deduplicates reciprocal rules to show accurate counts.
  Map<String, int> getRiskDistribution(List<DrugModel> drugs) {
    int severe = 0;
    int moderate = 0;
    int mild = 0;
    final Set<String> seenKeys = {};

    for (final drug in drugs) {
      for (final interaction in drug.drugInteractions) {
        final names = [
          drug.displayName.toLowerCase(),
          interaction.drugName.toLowerCase()
        ];
        names.sort();
        final key = '${names[0]}_${names[1]}_${interaction.severity.toLowerCase()}';

        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          switch (interaction.severity.toLowerCase()) {
            case 'severe':
              severe++;
              break;
            case 'moderate':
              moderate++;
              break;
            default:
              mild++;
          }
        }
      }
    }

    return {
      'severe': severe,
      'moderate': moderate,
      'mild': mild,
      'total': severe + moderate + mild,
    };
  }

  /// Total interaction rules across all drugs (deduplicated).
  int getInteractionRuleCount(List<DrugModel> drugs) {
    final Set<String> seenKeys = {};
    int count = 0;

    for (final drug in drugs) {
      for (final interaction in drug.drugInteractions) {
        final names = [
          drug.displayName.toLowerCase(),
          interaction.drugName.toLowerCase()
        ];
        names.sort();
        final key = '${names[0]}_${names[1]}_${interaction.severity.toLowerCase()}';

        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          count++;
        }
      }
    }
    return count;
  }

  // ==================== Audit Logging ====================

  CollectionReference<Map<String, dynamic>> get _adminLogs =>
      _firestore.collection('admin_audit_logs');

  /// Write an admin action to the audit log.
  Future<void> logAdminAction({
    required String action,
    String? details,
    String? targetId,
  }) async {
    try {
      await _adminLogs.add({
        'action': action,
        'details': details,
        'targetId': targetId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('AdminAnalytics: logAdminAction error: $e');
    }
  }

  /// Recent admin actions (most recent first).
  Future<List<Map<String, dynamic>>> getRecentAdminLogs({
    int limit = 10,
  }) async {
    try {
      final snapshot = await _adminLogs
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      debugPrint('AdminAnalytics: getRecentAdminLogs error: $e');
      return [];
    }
  }

  /// All admin actions with optional category filter.
  Future<List<Map<String, dynamic>>> getAdminLogs({
    int limit = 50,
    String? actionFilter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _adminLogs.orderBy(
        'timestamp',
        descending: true,
      );

      if (actionFilter != null && actionFilter.isNotEmpty) {
        query = query.where('action', isEqualTo: actionFilter);
      }

      final snapshot = await query.limit(limit).get();
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      debugPrint('AdminAnalytics: getAdminLogs error: $e');
      return [];
    }
  }

  // ==================== Guest Telemetry ====================

  CollectionReference<Map<String, dynamic>> get _guestTelemetry =>
      _firestore.collection('guest_telemetry');

  /// Write an anonymous guest action to the telemetry log.
  Future<void> logGuestEvent({
    required String guestId,
    required String action,
    String? details,
    String? targetId,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      await _guestTelemetry.add({
        'guestId': guestId,
        'action': action,
        'details': details,
        'targetId': targetId,
        'timestamp': FieldValue.serverTimestamp(),
        if (extraData != null) ...extraData,
      });
      debugPrint('GuestTelemetry: ✅ Logged "$action" for guest $guestId');
    } catch (e) {
      debugPrint('GuestTelemetry: ❌ FAILED to log "$action": $e');
    }
  }

  /// Fetches 2-stage funnel data: Active Guests, Registered Patients.
  Future<Map<String, int>> getFunnelData() async {
    try {
      // Fetch all telemetry once for efficient counting
      final interactionSnapshot = await _guestTelemetry.get();
      final guestEvents = interactionSnapshot.docs.map((doc) => doc.data()).toList();

      // Stage 1: Active Guests (Unique guest IDs with meaningful activity)
      final uniqueInteractedGuests = guestEvents
          .where((data) => [
            'guest_scan_start', 
            'guest_scan_success',
            'guest_scan_fail',
            'guest_interaction_check'
          ].contains(data['action']))
          .map((data) => data['guestId'] as String?)
          .where((id) => id != null)
          .toSet();

      // Stage 2: Registered Patients (Actual users in firestore)
      final userSnapshot = await _firestore.collection('users').count().get();
      final patients = userSnapshot.count ?? 0;

      final data = {
        'interactions': uniqueInteractedGuests.length,
        'patients': patients,
      };

      debugPrint('AdminAnalytics: Aggregated Funnel -> AG:${uniqueInteractedGuests.length} P:$patients');
      return data;
    } catch (e) {
      debugPrint('AdminAnalytics: getFunnelData error: $e');
      return {'interactions': 0, 'patients': 0};
    }
  }

  /// Top 10 guest interaction checks (Risk Heatmap).
  /// Combines A+B and B+A into a single entry and reports peak severity.
  Future<List<Map<String, dynamic>>> getTopGuestInteractions() async {
    try {
      final snapshot = await _guestTelemetry
          .where('action', isEqualTo: 'guest_interaction_check')
          .get();

      final Map<String, int> counts = {};
      final Map<String, String> severities = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final rawDetails = data['details'] as String? ?? 'Unknown';
        final severity = data['severity'] as String? ?? 'safe';

        // Normalize: "A + B" and "B + A" both become sorted "A + B"
        String label = rawDetails;
        if (rawDetails.contains(' + ')) {
          final parts = rawDetails.split(' + ');
          parts.sort();
          label = parts.join(' + ');
        }

        counts[label] = (counts[label] ?? 0) + 1;

        // Keep peak severity: severe > moderate > mild > safe
        final currentMax = severities[label] ?? 'safe';
        if (_isMoreSevere(severity, currentMax)) {
          severities[label] = severity;
        }
      }

      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted.take(10).map((e) {
        return {
          'label': e.key,
          'count': e.value,
          'severity': severities[e.key] ?? 'safe',
        };
      }).toList();
    } catch (e) {
      debugPrint('AdminAnalytics: getTopGuestInteractions error: $e');
      return [];
    }
  }

  bool _isMoreSevere(String a, String b) {
    const order = {'severe': 3, 'moderate': 2, 'mild': 1, 'safe': 0};
    return (order[a.toLowerCase()] ?? 0) > (order[b.toLowerCase()] ?? 0);
  }

  /// Guest scan success metrics.
  Future<Map<String, double>> getGuestPerformanceStats() async {
    try {
      final totalSnapshot = await _guestTelemetry
          .where('action', isEqualTo: 'guest_scan_start')
          .count()
          .get();
      
      final successSnapshot = await _guestTelemetry
          .where('action', isEqualTo: 'guest_scan_success')
          .count()
          .get();

      final total = totalSnapshot.count ?? 0;
      final success = successSnapshot.count ?? 0;

      if (total == 0) return {'successRate': 0.0};
      return {'successRate': (success / total) * 100};
    } catch (e) {
      debugPrint('AdminAnalytics: getGuestPerformanceStats error: $e');
      return {'successRate': 0.0};
    }
  }

  /// Recent guest telemetry actions (most recent first).
  Future<List<Map<String, dynamic>>> getRecentGuestTelemetry({
    int limit = 10,
  }) async {
    try {
      final snapshot = await _guestTelemetry
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      debugPrint('AdminAnalytics: getRecentGuestTelemetry error: $e');
      return [];
    }
  }
}
