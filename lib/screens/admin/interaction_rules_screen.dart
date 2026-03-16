import 'package:flutter/material.dart';
import '../../models/drug_model.dart';
import '../../services/drug_service.dart';
import '../../services/admin_analytics_service.dart';
import '../../theme/app_colors.dart';
import 'add_edit_interaction_rule_screen.dart';

/// Lists all drug interaction rules across the database.
/// Supports search/filter by drug name and severity.
class InteractionRulesScreen extends StatefulWidget {
  final List<DrugModel> drugs;

  const InteractionRulesScreen({super.key, required this.drugs});

  @override
  State<InteractionRulesScreen> createState() => _InteractionRulesScreenState();
}

class _InteractionRulesScreenState extends State<InteractionRulesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _severityFilter = 'All';
  late List<_FlatInteraction> _allRules;
  List<_FlatInteraction> _filteredRules = [];

  @override
  void initState() {
    super.initState();
    _flattenRules();
    _applyFilters();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Flatten all DrugInteraction entries across all drugs into a single list.
  void _flattenRules() {
    _allRules = [];
    for (final drug in widget.drugs) {
      for (int i = 0; i < drug.drugInteractions.length; i++) {
        final interaction = drug.drugInteractions[i];
        _allRules.add(
          _FlatInteraction(
            sourceDrug: drug,
            interaction: interaction,
            indexInSource: i,
          ),
        );
      }
    }
    // Sort: severe first, then moderate, then mild
    _allRules.sort((a, b) {
      final order = {'severe': 0, 'moderate': 1, 'mild': 2};
      final aOrder = order[a.interaction.severity.toLowerCase()] ?? 3;
      final bOrder = order[b.interaction.severity.toLowerCase()] ?? 3;
      return aOrder.compareTo(bOrder);
    });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredRules = _allRules.where((rule) {
        // Severity filter
        if (_severityFilter != 'All' &&
            rule.interaction.severity.toLowerCase() !=
                _severityFilter.toLowerCase()) {
          return false;
        }
        // Search filter
        if (query.isNotEmpty) {
          final matchesSource = rule.sourceDrug.displayName
              .toLowerCase()
              .contains(query);
          final matchesTarget = rule.interaction.drugName
              .toLowerCase()
              .contains(query);
          final matchesDesc = rule.interaction.description
              .toLowerCase()
              .contains(query);
          return matchesSource || matchesTarget || matchesDesc;
        }
        return true;
      }).toList();
    });
  }

  void _selectSeverity(String severity) {
    _severityFilter = severity;
    _applyFilters();
  }

  Future<void> _deleteRule(_FlatInteraction rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Rule',
          style: TextStyle(color: AppColors.lightText),
        ),
        content: Text(
          'Remove the ${rule.interaction.severity} interaction between '
          '${rule.sourceDrug.displayName} and ${rule.interaction.drugName}?',
          style: TextStyle(color: AppColors.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Remove interaction from the drug's interactions array
      final updatedInteractions = List<DrugInteraction>.from(
        rule.sourceDrug.drugInteractions,
      );
      updatedInteractions.removeAt(rule.indexInSource);

      final updatedDrug = rule.sourceDrug.copyWith(
        drugInteractions: updatedInteractions,
      );

      await DrugService().updateDrug(updatedDrug);
      await AdminAnalyticsService().logAdminAction(
        action: 'Deleted interaction rule',
        details:
            '${rule.sourceDrug.displayName} ↔ ${rule.interaction.drugName} (${rule.interaction.severity})',
        targetId: rule.sourceDrug.id,
      );

      // Refresh local state
      _allRules.remove(rule);
      _applyFilters();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rule deleted'),
            backgroundColor: AppColors.primaryTeal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
          'Interaction Rules',
          style: TextStyle(
            color: AppColors.lightText,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text(
                '${_filteredRules.length} rules',
                style: TextStyle(color: AppColors.mintGreen, fontSize: 12),
              ),
              backgroundColor: AppColors.primaryTeal.withValues(alpha: 0.15),
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AddEditInteractionRuleScreen(allDrugs: widget.drugs),
            ),
          );
          if (result == true) {
            // Reload drugs and re-flatten
            final freshDrugs = await DrugService().getAllDrugs(
              forceRefresh: true,
            );
            setState(() {
              widget.drugs.clear();
              widget.drugs.addAll(freshDrugs);
              _flattenRules();
              _applyFilters();
            });
          }
        },
        backgroundColor: AppColors.primaryTeal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildSeverityFilter(),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredRules.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredRules.length,
                    itemBuilder: (_, i) => _buildRuleCard(_filteredRules[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: AppColors.lightText),
        decoration: InputDecoration(
          hintText: 'Search drugs or interactions…',
          hintStyle: TextStyle(color: AppColors.mutedText),
          prefixIcon: Icon(Icons.search, color: AppColors.mutedText),
          filled: true,
          fillColor: AppColors.cardBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryTeal),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSeverityFilter() {
    const filters = ['All', 'Severe', 'Moderate', 'Mild'];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: filters.length,
        itemBuilder: (_, i) {
          final label = filters[i];
          final isSelected = _severityFilter == label;
          final color = _severityColor(label);
          return GestureDetector(
            onTap: () => _selectSeverity(label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.2)
                    : AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color : AppColors.borderColor,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : AppColors.mutedText,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.compare_arrows_rounded,
            color: AppColors.mutedText,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'No matching rules found'
                : 'No interaction rules yet',
            style: TextStyle(color: AppColors.mutedText, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a new rule',
            style: TextStyle(color: AppColors.mutedText.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(_FlatInteraction rule) {
    final color = _severityColor(rule.interaction.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rule.interaction.severity.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade400,
                  size: 18,
                ),
                onPressed: () => _deleteRule(rule),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Drug names
          Row(
            children: [
              Icon(
                Icons.medication_rounded,
                color: AppColors.mintGreen,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rule.sourceDrug.displayName,
                  style: TextStyle(
                    color: AppColors.lightText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.compare_arrows,
                  color: AppColors.mutedText,
                  size: 16,
                ),
              ),
              Expanded(
                child: Text(
                  rule.interaction.drugName,
                  style: TextStyle(
                    color: AppColors.lightText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Description
          Text(
            rule.interaction.description,
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'severe':
        return Colors.red.shade400;
      case 'moderate':
        return Colors.orange.shade400;
      case 'mild':
        return const Color(0xFF10B981);
      default:
        return AppColors.mintGreen;
    }
  }
}

/// Helper class to flatten interaction rules with source drug info.
class _FlatInteraction {
  final DrugModel sourceDrug;
  final DrugInteraction interaction;
  final int indexInSource;

  _FlatInteraction({
    required this.sourceDrug,
    required this.interaction,
    required this.indexInSource,
  });
}
