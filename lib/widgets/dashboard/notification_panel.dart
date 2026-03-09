import 'package:flutter/material.dart';
import '../../models/user_medicine_model.dart';
import '../../theme/app_colors.dart';

class NotificationPanel extends StatelessWidget {
  final int totalCount;
  final int expiredCount;
  final int expiringSoonCount;
  final List<UserMedicine> lowStockMedicines;
  final List<UserMedicine> expiringSoonMedicines;
  final VoidCallback onGoToCabinet;
  final Function(UserMedicine, String)
  onDismiss; // type: 'expired_all', 'soon', 'stock'
  final VoidCallback onClearAll;

  const NotificationPanel({
    super.key,
    required this.totalCount,
    required this.expiredCount,
    required this.expiringSoonCount,
    required this.lowStockMedicines,
    required this.expiringSoonMedicines,
    required this.onGoToCabinet,
    required this.onDismiss,
    required this.onClearAll,
  });

  static void show({
    required BuildContext context,
    required int totalCount,
    required int expiredCount,
    required int expiringSoonCount,
    required List<UserMedicine> lowStockMedicines,
    required List<UserMedicine> expiringSoonMedicines,
    required VoidCallback onGoToCabinet,
    required Function(UserMedicine, String) onDismiss,
    required VoidCallback onClearAll,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NotificationPanel(
        totalCount: totalCount,
        expiredCount: expiredCount,
        expiringSoonCount: expiringSoonCount,
        lowStockMedicines: lowStockMedicines,
        expiringSoonMedicines: expiringSoonMedicines,
        onGoToCabinet: onGoToCabinet,
        onDismiss: onDismiss,
        onClearAll: onClearAll,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: AppColors.primaryTeal,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
                const Spacer(),
                if (totalCount > 0)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onClearAll();
                    },
                    child: const Text(
                      'Clear All',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Notification list
          Flexible(
            child: totalCount == 0
                ? _buildEmptyNotifications()
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      ..._buildExpiredSection(context),
                      ..._buildLowStockSection(context),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyNotifications() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 64,
            color: AppColors.accentGreen.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'All clear!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No notifications at this time',
            style: TextStyle(fontSize: 14, color: AppColors.grayText),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExpiredSection(BuildContext context) {
    if (expiredCount == 0 && expiringSoonCount == 0) return [];

    return [
      _buildSectionHeader(
        'Expiry Alerts',
        Icons.warning_amber_rounded,
        Colors.red,
      ),
      if (expiredCount > 0)
        _buildNotificationItem(
          icon: Icons.error_rounded,
          iconColor: Colors.red,
          title: '$expiredCount Expired Medicine${expiredCount > 1 ? 's' : ''}',
          subtitle: 'Remove or replace these medicines',
          onTap: () {
            onDismiss(
              UserMedicine(drugId: '', medicineName: ''),
              'expired_all',
            );
            onGoToCabinet();
          },
          onDismiss: () => onDismiss(
            UserMedicine(drugId: '', medicineName: ''),
            'expired_all',
          ),
        ),
      if (expiringSoonCount > 0)
        ...expiringSoonMedicines.map(
          (med) => _buildNotificationItem(
            icon: Icons.schedule_rounded,
            iconColor: Colors.orange,
            title: med.medicineName,
            subtitle: 'Expires in ${med.daysUntilExpiry} days',
            onTap: () {
              onDismiss(med, 'soon');
              onGoToCabinet();
            },
            onDismiss: () => onDismiss(med, 'soon'),
          ),
        ),
    ];
  }

  List<Widget> _buildLowStockSection(BuildContext context) {
    if (lowStockMedicines.isEmpty) return [];

    return [
      _buildSectionHeader(
        'Low Stock',
        Icons.inventory_2_rounded,
        Colors.orange,
      ),
      ...lowStockMedicines.map(
        (med) => _buildNotificationItem(
          icon: Icons.medication_rounded,
          iconColor: Colors.orange,
          title: med.medicineName,
          subtitle:
              'Only ${med.tabletCount} tablet${med.tabletCount == 1 ? '' : 's'} left',
          onTap: () {
            onDismiss(med, 'stock');
            onGoToCabinet();
          },
          onDismiss: () => onDismiss(med, 'stock'),
        ),
      ),
    ];
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required VoidCallback onDismiss,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: AppColors.grayText),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.grayText,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
