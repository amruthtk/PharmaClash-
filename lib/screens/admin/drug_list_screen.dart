import 'package:flutter/material.dart';
import '../../models/drug_model.dart';
import '../../services/drug_service.dart';
import 'add_edit_drug_screen.dart';
import '../../theme/app_colors.dart';

/// Drug List Screen for Admin
/// Shows all drugs with search and delete functionality
class DrugListScreen extends StatefulWidget {
  const DrugListScreen({super.key});

  @override
  State<DrugListScreen> createState() => _DrugListScreenState();
}

class _DrugListScreenState extends State<DrugListScreen> {
  final DrugService _drugService = DrugService();
  final TextEditingController _searchController = TextEditingController();

  List<DrugModel> _allDrugs = [];
  List<DrugModel> _filteredDrugs = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];

  // Theme colors

  @override
  void initState() {
    super.initState();
    _loadDrugs();
    _searchController.addListener(_filterDrugs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDrugs() async {
    setState(() => _isLoading = true);

    try {
      final drugs = await _drugService.getAllDrugs(forceRefresh: true);
      final categories = await _drugService.getCategories();

      if (mounted) {
        setState(() {
          _allDrugs = drugs;
          _filteredDrugs = drugs;
          _categories = ['All', ...categories];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading drugs', isError: true);
      }
    }
  }

  void _filterDrugs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDrugs = _allDrugs.where((drug) {
        // Filter by search query
        final matchesSearch =
            query.isEmpty ||
            drug.genericName.toLowerCase().contains(query) ||
            drug.brandNames.any((b) => b.toLowerCase().contains(query));

        // Filter by category
        final matchesCategory =
            _selectedCategory == 'All' || drug.category == _selectedCategory;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _filterDrugs();
  }

  Future<void> _deleteDrug(DrugModel drug) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Drug', style: TextStyle(color: AppColors.lightText)),
        content: Text(
          'Are you sure you want to delete "${drug.genericName}"? This action cannot be undone.',
          style: TextStyle(color: AppColors.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && drug.id != null) {
      final success = await _drugService.deleteDrug(drug.id!);
      if (success) {
        _showSnackBar('Drug deleted successfully');
        _loadDrugs();
      } else {
        _showSnackBar('Failed to delete drug', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : AppColors.primaryTeal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Drug Database',
          style: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.mutedText),
            onPressed: _loadDrugs,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryFilter(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.primaryTeal))
                : _filteredDrugs.isEmpty
                ? _buildEmptyState()
                : _buildDrugList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditDrugScreen()),
          );
          _loadDrugs();
        },
        backgroundColor: AppColors.primaryTeal,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: AppColors.lightText),
        decoration: InputDecoration(
          hintText: 'Search drugs by name...',
          hintStyle: TextStyle(color: AppColors.mutedText.withValues(alpha: 0.5)),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.mutedText),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.mutedText),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
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
            borderSide: BorderSide(color: AppColors.primaryTeal, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (_) => _selectCategory(category),
              backgroundColor: AppColors.cardBg,
              selectedColor: AppColors.primaryTeal.withValues(alpha: 0.3),
              checkmarkColor: AppColors.mintGreen,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.mintGreen : AppColors.mutedText,
                fontSize: 12,
              ),
              side: BorderSide(color: isSelected ? AppColors.primaryTeal : AppColors.borderColor),
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
            Icons.medication_outlined,
            size: 64,
            color: AppColors.mutedText.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty || _selectedCategory != 'All'
                ? 'No drugs found'
                : 'No drugs in database',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty || _selectedCategory != 'All'
                ? 'Try a different search or filter'
                : 'Add your first drug to get started',
            style: TextStyle(fontSize: 14, color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _buildDrugList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredDrugs.length,
      itemBuilder: (context, index) {
        final drug = _filteredDrugs[index];
        return _buildDrugCard(drug);
      },
    );
  }

  Widget _buildDrugCard(DrugModel drug) {
    final hasInteractions = drug.drugInteractions.isNotEmpty;
    final hasFoodWarnings = drug.foodInteractions.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddEditDrugScreen(drug: drug)),
          );
          _loadDrugs();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.medication_rounded,
                      color: AppColors.mintGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          drug.genericName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.lightText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          drug.brandNames.take(3).join(', '),
                          style: TextStyle(fontSize: 12, color: AppColors.mutedText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: AppColors.mutedText),
                    color: AppColors.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddEditDrugScreen(drug: drug),
                          ),
                        ).then((_) => _loadDrugs());
                      } else if (value == 'delete') {
                        _deleteDrug(drug);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              color: AppColors.primaryTeal,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text('Edit', style: TextStyle(color: AppColors.lightText)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_rounded,
                              color: Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTag(drug.category, AppColors.primaryTeal),
                  const SizedBox(width: 8),
                  if (hasInteractions)
                    _buildTag(
                      '${drug.drugInteractions.length} interactions',
                      Colors.orange,
                    ),
                  if (hasFoodWarnings) ...[
                    const SizedBox(width: 8),
                    _buildTag(
                      '${drug.foodInteractions.length} food warnings',
                      Colors.amber,
                    ),
                  ],
                ],
              ),
              if (drug.allergyWarnings.isNotEmpty ||
                  drug.conditionWarnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (drug.allergyWarnings.isNotEmpty)
                      _buildTag(
                        '${drug.allergyWarnings.length} allergy warnings',
                        Colors.red,
                      ),
                    if (drug.conditionWarnings.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _buildTag(
                        '${drug.conditionWarnings.length} condition warnings',
                        Colors.purple,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

