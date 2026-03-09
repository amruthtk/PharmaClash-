import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'firebase_service.dart';

/// Sends emails **automatically** via Gmail SMTP using the `mailer` package.
/// No user interaction, no third-party signups — the email is dispatched
/// silently in the background the moment the patient overrides a severe warning.
///
/// Setup (one-time):
///  1. Go to https://myaccount.google.com/security
///  2. Enable 2-Step Verification (required for App Passwords)
///  3. Go to https://myaccount.google.com/apppasswords
///  4. Create an App Password (select "Mail" → "Other" → name it "PharmaClash")
///  5. Copy the 16-character password and paste it below in [_appPassword]
///  6. Put your Gmail address in [_senderEmail]
class AutoEmailService {
  static final AutoEmailService _instance = AutoEmailService._internal();
  factory AutoEmailService() => _instance;
  AutoEmailService._internal();

  final FirebaseService _firebaseService = FirebaseService();

  // ──────── Gmail SMTP Configuration ────────
  // Replace with your actual Gmail and App Password
  static const String _senderEmail = 'steam4u2pes@gmail.com';
  static const String _appPassword ='huxi ulwa fefy uqdk'; // 16-char app password

  /// Send an automatic email — no user interaction required.
  Future<bool> sendAutomaticEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String messageBody,
  }) async {
    try {
      final smtpServer = gmail(_senderEmail, _appPassword);

      final message = Message()
        ..from = Address(_senderEmail, 'PharmaClash Alerts')
        ..recipients.add(toEmail)
        ..subject = subject
        ..text = messageBody;

      final sendReport = await send(message, smtpServer);
      debugPrint('✅ Auto-email sent: ${sendReport.toString()}');
      return true;
    } on MailerException catch (e) {
      debugPrint('❌ Mailer error: ${e.message}');
      for (var p in e.problems) {
        debugPrint('  Problem: ${p.code} — ${p.msg}');
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error sending auto-email: $e');
      return false;
    }
  }

  /// Sends a caregiver alert email automatically when a patient overrides
  /// a severe drug interaction warning.
  ///
  /// Reads the caregiver email from the patient's medical info in Firestore.
  /// Requires NO user interaction — fully automatic.
  Future<bool> sendCaregiverOverrideAlert({
    required String drugA,
    required String drugB,
    required String interactionDescription,
  }) async {
    try {
      final user = _firebaseService.currentUser;
      if (user == null) {
        debugPrint('No logged-in user');
        return false;
      }

      // Fetch caregiver details from medical_info
      final medicalInfo = await _firebaseService.getMedicalInfo(user.uid);
      final caregiverEmail = medicalInfo?['caregiverEmail'] as String?;
      final caregiverName =
          medicalInfo?['caregiverName'] as String? ?? 'Caregiver';
      final patientName = user.displayName ?? 'Patient';

      if (caregiverEmail == null || caregiverEmail.isEmpty) {
        debugPrint('No caregiver email configured — skipping auto-email');
        return false;
      }

      final subject =
          '🚨 PHARMACLASH EMERGENCY: $patientName ignored a severe warning';

      final body =
          '''
🚨 EMERGENCY ALERT — PharmaClash 🚨

Patient: $patientName
Action:  Overrode a SEVERE drug interaction warning

⚠️ Interaction Details:
  • Drug A: $drugA
  • Drug B: $drugB
  • Risk:   $interactionDescription

The patient chose to add this medicine to their cabinet
despite the severe warning.

Please contact the patient immediately.

— PharmaClash Automated Alert System
''';

      return await sendAutomaticEmail(
        toEmail: caregiverEmail,
        toName: caregiverName,
        subject: subject,
        messageBody: body,
      );
    } catch (e) {
      debugPrint('Error in sendCaregiverOverrideAlert: $e');
      return false;
    }
  }
}
