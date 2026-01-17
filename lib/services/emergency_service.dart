import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_service.dart';

/// Service for handling emergency caregiver notifications
class EmergencyService {
  // Singleton pattern
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  final FirebaseService _firebaseService = FirebaseService();

  /// Get caregiver info for the current user
  Future<Map<String, String>?> getCaregiverInfo() async {
    try {
      final user = _firebaseService.currentUser;
      if (user == null) return null;

      final medicalInfo = await _firebaseService.getMedicalInfo(user.uid);
      if (medicalInfo == null) return null;

      final name = medicalInfo['caregiverName'] as String?;
      final phone = medicalInfo['caregiverPhone'] as String?;

      if (phone == null || phone.isEmpty) return null;

      return {'name': name ?? 'Caregiver', 'phone': phone};
    } catch (e) {
      debugPrint('Error getting caregiver info: $e');
      return null;
    }
  }

  /// Check if caregiver is configured
  Future<bool> hasCaregiverConfigured() async {
    final info = await getCaregiverInfo();
    return info != null && info['phone']!.isNotEmpty;
  }

  /// Send SMS alert to caregiver
  Future<bool> sendSMSAlert({
    required String message,
    String? customPhone,
  }) async {
    try {
      String? phone = customPhone;

      if (phone == null) {
        final caregiverInfo = await getCaregiverInfo();
        if (caregiverInfo == null) {
          debugPrint('No caregiver phone configured');
          return false;
        }
        phone = caregiverInfo['phone'];
      }

      final smsUri = Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      } else {
        debugPrint('Could not launch SMS');
        return false;
      }
    } catch (e) {
      debugPrint('Error sending SMS: $e');
      return false;
    }
  }

  /// Make emergency call to caregiver
  Future<bool> callCaregiver({String? customPhone}) async {
    try {
      String? phone = customPhone;

      if (phone == null) {
        final caregiverInfo = await getCaregiverInfo();
        if (caregiverInfo == null) {
          debugPrint('No caregiver phone configured');
          return false;
        }
        phone = caregiverInfo['phone'];
      }

      final phoneUri = Uri(scheme: 'tel', path: phone);

      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        return true;
      } else {
        debugPrint('Could not launch phone call');
        return false;
      }
    } catch (e) {
      debugPrint('Error making call: $e');
      return false;
    }
  }

  /// Generate emergency alert message for drug warning
  String generateDrugAlertMessage({
    required String patientName,
    required String drugName,
    required String warningType,
    required List<String> details,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🚨 PHARMACLASH ALERT 🚨');
    buffer.writeln('');
    buffer.writeln('Patient: $patientName');
    buffer.writeln('Drug: $drugName');
    buffer.writeln('Warning: $warningType');
    buffer.writeln('');
    if (details.isNotEmpty) {
      buffer.writeln('Details:');
      for (final detail in details) {
        buffer.writeln('• $detail');
      }
    }
    buffer.writeln('');
    buffer.writeln('Please check on the patient immediately.');

    return buffer.toString();
  }

  /// Show emergency options dialog
  Future<void> showEmergencyOptions(
    BuildContext context, {
    required String drugName,
    required String warningType,
    required List<String> details,
  }) async {
    final caregiverInfo = await getCaregiverInfo();
    final userName = _firebaseService.currentUser?.displayName ?? 'Patient';

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _EmergencyOptionsSheet(
        caregiverName: caregiverInfo?['name'] ?? 'Caregiver',
        caregiverPhone: caregiverInfo?['phone'],
        drugName: drugName,
        warningType: warningType,
        alertMessage: generateDrugAlertMessage(
          patientName: userName,
          drugName: drugName,
          warningType: warningType,
          details: details,
        ),
        onCallCaregiver: caregiverInfo != null
            ? () => callCaregiver(customPhone: caregiverInfo['phone'])
            : null,
        onSendSMS: caregiverInfo != null
            ? () => sendSMSAlert(
                message: generateDrugAlertMessage(
                  patientName: userName,
                  drugName: drugName,
                  warningType: warningType,
                  details: details,
                ),
                customPhone: caregiverInfo['phone'],
              )
            : null,
      ),
    );
  }
}

/// Bottom sheet for emergency options
class _EmergencyOptionsSheet extends StatelessWidget {
  final String caregiverName;
  final String? caregiverPhone;
  final String drugName;
  final String warningType;
  final String alertMessage;
  final Future<bool> Function()? onCallCaregiver;
  final Future<bool> Function()? onSendSMS;

  const _EmergencyOptionsSheet({
    required this.caregiverName,
    this.caregiverPhone,
    required this.drugName,
    required this.warningType,
    required this.alertMessage,
    this.onCallCaregiver,
    this.onSendSMS,
  });

  @override
  Widget build(BuildContext context) {
    final hasCaregiver = caregiverPhone != null && caregiverPhone!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Warning header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.warning_rounded,
                      color: Colors.red.shade600,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emergency Contact',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade700,
                          ),
                        ),
                        Text(
                          '$warningType detected for $drugName',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (hasCaregiver) ...[
              // Caregiver info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.teal.shade100,
                      child: Icon(Icons.person, color: Colors.teal.shade700),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            caregiverName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            caregiverPhone!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  // Call button
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.phone_rounded,
                      label: 'Call Now',
                      color: Colors.green,
                      onTap: () async {
                        if (onCallCaregiver != null) {
                          await onCallCaregiver!();
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // SMS button
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.message_rounded,
                      label: 'Send SMS',
                      color: Colors.blue,
                      onTap: () async {
                        if (onSendSMS != null) {
                          await onSendSMS!();
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              // No caregiver configured
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_add_rounded,
                      size: 48,
                      color: Colors.orange.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No Caregiver Configured',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add a caregiver in your profile to enable emergency alerts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/medical-info');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Caregiver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
