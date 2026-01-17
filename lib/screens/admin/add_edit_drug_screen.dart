import 'package:flutter/material.dart';
import '../../models/drug_model.dart';
import '../../services/drug_service.dart';
import '../../theme/app_colors.dart';

/// Add/Edit Drug Screen
/// Form to add a new drug or edit existing one
class AddEditDrugScreen extends StatefulWidget {
  final DrugModel? drug;

  const AddEditDrugScreen({super.key, this.drug});

  @override
  State<AddEditDrugScreen> createState() => _AddEditDrugScreenState();
}

class _AddEditDrugScreenState extends State<AddEditDrugScreen> {
  final DrugService _drugService = DrugService();
  final _formKey = GlobalKey<FormState>();

  // Controllers for basic info
  late TextEditingController _genericNameController;
  late TextEditingController _brandNamesController;
  late TextEditingController _categoryController;

  // Lists for warnings and interactions
  List<String> _allergyWarnings = [];
  List<String> _conditionWarnings = [];
  List<DrugInteraction> _drugInteractions = [];
  List<FoodInteraction> _foodInteractions = [];

  bool _isLoading = false;
  bool _isEditing = false;

  // Common categories for quick selection
  final List<String> _commonCategories = [
    'Pain Reliever',
    'NSAID',
    'Antibiotic',
    'Blood Pressure',
    'Diabetes',
    'Antihistamine',
    'Antacid',
    'Antidepressant',
    'Bronchodilator',
    'Statin',
    'Beta Blocker',
    'ACE Inhibitor',
    'Opioid',
    'Thyroid',
    'Other',
  ];

  // Theme colors

  @override
  void initState() {
    super.initState();
    _isEditing = widget.drug != null;

    _genericNameController = TextEditingController(
      text: widget.drug?.genericName ?? '',
    );
    _brandNamesController = TextEditingController(
      text: widget.drug?.brandNames.join(', ') ?? '',
    );
    _categoryController = TextEditingController(
      text: widget.drug?.category ?? '',
    );

    if (_isEditing) {
      _allergyWarnings = List.from(widget.drug!.allergyWarnings);
      _conditionWarnings = List.from(widget.drug!.conditionWarnings);
      _drugInteractions = List.from(widget.drug!.drugInteractions);
      _foodInteractions = List.from(widget.drug!.foodInteractions);
    }
  }

  @override
  void dispose() {
    _genericNameController.dispose();
    _brandNamesController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _saveDrug() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final brandNames = _brandNamesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final drug = DrugModel(
        id: widget.drug?.id,
        displayName: _genericNameController.text.trim(),
        brandNames: brandNames,
        category: _categoryController.text.trim(),
        allergyWarnings: _allergyWarnings,
        conditionWarnings: _conditionWarnings,
        drugInteractions: _drugInteractions,
        foodInteractions: _foodInteractions,
        createdAt: widget.drug?.createdAt,
      );

      bool success;
      if (_isEditing) {
        success = await _drugService.updateDrug(drug);
      } else {
        final id = await _drugService.addDrug(drug);
        success = id != null;
      }

      if (success && mounted) {
        _showSnackBar(
          _isEditing ? 'Drug updated successfully' : 'Drug added successfully',
        );
        Navigator.pop(context);
      } else {
        _showSnackBar('Failed to save drug', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          _isEditing ? 'Edit Drug' : 'Add New Drug',
          style: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.mintGreen,
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _saveDrug,
              icon: Icon(Icons.save_rounded, color: AppColors.mintGreen),
              label: Text('Save', style: TextStyle(color: AppColors.mintGreen)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Basic Information', Icons.info_outline),
              const SizedBox(height: 12),
              _buildBasicInfoCard(),
              const SizedBox(height: 24),
              _buildSectionTitle(
                'Allergy Warnings',
                Icons.warning_amber_rounded,
              ),
              const SizedBox(height: 12),
              _buildWarningList(
                _allergyWarnings,
                'allergy',
                Colors.red,
                'Add allergies that may be triggered by this drug',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(
                'Condition Warnings',
                Icons.health_and_safety_rounded,
              ),
              const SizedBox(height: 12),
              _buildWarningList(
                _conditionWarnings,
                'condition',
                Colors.purple,
                'Add medical conditions that may be affected',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Drug Interactions', Icons.medication_rounded),
              const SizedBox(height: 12),
              _buildDrugInteractionsList(),
              const SizedBox(height: 24),
              _buildSectionTitle('Food Interactions', Icons.restaurant_rounded),
              const SizedBox(height: 12),
              _buildFoodInteractionsList(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveDrug,
        backgroundColor: AppColors.primaryTeal,
        icon: Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded),
        label: Text(_isEditing ? 'Update Drug' : 'Add Drug'),
      ),
    );
  }

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

  Widget _buildBasicInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Generic Name
          _buildLabel('Generic Name *'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _genericNameController,
            style: TextStyle(color: AppColors.lightText),
            decoration: _inputDecoration('e.g., Paracetamol'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter generic name';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Brand Names
          _buildLabel('Brand Names (comma separated)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _brandNamesController,
            style: TextStyle(color: AppColors.lightText),
            decoration: _inputDecoration('e.g., Dolo, Crocin, Tylenol'),
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          // Category
          _buildLabel('Category *'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _categoryController,
            style: TextStyle(color: AppColors.lightText),
            decoration: _inputDecoration('e.g., Pain Reliever').copyWith(
              suffixIcon: PopupMenuButton<String>(
                icon: Icon(Icons.arrow_drop_down, color: AppColors.mutedText),
                color: AppColors.cardBg,
                onSelected: (value) {
                  _categoryController.text = value;
                },
                itemBuilder: (context) => _commonCategories
                    .map(
                      (cat) => PopupMenuItem(
                        value: cat,
                        child: Text(cat, style: TextStyle(color: AppColors.lightText)),
                      ),
                    )
                    .toList(),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter category';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.mutedText,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.mutedText.withValues(alpha: 0.5)),
      filled: true,
      fillColor: AppColors.darkBg,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildWarningList(
    List<String> warnings,
    String type,
    Color color,
    String hint,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (warnings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                hint,
                style: TextStyle(color: AppColors.mutedText, fontSize: 13),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: warnings
                  .map(
                    (w) => Chip(
                      label: Text(w),
                      labelStyle: TextStyle(color: AppColors.lightText, fontSize: 12),
                      backgroundColor: color.withValues(alpha: 0.2),
                      deleteIcon: Icon(Icons.close, size: 16, color: color),
                      onDeleted: () {
                        setState(() {
                          warnings.remove(w);
                        });
                      },
                      side: BorderSide(color: color.withValues(alpha: 0.3)),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAddWarningDialog(type, color),
              icon: Icon(Icons.add_rounded, color: color),
              label: Text(
                'Add ${type == 'allergy' ? 'Allergy' : 'Condition'}',
                style: TextStyle(color: color),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddWarningDialog(String type, Color color) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add ${type == 'allergy' ? 'Allergy Warning' : 'Condition Warning'}',
          style: TextStyle(color: AppColors.lightText),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppColors.lightText),
          decoration: _inputDecoration(
            type == 'allergy' ? 'e.g., Penicillin' : 'e.g., Liver Disease',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                setState(() {
                  if (type == 'allergy') {
                    _allergyWarnings.add(value);
                  } else {
                    _conditionWarnings.add(value);
                  }
                });
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrugInteractionsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_drugInteractions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Add drugs that interact with this medication',
                style: TextStyle(color: AppColors.mutedText, fontSize: 13),
              ),
            )
          else
            ...List.generate(_drugInteractions.length, (index) {
              final interaction = _drugInteractions[index];
              return _buildInteractionTile(
                interaction.drugName,
                interaction.severity,
                interaction.description,
                Colors.orange,
                () {
                  setState(() {
                    _drugInteractions.removeAt(index);
                  });
                },
              );
            }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAddDrugInteractionDialog,
              icon: Icon(Icons.add_rounded, color: Colors.orange),
              label: Text(
                'Add Drug Interaction',
                style: TextStyle(color: Colors.orange),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDrugInteractionDialog() {
    final drugController = TextEditingController();
    final descController = TextEditingController();
    String severity = 'moderate';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Add Drug Interaction',
            style: TextStyle(color: AppColors.lightText),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Interacting Drug *'),
                const SizedBox(height: 8),
                TextField(
                  controller: drugController,
                  style: TextStyle(color: AppColors.lightText),
                  decoration: _inputDecoration('e.g., Aspirin'),
                ),
                const SizedBox(height: 16),
                _buildLabel('Severity'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSeverityChip('mild', severity, (val) {
                      setDialogState(() => severity = val);
                    }),
                    const SizedBox(width: 8),
                    _buildSeverityChip('moderate', severity, (val) {
                      setDialogState(() => severity = val);
                    }),
                    const SizedBox(width: 8),
                    _buildSeverityChip('severe', severity, (val) {
                      setDialogState(() => severity = val);
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLabel('Description'),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  style: TextStyle(color: AppColors.lightText),
                  decoration: _inputDecoration('e.g., Increased bleeding risk'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
            ),
            ElevatedButton(
              onPressed: () {
                if (drugController.text.trim().isNotEmpty) {
                  setState(() {
                    _drugInteractions.add(
                      DrugInteraction(
                        drugName: drugController.text.trim(),
                        severity: severity,
                        description: descController.text.trim(),
                      ),
                    );
                  });
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityChip(
    String value,
    String selected,
    Function(String) onSelect,
  ) {
    final isSelected = value == selected;
    final color = value == 'severe'
        ? Colors.red
        : value == 'moderate'
        ? Colors.orange
        : Colors.yellow;

    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : AppColors.borderColor),
        ),
        child: Text(
          value.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? color : AppColors.mutedText,
          ),
        ),
      ),
    );
  }

  Widget _buildFoodInteractionsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_foodInteractions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Add foods that interact with this medication',
                style: TextStyle(color: AppColors.mutedText, fontSize: 13),
              ),
            )
          else
            ...List.generate(_foodInteractions.length, (index) {
              final interaction = _foodInteractions[index];
              return _buildInteractionTile(
                interaction.food,
                interaction.severity,
                interaction.description,
                Colors.amber,
                () {
                  setState(() {
                    _foodInteractions.removeAt(index);
                  });
                },
              );
            }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAddFoodInteractionDialog,
              icon: Icon(Icons.add_rounded, color: Colors.amber),
              label: Text(
                'Add Food Interaction',
                style: TextStyle(color: Colors.amber),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFoodInteractionDialog() {
    final foodController = TextEditingController();
    final descController = TextEditingController();
    String severity = 'caution';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Add Food Interaction',
            style: TextStyle(color: AppColors.lightText),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Food/Beverage *'),
                const SizedBox(height: 8),
                TextField(
                  controller: foodController,
                  style: TextStyle(color: AppColors.lightText),
                  decoration: _inputDecoration('e.g., Grapefruit, Alcohol'),
                ),
                const SizedBox(height: 16),
                _buildLabel('Severity'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildFoodSeverityChip('limit', severity, (val) {
                      setDialogState(() => severity = val);
                    }),
                    const SizedBox(width: 8),
                    _buildFoodSeverityChip('caution', severity, (val) {
                      setDialogState(() => severity = val);
                    }),
                    const SizedBox(width: 8),
                    _buildFoodSeverityChip('avoid', severity, (val) {
                      setDialogState(() => severity = val);
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLabel('Description'),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  style: TextStyle(color: AppColors.lightText),
                  decoration: _inputDecoration(
                    'e.g., Can increase drug levels',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
            ),
            ElevatedButton(
              onPressed: () {
                if (foodController.text.trim().isNotEmpty) {
                  setState(() {
                    _foodInteractions.add(
                      FoodInteraction(
                        food: foodController.text.trim(),
                        severity: severity,
                        description: descController.text.trim(),
                      ),
                    );
                  });
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodSeverityChip(
    String value,
    String selected,
    Function(String) onSelect,
  ) {
    final isSelected = value == selected;
    final color = value == 'avoid'
        ? Colors.red
        : value == 'caution'
        ? Colors.orange
        : Colors.yellow;

    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : AppColors.borderColor),
        ),
        child: Text(
          value.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? color : AppColors.mutedText,
          ),
        ),
      ),
    );
  }

  Widget _buildInteractionTile(
    String name,
    String severity,
    String description,
    Color color,
    VoidCallback onDelete,
  ) {
    final severityColor = severity == 'severe' || severity == 'avoid'
        ? Colors.red
        : severity == 'moderate' || severity == 'caution'
        ? Colors.orange
        : Colors.yellow;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        severity.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: severityColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: AppColors.mutedText),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Colors.red.shade400,
              size: 20,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

