import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// A single row in the "Recent Activity" feed on the admin dashboard.
class AdminActivityTile extends StatelessWidget {
  final Map<String, dynamic> log;

  const AdminActivityTile({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final action = log['action'] as String? ?? 'Unknown action';
    final details = log['details'] as String?;
    final timestamp = log['timestamp'] as Timestamp?;
    final timeAgo = timestamp != null ? _formatTimeAgo(timestamp.toDate()) : '';

    final iconData = _iconForAction(action);
    final iconColor = _colorForAction(action);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconData, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightText,
                  ),
                ),
                if (details != null && details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    details,
                    style: TextStyle(fontSize: 11, color: AppColors.mutedText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (timeAgo.isNotEmpty)
            Text(
              timeAgo,
              style: TextStyle(fontSize: 10, color: AppColors.mutedText),
            ),
        ],
      ),
    );
  }

  IconData _iconForAction(String action) {
    final a = action.toLowerCase();
    if (a.contains('add')) return Icons.add_circle_outline;
    if (a.contains('edit') || a.contains('update')) return Icons.edit_outlined;
    if (a.contains('delete') || a.contains('remove')) {
      return Icons.delete_outline;
    }
    if (a.contains('rule') || a.contains('interaction')) {
      return Icons.compare_arrows;
    }
    if (a.contains('import')) return Icons.cloud_upload_outlined;
    if (a.contains('ai') || a.contains('learned')) return Icons.auto_awesome;
    return Icons.history;
  }

  Color _colorForAction(String action) {
    final a = action.toLowerCase();
    if (a.contains('delete') || a.contains('remove')) {
      return Colors.red.shade400;
    }
    if (a.contains('add')) return AppColors.primaryTeal;
    if (a.contains('edit') || a.contains('update')) return Colors.amber;
    if (a.contains('rule') || a.contains('interaction')) return Colors.blue;
    if (a.contains('ai') || a.contains('learned')) return AppColors.primaryTeal;
    return AppColors.mutedText;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}';
  }
}
