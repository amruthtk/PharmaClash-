import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'new_strip_form.dart';

class MedicineSetupSheet extends StatefulWidget {
  final String medicineName;
  final Function(
    int quantity,
    List<String> scheduleTimes,
    DateTime? expiryDate,
    int doseIntervalDays,
  )
  onConfirm;

  const MedicineSetupSheet({
    super.key,
    required this.medicineName,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required String medicineName,
    required Function(
      int quantity,
      List<String> scheduleTimes,
      DateTime? expiryDate,
      int doseIntervalDays,
    )
    onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          MedicineSetupSheet(medicineName: medicineName, onConfirm: onConfirm),
    );
  }

  @override
  State<MedicineSetupSheet> createState() => _MedicineSetupSheetState();
}

class _MedicineSetupSheetState extends State<MedicineSetupSheet> {
  int _quantity = 10;
  int _frequency = 1; // times per day
  int _intervalDays = 0; // 0 = daily, 1 = alternate day, 2 = every 3 days
  List<TimeOfDay> _times = [const TimeOfDay(hour: 9, minute: 0)];
  DateTime? _expiryDate;

  void _updateFrequency(int freq) {
    setState(() {
      _frequency = freq;
      if (_times.length < freq) {
        for (int i = _times.length; i < freq; i++) {
          if (i == 1) _times.add(const TimeOfDay(hour: 14, minute: 0));
          if (i == 2) _times.add(const TimeOfDay(hour: 20, minute: 0));
        }
      } else if (_times.length > freq) {
        _times = _times.sublist(0, freq);
      }
    });
  }

  Future<void> _selectTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryTeal,
              onPrimary: Colors.white,
              onSurface: AppColors.darkText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _times[index] = picked;
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  Future<void> _selectExpiryDate() async {
    final now = DateTime.now();
    final initialDate = _expiryDate ?? DateTime(now.year + 2, now.month, 1);

    int tempMonth = initialDate.month;
    int tempYear = initialDate.year;

    final years = List.generate(10, (i) => now.year + i);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.grayText,
                            ),
                          ),
                        ),
                        const Text(
                          'Expiry Date',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _expiryDate = DateTime(tempYear, tempMonth, 1);
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scroll wheels
                  SizedBox(
                    height: 220,
                    child: Row(
                      children: [
                        // Month wheel
                        Expanded(
                          flex: 3,
                          child: ListWheelScrollView.useDelegate(
                            controller: FixedExtentScrollController(
                              initialItem: tempMonth - 1,
                            ),
                            itemExtent: 44,
                            physics: const FixedExtentScrollPhysics(),
                            diameterRatio: 1.5,
                            onSelectedItemChanged: (index) {
                              setModalState(() => tempMonth = index + 1);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 12,
                              builder: (context, index) {
                                final isSelected = index == tempMonth - 1;
                                return Center(
                                  child: Text(
                                    _monthNames[index],
                                    style: TextStyle(
                                      fontSize: isSelected ? 20 : 16,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? AppColors.darkText
                                          : AppColors.grayText,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Divider line
                        Container(
                          width: 1,
                          height: 120,
                          color: Colors.grey.shade200,
                        ),

                        // Year wheel
                        Expanded(
                          flex: 2,
                          child: ListWheelScrollView.useDelegate(
                            controller: FixedExtentScrollController(
                              initialItem: years.indexOf(tempYear).clamp(0, years.length - 1),
                            ),
                            itemExtent: 44,
                            physics: const FixedExtentScrollPhysics(),
                            diameterRatio: 1.5,
                            onSelectedItemChanged: (index) {
                              setModalState(() => tempYear = years[index]);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: years.length,
                              builder: (context, index) {
                                final isSelected = years[index] == tempYear;
                                return Center(
                                  child: Text(
                                    years[index].toString(),
                                    style: TextStyle(
                                      fontSize: isSelected ? 20 : 16,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? AppColors.darkText
                                          : AppColors.grayText,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Selection highlight
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primaryTeal,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_monthNames[tempMonth - 1]} $tempYear',
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
          },
        );
      },
    );
  }

  String _formatExpiryDate(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.year}';
  }

  String _getIntervalHint() {
    switch (_intervalDays) {
      case 0:
        return 'Takes medicine every day';
      case 1:
        return 'Takes medicine every other day';
      case 2:
        return 'Takes medicine once every 3 days';
      default:
        return 'Takes medicine every ${_intervalDays + 1} days';
    }
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.settings_suggest_rounded,
                    color: AppColors.primaryTeal,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Medicine Setup',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkText,
                        ),
                      ),
                      Text(
                        widget.medicineName,
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
            const SizedBox(height: 28),

            // Quantity Section
            const Text(
              'How much medicine to inventory?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.lightBorderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Tablets',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.grayText,
                    ),
                  ),
                  QuantitySelector(
                    initialValue: _quantity,
                    onChanged: (val) => setState(() => _quantity = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Dosing Pattern Section
            const Text(
              'Dosing Pattern',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildIntervalChip('Daily', 0),
                const SizedBox(width: 8),
                _buildIntervalChip('Alt. Day', 1),
                const SizedBox(width: 8),
                _buildIntervalChip('Every 3 Days', 2),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _getIntervalHint(),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.grayText,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),

            // Frequency Section
            const Text(
              'How many times a day?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [1, 2, 3].map((f) {
                final isSelected = _frequency == f;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _updateFrequency(f),
                    child: Container(
                      margin: EdgeInsets.only(right: f < 3 ? 12 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryTeal.withValues(alpha: 0.1)
                            : AppColors.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryTeal
                              : AppColors.lightBorderColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${f}x Day',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.primaryTeal
                                : AppColors.darkText,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Time Slots
            const Text(
              'Schedule Times',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.grayText,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(_frequency, (index) {
                return GestureDetector(
                  onTap: () => _selectTime(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primaryTeal.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryTeal.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_filled_rounded,
                          size: 16,
                          color: AppColors.primaryTeal,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(_times[index]),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Expiry Date Section
            const Text(
              'Expiry Date',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _selectExpiryDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _expiryDate != null
                      ? AppColors.primaryTeal.withValues(alpha: 0.06)
                      : AppColors.inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _expiryDate != null
                        ? AppColors.primaryTeal.withValues(alpha: 0.4)
                        : AppColors.lightBorderColor,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _expiryDate != null
                            ? AppColors.primaryTeal.withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.event_rounded,
                        size: 20,
                        color: _expiryDate != null
                            ? AppColors.primaryTeal
                            : AppColors.grayText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _expiryDate != null
                                ? _formatExpiryDate(_expiryDate!)
                                : 'Tap to set expiry date',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _expiryDate != null
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _expiryDate != null
                                  ? AppColors.darkText
                                  : AppColors.grayText,
                            ),
                          ),
                          if (_expiryDate == null)
                            const Text(
                              'Required · Tap to set',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.redAccent,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: _expiryDate != null
                          ? AppColors.primaryTeal
                          : AppColors.grayText,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _expiryDate == null
                    ? null
                    : () {
                        final scheduleStrs = _times.map((t) {
                          final h = t.hour.toString().padLeft(2, '0');
                          final m = t.minute.toString().padLeft(2, '0');
                          return '$h:$m';
                        }).toList();
                        widget.onConfirm(
                          _quantity,
                          scheduleStrs,
                          _expiryDate,
                          _intervalDays,
                        );
                        Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Add to Cabinet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalChip(String label, int value) {
    final isSelected = _intervalDays == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _intervalDays = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryTeal.withValues(alpha: 0.1)
                : AppColors.inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryTeal
                  : AppColors.lightBorderColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.primaryTeal : AppColors.darkText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
