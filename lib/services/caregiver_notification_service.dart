import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for managing caregiver alerts via Firestore real-time sync.
///
/// Uses "Escalated Alerting" — notifications are triggered locally on the
/// caregiver's device via a Firestore snapshot listener when:
/// 1. Patient overrides a severe interaction warning (IMMEDIATE)
/// 2. Patient misses a dose (OPTIONAL — if toggle is enabled)
class CaregiverNotificationService {
  static final CaregiverNotificationService _instance =
      CaregiverNotificationService._internal();
  factory CaregiverNotificationService() => _instance;
  CaregiverNotificationService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  StreamSubscription<QuerySnapshot>? _alertListener;

  // ────────────────────── LINK CODE ──────────────────────

  /// Generate a 6-digit link code for the current patient.
  /// Expires after 15 minutes.
  Future<String?> generateLinkCode() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;

      final code = _generateCode();
      await _firestore.collection('caregiver_links').doc(code).set({
        'patientUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 15)),
        ),
        'redeemed': false,
      });

      return code;
    } catch (e) {
      debugPrint('CaregiverNotif: link code error: $e');
      return null;
    }
  }

  /// Caregiver redeems the patient's link code.
  /// Returns patient name on success, null on failure.
  Future<Map<String, String>?> redeemLinkCode(String code) async {
    try {
      final caregiverUid = _auth.currentUser?.uid;
      if (caregiverUid == null) return null;

      final doc = await _firestore
          .collection('caregiver_links')
          .doc(code)
          .get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final patientUid = data['patientUid'] as String;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final redeemed = data['redeemed'] as bool? ?? false;

      if (redeemed || DateTime.now().isAfter(expiresAt)) return null;
      if (patientUid == caregiverUid) return null; // Can't link to self

      // Mark code as redeemed
      await _firestore.collection('caregiver_links').doc(code).update({
        'redeemed': true,
        'redeemedBy': caregiverUid,
      });

      // Create bidirectional link
      await _firestore.collection('users').doc(patientUid).update({
        'linkedCaregivers': FieldValue.arrayUnion([caregiverUid]),
      });
      await _firestore.collection('users').doc(caregiverUid).update({
        'linkedPatients': FieldValue.arrayUnion([patientUid]),
      });

      // Get patient name for confirmation
      final patientDoc = await _firestore
          .collection('users')
          .doc(patientUid)
          .get();
      final patientName =
          patientDoc.data()?['fullName'] as String? ?? 'Patient';

      // Get caregiver name for patient notification
      final caregiverDoc = await _firestore
          .collection('users')
          .doc(caregiverUid)
          .get();
      final caregiverName =
          caregiverDoc.data()?['fullName'] as String? ?? 'Caregiver';

      // Notify patient that a caregiver linked
      await _firestore
          .collection('caregiver_alerts')
          .doc(patientUid)
          .collection('alerts')
          .add({
            'type': 'caregiver_linked',
            'title': 'Caregiver Linked',
            'message':
                '$caregiverName has linked as your caregiver and will receive medication alerts.',
            'caregiverUid': caregiverUid,
            'caregiverName': caregiverName,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });

      return {'patientName': patientName, 'patientUid': patientUid};
    } catch (e) {
      debugPrint('CaregiverNotif: redeem error: $e');
      return null;
    }
  }

  /// Get list of linked caregivers for the current patient.
  Future<List<Map<String, dynamic>>> getLinkedCaregivers() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return [];

      final userDoc = await _firestore.collection('users').doc(uid).get();
      final caregiverUids = List<String>.from(
        userDoc.data()?['linkedCaregivers'] ?? [],
      );

      final caregivers = <Map<String, dynamic>>[];
      for (final cUid in caregiverUids) {
        final cDoc = await _firestore.collection('users').doc(cUid).get();
        if (cDoc.exists) {
          caregivers.add({
            'uid': cUid,
            'name': cDoc.data()?['fullName'] ?? 'Caregiver',
            'email': cDoc.data()?['email'] ?? '',
          });
        }
      }
      return caregivers;
    } catch (e) {
      debugPrint('CaregiverNotif: get caregivers error: $e');
      return [];
    }
  }

  /// Get list of linked patients for the current caregiver.
  Future<List<Map<String, dynamic>>> getLinkedPatients() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return [];

      final userDoc = await _firestore.collection('users').doc(uid).get();
      final patientUids = List<String>.from(
        userDoc.data()?['linkedPatients'] ?? [],
      );

      final patients = <Map<String, dynamic>>[];
      for (final pUid in patientUids) {
        final pDoc = await _firestore.collection('users').doc(pUid).get();
        if (pDoc.exists) {
          patients.add({
            'uid': pUid,
            'name': pDoc.data()?['fullName'] ?? 'Patient',
            'email': pDoc.data()?['email'] ?? '',
          });
        }
      }
      return patients;
    } catch (e) {
      debugPrint('CaregiverNotif: get patients error: $e');
      return [];
    }
  }

  /// Unlink a caregiver from a patient.
  Future<bool> unlinkCaregiver(String caregiverUid) async {
    try {
      final patientUid = _auth.currentUser?.uid;
      if (patientUid == null) return false;

      await _firestore.collection('users').doc(patientUid).update({
        'linkedCaregivers': FieldValue.arrayRemove([caregiverUid]),
      });
      await _firestore.collection('users').doc(caregiverUid).update({
        'linkedPatients': FieldValue.arrayRemove([patientUid]),
      });

      return true;
    } catch (e) {
      debugPrint('CaregiverNotif: unlink error: $e');
      return false;
    }
  }

  // ────────────────────── ALERT TRIGGERS ──────────────────────

  /// 🚨 SEVERE OVERRIDE ALERT — sent when patient ignores a high-risk warning.
  Future<void> sendSevereOverrideAlert({
    required String drugA,
    required String drugB,
    required String severity,
    String? interactionDescription,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final userDoc = await _firestore.collection('users').doc(uid).get();
      final patientName = userDoc.data()?['fullName'] as String? ?? 'Patient';
      final caregiverUids = List<String>.from(
        userDoc.data()?['linkedCaregivers'] ?? [],
      );

      if (caregiverUids.isEmpty) return;

      for (final caregiverUid in caregiverUids) {
        await _firestore
            .collection('caregiver_alerts')
            .doc(caregiverUid)
            .collection('alerts')
            .add({
              'type': 'severe_override',
              'patientUid': uid,
              'patientName': patientName,
              'title': '🚨 EMERGENCY: High-Risk Override',
              'message':
                  '$patientName has ignored a severe interaction warning between $drugA and $drugB. Please intervene immediately.',
              'drugA': drugA,
              'drugB': drugB,
              'severity': severity,
              'interactionDescription': interactionDescription ?? '',
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
            });
      }

      debugPrint(
        'CaregiverNotif: severe override alert sent to '
        '${caregiverUids.length} caregivers',
      );
    } catch (e) {
      debugPrint('CaregiverNotif: severe override alert error: $e');
    }
  }

  /// ⏰ MISSED DOSE ALERT — sent only if the toggle is enabled.
  Future<void> sendMissedDoseAlert({
    required String medicineName,
    required String scheduledTime,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      // Check if missed dose alerts are enabled
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final missedDoseAlertsEnabled =
          userDoc.data()?['missedDoseAlertsEnabled'] as bool? ?? false;
      if (!missedDoseAlertsEnabled) return;

      final patientName = userDoc.data()?['fullName'] as String? ?? 'Patient';
      final caregiverUids = List<String>.from(
        userDoc.data()?['linkedCaregivers'] ?? [],
      );

      if (caregiverUids.isEmpty) return;

      for (final caregiverUid in caregiverUids) {
        await _firestore
            .collection('caregiver_alerts')
            .doc(caregiverUid)
            .collection('alerts')
            .add({
              'type': 'missed_dose',
              'patientUid': uid,
              'patientName': patientName,
              'title': '⏰ Missed Dose',
              'message':
                  '$patientName missed their $scheduledTime dose of $medicineName.',
              'medicineName': medicineName,
              'scheduledTime': scheduledTime,
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
            });
      }
    } catch (e) {
      debugPrint('CaregiverNotif: missed dose alert error: $e');
    }
  }

  /// Toggle missed dose alerts setting.
  Future<void> setMissedDoseAlerts(bool enabled) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).update({
      'missedDoseAlertsEnabled': enabled,
    });
  }

  /// Get missed dose alerts setting.
  Future<bool> getMissedDoseAlerts() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['missedDoseAlertsEnabled'] as bool? ?? false;
  }

  // ────────────────────── LISTENER ──────────────────────

  /// Start listening for incoming caregiver alerts.
  /// Fires a local notification when a new alert arrives.
  void startListening() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _alertListener?.cancel();
    _alertListener = _firestore
        .collection('caregiver_alerts')
        .doc(uid)
        .collection('alerts')
        .where('read', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null) {
                _showLocalNotification(
                  title: data['title'] as String? ?? 'Alert',
                  body: data['message'] as String? ?? '',
                  type: data['type'] as String? ?? 'unknown',
                );
              }
            }
          }
        });
  }

  /// Stop listening for caregiver alerts.
  void stopListening() {
    _alertListener?.cancel();
    _alertListener = null;
  }

  /// Get all alerts for the current user (as caregiver).
  Future<List<Map<String, dynamic>>> getAlerts({int limit = 50}) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return [];

      final query = await _firestore
          .collection('caregiver_alerts')
          .doc(uid)
          .collection('alerts')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('CaregiverNotif: get alerts error: $e');
      return [];
    }
  }

  /// Mark an alert as read.
  Future<void> markAlertRead(String alertId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      await _firestore
          .collection('caregiver_alerts')
          .doc(uid)
          .collection('alerts')
          .doc(alertId)
          .update({'read': true});
    } catch (e) {
      debugPrint('CaregiverNotif: mark read error: $e');
    }
  }

  /// Get count of unread alerts.
  Future<int> getUnreadCount() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return 0;

      final query = await _firestore
          .collection('caregiver_alerts')
          .doc(uid)
          .collection('alerts')
          .where('read', isEqualTo: false)
          .count()
          .get();

      return query.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Check if the current user has any linked patients (i.e., is a caregiver).
  Future<bool> isCaregiver() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _firestore.collection('users').doc(uid).get();
    final patients = List<String>.from(doc.data()?['linkedPatients'] ?? []);
    return patients.isNotEmpty;
  }

  /// Check if the current user has any linked caregivers (i.e., is a patient).
  Future<bool> hasLinkedCaregivers() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _firestore.collection('users').doc(uid).get();
    final caregivers = List<String>.from(doc.data()?['linkedCaregivers'] ?? []);
    return caregivers.isNotEmpty;
  }

  // ────────────────────── HELPERS ──────────────────────

  String _generateCode() {
    final rng = Random.secure();
    return List.generate(6, (_) => rng.nextInt(10)).join();
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final isSevere = type == 'severe_override';

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            isSevere ? 'caregiver_emergency' : 'caregiver_alerts',
            isSevere ? 'Emergency Alerts' : 'Caregiver Alerts',
            channelDescription: isSevere
                ? 'Emergency alerts for severe interaction overrides'
                : 'Caregiver notifications for patient medication events',
            importance: isSevere ? Importance.max : Importance.high,
            priority: isSevere ? Priority.max : Priority.high,
            category: isSevere
                ? AndroidNotificationCategory.alarm
                : AndroidNotificationCategory.message,
            fullScreenIntent: isSevere,
            color: isSevere ? const Color(0xFFFF0000) : const Color(0xFF009688),
          ),
        ),
      );
    } catch (e) {
      debugPrint('CaregiverNotif: local notification error: $e');
    }
  }
}
