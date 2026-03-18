import 'package:flutter/material.dart';
import '../../services/admin_analytics_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin/admin_activity_tile.dart';

/// Full audit log screen with filtering and pagination.
class AdminAuditLogsScreen extends StatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  final AdminAnalyticsService _analytics = AdminAnalyticsService();
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String _activeFilter = 'All';

  static const _filters = [
    'All',
    'Added',
    'Updated',
    'Deleted',
    'Rule',
    'Import',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _analytics.getAdminLogs(limit: 100);
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('AuditLogs: error loading: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_activeFilter == 'All') return _logs;
    final keyword = _activeFilter.toLowerCase();
    return _logs.where((log) {
      final action = (log['action'] as String? ?? '').toLowerCase();
      final details = (log['details'] as String? ?? '').toLowerCase();
      return action.contains(keyword) || details.contains(keyword);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;

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
          'Audit Logs',
          style: TextStyle(
            color: AppColors.lightText,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '${filtered.length} entries',
                style: TextStyle(color: AppColors.mutedText, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final filter = _filters[i];
                final isActive = _activeFilter == filter;
                return GestureDetector(
                  onTap: () => setState(() => _activeFilter = filter),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primaryTeal.withValues(alpha: 0.2)
                          : AppColors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive
                            ? AppColors.primaryTeal
                            : AppColors.borderColor,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? AppColors.mintGreen
                              : AppColors.mutedText,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Log list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryTeal,
                    ),
                  )
                : filtered.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadLogs,
                    color: AppColors.primaryTeal,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) =>
                          AdminActivityTile(log: filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            color: AppColors.mutedText,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            _activeFilter == 'All'
                ? 'No audit logs yet'
                : 'No "$_activeFilter" logs found',
            style: TextStyle(color: AppColors.mutedText, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            'Actions will appear here automatically',
            style: TextStyle(
              color: AppColors.mutedText.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
