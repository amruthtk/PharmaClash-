import 'package:flutter/material.dart';
import '../models/user_medicine_model.dart';
import '../theme/app_colors.dart';

/// Bottom sheet for confirming dose intake
/// Shows quantity selector and updates pill count
class TakeDoseSheet extends StatefulWidget {
  final UserMedicine medicine;
  final Function(int quantity, String? scheduledTime) onConfirm;
  final List<String> loggedTimesToday; // Times already logged today

  const TakeDoseSheet({
    super.key,
    required this.medicine,
    required this.onConfirm,
    this.loggedTimesToday = const [],
  });

  /// Show the take dose bottom sheet
  static Future<void> show(
    BuildContext context, {
    required UserMedicine medicine,
    required Function(int quantity, String? scheduledTime) onConfirm,
    List<String> loggedTimesToday = const [],
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TakeDoseSheet(
        medicine: medicine,
        onConfirm: onConfirm,
        loggedTimesToday: loggedTimesToday,
      ),
    );
  }

  @override
  State<TakeDoseSheet> createState() => _TakeDoseSheetState();
}

class _TakeDoseSheetState extends State<TakeDoseSheet> {
  int _selectedQuantity = 1;
  String? _selectedTime;
  bool _dietaryConfirmed = false; // For pre-dose dietary confirmation

  @override
  void initState() {
    super.initState();
    // Pre-select the next available (not logged) scheduled time
    if (widget.medicine.scheduleTimes.isNotEmpty) {
      _selectedTime = _getNextAvailableTime();
    }
  }

  /// Check if a time slot has already been logged today
  bool _isTimeLogged(String time) {
    return widget.loggedTimesToday.contains(time);
  }

  /// Get the next scheduled time that hasn't been logged yet
  String? _getNextAvailableTime() {
    if (widget.medicine.scheduleTimes.isEmpty) return null;

    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    // First, try to find an upcoming time that's not logged
    for (final time in widget.medicine.scheduleTimes) {
      if (_isTimeLogged(time)) continue; // Skip logged times

      final parts = time.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final timeMinutes = hour * 60 + minute;
        if (timeMinutes >= nowMinutes - 30) {
          return time;
        }
      }
    }

    // If all upcoming times are logged, find any unlogged time
    for (final time in widget.medicine.scheduleTimes) {
      if (!_isTimeLogged(time)) {
        return time;
      }
    }

    // All times are logged - return null (all done for today)
    return null;
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  int get _remainingAfterDose =>
      (widget.medicine.tabletCount - _selectedQuantity).clamp(0, 9999);

  bool get _isLowStockAfter => _remainingAfterDose <= 5;

  /// Check if all doses for today have been taken
  bool get _allDosesLogged {
    if (widget.medicine.scheduleTimes.isEmpty) return false;
    return widget.medicine.scheduleTimes.every((t) => _isTimeLogged(t));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: AppColors.accentGreen,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Take Dose',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText,
                      ),
                    ),
                    Text(
                      widget.medicine.medicineName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // All doses completed message
          if (_allDosesLogged) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.accentGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.accentGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All scheduled doses for today have been taken! ✓',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Schedule time selector (if times are configured)
          if (widget.medicine.scheduleTimes.isNotEmpty) ...[
            const Text(
              'Which dose?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: widget.medicine.scheduleTimes.map((time) {
                final isSelected = _selectedTime == time;
                final isLogged = _isTimeLogged(time);
                return GestureDetector(
                  onTap: isLogged
                      ? null
                      : () => setState(() => _selectedTime = time),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isLogged
                          ? Colors.grey.shade100
                          : isSelected
                          ? AppColors.primaryTeal.withValues(alpha: 0.15)
                          : AppColors.inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLogged
                            ? Colors.grey.shade300
                            : isSelected
                            ? AppColors.primaryTeal
                            : AppColors.lightBorderColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLogged) ...[
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppColors.accentGreen,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _formatTime(time),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isLogged
                                ? Colors.grey.shade500
                                : isSelected
                                ? AppColors.primaryTeal
                                : AppColors.darkText,
                            decoration: isLogged
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Quantity selector
          const Text(
            'How many tablets?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [1, 2, 3].map((qty) {
              final isSelected = _selectedQuantity == qty;
              final isDisabled = qty > widget.medicine.tabletCount;
              return Expanded(
                child: GestureDetector(
                  onTap: isDisabled
                      ? null
                      : () => setState(() => _selectedQuantity = qty),
                  child: Container(
                    margin: EdgeInsets.only(right: qty < 3 ? 12 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isDisabled
                          ? Colors.grey.shade100
                          : isSelected
                          ? AppColors.accentGreen.withValues(alpha: 0.15)
                          : AppColors.inputBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDisabled
                            ? Colors.grey.shade300
                            : isSelected
                            ? AppColors.accentGreen
                            : AppColors.lightBorderColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$qty',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: isDisabled
                                ? Colors.grey.shade400
                                : isSelected
                                ? AppColors.accentGreen
                                : AppColors.darkText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          qty == 1 ? 'tablet' : 'tablets',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDisabled
                                ? Colors.grey.shade400
                                : isSelected
                                ? AppColors.accentGreen
                                : AppColors.grayText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Stock info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isLowStockAfter
                  ? Colors.orange.shade50
                  : AppColors.inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isLowStockAfter
                    ? Colors.orange.shade200
                    : AppColors.lightBorderColor,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isLowStockAfter
                      ? Icons.warning_amber_rounded
                      : Icons.inventory_2_outlined,
                  size: 20,
                  color: _isLowStockAfter
                      ? Colors.orange.shade700
                      : AppColors.grayText,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: _isLowStockAfter
                            ? Colors.orange.shade800
                            : AppColors.darkText,
                      ),
                      children: [
                        const TextSpan(text: 'Current stock: '),
                        TextSpan(
                          text: '${widget.medicine.tabletCount}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: ' → After: '),
                        TextSpan(
                          text: '$_remainingAfterDose',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _isLowStockAfter
                                ? Colors.orange.shade800
                                : AppColors.darkText,
                          ),
                        ),
                        if (_isLowStockAfter)
                          TextSpan(
                            text: ' (Low stock!)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Dietary Warnings Confirmation (US-15)
          if (widget.medicine.foodWarnings.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Dietary Guidelines',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...widget.medicine.foodWarnings.map(
                    (warning) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: Colors.orange.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              warning,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () =>
                        setState(() => _dietaryConfirmed = !_dietaryConfirmed),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _dietaryConfirmed,
                            onChanged: (v) =>
                                setState(() => _dietaryConfirmed = v ?? false),
                            activeColor: AppColors.accentGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'I confirm I have followed these dietary guidelines',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canConfirmDose
                  ? () {
                      Navigator.pop(context);
                      widget.onConfirm(_selectedQuantity, _selectedTime);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_confirmButtonIcon, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _confirmButtonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Check if confirm can be pressed
  bool get _canConfirmDose {
    // Can't confirm if out of stock
    if (widget.medicine.tabletCount <= 0) return false;
    // Can't confirm if all scheduled doses are already logged
    if (_allDosesLogged) return false;
    // Can't confirm if a scheduled time is required but selected time is logged
    if (widget.medicine.scheduleTimes.isNotEmpty &&
        _selectedTime != null &&
        _isTimeLogged(_selectedTime!)) {
      return false;
    }
    // Can't confirm if dietary warnings exist but not confirmed (US-15)
    if (widget.medicine.foodWarnings.isNotEmpty && !_dietaryConfirmed) {
      return false;
    }
    return true;
  }

  /// Get appropriate button text
  String get _confirmButtonText {
    if (widget.medicine.tabletCount <= 0) return 'Out of Stock';
    if (_allDosesLogged) return 'All Doses Taken ✓';
    return 'Confirm Dose';
  }

  /// Get appropriate button icon
  IconData get _confirmButtonIcon {
    if (_allDosesLogged) return Icons.check_circle_rounded;
    return Icons.check_circle_rounded;
  }
}
