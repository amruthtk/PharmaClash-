import 'package:flutter/material.dart';
import '../models/drug_model.dart';
import '../theme/app_colors.dart';

class DrugDetailsScreen extends StatelessWidget {
  final DrugModel drug;

  const DrugDetailsScreen({super.key, required this.drug});

  @override
  Widget build(BuildContext context) {
    final displayTitle = drug.matchedBrandName ?? drug.displayName;
    return Scaffold(
      appBar: AppBar(
        title: Text(displayTitle.toUpperCase()),
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Info Header
            _buildInfoHeader(),
            const SizedBox(height: 32),

            // US-11 (Ingredient View) and US-12 (Restriction Library)
            _buildSafetyLibrary(drug),

            const SizedBox(height: 32),

            // Interaction History / Other Info
            _buildAdditionalInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: AppColors.primaryTeal,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drug.matchedBrandName ?? drug.displayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  drug.matchedBrandName != null
                      ? 'Generic: ${drug.displayName}'
                      : drug.category,
                  style: const TextStyle(
                    color: AppColors.grayText,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget for US-11 (Ingredient View) and US-12 (Restriction Library)
  Widget _buildSafetyLibrary(DrugModel drug) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // US-11: Active Ingredient View Module
        const Text(
          "CHEMICAL COMPOSITION",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.primaryTeal,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blueGrey.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              if (drug.activeIngredients.isEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      drug.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const Text(
                      "Generic",
                      style: TextStyle(color: Colors.blueGrey, fontSize: 13),
                    ),
                  ],
                )
              else
                ...drug.activeIngredients.map(
                  (ing) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ing.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          ing.strength ?? "",
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // NEW: Condition Warnings (Contraindications)
        const Text(
          "CONTRADICTIONS & WARNINGS",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.primaryTeal,
          ),
        ),
        const SizedBox(height: 12),
        if (drug.conditionWarnings.isEmpty)
          const Text(
            "No specific condition-based contraindications found in database.",
            style: TextStyle(
              color: AppColors.grayText,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          ...drug.conditionWarnings.map(
            (warning) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: Colors.orange.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.orange.withOpacity(0.2)),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                ),
                title: Text(
                  warning,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),

        // NEW: Drug-Drug Interactions
        const Text(
          "DRUG CLASHES (INTERACTIONS)",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.primaryTeal,
          ),
        ),
        const SizedBox(height: 12),
        if (drug.drugInteractions.isEmpty)
          const Text(
            "No known drug-drug interactions in database.",
            style: TextStyle(
              color: AppColors.grayText,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          ...drug.drugInteractions.map(
            (interaction) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color:
                  (interaction.severity == 'severe'
                          ? Colors.red
                          : Colors.orange)
                      .withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color:
                      (interaction.severity == 'severe'
                              ? Colors.red
                              : Colors.orange)
                          .withOpacity(0.2),
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.flash_on_rounded,
                  color: interaction.severity == 'severe'
                      ? Colors.red
                      : Colors.orange,
                ),
                title: Text(
                  interaction.drugName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(interaction.description),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (interaction.severity == 'severe'
                                ? Colors.red
                                : Colors.orange)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    interaction.severity.toUpperCase(),
                    style: TextStyle(
                      color: interaction.severity == 'severe'
                          ? Colors.red
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),

        // US-12: Food/Alcohol Restriction Library
        const Text(
          "FOOD & ALCOHOL RESTRICTIONS",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.primaryTeal,
          ),
        ),
        const SizedBox(height: 12),
        if (drug.foodInteractions.isEmpty && !drug.hasAlcoholWarning)
          const Text(
            "No specific food or alcohol restrictions known.",
            style: TextStyle(
              color: AppColors.grayText,
              fontStyle: FontStyle.italic,
            ),
          )
        else ...[
          ...drug.foodInteractions.map(
            (food) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: (food.severity == 'avoid' ? Colors.red : Colors.orange)
                  .withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: (food.severity == 'avoid' ? Colors.red : Colors.orange)
                      .withOpacity(0.2),
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.restaurant,
                  color: food.severity == 'avoid' ? Colors.red : Colors.orange,
                ),
                title: Text(
                  food.food,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(food.description),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ),
          if (drug.hasAlcoholWarning)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color:
                  (drug.alcoholRestriction == 'avoid'
                          ? Colors.red
                          : Colors.orange)
                      .withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color:
                      (drug.alcoholRestriction == 'avoid'
                              ? Colors.red
                              : Colors.orange)
                          .withOpacity(0.2),
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.local_bar,
                  color: drug.alcoholRestriction == 'avoid'
                      ? Colors.red
                      : Colors.orange,
                ),
                title: const Text(
                  "Alcohol Restriction",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  drug.alcoholWarningDescription ??
                      "Caution with alcohol intake.",
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildAdditionalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "PROFESSIONAL GUIDANCE",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.primaryTeal,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.inputBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            "Always consult with a healthcare professional before changing your medication regimen. This library is for informational purposes only.",
            style: TextStyle(fontSize: 13, color: AppColors.grayText),
          ),
        ),
      ],
    );
  }
}
