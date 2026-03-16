import 'package:flutter/material.dart';
import '../models/user_medicine_model.dart';
import '../theme/app_colors.dart';
import 'new_strip_form.dart'; // To reuse QuantitySelector

class MedicineEditSheet extends StatefulWidget {
  final UserMedicine medicine;
  final Function(UserMedicine updatedMedicine) onSave;

  const MedicineEditSheet({
    super.key,
    required this.medicine,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required UserMedicine medicine,
    required Function(UserMedicine updatedMedicine) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          MedicineEditSheet(medicine: medicine, onSave: onSave),
    );
  }

  @override
  State<MedicineEditSheet> createState() => _MedicineEditSheetState();
}

class _MedicineEditSheetState extends State<MedicineEditSheet> {
  late int _tabletCount;
  late int _frequency;
  late List<TimeOfDay> _times;

  @override
  void initState() {
    super.initState();
    _tabletCount = widget.medicine.tabletCount;
    _frequency = widget.medicine.dosesPerDay;

    // Parse schedule strings into TimeOfDay
    _times = widget.medicine.scheduleTimes.map((t) {
      final parts = t.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }).toList();

    // Safety check if list is empty but frequency is set
    if (_times.isEmpty && _frequency > 0) {
      _times = [const TimeOfDay(hour: 9, minute: 0)];
      _frequency = 1;
    }
  }

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
                    Icons.edit_calendar_rounded,
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
                        'Edit Medicine Detail',
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
            const SizedBox(height: 28),

            // US-14: Manual Inventory Correction
            const Text(
              'CURRENT STOCK LEVEL',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryTeal,
                letterSpacing: 1.1,
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
                    'Manual Edit',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.grayText,
                    ),
                  ),
                  QuantitySelector(
                    initialValue: _tabletCount,
                    onChanged: (val) => setState(() => _tabletCount = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // US-13: Scheduler Editing
            const Text(
              'DOSAGE SCHEDULE',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryTeal,
                letterSpacing: 1.1,
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

            const Text(
              'REVISIT TIMES',
              style: TextStyle(
                fontSize: 12,
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
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final scheduleStrs = _times.map((t) {
                    final h = t.hour.toString().padLeft(2, '0');
                    final m = t.minute.toString().padLeft(2, '0');
                    return '$h:$m';
                  }).toList();

                  final updatedMed = widget.medicine.copyWith(
                    tabletCount: _tabletCount,
                    dosesPerDay: _frequency,
                    scheduleTimes: scheduleStrs,
                  );

                  widget.onSave(updatedMed);
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
                  'Update Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
