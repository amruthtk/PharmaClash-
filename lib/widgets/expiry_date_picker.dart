import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Senior-friendly Month/Year date picker for setting medicine expiry dates
class ExpiryDatePicker extends StatefulWidget {
  final DateTime? initialDate;
  final ValueChanged<DateTime> onDateSelected;
  final bool allowPastDates;

  const ExpiryDatePicker({
    super.key,
    this.initialDate,
    required this.onDateSelected,
    this.allowPastDates = false,
  });

  @override
  State<ExpiryDatePicker> createState() => _ExpiryDatePickerState();
}

class _ExpiryDatePickerState extends State<ExpiryDatePicker> {
  late int _selectedMonth;
  late int _selectedYear;

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final initial = widget.initialDate ?? DateTime(now.year, now.month + 1);
    _selectedMonth = initial.month;
    _selectedYear = initial.year;
  }

  List<int> get _availableYears {
    final now = DateTime.now();
    final startYear = widget.allowPastDates ? now.year - 2 : now.year;
    return List.generate(10, (index) => startYear + index);
  }

  void _notifyChange() {
    // Set to 1st of the month
    widget.onDateSelected(DateTime(_selectedYear, _selectedMonth, 1));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.primaryTeal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'When does this expire?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    Text(
                      'Check the expiry date on your medicine strip',
                      style: TextStyle(fontSize: 12, color: AppColors.grayText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Month and Year dropdowns
          Row(
            children: [
              // Month dropdown
              Expanded(
                flex: 3,
                child: _buildDropdown(
                  value: _selectedMonth,
                  items: List.generate(12, (index) => index + 1),
                  onChanged: (value) {
                    setState(() => _selectedMonth = value!);
                    _notifyChange();
                  },
                  itemBuilder: (month) => _months[month - 1],
                  label: 'Month',
                ),
              ),
              const SizedBox(width: 16),
              // Year dropdown
              Expanded(
                flex: 2,
                child: _buildDropdown(
                  value: _selectedYear,
                  items: _availableYears,
                  onChanged: (value) {
                    setState(() => _selectedYear = value!);
                    _notifyChange();
                  },
                  itemBuilder: (year) => year.toString(),
                  label: 'Year',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Selected date display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryTeal.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primaryTeal,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Expires: ${_months[_selectedMonth - 1]} $_selectedYear',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryTeal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String Function(T) itemBuilder,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.grayText,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.inputBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.lightBorderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.grayText,
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(
                        itemBuilder(item),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact version of date picker for inline use
class ExpiryDatePickerCompact extends StatefulWidget {
  final DateTime? initialDate;
  final ValueChanged<DateTime> onDateSelected;

  const ExpiryDatePickerCompact({
    super.key,
    this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<ExpiryDatePickerCompact> createState() =>
      _ExpiryDatePickerCompactState();
}

class _ExpiryDatePickerCompactState extends State<ExpiryDatePickerCompact> {
  late int _selectedMonth;
  late int _selectedYear;

  static const List<String> _monthsShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final initial = widget.initialDate ?? DateTime(now.year, now.month + 1);
    _selectedMonth = initial.month;
    _selectedYear = initial.year;
  }

  List<int> get _availableYears {
    final now = DateTime.now();
    return List.generate(10, (index) => now.year + index);
  }

  void _notifyChange() {
    widget.onDateSelected(DateTime(_selectedYear, _selectedMonth, 1));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Month selector
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightBorderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedMonth,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkText,
                ),
                items: List.generate(12, (index) {
                  final month = index + 1;
                  return DropdownMenuItem(
                    value: month,
                    child: Text(_monthsShort[index]),
                  );
                }),
                onChanged: (value) {
                  setState(() => _selectedMonth = value!);
                  _notifyChange();
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Year selector
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightBorderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkText,
                ),
                items: _availableYears
                    .map(
                      (year) => DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedYear = value!);
                  _notifyChange();
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
