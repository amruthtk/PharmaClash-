import 'package:flutter/material.dart';
import '../../models/user_medicine_model.dart';
import '../../theme/app_colors.dart';

class MedicineScheduleCard extends StatelessWidget {
  final UserMedicine medicine;
  final String time;
  final bool isLogged;
  final bool isPast;
  final String userId;
  final VoidCallback onTap;

  const MedicineScheduleCard({
    super.key,
    required this.medicine,
    required this.time,
    required this.isLogged,
    required this.isPast,
    required this.userId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isLogged
        ? Colors.green
        : (medicine.isExpired
            ? Colors.red
            : (isPast ? Colors.orange : AppColors.primaryTeal));
    final statusIcon = isLogged
        ? Icons.check_circle_rounded
        : (medicine.isExpired
            ? Icons.warning_rounded
            : (isPast ? Icons.access_time_rounded : Icons.radio_button_unchecked));
    final statusText = isLogged
        ? 'Taken'
        : (medicine.isExpired ? 'Expired' : (isPast ? 'Overdue' : 'Upcoming'));

    // Locked logic: Dose is more than 1 hour in the future
    bool isLocked = false;
    if (!isLogged && !isPast && !medicine.isExpired) {
      try {
        final now = DateTime.now();
        final cleanTime = time.replaceAll(RegExp(r'[^0-9:]'), '');
        final parts = cleanTime.split(':');
        if (parts.length >= 2) {
          int hour = int.parse(parts[0]);
          int minute = int.parse(parts[1]);

          if (time.toUpperCase().contains('PM') && hour < 12) hour += 12;
          if (time.toUpperCase().contains('AM') && hour == 12) hour = 0;

          final scheduledDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            hour,
            minute,
          );
          isLocked = scheduledDateTime.difference(now).inMinutes >= 60;
        }
      } catch (e) {
        debugPrint('Error parsing schedule time "$time": $e');
      }
    }

    final displayColor = isLocked ? Colors.grey : statusColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLogged
                ? Colors.green.withValues(alpha: 0.3)
                : (medicine.isExpired
                    ? Colors.red.withValues(alpha: 0.3)
                    : (isLocked
                        ? Colors.grey.withValues(alpha: 0.2)
                        : AppColors.lightBorderColor)),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: displayColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isLocked
                    ? Icons.lock_rounded
                    : (medicine.isExpired
                        ? Icons.warning_rounded
                        : (medicine.tabletCount <= 0
                            ? Icons.error_outline_rounded
                            : Icons.medication_rounded)),
                color: medicine.isExpired && !isLogged
                    ? Colors.red
                    : (medicine.tabletCount <= 0 && !isLogged && !isLocked
                        ? Colors.orange
                        : displayColor),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.medicineName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isLogged || isLocked
                          ? AppColors.grayText
                          : AppColors.darkText,
                      decoration: isLogged ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isLocked ? Icons.lock_clock_rounded : statusIcon,
                        size: 14,
                        color: displayColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isLocked
                              ? 'Locked until later'
                              : (medicine.isExpired && !isLogged
                                  ? 'Expired'
                                  : (medicine.tabletCount <= 0 && !isLogged
                                      ? 'Out of Stock'
                                      : (isLogged
                                          ? 'Taken'
                                          : (medicine.isExpiringSoon
                                              ? 'Expiring Soon'
                                              : (medicine.isLowStock
                                                  ? 'Low Stock (${medicine.tabletCount} left)'
                                                  : statusText))))),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: medicine.isExpired && !isLogged
                                ? Colors.red
                                : (medicine.tabletCount <= 0 &&
                                        !isLogged &&
                                        !isLocked
                                    ? Colors.orange
                                    : (medicine.isExpiringSoon || medicine.isLowStock
                                        ? Colors.orange.shade700
                                        : displayColor)),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (!isLogged && !isLocked && (medicine.isExpiringSoon || medicine.isLowStock)) 
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.priority_high_rounded,
                            size: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      if (medicine.tabletCount <= 5) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${medicine.tabletCount} left',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (!isLogged)
              Icon(
                isLocked
                    ? Icons.lock_outline_rounded
                    : (medicine.tabletCount <= 0
                          ? Icons.warning_amber_rounded
                          : Icons.chevron_right_rounded),
                color: isLocked
                    ? Colors.grey
                    : (medicine.tabletCount <= 0
                          ? Colors.orange
                          : AppColors.grayText),
              ),
          ],
        ),
      ),
    );
  }
}
