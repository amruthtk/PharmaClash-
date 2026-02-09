import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/medicine_inventory_service.dart';
import '../services/pdf_report_service.dart';
import '../models/dose_log_model.dart';
import '../theme/app_colors.dart';

/// History Screen - Shows dose logs and allows PDF export
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final MedicineInventoryService _inventoryService = MedicineInventoryService();

  List<DoseLog> _doseLogs = [];
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadDoseLogs();
  }

  Future<void> _loadDoseLogs() async {
    final user = _firebaseService.currentUser;
    if (user == null) return;

    try {
      final logs = await _inventoryService.getDoseLogs(user.uid, limit: 100);
      if (mounted) {
        setState(() {
          _doseLogs = logs
              .map((log) => DoseLog.fromMap(log, log['id'] ?? ''))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportReport() async {
    final user = _firebaseService.currentUser;
    if (user == null) return;

    setState(() => _isExporting = true);

    try {
      // Fetch all required data
      final userProfile = await _firebaseService.getUserProfile(user.uid);
      final medicalInfo = await _firebaseService.getMedicalInfo(user.uid);
      final medicines = await _inventoryService.getUserMedicines(user.uid);

      if (!mounted) return;

      // Generate and share PDF
      await PdfReportService.generateAndShareReport(
        context: context,
        userName: userProfile?['fullName'] ?? user.displayName ?? 'Patient',
        dateOfBirth: userProfile?['dateOfBirth'],
        allergies: List<String>.from(medicalInfo?['allergies'] ?? []),
        conditions: List<String>.from(medicalInfo?['conditions'] ?? []),
        medicines: medicines,
        doseLogs: _doseLogs,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _doseLogs.isEmpty
            ? _buildEmptyState()
            : _buildDoseLogsList(),

        // Export FAB
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton.extended(
            onPressed: _isExporting ? null : _exportReport,
            backgroundColor: _isExporting ? Colors.grey : AppColors.primaryTeal,
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
            label: Text(_isExporting ? 'Generating...' : 'Export Report'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 80,
            color: AppColors.grayText.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Dose History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your medication history will appear here\nonce you start logging doses.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.grayText),
          ),
        ],
      ),
    );
  }

  Widget _buildDoseLogsList() {
    // Group logs by date
    final groupedLogs = <String, List<DoseLog>>{};
    for (final log in _doseLogs) {
      final dateKey = log.formattedDate;
      groupedLogs.putIfAbsent(dateKey, () => []);
      groupedLogs[dateKey]!.add(log);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: groupedLogs.length,
      itemBuilder: (context, index) {
        final date = groupedLogs.keys.elementAt(index);
        final logs = groupedLogs[date]!;
        return _buildDateSection(date, logs);
      },
    );
  }

  Widget _buildDateSection(String date, List<DoseLog> logs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  date,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryTeal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${logs.length} dose${logs.length > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 12, color: AppColors.grayText),
              ),
            ],
          ),
        ),
        // Dose cards
        ...logs.map((log) => _buildDoseCard(log)),
      ],
    );
  }

  Widget _buildDoseCard(DoseLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Time indicator
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: AppColors.accentGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Medicine info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.medicineName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${log.quantityTaken} tablet${log.quantityTaken > 1 ? 's' : ''} at ${log.formattedTakenTime}',
                  style: TextStyle(fontSize: 13, color: AppColors.grayText),
                ),
              ],
            ),
          ),
          // Scheduled time badge
          if (log.scheduledTime != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                log.scheduledTime!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
