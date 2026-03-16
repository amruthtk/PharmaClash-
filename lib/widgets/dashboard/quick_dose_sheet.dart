import 'package:flutter/material.dart';
import '../../models/user_medicine_model.dart';
import '../../services/medicine_inventory_service.dart';
import '../../theme/app_colors.dart';
import '../safety_confirmation_modal.dart';

class QuickDoseSheet extends StatelessWidget {
  final UserMedicine medicine;
  final String time;
  final String userId;
  final Function(UserMedicine, String) onLogDose;

  const QuickDoseSheet({
    super.key,
    required this.medicine,
    required this.time,
    required this.userId,
    required this.onLogDose,
  });

  static Future<void> show({
    required BuildContext context,
    required UserMedicine medicine,
    required String time,
    required String userId,
    required Function(UserMedicine, String) onLogDose,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickDoseSheet(
        medicine: medicine,
        time: time,
        userId: userId,
        onLogDose: onLogDose,
      ),
    );
  }

  /// Whether the safety modal needs to be shown for this medicine.
  /// Only shown on the FIRST dose if there are food warnings.
  bool get _needsSafetyCheck =>
      medicine.foodWarnings.isNotEmpty && !medicine.safetyAcknowledged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Icon(
            Icons.medication_rounded,
            size: 48,
            color: AppColors.primaryTeal,
          ),
          const SizedBox(height: 16),
          Text(
            'Take ${medicine.medicineName}?',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scheduled for $time',
            style: TextStyle(fontSize: 14, color: AppColors.grayText),
          ),
          if (medicine.isExpired) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This medicine is expired! It is no longer safe to take.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (medicine.isExpiringSoon) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                   Icon(Icons.event_note_rounded, color: Colors.orange.shade800, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This medicine expires in ${medicine.daysUntilExpiry} days.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (medicine.foodWarnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      medicine.safetyAcknowledged
                          ? '✅ Safety warnings acknowledged'
                          : '⚠️ Food restriction applies',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: medicine.safetyAcknowledged
                            ? AppColors.accentGreen
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: medicine.tabletCount <= 0 || medicine.isExpired
                      ? null
                      : () async {
                          Navigator.pop(context);
                          if (_needsSafetyCheck) {
                            // First time — show safety modal
                            await SafetyConfirmationModal.show(
                              context: context,
                              medicine: medicine,
                              onConfirmed: () {
                                // Mark as acknowledged so it won't show again
                                if (medicine.id != null) {
                                  MedicineInventoryService()
                                      .markSafetyAcknowledged(
                                        userId,
                                        medicine.id!,
                                      );
                                }
                                onLogDose(medicine, time);
                              },
                            );
                          } else {
                            // Already acknowledged or no warnings — log directly
                            onLogDose(medicine, time);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    medicine.isExpired
                        ? 'Expired'
                        : (medicine.tabletCount <= 0 ? 'Out of Stock' : 'Take Dose'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
