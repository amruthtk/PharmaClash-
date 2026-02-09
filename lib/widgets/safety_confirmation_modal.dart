import 'package:flutter/material.dart';
import '../models/user_medicine_model.dart';
import '../theme/app_colors.dart';

/// Safety Confirmation Modal - Layer 2 Defense
/// A BLOCKING dialog that requires user to confirm safe intake conditions
/// before logging a dose when food warnings exist.
class SafetyConfirmationModal extends StatefulWidget {
  final UserMedicine medicine;
  final VoidCallback onConfirmed;
  final VoidCallback? onCancelled;

  const SafetyConfirmationModal({
    super.key,
    required this.medicine,
    required this.onConfirmed,
    this.onCancelled,
  });

  /// Show the safety confirmation modal
  static Future<void> show({
    required BuildContext context,
    required UserMedicine medicine,
    required VoidCallback onConfirmed,
    VoidCallback? onCancelled,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false, // User MUST answer
      builder: (context) => SafetyConfirmationModal(
        medicine: medicine,
        onConfirmed: onConfirmed,
        onCancelled: onCancelled,
      ),
    );
  }

  @override
  State<SafetyConfirmationModal> createState() =>
      _SafetyConfirmationModalState();
}

class _SafetyConfirmationModalState extends State<SafetyConfirmationModal> {
  bool _waterConfirmed = false;
  bool _noDairyConfirmed = false;

  bool get _canProceed => _waterConfirmed && _noDairyConfirmed;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              '⚠️ Food Interaction Warning',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Medicine name
            Text(
              widget.medicine.medicineName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryTeal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Warning message box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  for (final warning in widget.medicine.foodWarnings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.no_food_rounded,
                            color: Colors.orange.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              warning,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange.shade900,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Confirmation checkboxes
            Text(
              'Please confirm before taking:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.grayText,
              ),
            ),
            const SizedBox(height: 12),

            // Water checkbox
            _buildCheckbox(
              value: _waterConfirmed,
              label: 'I am taking this with WATER only',
              icon: Icons.water_drop_rounded,
              iconColor: Colors.blue,
              onChanged: (value) =>
                  setState(() => _waterConfirmed = value ?? false),
            ),

            const SizedBox(height: 8),

            // No dairy checkbox
            _buildCheckbox(
              value: _noDairyConfirmed,
              label: 'I have NOT consumed milk/dairy/yogurt',
              icon: Icons.no_drinks_rounded,
              iconColor: Colors.red,
              onChanged: (value) =>
                  setState(() => _noDairyConfirmed = value ?? false),
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onCancelled?.call();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: AppColors.grayText),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.grayText),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canProceed
                        ? () {
                            Navigator.pop(context);
                            widget.onConfirmed();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canProceed
                          ? AppColors.accentGreen
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _canProceed
                              ? Icons.check_circle_rounded
                              : Icons.lock_rounded,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(_canProceed ? 'Confirm & Take' : 'Check Both'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required String label,
    required IconData icon,
    required Color iconColor,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value
              ? AppColors.accentGreen.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? AppColors.accentGreen.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: value ? AppColors.darkText : AppColors.grayText,
                ),
              ),
            ),
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.accentGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
