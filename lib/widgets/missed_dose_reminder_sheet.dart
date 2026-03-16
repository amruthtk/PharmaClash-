import 'package:flutter/material.dart';
import '../services/missed_dose_service.dart';
import '../theme/app_colors.dart';

/// A premium bottom sheet that appears when the user opens the app
/// and has unlogged doses. Assumes the user took the medicine and
/// asks for confirmation — "Did you take these?" with options to
/// confirm or skip each one.
class MissedDoseReminderSheet extends StatefulWidget {
  final List<MissedDose> missedDoses;
  final String userId;
  final VoidCallback onComplete;

  const MissedDoseReminderSheet({
    super.key,
    required this.missedDoses,
    required this.userId,
    required this.onComplete,
  });

  /// Show the missed dose reminder as a modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required List<MissedDose> missedDoses,
    required String userId,
    required VoidCallback onComplete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => MissedDoseReminderSheet(
        missedDoses: missedDoses,
        userId: userId,
        onComplete: onComplete,
      ),
    );
  }

  @override
  State<MissedDoseReminderSheet> createState() =>
      _MissedDoseReminderSheetState();
}

class _MissedDoseReminderSheetState extends State<MissedDoseReminderSheet>
    with SingleTickerProviderStateMixin {
  final MissedDoseService _missedDoseService = MissedDoseService();

  // Track which doses are selected as "taken" (default: all selected)
  late Map<String, bool> _selectedDoses;
  bool _isSubmitting = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Default: assume all doses were taken, EXCEPT expired ones
    _selectedDoses = {
      for (final dose in widget.missedDoses) 
        dose.key: !dose.medicine.isExpired,
    };

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      for (final dose in widget.missedDoses) {
        if (_selectedDoses[dose.key] == true) {
          // User confirms they took it — log the dose
          await _missedDoseService.markAsTaken(widget.userId, dose);
        } else {
          // User says they didn't take it — dismiss so it won't show again
          await _missedDoseService.dismissMissedDose(dose);
        }
      }
    } catch (e) {
      debugPrint('Error submitting missed doses: $e');
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onComplete();
    }
  }

  Future<void> _handleSkipAll() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await _missedDoseService.dismissAll(widget.missedDoses);
    } catch (e) {
      debugPrint('Error dismissing all missed doses: $e');
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxSheetHeight = screenHeight * 0.75;

    // Group missed doses by date
    final grouped = <String, List<MissedDose>>{};
    for (final dose in widget.missedDoses) {
      grouped.putIfAbsent(dose.displayDate, () => []);
      grouped[dose.displayDate]!.add(dose);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animController,
          curve: Curves.easeOutCubic,
        )),
        child: Container(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        padding: EdgeInsets.only(bottom: bottomPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                children: [
                  // Icon with gradient background
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade400,
                          Colors.orange.shade400,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.medication_liquid_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Did you take these?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'We noticed ${widget.missedDoses.length == 1 ? 'a dose' : '${widget.missedDoses.length} doses'} that ${widget.missedDoses.length == 1 ? "wasn't" : "weren't"} logged. '
                    'We\'ve assumed you took them — please confirm or uncheck any you missed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.grayText,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Divider
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              color: Colors.grey.shade200,
            ),

            // Dose list
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                shrinkWrap: true,
                children: grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date header
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Row(
                          children: [
                            Icon(
                              entry.key == 'Yesterday'
                                  ? Icons.history_rounded
                                  : Icons.today_rounded,
                              size: 14,
                              color: AppColors.grayText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.grayText,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Dose items for this date
                      ...entry.value.map((dose) => _buildDoseItem(dose)),
                      const SizedBox(height: 12),
                    ],
                  );
                }).toList(),
              ),
            ),

            // Bottom actions
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _getConfirmButtonText(),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Skip all button
                  TextButton(
                    onPressed: _isSubmitting ? null : _handleSkipAll,
                    child: Text(
                      'I didn\'t take any of these',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grayText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),     // Container
      ),     // SlideTransition
    );      // FadeTransition
  }

  String _getConfirmButtonText() {
    final selectedCount =
        _selectedDoses.values.where((v) => v).length;
    if (selectedCount == widget.missedDoses.length) {
      return 'Confirm All Taken';
    } else if (selectedCount == 0) {
      return 'Skip All';
    }
    return 'Confirm $selectedCount Taken';
  }

  Widget _buildDoseItem(MissedDose dose) {
    final isExpired = dose.medicine.isExpired;
    final isSelected = _selectedDoses[dose.key] ?? false;

    return GestureDetector(
      onTap: isExpired 
        ? null // Cannot confirm taking expired meds
        : () {
            setState(() {
              _selectedDoses[dose.key] = !isSelected;
            });
          },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isExpired
              ? Colors.red.withOpacity(0.05)
              : (isSelected
                  ? AppColors.primaryTeal.withOpacity(0.06)
                  : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isExpired
                ? Colors.red.withOpacity(0.3)
                : (isSelected
                    ? AppColors.primaryTeal.withOpacity(0.3)
                    : Colors.grey.shade200),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isExpired
                    ? Colors.grey.shade300
                    : (isSelected ? AppColors.primaryTeal : Colors.transparent),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isExpired
                      ? Colors.grey.shade400
                      : (isSelected
                          ? AppColors.primaryTeal
                          : Colors.grey.shade400),
                  width: 2,
                ),
              ),
              child: isSelected && !isExpired
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : (isExpired ? const Icon(Icons.block_rounded, size: 14, color: Colors.grey) : null),
            ),

            const SizedBox(width: 14),

            // Medicine icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isExpired 
                    ? Colors.red.withOpacity(0.1)
                    : (isSelected
                        ? AppColors.primaryTeal.withOpacity(0.1)
                        : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isExpired ? Icons.warning_rounded : Icons.medication_rounded,
                size: 20,
                color: isExpired 
                    ? Colors.red 
                    : (isSelected ? AppColors.primaryTeal : AppColors.grayText),
              ),
            ),

            const SizedBox(width: 12),

            // Medicine info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dose.medicine.medicineName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isExpired ? Colors.red.shade800 : AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${dose.displayDate} at ${dose.displayTime}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isExpired ? Colors.red.shade400 : AppColors.grayText,
                        ),
                      ),
                      if (isExpired) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'EXPIRED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Status indicator
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Container(
                      key: const ValueKey('taken'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Taken',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade700,
                        ),
                      ),
                    )
                  : Container(
                      key: const ValueKey('missed'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Missed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
