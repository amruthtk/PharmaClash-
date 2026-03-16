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
  final VoidCallback onDeepSearch;
  final bool isAiSearching;

  const VerificationOverlay({
    super.key,
    required this.detectedDrugs,
    required this.searchResults,
    required this.searchController,
    required this.onRescan,
    required this.onConfirm,
    required this.onAddDrug,
    required this.onRemoveDrug,
    required this.onDeepSearch,
    required this.isAiSearching,
  });

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Positioned.fill(
      child: Container(
        color: AppColors.softWhite,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top Bar — NO indefinite spinner
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onRescan,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: AppColors.darkText,
                    ),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verify Scan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkText,
                            ),
                          ),
                          Text(
                            'Step 2 of 3 · Verify Medicines',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryTeal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Step indicator (replaces the old indefinite spinner)
                    _buildStepIndicator(),
                  ],
                ),
              ),

              // Progress bar
              _buildProgressBar(),

              // Detected drugs section
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + keyboardHeight),
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
                        onDeepSearch: onDeepSearch,
                        isAiSearching: isAiSearching,
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),

              // Action buttons — slides up smoothly with keyboard
              AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardHeight),
                child: _buildVerificationActions(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryTeal.withValues(alpha: 0.1),
            AppColors.deepTeal.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryTeal.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLabeledStep(
            label: 'Scan',
            stepNum: 1,
            isDone: true,
            isCurrent: false,
          ),
          _buildStepConnector(isDone: true),
          _buildLabeledStep(
            label: 'Verify',
            stepNum: 2,
            isDone: false,
            isCurrent: true,
          ),
          _buildStepConnector(isDone: false),
          _buildLabeledStep(
            label: 'Setup',
            stepNum: 3,
            isDone: false,
            isCurrent: false,
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledStep({
    required String label,
    required int stepNum,
    required bool isDone,
    required bool isCurrent,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStepDot(isDone: isDone, isCurrent: isCurrent),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isDone || isCurrent
                ? AppColors.primaryTeal
                : AppColors.grayText,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDot({required bool isDone, required bool isCurrent}) {
    return Container(
      width: isCurrent ? 12 : 8,
      height: isCurrent ? 12 : 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone
            ? AppColors.primaryTeal
            : isCurrent
            ? AppColors.primaryTeal
            : AppColors.lightBorderColor,
        border: isCurrent
            ? Border.all(
                color: AppColors.primaryTeal.withValues(alpha: 0.4),
                width: 2,
              )
            : null,
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: AppColors.primaryTeal.withValues(alpha: 0.3),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
      child: isDone
          ? const Icon(Icons.check, size: 6, color: Colors.white)
          : null,
    );
  }

  Widget _buildStepConnector({required bool isDone}) {
    return Container(
      width: 20,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isDone ? AppColors.primaryTeal : AppColors.lightBorderColor,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.lightBorderColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: 0.66,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryTeal, AppColors.mintGreen],
            ),
            borderRadius: BorderRadius.circular(2),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detectedDrugs.isEmpty
                      ? 'No Medicine Detected'
                      : '${detectedDrugs.length} Medicine${detectedDrugs.length > 1 ? 's' : ''} Found',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                Text(
                  detectedDrugs.isEmpty
                      ? 'Search manually below'
                      : 'Please verify before checking',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grayText,
                  ),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        drug.displayName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                    if (drug.isAiGenerated)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 10,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Gemini AI',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
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
                // Dietary, Alcohol, and Condition Warning Icons
                if (drug.hasDietaryWarning ||
                    drug.hasAlcoholWarning ||
                    drug.conditionWarnings.isNotEmpty) ...[
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
        if (drug.conditionWarnings.isNotEmpty)
          ...drug.conditionWarnings.map(
            (condition) => _buildWarningIcon(
              icon: Icons.warning_amber_rounded,
              label: condition
                  .split(':')
                  .first, // Showing only condition name for space
              severity: 'caution',
              isFood: false,
              isCondition: true,
            ),
          ),
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
    bool isCondition = false,
  }) {
    Color bgColor;
    Color iconColor;

    if (isCondition) {
      bgColor = Colors.orange.withValues(alpha: 0.1);
      iconColor = Colors.orange.shade800;
    } else {
      switch (severity.toLowerCase()) {
        case 'avoid':
          bgColor = Colors.red.withValues(alpha: 0.1);
          iconColor = Colors.red.shade700;
          break;
        case 'caution':
          bgColor = Colors.orange.withValues(alpha: 0.1);
          iconColor = Colors.orange.shade700;
          break;
        case 'limit':
          bgColor = Colors.amber.withValues(alpha: 0.1);
          iconColor = Colors.amber.shade700;
          break;
        default:
          bgColor = Colors.grey.withValues(alpha: 0.1);
          iconColor = Colors.grey.shade600;
      }
    }

    return Tooltip(
      message: isCondition
          ? 'Contradiction: $label'
          : (isFood ? '$label: $severity' : 'Alcohol: $severity'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: iconColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label.length > 15 ? '${label.substring(0, 12)}...' : label,
              style: TextStyle(
                fontSize: 10,
                color: iconColor,
                fontWeight: FontWeight.w700,
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
