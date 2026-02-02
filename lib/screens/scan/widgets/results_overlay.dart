import 'package:flutter/material.dart';
import '../../../models/drug_model.dart';
import '../../../services/emergency_service.dart';
import '../../../services/drug_service.dart';
import '../../../theme/app_colors.dart';

/// Results overlay widget shown after user confirms drugs
/// Displays warnings, risk levels, and drug interactions
class ResultsOverlay extends StatelessWidget {
  final List<DrugWarningResult> verifiedDrugs;
  final VoidCallback onRescan;
  final VoidCallback onAddToCabinet;
  final VoidCallback onHighRiskOverride;
  final EmergencyService emergencyService;

  const ResultsOverlay({
    super.key,
    required this.verifiedDrugs,
    required this.onRescan,
    required this.onAddToCabinet,
    required this.onHighRiskOverride,
    required this.emergencyService,
  });

  /// Check if any verified drug has HIGH RISK warning
  bool get _hasHighRiskWarning {
    return verifiedDrugs.any((result) => result.riskLevel == 'high');
  }

  @override
  Widget build(BuildContext context) {
    final bool isHighRisk = _hasHighRiskWarning;

    return Positioned.fill(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: isHighRisk
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.red.shade900,
                    Colors.red.shade800,
                    Colors.red.shade700,
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.softWhite, AppColors.softWhite],
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 70),

              // HIGH RISK BANNER
              if (isHighRisk) _buildHighRiskBanner(),

              const SizedBox(height: 10),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: verifiedDrugs.length,
                  itemBuilder: (context, index) {
                    return _buildDrugResultCard(context, verifiedDrugs[index]);
                  },
                ),
              ),
              _buildResultActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighRiskBanner() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Pulsing warning icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: 1.2),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.dangerous_rounded,
                          size: 48,
                          color: Colors.red.shade700,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                Text(
                  '⚠️ DANGER - DO NOT TAKE ⚠️',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.red.shade700,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  'High-risk warning detected!\nContact your doctor or caregiver immediately.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade600,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrugResultCard(BuildContext context, DrugWarningResult result) {
    Color riskColor;
    IconData riskIcon;
    String riskLabel;

    switch (result.riskLevel) {
      case 'high':
        riskColor = Colors.red;
        riskIcon = Icons.dangerous_rounded;
        riskLabel = 'HIGH RISK - ALLERGY';
        break;
      case 'medium':
        riskColor = Colors.orange;
        riskIcon = Icons.warning_rounded;
        riskLabel = 'CAUTION - CONDITION';
        break;
      default:
        riskColor = AppColors.accentGreen;
        riskIcon = Icons.check_circle_rounded;
        riskLabel = 'SAFE TO USE';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: riskColor.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: riskColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(riskIcon, color: riskColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      riskLabel,
                      style: TextStyle(
                        color: riskColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.drug.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: AppColors.lightBorderColor),
          ),

          // Warnings
          if (result.hasWarnings) ...[
            if (result.matchedAllergies.isNotEmpty)
              _buildWarningSection(
                'ALLERGY WARNING',
                'Contains ${result.matchedAllergies.join(", ")} which matches your allergy profile.',
                Colors.red,
              ),
            if (result.matchedConditions.isNotEmpty)
              _buildWarningSection(
                'CONDITION WARNING',
                'May not be suitable for ${result.matchedConditions.join(", ")}.',
                Colors.orange,
              ),
            if (result.matchedDrugInteractions.isNotEmpty)
              ...result.matchedDrugInteractions.map(
                (interaction) => _buildWarningSection(
                  'DRUG INTERACTION',
                  'Interacts with ${interaction.drugName}: ${interaction.description}',
                  Colors.orange,
                ),
              ),
            if (result.hasDuplicateTherapy)
              ...result.matchedDuplicates.map(
                (duplicate) => _buildWarningSection(
                  'DUPLICATE THERAPY DETECTED',
                  'You are already taking ${duplicate.ingredientName} in "${duplicate.otherDrugName}". Taking both may cause an overdose.',
                  Colors.amber.shade800,
                ),
              ),
            if (result.drug.foodInteractions.isNotEmpty)
              ...result.drug.foodInteractions.map(
                (food) => _buildWarningSection(
                  'FOOD RESTRICTION',
                  '${food.food}: ${food.description}',
                  food.severity == 'avoid' ? Colors.red : Colors.amber,
                ),
              ),
            if (result.drug.hasAlcoholWarning)
              _buildWarningSection(
                'ALCOHOL WARNING',
                result.drug.alcoholWarningDescription ??
                    'Avoid alcohol while taking this medication.',
                result.drug.alcoholRestriction == 'avoid'
                    ? Colors.red
                    : Colors.amber,
              ),
            if (result.riskLevel == 'high')
              _buildEmergencyAlertButton(context, result),
          ] else ...[
            Center(
              child: Text(
                'No known issues found based on your profile.',
                style: TextStyle(
                  color: AppColors.accentGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWarningSection(String title, String message, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyAlertButton(
    BuildContext context,
    DrugWarningResult result,
  ) {
    final details = <String>[];
    if (result.matchedAllergies.isNotEmpty) {
      details.add('Allergy: ${result.matchedAllergies.join(", ")}');
    }
    if (result.matchedConditions.isNotEmpty) {
      details.add('Condition: ${result.matchedConditions.join(", ")}');
    }
    for (final interaction in result.matchedDrugInteractions) {
      details.add('Drug interaction: ${interaction.drugName}');
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: GestureDetector(
        onTap: () {
          emergencyService.showEmergencyOptions(
            context,
            drugName: result.drug.displayName,
            warningType: result.matchedAllergies.isNotEmpty
                ? 'Allergy Alert'
                : 'Health Warning',
            details: details,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade600, Colors.red.shade700],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notification_important_rounded,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Alert Caregiver',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultActions(BuildContext context) {
    final bool isHighRisk = _hasHighRiskWarning;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onRescan,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primaryTeal.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            color: AppColors.primaryTeal,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Scan Again',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: isHighRisk ? onHighRiskOverride : onAddToCabinet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isHighRisk
                              ? [Colors.grey.shade400, Colors.grey.shade500]
                              : [AppColors.primaryTeal, AppColors.deepTeal],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (isHighRisk
                                        ? Colors.grey
                                        : AppColors.primaryTeal)
                                    .withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isHighRisk
                                ? Icons.lock_outline
                                : Icons.medication_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isHighRisk ? 'Blocked' : 'Save to Cabinet',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (isHighRisk)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GestureDetector(
                  onTap: onHighRiskOverride,
                  child: Text(
                    "I need to add this anyway (Not Recommended)",
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
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
