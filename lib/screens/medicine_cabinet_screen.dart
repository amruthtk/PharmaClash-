import 'package:flutter/material.dart';
import '../models/user_medicine_model.dart';
import '../services/firebase_service.dart';
import '../services/medicine_inventory_service.dart';
import '../services/expiry_alert_service.dart';
import '../theme/app_colors.dart';
import '../widgets/expiry_alert_modal.dart';
import '../widgets/new_strip_form.dart';
import '../widgets/take_dose_sheet.dart';

/// Filter options for medicine cabinet
enum CabinetFilter { all, expiringSoon, expired }

/// Medicine Cabinet Screen - Shows all user's medicines with expiry tracking
class MedicineCabinetScreen extends StatefulWidget {
  const MedicineCabinetScreen({super.key});

  @override
  State<MedicineCabinetScreen> createState() => _MedicineCabinetScreenState();
}

class _MedicineCabinetScreenState extends State<MedicineCabinetScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final MedicineInventoryService _inventoryService = MedicineInventoryService();
  final ExpiryAlertService _expiryService = ExpiryAlertService();

  List<UserMedicine> _medicines = [];
  bool _isLoading = true;
  CabinetFilter _currentFilter = CabinetFilter.all;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    setState(() => _isLoading = true);
    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        final medicines = await _inventoryService.getUserMedicines(user.uid);
        if (mounted) {
          setState(() {
            _medicines = medicines;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading medicines: $e', isError: true);
      }
    }
  }

  List<UserMedicine> get _filteredMedicines {
    switch (_currentFilter) {
      case CabinetFilter.expired:
        return _medicines.where((m) => m.isExpired).toList();
      case CabinetFilter.expiringSoon:
        return _medicines.where((m) => m.isExpiringSoon).toList();
      case CabinetFilter.all:
        return _medicines;
    }
  }

  int get _expiredCount => _medicines.where((m) => m.isExpired).length;
  int get _expiringSoonCount =>
      _medicines.where((m) => m.isExpiringSoon).length;

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : AppColors.primaryTeal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _removeMedicine(UserMedicine medicine) async {
    final user = _firebaseService.currentUser;
    if (user != null && medicine.id != null) {
      try {
        await _inventoryService.removeMedicine(user.uid, medicine.id!);
        _showSnackBar('${medicine.medicineName} removed from cabinet');
        _loadMedicines();
      } catch (e) {
        _showSnackBar('Failed to remove: $e', isError: true);
      }
    }
  }

  Future<void> _showNewStripForm(UserMedicine medicine) async {
    await NewStripForm.show(
      context,
      medicineName: medicine.medicineName,
      onSubmit: (expiryDate, quantity) async {
        final user = _firebaseService.currentUser;
        if (user != null && medicine.id != null) {
          try {
            await _inventoryService.updateStrip(
              user.uid,
              medicine.id!,
              newExpiryDate: expiryDate,
              addQuantity: quantity,
            );
            _showSnackBar('Strip updated successfully!');
            _loadMedicines();
          } catch (e) {
            _showSnackBar('Failed to update: $e', isError: true);
          }
        }
      },
    );
  }

  void _showExpiryAlert(UserMedicine medicine) {
    ExpiryAlertModal.show(
      context,
      medicine: medicine,
      onRemove: () => _removeMedicine(medicine),
      onNewStrip: () => _showNewStripForm(medicine),
      onDismiss: () async {
        // Mark alert as shown
        final user = _firebaseService.currentUser;
        if (user != null && medicine.id != null) {
          await _expiryService.markAlertShown(user.uid, medicine.id!);
          _loadMedicines();
        }
      },
    );
  }

  /// Show take dose sheet and log dose when confirmed
  Future<void> _takeDose(UserMedicine medicine) async {
    final user = _firebaseService.currentUser;
    if (user == null || medicine.id == null) return;

    // Get today's logged times for this medicine to prevent duplicate logging
    List<String> loggedTimesToday = [];
    try {
      // Use getTodayDoseLogs and filter by medicineId locally
      // (avoids Firestore composite index requirement)
      final allTodayLogs = await _inventoryService.getTodayDoseLogs(user.uid);

      debugPrint('=== DOSE LOG DEBUG ===');
      debugPrint('Medicine ID: ${medicine.id}');
      debugPrint('Total today logs: ${allTodayLogs.length}');

      for (final log in allTodayLogs) {
        debugPrint('Log: $log');
        // Filter to this medicine
        if (log['medicineId'] == medicine.id) {
          final scheduledTime = log['scheduledTime'] as String?;
          debugPrint('Found matching log with scheduledTime: $scheduledTime');
          if (scheduledTime != null) {
            loggedTimesToday.add(scheduledTime);
          }
        }
      }
      debugPrint('Logged times today for this medicine: $loggedTimesToday');
      debugPrint('=== END DEBUG ===');
    } catch (e) {
      // Continue even if fetching logs fails
      debugPrint('Error fetching today logs: $e');
    }

    if (!mounted) return;

    await TakeDoseSheet.show(
      context,
      medicine: medicine,
      loggedTimesToday: loggedTimesToday,
      onConfirm: (quantity, scheduledTime) async {
        try {
          await _inventoryService.logDose(
            uid: user.uid,
            medicineId: medicine.id!,
            medicineName: medicine.medicineName,
            quantity: quantity,
            scheduledTime: scheduledTime,
          );

          final remaining = medicine.tabletCount - quantity;
          _showSnackBar(
            'Took $quantity ${medicine.medicineName}. $remaining remaining.',
          );

          // Show low stock warning if applicable
          if (remaining <= 5 && remaining > 0) {
            _showSnackBar(
              '⚠️ Low stock! Only $remaining tablets left.',
              isError: false,
            );
          }

          _loadMedicines();
        } catch (e) {
          _showSnackBar('Failed to log dose: $e', isError: true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter tabs
        _buildFilterTabs(),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryTeal,
                  ),
                )
              : _filteredMedicines.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadMedicines,
                  color: AppColors.primaryTeal,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredMedicines.length,
                    itemBuilder: (context, index) {
                      return _buildMedicineCard(_filteredMedicines[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildFilterChip(CabinetFilter.all, 'All', _medicines.length),
          const SizedBox(width: 10),
          _buildFilterChip(
            CabinetFilter.expiringSoon,
            'Expiring Soon',
            _expiringSoonCount,
            color: Colors.orange,
          ),
          const SizedBox(width: 10),
          _buildFilterChip(
            CabinetFilter.expired,
            'Expired',
            _expiredCount,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    CabinetFilter filter,
    String label,
    int count, {
    Color? color,
  }) {
    final isSelected = _currentFilter == filter;
    final chipColor = color ?? AppColors.primaryTeal;

    return GestureDetector(
      onTap: () => setState(() => _currentFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : AppColors.lightBorderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? chipColor : AppColors.grayText,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? chipColor : AppColors.grayText,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_currentFilter) {
      case CabinetFilter.expired:
        message = 'No expired medicines';
        icon = Icons.check_circle_outline_rounded;
        break;
      case CabinetFilter.expiringSoon:
        message = 'No medicines expiring soon';
        icon = Icons.timer_off_rounded;
        break;
      case CabinetFilter.all:
        message = 'Your cabinet is empty';
        icon = Icons.inbox_rounded;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: AppColors.grayText),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentFilter == CabinetFilter.all
                ? 'Scan a medicine to add it here'
                : 'Great! Your medicines are safe',
            style: TextStyle(fontSize: 14, color: AppColors.grayText),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(UserMedicine medicine) {
    final alert = _expiryService.createAlert(medicine);

    Color borderColor;
    Color bgColor;

    switch (alert.level) {
      case ExpiryAlertLevel.expired:
        borderColor = Colors.red.shade300;
        bgColor = Colors.red.shade50;
        break;
      case ExpiryAlertLevel.expiringSoon:
        borderColor = Colors.orange.shade300;
        bgColor = Colors.orange.shade50;
        break;
      default:
        borderColor = AppColors.lightBorderColor;
        bgColor = Colors.white;
    }

    return GestureDetector(
      onTap: medicine.isExpired ? () => _showExpiryAlert(medicine) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Medicine icon
                _buildMedicineIcon(medicine),
                const SizedBox(width: 14),

                // Medicine info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine.medicineName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      if (medicine.category != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            medicine.category!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryTeal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Expiry badge
                _buildExpiryBadge(medicine, alert),
              ],
            ),
            const SizedBox(height: 14),

            // Stats row
            Row(
              children: [
                // Expiry date
                _buildStatItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'Expires',
                  value: medicine.formattedExpiryDate,
                  color: medicine.isExpired
                      ? Colors.red
                      : medicine.isExpiringSoon
                      ? Colors.orange
                      : AppColors.grayText,
                ),
                const SizedBox(width: 20),
                // Tablet count
                _buildStatItem(
                  icon: Icons.medication_rounded,
                  label: 'Stock',
                  value: '${medicine.tabletCount} tablets',
                  color: medicine.isLowStock
                      ? Colors.orange
                      : AppColors.grayText,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Action buttons
            Row(
              children: [
                if (!medicine.isExpired) ...[
                  // Take Dose button (only for non-expired medicines)
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.check_circle_rounded,
                      label: 'Take Dose',
                      color: AppColors.accentGreen,
                      onTap: () => _takeDose(medicine),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.inventory_2_rounded,
                    label: 'New Strip',
                    color: AppColors.primaryTeal,
                    onTap: () => _showNewStripForm(medicine),
                  ),
                ),
                const SizedBox(width: 10),
                // Remove button (always available)
                _buildSmallIconButton(
                  icon: Icons.delete_outline_rounded,
                  color: Colors.red,
                  onTap: () => _confirmRemoveMedicine(medicine),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineIcon(UserMedicine medicine) {
    Color iconColor;
    Color bgColor;

    if (medicine.isExpired) {
      iconColor = Colors.red.shade600;
      bgColor = Colors.red.shade100;
    } else if (medicine.isExpiringSoon) {
      iconColor = Colors.orange.shade600;
      bgColor = Colors.orange.shade100;
    } else {
      iconColor = AppColors.primaryTeal;
      bgColor = AppColors.primaryTeal.withValues(alpha: 0.15);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.medication_rounded, color: iconColor, size: 26),
    );
  }

  Widget _buildExpiryBadge(UserMedicine medicine, ExpiryAlert alert) {
    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    switch (alert.level) {
      case ExpiryAlertLevel.expired:
        bgColor = Colors.red.shade600;
        textColor = Colors.white;
        text = 'EXPIRED';
        icon = Icons.cancel_rounded;
        break;
      case ExpiryAlertLevel.expiringSoon:
        bgColor = Colors.orange.shade600;
        textColor = Colors.white;
        text = '${medicine.daysUntilExpiry}d left';
        icon = Icons.access_time_filled_rounded;
        break;
      default:
        bgColor = AppColors.accentGreen;
        textColor = Colors.white;
        text = 'Safe';
        icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.grayText),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  /// Show confirmation dialog before removing a medicine
  Future<void> _confirmRemoveMedicine(UserMedicine medicine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Text('Remove Medicine?'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${medicine.medicineName}" from your cabinet? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final user = _firebaseService.currentUser;
      if (user != null && medicine.id != null) {
        try {
          await _inventoryService.removeMedicine(user.uid, medicine.id!);
          _showSnackBar('${medicine.medicineName} removed from cabinet');
          _loadMedicines();
        } catch (e) {
          _showSnackBar('Failed to remove: $e', isError: true);
        }
      }
    }
  }
}
