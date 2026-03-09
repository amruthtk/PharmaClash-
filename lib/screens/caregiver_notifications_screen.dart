import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/caregiver_notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/caregiver_notification_card.dart';

/// Screen showing the caregiver's alert history feed.
class CaregiverNotificationsScreen extends StatefulWidget {
  const CaregiverNotificationsScreen({super.key});

  @override
  State<CaregiverNotificationsScreen> createState() =>
      _CaregiverNotificationsScreenState();
}

class _CaregiverNotificationsScreenState
    extends State<CaregiverNotificationsScreen> {
  final _service = CaregiverNotificationService();
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    final alerts = await _service.getAlerts();
    if (mounted) {
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredAlerts {
    if (_filter == 'all') return _alerts;
    return _alerts.where((a) => a['type'] == _filter).toList();
  }

  Future<void> _emailPatient(String patientUid) async {
    // Get patient email from their user profile
    try {
      final patients = await _service.getLinkedPatients();
      final patient = patients.firstWhere(
        (p) => p['uid'] == patientUid,
        orElse: () => {},
      );
      final email = patient['email'] as String?;
      if (email != null && email.isNotEmpty) {
        final uri = Uri.parse(
          'mailto:$email?subject=Attention needed regarding your health tracker&body=Hello, I received a notification regarding your medication. Are you okay?',
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Patient email not available'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error emailing patient: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Caregiver Alerts',
          style: TextStyle(
            color: AppColors.lightText,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.primaryTeal),
            onPressed: _loadAlerts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('🚨 Emergency', 'severe_override'),
                _buildFilterChip('⏰ Missed Dose', 'missed_dose'),
                _buildFilterChip('🔗 Links', 'caregiver_linked'),
              ],
            ),
          ),
          const Divider(color: AppColors.borderColor, height: 1),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryTeal,
                    ),
                  )
                : _filteredAlerts.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadAlerts,
                    color: AppColors.primaryTeal,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredAlerts.length,
                      itemBuilder: (context, index) {
                        final alert = _filteredAlerts[index];
                        return CaregiverNotificationCard(
                          alert: alert,
                          onEmailPatient: alert['type'] == 'severe_override'
                              ? () => _emailPatient(
                                  alert['patientUid'] as String? ?? '',
                                )
                              : null,
                          onMarkRead: !(alert['read'] as bool? ?? true)
                              ? () async {
                                  await _service.markAlertRead(alert['id']);
                                  _loadAlerts();
                                }
                              : null,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterVal) {
    final isSelected = _filter == filterVal;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.mutedText,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        onSelected: (val) => setState(() => _filter = val ? filterVal : 'all'),
        backgroundColor: AppColors.cardBg,
        selectedColor: AppColors.primaryTeal,
        side: BorderSide(
          color: isSelected ? AppColors.primaryTeal : AppColors.borderColor,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            color: AppColors.mutedText,
            size: 56,
          ),
          const SizedBox(height: 12),
          Text(
            'No alerts yet',
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You\'ll see alerts from your patients here.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
