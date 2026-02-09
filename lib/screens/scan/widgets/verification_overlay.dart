import 'package:flutter/material.dart';
import '../../../models/drug_model.dart';
import '../../../theme/app_colors.dart';
import 'drug_search_field.dart';

/// Verification overlay widget shown after OCR detects drugs
/// Allows user to confirm, add, or remove medications before analysis
class VerificationOverlay extends StatelessWidget {
  final List<DrugModel> detectedDrugs;
  final List<DrugModel> searchResults;
  final TextEditingController searchController;
  final VoidCallback onRescan;
  final VoidCallback onConfirm;
  final Function(DrugModel) onAddDrug;
  final Function(DrugModel) onRemoveDrug;

  const VerificationOverlay({
    super.key,
    required this.detectedDrugs,
    required this.searchResults,
    required this.searchController,
    required this.onRescan,
    required this.onConfirm,
    required this.onAddDrug,
    required this.onRemoveDrug,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: AppColors.softWhite,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 80),

              // Detected drugs section
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      _buildHeader(),
                      const SizedBox(height: 20),

                      // Detected drug cards
                      if (detectedDrugs.isEmpty)
                        _buildEmptyDetectionCard()
                      else
                        ...detectedDrugs.map(
                          (drug) => _buildDetectedDrugCard(drug),
                        ),

                      const SizedBox(height: 24),

                      // Manual search section
                      const Text(
                        'Not the right medicine?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grayText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DrugSearchField(
                        controller: searchController,
                        searchResults: searchResults,
                        detectedDrugs: detectedDrugs,
                        onAddDrug: onAddDrug,
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),

              // Action buttons
              _buildVerificationActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.document_scanner,
              color: AppColors.primaryTeal,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detected Medicine',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                Text(
                  'Please verify the scanned medicine is correct',
                  style: TextStyle(fontSize: 12, color: AppColors.grayText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDetectionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightBorderColor),
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
          Icon(Icons.search_off, size: 48, color: AppColors.grayText),
          const SizedBox(height: 12),
          const Text(
            'No medicine detected',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use the search below to find your medicine',
            style: TextStyle(fontSize: 13, color: AppColors.grayText),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedDrugCard(DrugModel drug) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Drug icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: drug.isCombination
                    ? [
                        Colors.purple.withValues(alpha: 0.15),
                        Colors.purple.withValues(alpha: 0.05),
                      ]
                    : [
                        AppColors.primaryTeal.withValues(alpha: 0.15),
                        AppColors.deepTeal.withValues(alpha: 0.05),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              drug.isCombination
                  ? Icons.layers_rounded
                  : Icons.medication_rounded,
              color: drug.isCombination
                  ? Colors.purple.shade400
                  : AppColors.primaryTeal,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),

          // Drug info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drug.displayName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                if (drug.brandNames.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    drug.brandNames.take(3).join(', '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.grayText,
                    ),
                  ),
                ],
                if (drug.isCombination &&
                    drug.activeIngredients.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '(${drug.ingredientsDisplay})',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.grayText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                // Category tag
                _buildCategoryTags(drug),
                // Dietary and Alcohol Warning Icons
                if (drug.hasDietaryWarning || drug.hasAlcoholWarning) ...[
                  const SizedBox(height: 8),
                  _buildWarningIcons(drug),
                ],
              ],
            ),
          ),

          // Remove button
          IconButton(
            onPressed: () => onRemoveDrug(drug),
            icon: Icon(Icons.close_rounded, color: Colors.red.shade500),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTags(DrugModel drug) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primaryTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            drug.category,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.primaryTeal,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (drug.isCombination) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'COMBO',
              style: TextStyle(
                fontSize: 9,
                color: Colors.purple.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWarningIcons(DrugModel drug) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (drug.hasDietaryWarning)
          ...drug.foodInteractions.map(
            (food) => _buildWarningIcon(
              icon: Icons.restaurant,
              label: food.food,
              severity: food.severity,
              isFood: true,
            ),
          ),
        if (drug.hasAlcoholWarning)
          _buildWarningIcon(
            icon: Icons.local_bar,
            // Changed from "Alcohol" to actionable text to avoid ambiguity
            label: _getAlcoholLabel(drug.alcoholRestriction),
            severity: drug.alcoholRestriction,
            isFood: false,
          ),
      ],
    );
  }

  String _getAlcoholLabel(String restriction) {
    switch (restriction.toLowerCase()) {
      case 'avoid':
        return 'Avoid Alcohol';
      case 'limit':
        return 'Limit Alcohol';
      case 'caution':
        return 'Alcohol Caution';
      default:
        return 'No Alcohol';
    }
  }

  Widget _buildWarningIcon({
    required IconData icon,
    required String label,
    required String severity,
    required bool isFood,
  }) {
    Color bgColor;
    Color iconColor;

    switch (severity.toLowerCase()) {
      case 'avoid':
        bgColor = Colors.red.shade100;
        iconColor = Colors.red.shade700;
        break;
      case 'caution':
        bgColor = Colors.orange.shade100;
        iconColor = Colors.orange.shade700;
        break;
      case 'limit':
        bgColor = Colors.amber.shade100;
        iconColor = Colors.amber.shade700;
        break;
      default:
        bgColor = Colors.grey.shade100;
        iconColor = Colors.grey.shade600;
    }

    return Tooltip(
      message: isFood ? '$label: $severity' : 'Alcohol: $severity',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 3),
            Text(
              label.length > 10 ? '${label.substring(0, 8)}...' : label,
              style: TextStyle(
                fontSize: 9,
                color: iconColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Rescan button
            Expanded(
              child: GestureDetector(
                onTap: onRescan,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.inputBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.lightBorderColor),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_rounded,
                        color: AppColors.grayText,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Rescan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grayText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Confirm button
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: detectedDrugs.isEmpty ? null : onConfirm,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: detectedDrugs.isEmpty
                        ? null
                        : const LinearGradient(
                            colors: [AppColors.primaryTeal, AppColors.deepTeal],
                          ),
                    color: detectedDrugs.isEmpty ? AppColors.inputBg : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: detectedDrugs.isEmpty
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.primaryTeal.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: detectedDrugs.isEmpty
                            ? AppColors.grayText
                            : Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Confirm & Check',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: detectedDrugs.isEmpty
                              ? AppColors.grayText
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
