import 'package:flutter/material.dart';
import '../../models/drug_model.dart';
import '../../services/firebase_service.dart';
import '../../services/drug_service.dart';
import '../../services/admin_analytics_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin/admin_stat_card.dart';
import '../../widgets/admin/risk_donut_chart.dart';
import '../../widgets/admin/admin_activity_tile.dart';
import 'drug_list_screen.dart';
import 'add_edit_drug_screen.dart';
import 'data_migration_screen.dart';
import 'interaction_rules_screen.dart';
import 'admin_audit_logs_screen.dart';
import 'guest_telemetry_logs_screen.dart';
import '../../widgets/admin/admin_funnel_chart.dart';

/// Admin Dashboard Screen — actionable insights hub.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final DrugService _drugService = DrugService();
  final AdminAnalyticsService _analytics = AdminAnalyticsService();

  // Stats
  List<DrugModel> _drugs = [];
  int _drugCount = 0;
  int _categoryCount = 0;
  int _ruleCount = 0;
  Map<String, int> _riskDistribution = {'severe': 0, 'moderate': 0, 'mild': 0};

  // Recent activity
  List<Map<String, dynamic>> _recentLogs = [];
  List<Map<String, dynamic>> _recentGuestLogs = [];

  // Guest Stats
  Map<String, int> _funnelData = {'interactions': 0, 'patients': 0};
  List<Map<String, dynamic>> _topGuestChecks = [];
  double _guestScanSuccessRate = 0.0;
  bool _showGuestInsights = false;

  bool _isLoading = true;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    try {
      // Core data — these are critical
      final drugs = await _drugService.getAllDrugs(forceRefresh: true);
      final categories = await _drugService.getCategories();

      List<Map<String, dynamic>> recentLogs = [];
      try { recentLogs = await _analytics.getRecentAdminLogs(limit: 5); } catch (e) { debugPrint('Dashboard: recentLogs error: $e'); }

      // Guest analytics — each is independent, one failing shouldn't block others
      Map<String, int> funnelData = {'interactions': 0, 'patients': 0};
      try { funnelData = await _analytics.getFunnelData(); } catch (e) { debugPrint('Dashboard: funnelData error: $e'); }

      List<Map<String, dynamic>> topGuestChecks = [];
      try { topGuestChecks = await _analytics.getTopGuestInteractions(); } catch (e) { debugPrint('Dashboard: topGuestChecks error: $e'); }

      Map<String, double> perfStats = {'successRate': 0.0};
      try { perfStats = await _analytics.getGuestPerformanceStats(); } catch (e) { debugPrint('Dashboard: perfStats error: $e'); }

      List<Map<String, dynamic>> recentGuestLogs = [];
      try { recentGuestLogs = await _analytics.getRecentGuestTelemetry(limit: 5); } catch (e) { debugPrint('Dashboard: recentGuestLogs error: $e'); }

      if (mounted) {
        setState(() {
          _drugs = drugs;
          _drugCount = drugs.length;
          _categoryCount = categories.length;
          _ruleCount = _analytics.getInteractionRuleCount(drugs);
          _riskDistribution = _analytics.getRiskDistribution(drugs);
          _recentLogs = recentLogs;
          _funnelData = funnelData;
          _topGuestChecks = topGuestChecks;
          _guestScanSuccessRate = perfStats['successRate'] ?? 0.0;
          _recentGuestLogs = recentGuestLogs;
          _isLoading = false;
        });
        _animationController.forward(from: 0);
      }
    } catch (e) {
      debugPrint('Dashboard load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: TextStyle(color: AppColors.lightText)),
        content: Text(
          'Are you sure you want to logout from admin panel?',
          style: TextStyle(color: AppColors.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              await FirebaseService().signOut();
              if (mounted) {
                navigator.pushNamedAndRemoveUntil('/splash', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.admin_panel_settings,
                color: AppColors.mintGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Admin Dashboard',
                style: TextStyle(
                  color: AppColors.lightText,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.mutedText),
            onPressed: _loadAll,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: Colors.red.shade400),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primaryTeal),
            )
          : RefreshIndicator(
              onRefresh: _loadAll,
              color: AppColors.primaryTeal,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(),
                    const SizedBox(height: 20),
                    _buildModeToggle(),
                    const SizedBox(height: 20),
                    if (!_showGuestInsights) ...[
                      _buildStatsGrid(),
                      const SizedBox(height: 20),
                      RiskDonutChart(
                        severe: _riskDistribution['severe'] ?? 0,
                        moderate: _riskDistribution['moderate'] ?? 0,
                        mild: _riskDistribution['mild'] ?? 0,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Quick Actions', Icons.flash_on_rounded),
                      const SizedBox(height: 12),
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle(
                            'Recent Activity',
                            Icons.history_rounded,
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminAuditLogsScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'See All',
                              style: TextStyle(
                                color: AppColors.primaryTeal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildRecentActivity(),
                    ] else ...[
                      _buildGuestInsights(),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // ==================== SECTIONS ====================

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryTeal, AppColors.deepTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryTeal.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Admin',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage drugs, interaction rules, and monitor system analytics.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.medication_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.9,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        AdminStatCard(
          label: 'Drugs',
          value: '$_drugCount',
          icon: Icons.medication_rounded,
          color: AppColors.mintGreen,
        ),
        AdminStatCard(
          label: 'Categories',
          value: '$_categoryCount',
          icon: Icons.category_rounded,
          color: Colors.amber,
        ),
        AdminStatCard(
          label: 'Rules',
          value: '$_ruleCount',
          icon: Icons.compare_arrows_rounded,
          color: Colors.red.shade400,
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Add Drug',
                Icons.add_circle_outline,
                AppColors.primaryTeal,
                () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddEditDrugScreen(),
                    ),
                  );
                  _loadAll();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'View All',
                Icons.list_alt_rounded,
                Colors.blue,
                () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DrugListScreen()),
                  );
                  _loadAll();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Manage Rules',
                Icons.compare_arrows_rounded,
                Colors.orange,
                () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InteractionRulesScreen(drugs: _drugs),
                    ),
                  );
                  _loadAll();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Import Data',
                Icons.cloud_upload_rounded,
                Colors.teal.shade300,
                () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DataMigrationScreen(),
                    ),
                  );
                  _loadAll();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    if (_recentLogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history, color: AppColors.mutedText, size: 28),
              const SizedBox(height: 8),
              Text(
                'No recent activity',
                style: TextStyle(color: AppColors.mutedText, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _recentLogs.map((log) => AdminActivityTile(log: log)).toList(),
    );
  }

  // ==================== HELPERS ====================

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.mintGreen, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.lightText,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleItem(
              'System Overview',
              Icons.dashboard_rounded,
              !_showGuestInsights,
              () => setState(() => _showGuestInsights = false),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildToggleItem(
              'User Insights',
              Icons.analytics_rounded,
              _showGuestInsights,
              () => setState(() => _showGuestInsights = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(
    String label,
    IconData icon,
    bool isActive,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : AppColors.mutedText,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : AppColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Acquisition Funnel', Icons.filter_alt_rounded),
        const SizedBox(height: 16),
        AdminFunnelChart(
          interactions: _funnelData['interactions'] ?? 0,
          patients: _funnelData['patients'] ?? 0,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: AdminStatCard(
                label: 'Guest Scan Success',
                value: '${_guestScanSuccessRate.toStringAsFixed(1)}%',
                icon: Icons.camera_alt_rounded,
                color: AppColors.mintGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AdminStatCard(
                label: 'Guest Checks',
                value: '${_funnelData['interactions']}',
                icon: Icons.search_rounded,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Risk Heatmap (Top Guest Checks)', Icons.local_fire_department_rounded),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: _topGuestChecks.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No guest interaction check data yet.', style: TextStyle(color: AppColors.mutedText)),
                  ),
                )
              : Column(
                  children: _topGuestChecks.map((check) {
                    final label = check['label'] as String;
                    final count = check['count'] as int;
                    final severity = check['severity'] as String? ?? 'safe';
                    final maxCount = _topGuestChecks.first['count'] as int;
                    
                    Color barColor = AppColors.primaryTeal;
                    switch (severity.toLowerCase()) {
                      case 'severe': barColor = Colors.red.shade400; break;
                      case 'moderate': barColor = Colors.orange.shade400; break;
                      case 'mild': barColor = Colors.blue.shade400; break;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                              Text('$count checks', style: TextStyle(color: barColor, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: count / maxCount,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              color: barColor,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Anonymous Activity', Icons.person_search_rounded),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GuestTelemetryLogsScreen(),
                  ),
                );
              },
              child: Text(
                'See All',
                style: TextStyle(
                  color: AppColors.primaryTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._recentGuestLogs.map((log) => AdminActivityTile(log: {
          ...log,
          'action': '👤 Guest: ${log['action']}',
        })),
        if (_recentGuestLogs.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No guest activity monitored yet.', style: TextStyle(color: AppColors.mutedText)),
            ),
          ),
      ],
    );
  }
}
