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
  final VoidCallback onDeepSearch;
  final bool isAiSearching;

  const DrugSearchField({
    super.key,
    required this.controller,
    required this.searchResults,
    required this.detectedDrugs,
    required this.onAddDrug,
    required this.onDeepSearch,
    required this.isAiSearching,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(),

        // AI Searching Indicator
        if (isAiSearching)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryTeal,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Gemini AI is searching...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child:
              (searchResults.isNotEmpty ||
                  (controller.text.length >= 2 && !isAiSearching))
              ? Column(
                  children: [
                    const SizedBox(height: 12),
                    ...searchResults
                        .take(5)
                        .map((drug) => _buildSearchResultTile(drug)),

                    // Deep Search button if no match or as an extra option
                    if (searchResults.isEmpty &&
                        controller.text.length >= 2 &&
                        !isAiSearching)
                      _buildDeepSearchButton(),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildDeepSearchButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onDeepSearch,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryTeal.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primaryTeal,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Deep Search with AI',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      Text(
                        'Fetch details from our medical AI model',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.grayText,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.grayText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: controller,
      autofocus: false,
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

    // Prioritize brand name if it matches query
    final query = controller.text.toLowerCase();
    String? matchedBrand;
    if (query.isNotEmpty) {
      for (final brand in drug.brandNames) {
        if (brand.toLowerCase().contains(query)) {
          matchedBrand = brand;
          break;
        }
      }
    }

    final displayName = matchedBrand ?? drug.displayName;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAlreadyAdded
              ? null
              : () => onAddDrug(drug.copyWith(matchedBrandName: matchedBrand)),
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
                        displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
                      Text(
                        (drug.brandNames.any(
                              (b) => b.toLowerCase().contains(
                                controller.text.toLowerCase(),
                              ),
                            ))
                            ? 'Generic: ${drug.displayName}'
                            : drug.category,
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
