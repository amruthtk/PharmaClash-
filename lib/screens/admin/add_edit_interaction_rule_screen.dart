import 'package:flutter/material.dart';
import '../../models/drug_model.dart';
import '../../services/drug_service.dart';
import '../../services/admin_analytics_service.dart';
import '../../theme/app_colors.dart';

/// Screen to add or edit a single interaction rule between two drugs.
class AddEditInteractionRuleScreen extends StatefulWidget {
  final List<DrugModel> allDrugs;
  final DrugModel? preselectedDrugA;
  final DrugInteraction? existingRule;

  const AddEditInteractionRuleScreen({
    super.key,
    required this.allDrugs,
    this.preselectedDrugA,
    this.existingRule,
  });

  @override
  State<AddEditInteractionRuleScreen> createState() =>
      _AddEditInteractionRuleScreenState();
}

class _AddEditInteractionRuleScreenState
    extends State<AddEditInteractionRuleScreen> {
  DrugModel? _drugA;
  DrugModel? _drugB;
  String _severity = 'moderate';
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSaving = false;

  bool get _isEditing => widget.existingRule != null;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedDrugA != null) {
      _drugA = widget.preselectedDrugA;
    }
    if (widget.existingRule != null) {
      _severity = widget.existingRule!.severity;
      _descriptionController.text = widget.existingRule!.description;
      // Try to find drug B by name
      final targetName = widget.existingRule!.drugName.toLowerCase();
      _drugB = widget.allDrugs.cast<DrugModel?>().firstWhere(
        (d) => d!.displayName.toLowerCase() == targetName,
        orElse: () => null,
      );
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_drugA == null || _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill all required fields'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Drug B name — either from selected drug or typed in
    final drugBName =
        _drugB?.displayName ?? widget.existingRule?.drugName ?? '';
    if (drugBName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select the target drug'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final newInteraction = DrugInteraction(
        drugName: drugBName,
        severity: _severity,
        description: _descriptionController.text.trim(),
      );

      // Update Drug A's interactions
      final updatedInteractions = List<DrugInteraction>.from(
        _drugA!.drugInteractions,
      );

      if (_isEditing) {
        // Find and replace the existing rule
        final idx = updatedInteractions.indexWhere(
          (i) =>
              i.drugName.toLowerCase() ==
              widget.existingRule!.drugName.toLowerCase(),
        );
        if (idx >= 0) {
          updatedInteractions[idx] = newInteraction;
        } else {
          updatedInteractions.add(newInteraction);
        }
      } else {
        updatedInteractions.add(newInteraction);
      }

      final updatedDrugA = _drugA!.copyWith(
        drugInteractions: updatedInteractions,
      );

      await DrugService().updateDrug(updatedDrugA);

      // Also add reciprocal rule on Drug B if it exists in DB
      if (_drugB != null && _drugB!.id != null) {
        final reciprocal = DrugInteraction(
          drugName: _drugA!.displayName,
          severity: _severity,
          description: _descriptionController.text.trim(),
        );

        // Check if reciprocal already exists
        final alreadyExists = _drugB!.drugInteractions.any(
          (i) => i.drugName.toLowerCase() == _drugA!.displayName.toLowerCase(),
        );

        if (!alreadyExists) {
          final updatedDrugBInteractions = List<DrugInteraction>.from(
            _drugB!.drugInteractions,
          )..add(reciprocal);
          final updatedDrugB = _drugB!.copyWith(
            drugInteractions: updatedDrugBInteractions,
          );
          await DrugService().updateDrug(updatedDrugB);
        }
      }

      // Log the action
      await AdminAnalyticsService().logAdminAction(
        action: _isEditing
            ? 'Updated interaction rule'
            : 'Added interaction rule',
        details: '${_drugA!.displayName} ↔ $drugBName ($_severity)',
        targetId: _drugA!.id,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
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
          _isEditing ? 'Edit Rule' : 'Add Interaction Rule',
          style: TextStyle(
            color: AppColors.lightText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Drug A *'),
            const SizedBox(height: 8),
            _buildDrugSelector(
              selectedDrug: _drugA,
              onSelected: (drug) => setState(() => _drugA = drug),
              excludeDrug: _drugB,
            ),
            const SizedBox(height: 20),
            _buildLabel('Drug B *'),
            const SizedBox(height: 8),
            _buildDrugSelector(
              selectedDrug: _drugB,
              onSelected: (drug) => setState(() => _drugB = drug),
              excludeDrug: _drugA,
            ),
            const SizedBox(height: 20),
            _buildLabel('Severity'),
            const SizedBox(height: 8),
            _buildSeveritySelector(),
            const SizedBox(height: 20),
            _buildLabel('Description *'),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              style: TextStyle(color: AppColors.lightText, fontSize: 14),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe the clinical interaction…',
                hintStyle: TextStyle(color: AppColors.mutedText),
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
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Update Rule' : 'Add Rule',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.lightText,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }

  Widget _buildDrugSelector({
    required DrugModel? selectedDrug,
    required ValueChanged<DrugModel> onSelected,
    DrugModel? excludeDrug,
  }) {
    return GestureDetector(
      onTap: () => _showDrugPicker(onSelected, excludeDrug),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            Icon(
              Icons.medication_rounded,
              color: selectedDrug != null
                  ? AppColors.mintGreen
                  : AppColors.mutedText,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedDrug?.displayName ?? 'Select a drug…',
                style: TextStyle(
                  color: selectedDrug != null
                      ? AppColors.lightText
                      : AppColors.mutedText,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.mutedText, size: 20),
          ],
        ),
      ),
    );
  }

  void _showDrugPicker(
    ValueChanged<DrugModel> onSelected,
    DrugModel? excludeDrug,
  ) {
    final searchCtrl = TextEditingController();
    List<DrugModel> filtered = widget.allDrugs
        .where((d) => d.id != excludeDrug?.id)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (_, scrollController) => Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.mutedText,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: searchCtrl,
                      style: TextStyle(color: AppColors.lightText),
                      onChanged: (query) {
                        setSheetState(() {
                          filtered = widget.allDrugs
                              .where(
                                (d) =>
                                    d.id != excludeDrug?.id &&
                                    d.displayName.toLowerCase().contains(
                                      query.toLowerCase(),
                                    ),
                              )
                              .toList();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search drug…',
                        hintStyle: TextStyle(color: AppColors.mutedText),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.mutedText,
                        ),
                        filled: true,
                        fillColor: AppColors.cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final drug = filtered[i];
                        return ListTile(
                          leading: Icon(
                            Icons.medication_rounded,
                            color: AppColors.mintGreen,
                            size: 20,
                          ),
                          title: Text(
                            drug.displayName,
                            style: TextStyle(
                              color: AppColors.lightText,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: drug.category.isNotEmpty
                              ? Text(
                                  drug.category,
                                  style: TextStyle(
                                    color: AppColors.mutedText,
                                    fontSize: 11,
                                  ),
                                )
                              : null,
                          onTap: () {
                            onSelected(drug);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSeveritySelector() {
    const options = ['severe', 'moderate', 'mild'];
    return Row(
      children: options.map((s) {
        final isSelected = _severity == s;
        final color = _colorForSeverity(s);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: s != options.last ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _severity = s),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.2)
                      : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : AppColors.borderColor,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    s[0].toUpperCase() + s.substring(1),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : AppColors.mutedText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _colorForSeverity(String s) {
    switch (s) {
      case 'severe':
        return Colors.red.shade400;
      case 'moderate':
        return Colors.orange.shade400;
      default:
        return const Color(0xFF10B981);
    }
  }
}
