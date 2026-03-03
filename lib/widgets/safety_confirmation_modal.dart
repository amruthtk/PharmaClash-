import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user_medicine_model.dart';
import '../theme/app_colors.dart';

/// Safety Confirmation Modal — Pre-Dose Check (US 16)
/// ALWAYS shown before logging a dose from the schedule quick-dose flow.
/// User must confirm:
/// 1. Taking medicine with water
/// 2. Not consumed alcohol
/// 3. Individual checkboxes for AVOID-severity food items (in red)
/// 4. CAUTION items shown as info text (no checkbox)
/// 5. Final "I confirm" checkbox
/// Button only lights up once all checks are ticked.
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

  static Future<void> show({
    required BuildContext context,
    required UserMedicine medicine,
    required VoidCallback onConfirmed,
    VoidCallback? onCancelled,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
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
  bool _noAlcoholConfirmed = false;
  bool _finalConfirm = false;
  final Map<int, bool> _avoidChecks = {};

  // Parse warnings once
  late final List<String> _avoidWarnings;
  late final List<String> _cautionWarnings;
  late final bool _hasFoodWarnings;

  @override
  void initState() {
    super.initState();
    _avoidWarnings = [];
    _cautionWarnings = [];
    for (final raw in widget.medicine.foodWarnings) {
      final match = RegExp(r'^\[(\w+)\]\s*(.+)$').firstMatch(raw);
      if (match != null) {
        final severity = match.group(1)!.toLowerCase();
        final text = match.group(2)!;
        if (severity == 'avoid') {
          _avoidWarnings.add(text);
        } else {
          _cautionWarnings.add(text);
        }
      } else {
        _cautionWarnings.add(raw);
      }
    }
    _hasFoodWarnings = widget.medicine.foodWarnings.isNotEmpty;
  }

  bool get _canProceed {
    if (!_waterConfirmed || !_noAlcoholConfirmed) return false;
    if (_hasFoodWarnings) {
      // All avoid checkboxes must be ticked
      for (int i = 0; i < _avoidWarnings.length; i++) {
        if (!(_avoidChecks[i] ?? false)) return false;
      }
      // Final confirm must be ticked
      if (!_finalConfirm) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(22),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.92),
                  Colors.white.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 1,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Shield Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryTeal.withOpacity(0.15),
                          Colors.blue.withOpacity(0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.health_and_safety_rounded,
                      size: 32,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Pre-Dose Safety Check',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.medicine.medicineName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Standard checks ──
                  _buildCheckItem(
                    checked: _waterConfirmed,
                    label: 'I will take this with water',
                    icon: Icons.water_drop_rounded,
                    iconColor: Colors.blue,
                    onTap: () =>
                        setState(() => _waterConfirmed = !_waterConfirmed),
                  ),
                  const SizedBox(height: 8),
                  _buildCheckItem(
                    checked: _noAlcoholConfirmed,
                    label: 'I have NOT consumed alcohol',
                    icon: Icons.no_drinks_rounded,
                    iconColor: Colors.red.shade600,
                    onTap: () => setState(
                      () => _noAlcoholConfirmed = !_noAlcoholConfirmed,
                    ),
                  ),

                  // ── Food interaction section ──
                  if (_hasFoodWarnings) ...[
                    const SizedBox(height: 14),

                    // AVOID items — red, individual checkboxes
                    if (_avoidWarnings.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '⛔ AVOID',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Severe Interactions',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...List.generate(_avoidWarnings.length, (i) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: i < _avoidWarnings.length - 1 ? 8 : 0,
                                ),
                                child: InkWell(
                                  onTap: () => setState(
                                    () => _avoidChecks[i] =
                                        !(_avoidChecks[i] ?? false),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildSeverityCheckbox(
                                        _avoidChecks[i] ?? false,
                                        severe: true,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'I have NOT consumed ${_avoidWarnings[i].split(':').first.trim()}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFDC2626),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // CAUTION items — orange info text, no checkboxes
                    if (_cautionWarnings.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.orange.shade700,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Caution',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...(_cautionWarnings.map(
                              (w) => Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• ',
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        w,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade900,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Final "I confirm" checkbox
                    _buildCheckItem(
                      checked: _finalConfirm,
                      label: 'I confirm I have followed all guidelines',
                      icon: Icons.verified_user_rounded,
                      iconColor: AppColors.accentGreen,
                      onTap: () =>
                          setState(() => _finalConfirm = !_finalConfirm),
                    ),
                  ],

                  const SizedBox(height: 18),

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
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(
                              color: AppColors.grayText.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppColors.grayText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
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
                                : Colors.grey.shade300,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade500,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: _canProceed ? 4 : 0,
                            shadowColor: _canProceed
                                ? AppColors.accentGreen.withOpacity(0.4)
                                : Colors.transparent,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _canProceed
                                    ? Icons.check_circle_rounded
                                    : Icons.lock_rounded,
                                size: 17,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _canProceed
                                    ? 'Confirm Dose'
                                    : 'Tick All to Confirm',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Standard check item ──
  Widget _buildCheckItem({
    required bool checked,
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: checked
                ? [
                    AppColors.accentGreen.withOpacity(0.12),
                    AppColors.accentGreen.withOpacity(0.05),
                  ]
                : [
                    Colors.grey.withOpacity(0.08),
                    Colors.grey.withOpacity(0.04),
                  ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: checked
                ? AppColors.accentGreen.withOpacity(0.4)
                : Colors.grey.withOpacity(0.2),
            width: 1.5,
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
                  fontWeight: checked ? FontWeight.w600 : FontWeight.w500,
                  color: checked ? AppColors.darkText : AppColors.grayText,
                ),
              ),
            ),
            _buildSeverityCheckbox(checked),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityCheckbox(bool checked, {bool severe = false}) {
    final checkColor = severe && !checked
        ? const Color(0xFFDC2626)
        : (checked ? AppColors.accentGreen : Colors.grey.withOpacity(0.4));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: checked
            ? (severe ? const Color(0xFFDC2626) : AppColors.accentGreen)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: checked ? Colors.transparent : checkColor,
          width: 2,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : null,
    );
  }
}
