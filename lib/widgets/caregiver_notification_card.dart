import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Widget for displaying a caregiver alert notification card.
class CaregiverNotificationCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback? onEmailPatient;
  final VoidCallback? onMarkRead;

  const CaregiverNotificationCard({
    super.key,
    required this.alert,
    this.onEmailPatient,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final type = alert['type'] as String? ?? '';
    final isSevere = type == 'severe_override';
    final isMissedDose = type == 'missed_dose';
    final isLinked = type == 'caregiver_linked';
    final isRead = alert['read'] as bool? ?? false;

    final timestamp = alert['timestamp'] as Timestamp?;
    final timeAgo = timestamp != null ? _timeAgo(timestamp.toDate()) : '';

    final bgColor = isSevere
        ? Colors.red.shade900.withValues(alpha: 0.3)
        : (isMissedDose
              ? Colors.amber.shade900.withValues(alpha: 0.2)
              : AppColors.cardBg);

    final borderColor = isSevere
        ? Colors.red.withValues(alpha: 0.4)
        : (isMissedDose
              ? Colors.amber.withValues(alpha: 0.3)
              : AppColors.borderColor);

    final iconData = isSevere
        ? Icons.warning_amber_rounded
        : (isMissedDose
              ? Icons.timer_off_rounded
              : (isLinked ? Icons.link_rounded : Icons.notifications_rounded));

    final iconColor = isSevere
        ? Colors.red
        : (isMissedDose ? Colors.amber : AppColors.primaryTeal);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isSevere ? 2 : 1),
        boxShadow: isSevere
            ? [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert['title'] as String? ?? 'Alert',
                        style: TextStyle(
                          color: isSevere
                              ? Colors.red.shade200
                              : AppColors.lightText,
                          fontWeight: FontWeight.w700,
                          fontSize: isSevere ? 15 : 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert['message'] as String? ?? '',
                        style: TextStyle(
                          color: isSevere
                              ? Colors.red.shade100
                              : AppColors.mutedText,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isSevere ? Colors.red : AppColors.primaryTeal,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: AppColors.mutedText,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  timeAgo,
                  style: TextStyle(color: AppColors.mutedText, fontSize: 11),
                ),
                const Spacer(),
                if (isSevere && onEmailPatient != null)
                  SizedBox(
                    height: 30,
                    child: ElevatedButton.icon(
                      onPressed: onEmailPatient,
                      icon: const Icon(Icons.email_rounded, size: 14),
                      label: const Text(
                        'Email Patient',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                if (!isRead && onMarkRead != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 30,
                    child: OutlinedButton(
                      onPressed: onMarkRead,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.mutedText.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Mark Read',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
