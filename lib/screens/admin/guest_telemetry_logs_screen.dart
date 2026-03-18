import 'package:flutter/material.dart';
import '../../services/admin_analytics_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin/admin_activity_tile.dart';

/// Full guest telemetry log screen with filtering.
class GuestTelemetryLogsScreen extends StatefulWidget {
  const GuestTelemetryLogsScreen({super.key});

  @override
  State<GuestTelemetryLogsScreen> createState() =>
      _GuestTelemetryLogsScreenState();
}

class _GuestTelemetryLogsScreenState extends State<GuestTelemetryLogsScreen> {
  final AdminAnalyticsService _analytics = AdminAnalyticsService();
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String _activeFilter = 'All';

  static const _filters = [
    'All',
    'scan',
    'interaction',
    'install',
    'registration',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _analytics.getRecentGuestTelemetry(limit: 200);
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('GuestTelemetryLogs: error loading: $e');
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
          'Guest Activity',
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
                '${filtered.length} events',
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                        filter[0].toUpperCase() + filter.substring(1),
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
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final log = filtered[i];
                            return AdminActivityTile(log: {
                              ...log,
                              'action': '👤 ${log['action']}',
                            });
                          },
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
            Icons.person_search_rounded,
            color: AppColors.mutedText,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            _activeFilter == 'All'
                ? 'No guest activity yet'
                : 'No "$_activeFilter" events found',
            style: TextStyle(color: AppColors.mutedText, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            'Guest actions will appear here automatically',
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
