import 'package:flutter/material.dart';
import '../../../models/drug_model.dart';
import '../../../theme/app_colors.dart';

/// Drug search field widget for manual drug entry
/// Provides search input and displays results list
class DrugSearchField extends StatelessWidget {
  final TextEditingController controller;
  final List<DrugModel> searchResults;
  final List<DrugModel> detectedDrugs;
  final Function(DrugModel) onAddDrug;

  const DrugSearchField({
    super.key,
    required this.controller,
    required this.searchResults,
    required this.detectedDrugs,
    required this.onAddDrug,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(),
        if (searchResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...searchResults.take(5).map((drug) => _buildSearchResultTile(drug)),
        ],
      ],
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: controller,
      autofocus: true, // Auto-show keyboard when entering manual search
      style: const TextStyle(color: AppColors.darkText),
      decoration: InputDecoration(
        hintText: 'Search medicine by name...',
        hintStyle: TextStyle(color: AppColors.grayText.withValues(alpha: 0.7)),
        prefixIcon: const Icon(Icons.search, color: AppColors.grayText),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.grayText,
                onPressed: () => controller.clear(),
              )
            : null,
        filled: true,
        fillColor: AppColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.lightBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.lightBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildSearchResultTile(DrugModel drug) {
    final isAlreadyAdded = detectedDrugs.contains(drug);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAlreadyAdded ? null : () => onAddDrug(drug),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isAlreadyAdded
                  ? AppColors.primaryTeal.withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isAlreadyAdded
                    ? AppColors.primaryTeal.withValues(alpha: 0.3)
                    : AppColors.lightBorderColor,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAlreadyAdded
                      ? Icons.check_circle
                      : Icons.add_circle_outline,
                  color: AppColors.primaryTeal,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drug.displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
                      Text(
                        drug.category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.grayText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAlreadyAdded)
                  const Text(
                    'Added',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryTeal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
