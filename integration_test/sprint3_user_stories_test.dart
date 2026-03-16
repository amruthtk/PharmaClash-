import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaclash/models/drug_model.dart';
import 'package:pharmaclash/services/drug_service.dart';

/// Sprint 3 Test Cases for PharmaClash
///
/// TC_S3_01: Verify severe drug-drug interaction (Clash)
/// TC_S3_02: Verify drug safety warning against user allergies (Cross-reactivity)
/// TC_S3_03: Verify drug safety warning against user chronic conditions

void main() {
  final drugService = DrugService();

  // ============================================================================
  // TC_S3_01: Verify severe drug-drug interaction (Clash)
  // Input Data: Drug A (Ibuprofen), Drug B (Warfarin)
  // Expected Result: Severe interaction should be detected
  // ============================================================================
  group('TC_S3_01: Drug-Drug Interaction Tests', () {
    test('Should detect severe interaction between Ibuprofen and Warfarin', () {
      final ibuprofen = DrugModel(
        displayName: 'Ibuprofen',
        brandNames: ['Brufen'],
        category: 'NSAID',
        drugInteractions: [
          DrugInteraction(
            drugName: 'Warfarin',
            severity: 'severe',
            description: 'Marked increase in bleeding risk',
          ),
        ],
      );

      final warfarin = DrugModel(
        displayName: 'Warfarin',
        brandNames: ['Coumadin'],
        category: 'Anticoagulant',
      );

      // Check Ibuprofen against Warfarin
      final result = drugService.checkDrugWarnings(ibuprofen, [], [], [
        warfarin,
      ]);

      expect(result.hasDrugInteraction, true);
      expect(result.matchedDrugInteractions.first.severity, 'severe');
      expect(result.riskLevel, 'high');
    });

    test('Should detect bidirectional interaction', () {
      // Even if Drug A doesn't list B, if B lists A, it should be caught
      final aspirin = DrugModel(
        displayName: 'Aspirin',
        brandNames: ['Ecosprin'],
        category: 'Antiplatelet',
        drugInteractions: [
          DrugInteraction(
            drugName: 'Ibuprofen',
            severity: 'severe',
            description: 'Ibuprofen blocks heart-protective effect of Aspirin',
          ),
        ],
      );

      final ibuprofen = DrugModel(
        displayName: 'Ibuprofen',
        brandNames: ['Brufen'],
        category: 'NSAID',
        drugInteractions: [], // Empty listing
      );

      final result = drugService.checkDrugWarnings(
        ibuprofen, // Scanned drug
        [],
        [],
        [aspirin], // Already in cabinet
      );

      expect(result.hasDrugInteraction, true);
      expect(
        result.matchedDrugInteractions.any(
          (m) => m.drugName.contains('Aspirin'),
        ),
        true,
      );
    });
  });

  // ============================================================================
  // TC_S3_02: Verify drug safety warning against user allergies
  // Input Data: User allergy (Penicillins), Drug (Amoxicillin)
  // Expected Result: Allergy warning should trigger (Cross-reactivity)
  // ============================================================================
  group('TC_S3_02: Drug-Allergy Interaction Tests', () {
    test(
      'Should detect cross-reactivity for Penicillin allergy with Amoxicillin',
      () {
        final amoxicillin = DrugModel(
          displayName: 'Amoxicillin',
          brandNames: ['Mox'],
          category: 'Antibiotic',
          activeIngredients: [ActiveIngredient(name: 'Amoxicillin')],
        );

        final userAllergies = ['Penicillins'];

        final result = drugService.checkDrugWarnings(
          amoxicillin,
          userAllergies,
          [],
          [],
        );

        expect(result.hasAllergyWarning, true);
        expect(result.matchedAllergies, contains('Penicillins'));
        expect(result.riskLevel, 'high');
      },
    );

    test('Should detect allergy match via brand names', () {
      final augmentin = DrugModel(
        displayName: 'Augmentin',
        brandNames: ['Augmentin', 'Clavam'],
        category: 'Antibiotic',
        activeIngredients: [
          ActiveIngredient(name: 'Amoxicillin'),
          ActiveIngredient(name: 'Clavulanic Acid'),
        ],
      );

      final userAllergies = ['Amoxicillin'];

      final result = drugService.checkDrugWarnings(
        augmentin,
        userAllergies,
        [],
        [],
      );

      expect(result.hasAllergyWarning, true);
      expect(result.matchedAllergies, contains('Amoxicillin'));
    });
  });

  // ============================================================================
  // TC_S3_03: Verify drug safety warning against user chronic conditions
  // Input Data: User condition (Hypertension), Drug (Sinarest - contains Phenylephrine)
  // Expected Result: Condition warning should be matched and displayed
  // ============================================================================
  group('TC_S3_03: Drug-Condition Interaction Tests', () {
    test('Should detect warning for Sinarest in Hypertension patients', () {
      final sinarest = DrugModel(
        displayName: 'Sinarest',
        brandNames: ['Coldarin'],
        category: 'Cold',
        conditionWarnings: [
          'High Blood Pressure: Phenylephrine raises BP dangerously',
          'Glaucoma: Can increase eye pressure',
        ],
      );

      final userConditions = ['Hypertension (High Blood Pressure)'];

      final result = drugService.checkDrugWarnings(
        sinarest,
        [],
        userConditions,
        [],
      );

      expect(result.hasConditionWarning, true);
      expect(
        result.matchedConditions.any((c) => c.contains('High Blood Pressure')),
        true,
        reason: 'Should match "High Blood Pressure" in user condition string',
      );
      expect(result.riskLevel, 'medium');
    });

    test('Should detect warning for Telma AM in Pregnancy', () {
      final telmaAM = DrugModel(
        displayName: 'Telma AM',
        brandNames: ['Telmikind AM'],
        category: 'BP Combination',
        conditionWarnings: ['Pregnancy: CONTRAINDICATED - causes fetal harm'],
      );

      final userConditions = ['Pregnancy'];

      final result = drugService.checkDrugWarnings(
        telmaAM,
        [],
        userConditions,
        [],
      );

      expect(result.hasConditionWarning, true);
      expect(
        result.matchedConditions,
        contains('Pregnancy: CONTRAINDICATED - causes fetal harm'),
      );
    });

    test(
      'Should detect duplicate therapy (Multiple drugs with same ingredient)',
      () {
        final paracetamol = DrugModel(
          displayName: 'Paracetamol',
          brandNames: [],
          activeIngredients: [ActiveIngredient(name: 'Paracetamol')],
          category: 'Analgesic',
        );

        final combiflam = DrugModel(
          displayName: 'Combiflam',
          brandNames: ['Combiflam'],
          activeIngredients: [
            ActiveIngredient(name: 'Ibuprofen'),
            ActiveIngredient(name: 'Paracetamol'),
          ],
          category: 'NSAID + Analgesic',
        );

        final result = drugService.checkDrugWarnings(combiflam, [], [], [
          paracetamol,
        ]);

        expect(result.hasDuplicateTherapy, true);
        expect(result.matchedDuplicates.first.displayName, 'Paracetamol');
      },
    );
  });
}
