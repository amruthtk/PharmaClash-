import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/drug_model.dart';

/// Service for managing drugs in Firebase Firestore
class DrugService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'drugs';

  // Singleton pattern
  static final DrugService _instance = DrugService._internal();
  factory DrugService() => _instance;
  DrugService._internal();

  // Cache for drugs
  List<DrugModel>? _cachedDrugs;
  DateTime? _lastFetch;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Get all drugs from Firestore
  Future<List<DrugModel>> getAllDrugs({bool forceRefresh = false}) async {
    // Check cache
    if (!forceRefresh &&
        _cachedDrugs != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheExpiry) {
      return _cachedDrugs!;
    }

    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('genericName')
          .get();

      _cachedDrugs = snapshot.docs
          .map((doc) => DrugModel.fromMap(doc.data(), doc.id))
          .toList();
      _lastFetch = DateTime.now();

      return _cachedDrugs!;
    } catch (e) {
      debugPrint('Error fetching drugs: $e');
      return _cachedDrugs ?? [];
    }
  }

  /// Get a single drug by ID
  Future<DrugModel?> getDrug(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return DrugModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching drug: $e');
      return null;
    }
  }

  /// Get a single drug by name
  Future<DrugModel?> getDrugByName(String name) async {
    try {
      final drugs = await getAllDrugs();
      final lowerName = name.toLowerCase();

      // Try exact match on displayName first
      for (final drug in drugs) {
        if (drug.displayName.toLowerCase() == lowerName) return drug;
      }

      // Try brand names
      for (final drug in drugs) {
        if (drug.brandNames.any((b) => b.toLowerCase() == lowerName)) {
          return drug;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching drug by name: $e');
      return null;
    }
  }

  /// Add a new drug
  Future<String?> addDrug(DrugModel drug) async {
    try {
      final docRef = await _firestore.collection(_collection).add(drug.toMap());
      _invalidateCache();
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding drug: $e');
      return null;
    }
  }

  /// Update an existing drug
  Future<bool> updateDrug(DrugModel drug) async {
    if (drug.id == null) return false;

    try {
      await _firestore
          .collection(_collection)
          .doc(drug.id)
          .update(drug.toMap());
      _invalidateCache();
      return true;
    } catch (e) {
      debugPrint('Error updating drug: $e');
      return false;
    }
  }

  /// Delete a drug
  Future<bool> deleteDrug(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      _invalidateCache();
      return true;
    } catch (e) {
      debugPrint('Error deleting drug: $e');
      return false;
    }
  }

  /// Search drugs by name (generic or brand)
  Future<List<DrugModel>> searchDrugs(String query) async {
    final drugs = await getAllDrugs();
    final lowerQuery = query.toLowerCase();

    return drugs.where((drug) {
      if (drug.genericName.toLowerCase().contains(lowerQuery)) return true;
      if (drug.brandNames.any((b) => b.toLowerCase().contains(lowerQuery))) {
        return true;
      }
      return false;
    }).toList();
  }

  /// Find drugs in OCR text (for scan feature)
  /// Prioritizes combination drugs and excludes individual ingredients when a combo is found
  Future<List<DrugModel>> findDrugsInText(String ocrText) async {
    final drugs = await getAllDrugs();
    final foundDrugs = <DrugModel>[];
    final lowerText = ocrText.toLowerCase();

    // Common noise words found on medicine strips that should NOT trigger matches.
    // These include manufacturer names, dosage terms, instructions, regulatory text, etc.
    const noiseWords = <String>{
      // Manufacturer / company names
      'micro', 'labs', 'limited', 'pharma', 'cipla', 'sun', 'lupin', 'intas',
      'zydus', 'cadila', 'torrent', 'alkem', 'abbott', 'biocon', 'glenmark',
      'ranbaxy', 'hetero', 'wockhardt', 'ipca', 'ajanta', 'mankind',
      // Dosage form / strip text
      'tablet', 'tablets', 'capsule', 'capsules', 'syrup', 'injection',
      'cream', 'ointment', 'drops', 'strip', 'blister', 'pack',
      'film', 'coated', 'uncoated', 'sustained', 'release', 'modified',
      // Instructions / labels
      'store', 'dosage', 'directed', 'physician', 'temperature', 'overdose',
      'injurious', 'health', 'children', 'reach', 'below', 'protect',
      'light', 'moisture', 'batch', 'mfg', 'date', 'expiry', 'price',
      'schedule', 'drug', 'composition', 'each', 'contains', 'excipients',
      'colour', 'color', 'suitable', 'quantity', 'sufficient',
      // Regulatory text
      'indian', 'pharmacopoeia', 'not', 'exceeding',
    };

    // Split into words and enhance
    final words = lowerText
        .split(RegExp(r'[\s\n\r,.:;!?()]+'))
        .where((w) => w.length >= 3)
        .toList();

    final enhancedWords = <String>[];
    for (final word in words) {
      if (!noiseWords.contains(word)) {
        enhancedWords.add(word);
      }
      final alphaOnly = word.replaceAll(RegExp(r'[0-9]'), '');
      if (alphaOnly.length >= 3 &&
          !enhancedWords.contains(alphaOnly) &&
          !noiseWords.contains(alphaOnly)) {
        enhancedWords.add(alphaOnly);
      }
      if (word.contains('-')) {
        for (final part in word.split('-')) {
          if (part.length >= 3 &&
              !enhancedWords.contains(part) &&
              !noiseWords.contains(part)) {
            enhancedWords.add(part);
          }
        }
      }
    }

    // Separate combo drugs from single drugs
    final comboDrugs = drugs.where((d) => d.isCombination).toList();
    final singleDrugs = drugs.where((d) => !d.isCombination).toList();

    // Track matched ingredient names from combos
    final matchedIngredients = <String>{};

    // FIRST: Check combo drugs (priority)
    for (final drug in comboDrugs) {
      String? matchedName;
      bool found = false;

      // Check brand names first (most specific match)
      for (final brand in drug.brandNames) {
        final brandLower = brand.toLowerCase();
        final brandClean = brandLower.replaceAll(RegExp(r'[-\s]'), '');

        if (lowerText.contains(brandLower) || lowerText.contains(brandClean)) {
          matchedName = brand;
          found = true;
          break;
        }

        // Check if any word matches brand (strict: 80% coverage, min 6 chars)
        for (final word in enhancedWords) {
          if (word.length >= 6) {
            if ((brandLower.startsWith(word) || brandClean.startsWith(word)) &&
                word.length >= (brandLower.length * 0.8).ceil()) {
              matchedName = brand;
              found = true;
              break;
            }
          }
        }
        if (found) break;
      }

      // Check if multiple ingredients are mentioned
      if (!found && drug.activeIngredients.isNotEmpty) {
        int ingredientMatches = 0;
        for (final ingredient in drug.activeIngredients) {
          final ingredientLower = ingredient.name.toLowerCase();
          if (lowerText.contains(ingredientLower)) {
            ingredientMatches++;
          }
        }
        // If 2+ ingredients match, it's likely this combo
        if (ingredientMatches >= 2) {
          found = true;
        }
      }

      // Check display name
      if (!found) {
        final displayLower = drug.displayName.toLowerCase();
        // Split combo name by + and check each part
        final parts = displayLower.split('+').map((p) => p.trim()).toList();
        int matchedParts = 0;
        for (final part in parts) {
          if (lowerText.contains(part)) {
            matchedParts++;
          }
        }
        if (matchedParts >= 2) {
          found = true;
        }
      }

      if (found && !foundDrugs.contains(drug)) {
        foundDrugs.add(drug.copyWith(matchedBrandName: matchedName));
        // Track the ingredients so we don't match them individually
        for (final ingredient in drug.activeIngredients) {
          matchedIngredients.add(ingredient.name.toLowerCase());
        }
      }
    }

    // SECOND: Check single drugs (but skip if already matched in a combo)
    for (final drug in singleDrugs) {
      final genericLower = drug.genericName.toLowerCase();

      // Skip if this ingredient is already in a matched combo
      if (matchedIngredients.contains(genericLower)) {
        continue;
      }

      String? matchedName;
      bool found = false;

      // Check generic name — require full generic name match in text
      if (lowerText.contains(genericLower)) {
        found = true;
      }

      // Check words against generic name (strict: 80% coverage, min 6 chars)
      if (!found) {
        for (final word in enhancedWords) {
          if (word.length >= 6 &&
              (genericLower.startsWith(word) || word == genericLower) &&
              word.length >= (genericLower.length * 0.8).ceil()) {
            found = true;
            break;
          }
        }
      }

      // Check brand names
      if (!found) {
        for (final brand in drug.brandNames) {
          final brandLower = brand.toLowerCase();
          // Full brand name found as substring in OCR text
          if (lowerText.contains(brandLower)) {
            matchedName = brand;
            found = true;
            break;
          }
          // Strict prefix match on non-noise words (80% coverage, min 6 chars)
          for (final word in enhancedWords) {
            if (word.length >= 6) {
              if (word == brandLower ||
                  (brandLower.startsWith(word) &&
                      word.length >= (brandLower.length * 0.8).ceil())) {
                matchedName = brand;
                found = true;
                break;
              }
            }
          }
          if (found) break;
        }
      }

      if (found && !foundDrugs.contains(drug)) {
        // Check if a drug with similar name already exists (prevent duplicates)
        final normalizedName = drug.displayName.toLowerCase().replaceAll(
          RegExp(r'[\s+]'),
          '',
        );
        final isDuplicate = foundDrugs.any((d) {
          final existingName = d.displayName.toLowerCase().replaceAll(
            RegExp(r'[\s+]'),
            '',
          );
          return existingName == normalizedName ||
              existingName.contains(normalizedName) ||
              normalizedName.contains(existingName);
        });

        if (!isDuplicate) {
          foundDrugs.add(drug.copyWith(matchedBrandName: matchedName));
        }
      }
    }

    return foundDrugs;
  }

  /// Find drugs in OCR text (offline version)
  /// Uses cached drugs if available
  Future<List<DrugModel>> findDrugsInTextOffline(String ocrText) async {
    // For now, offline search uses the same logic but avoids forced refresh
    // In a real app, this might use a local SQLite database or heavily cached data
    return findDrugsInText(ocrText);
  }

  /// Check drug warnings against user profile
  DrugWarningResult checkDrugWarnings(
    DrugModel drug,
    List<String> userAllergies,
    List<String> userConditions,
    List<DrugModel> otherDrugs,
  ) {
    final allergyMatches = <String>[];
    final classAllergyMatches = <String>[];
    final conditionMatches = <String>[];
    final drugMatches = <DrugInteraction>[];
    final foodMatches = drug.foodInteractions;

    // Cross-reactivity mapping — drug class groups
    final Map<String, List<String>> crossReactivity = {
      'penicillin': [
        'amoxicillin',
        'ampicillin',
        'penicillin',
        'cloxacillin',
        'dicloxacillin',
        'augmentin',
        'piperacillin',
      ],
      'cephalosporin': [
        'cephalexin',
        'cefixime',
        'cefuroxime',
        'ceftriaxone',
        'cefpodoxime',
        'cefdinir',
        'cephalosporin',
      ],
      'nsaid': [
        'ibuprofen',
        'aspirin',
        'naproxen',
        'diclofenac',
        'celecoxib',
        'aceclofenac',
        'piroxicam',
        'indomethacin',
      ],
      'sulfa': ['sulfamethoxazole', 'sulfonylureas', 'bactrim', 'septra'],
      'macrolide': [
        'azithromycin',
        'erythromycin',
        'clarithromycin',
        'roxithromycin',
      ],
      'fluoroquinolone': [
        'ciprofloxacin',
        'levofloxacin',
        'moxifloxacin',
        'ofloxacin',
      ],
      'tetracycline': ['doxycycline', 'tetracycline', 'minocycline'],
      'opioid': ['morphine', 'codeine', 'tramadol', 'fentanyl', 'oxycodone'],
      'statin': ['atorvastatin', 'rosuvastatin', 'simvastatin', 'lovastatin'],
      'ace_inhibitor': ['lisinopril', 'enalapril', 'ramipril', 'captopril'],
      'arb': ['telmisartan', 'losartan', 'valsartan', 'olmesartan'],
      'anticonvulsant': [
        'phenytoin',
        'carbamazepine',
        'lamotrigine',
        'valproate',
      ],
    };

    // Check allergies
    for (final allergy in userAllergies) {
      final allergyLower = allergy.toLowerCase().trim();
      // Strip parenthetical text for matching: "Aspirin (Salicylates)" -> "aspirin"
      final allergyCore = allergyLower
          .replaceAll(RegExp(r'\s*\(.*?\)\s*'), '')
          .trim();

      bool matched = false;
      bool isClassMatch = false;

      // 1. Direct match in drug's allergyWarnings list
      matched = drug.allergyWarnings.any((w) {
        final warningLower = w.toLowerCase().trim();
        return warningLower == allergyLower ||
            warningLower == allergyCore ||
            warningLower.contains(allergyCore) ||
            allergyCore.contains(warningLower);
      });

      // 2. Check displayName (generic name)
      if (!matched) {
        final displayNameLower = drug.displayName.toLowerCase().trim();
        if (displayNameLower.contains(allergyCore) ||
            allergyCore.contains(displayNameLower)) {
          matched = true;
        }
      }

      // 3. Check ALL brand names
      if (!matched) {
        for (final brand in drug.brandNames) {
          final brandLower = brand.toLowerCase().trim();
          if (brandLower.contains(allergyCore) ||
              allergyCore.contains(brandLower)) {
            matched = true;
            break;
          }
        }
      }

      // 4. Check active ingredients
      if (!matched) {
        for (final ingredient in drug.activeIngredients) {
          final ingLower = ingredient.name.toLowerCase().trim();
          if (ingLower.contains(allergyCore) ||
              allergyCore.contains(ingLower)) {
            matched = true;
            break;
          }
        }
      }

      // 5. Class-based cross-reactivity check
      if (!matched) {
        for (final entry in crossReactivity.entries) {
          final groupName = entry.key;
          final relatedDrugs = entry.value;

          // Check if user's allergy matches the group name OR any drug in the group
          final allergyMatchesGroup =
              allergyCore.contains(groupName) ||
              relatedDrugs.any(
                (d) => allergyCore.contains(d) || d.contains(allergyCore),
              );

          if (allergyMatchesGroup) {
            // Check if the scanned drug is in that group
            final drugDisplayLower = drug.displayName.toLowerCase();
            final isRelated =
                drugDisplayLower.contains(groupName) ||
                relatedDrugs.any((d) => drugDisplayLower.contains(d)) ||
                drug.brandNames.any(
                  (b) => relatedDrugs.any((d) => b.toLowerCase().contains(d)),
                ) ||
                drug.activeIngredients.any(
                  (ing) => relatedDrugs.any(
                    (d) => ing.name.toLowerCase().contains(d),
                  ),
                );

            if (isRelated) {
              matched = true;
              isClassMatch = true;
              break;
            }
          }
        }
      }

      if (matched) {
        if (isClassMatch) {
          classAllergyMatches.add(allergy);
        } else {
          allergyMatches.add(allergy);
        }
      }
    }

    // Check conditions — use partial matching to handle verbose condition names
    // e.g., user has "Peptic Ulcer Disease" and drug warns about "Peptic Ulcer"
    for (final warning in drug.conditionWarnings) {
      final warningLower = warning.toLowerCase().trim();
      if (userConditions.any((c) {
        final condLower = c.toLowerCase().trim();
        return condLower == warningLower ||
            condLower.contains(warningLower) ||
            warningLower.contains(condLower);
      })) {
        conditionMatches.add(warning);
      }
    }

    // --- Special Class-based Condition Checks (Fail-safe) ---
    // User Context: User has heart issues and is pregnant.
    // Logic: If the drug is an NSAID, automatically check for CV and Pregnancy risks.
    final drugCategoryLower = drug.category.toLowerCase();
    if (drugCategoryLower.contains('nsaid')) {
      final highRiskConditions = [
        'Heart Failure',
        'History of Myocardial Infarction (Heart Attack)',
        'Coronary Artery Disease',
        'Pregnancy',
      ];

      for (final riskCond in highRiskConditions) {
        if (userConditions.any(
          (uc) => uc.toLowerCase().contains(riskCond.toLowerCase()),
        )) {
          // Add if not already explicitly matched
          final exists = conditionMatches.any(
            (cm) => cm.toLowerCase().contains(riskCond.toLowerCase()),
          );
          if (!exists) {
            conditionMatches.add(
              'Class Warning (NSAID): High risk for $riskCond',
            );
          }
        }
      }
    }
    // --------------------------------------------------------

    // Check drug-drug interactions (bidirectional)
    for (final interaction in drug.drugInteractions) {
      final interactionNameLower = interaction.drugName.toLowerCase().trim();
      for (final otherDrug in otherDrugs) {
        final otherDisplayLower = otherDrug.displayName.toLowerCase().trim();
        final otherGenericLower = otherDrug.genericName.toLowerCase().trim();

        if (otherDisplayLower == interactionNameLower ||
            otherGenericLower == interactionNameLower ||
            otherDisplayLower.contains(interactionNameLower) ||
            interactionNameLower.contains(otherDisplayLower) ||
            otherDrug.brandNames.any((b) {
              final bLower = b.toLowerCase().trim();
              return bLower == interactionNameLower ||
                  bLower.contains(interactionNameLower) ||
                  interactionNameLower.contains(bLower);
            }) ||
            otherDrug.activeIngredients.any((ing) {
              final ingLower = ing.name.toLowerCase().trim();
              return ingLower == interactionNameLower ||
                  ingLower.contains(interactionNameLower) ||
                  interactionNameLower.contains(ingLower);
            })) {
          drugMatches.add(interaction);
          break; // prevent duplicates for same interaction
        }
      }
    }

    // Bidirectional: also check if OTHER drugs have interactions with THIS drug
    for (final otherDrug in otherDrugs) {
      for (final interaction in otherDrug.drugInteractions) {
        final interactionNameLower = interaction.drugName.toLowerCase().trim();
        final drugDisplayLower = drug.displayName.toLowerCase().trim();

        // Skip if already matched (check both generic and brand name matches)
        bool alreadyMatched = drugMatches.any((m) {
          final existingName = m.drugName.toLowerCase().trim();
          return existingName == interactionNameLower ||
              existingName == otherDrug.displayName.toLowerCase().trim() ||
              interactionNameLower ==
                  otherDrug.displayName.toLowerCase().trim();
        });

        if (alreadyMatched) continue;

        if (drugDisplayLower == interactionNameLower ||
            drugDisplayLower.contains(interactionNameLower) ||
            interactionNameLower.contains(drugDisplayLower) ||
            drug.brandNames.any((b) {
              final bLower = b.toLowerCase().trim();
              return bLower == interactionNameLower ||
                  bLower.contains(interactionNameLower) ||
                  interactionNameLower.contains(bLower);
            }) ||
            drug.activeIngredients.any((ing) {
              final ingLower = ing.name.toLowerCase().trim();
              return ingLower == interactionNameLower ||
                  ingLower.contains(interactionNameLower) ||
                  interactionNameLower.contains(ingLower);
            })) {
          // Add with the other drug's name for better messaging
          drugMatches.add(
            DrugInteraction(
              drugName: otherDrug.displayName,
              severity: interaction.severity,
              description: interaction.description,
            ),
          );
          break;
        }
      }
    }

    // Check duplicate therapy
    final duplicateMatches = <DrugModel>[];
    for (final otherDrug in otherDrugs) {
      // Check if they share any active ingredients
      final otherIngredients = otherDrug.activeIngredients
          .map((i) => i.name.toLowerCase())
          .toSet();
      final currentIngredients = drug.activeIngredients
          .map((i) => i.name.toLowerCase())
          .toSet();

      if (currentIngredients.intersection(otherIngredients).isNotEmpty) {
        duplicateMatches.add(otherDrug);
      }
    }

    return DrugWarningResult(
      drug: drug,
      matchedAllergies: allergyMatches,
      matchedClassAllergies: classAllergyMatches,
      matchedConditions: conditionMatches,
      matchedDrugInteractions: drugMatches,
      foodInteractions: foodMatches,
      matchedDuplicates: duplicateMatches,
    );
  }

  /// Get drug count
  Future<int> getDrugCount() async {
    final drugs = await getAllDrugs();
    return drugs.length;
  }

  /// Get drugs by category
  Future<List<DrugModel>> getDrugsByCategory(String category) async {
    final drugs = await getAllDrugs();
    return drugs.where((d) => d.category == category).toList();
  }

  /// Get all unique categories
  Future<List<String>> getCategories() async {
    final drugs = await getAllDrugs();
    final categories = drugs.map((d) => d.category).toSet().toList();
    categories.sort();
    return categories;
  }

  void _invalidateCache() {
    _cachedDrugs = null;
    _lastFetch = null;
  }
}

/// Result of drug warning check
class DrugWarningResult {
  final DrugModel drug;
  final List<String> matchedAllergies; // Direct ingredient/brand match
  final List<String> matchedClassAllergies; // Group/Class-based sensitivity
  final List<String> matchedConditions;
  final List<DrugInteraction> matchedDrugInteractions;
  final List<FoodInteraction> foodInteractions;
  final List<DrugModel> matchedDuplicates;

  DrugWarningResult({
    required this.drug,
    required this.matchedAllergies,
    required this.matchedClassAllergies,
    required this.matchedConditions,
    required this.matchedDrugInteractions,
    required this.foodInteractions,
    this.matchedDuplicates = const [],
  });

  bool get hasWarnings =>
      matchedAllergies.isNotEmpty ||
      matchedClassAllergies.isNotEmpty ||
      matchedConditions.isNotEmpty ||
      matchedDrugInteractions.isNotEmpty ||
      matchedDuplicates.isNotEmpty ||
      foodInteractions.isNotEmpty ||
      drug.hasAlcoholWarning;

  bool get hasAllergyWarning =>
      matchedAllergies.isNotEmpty || matchedClassAllergies.isNotEmpty;
  bool get hasDirectAllergy => matchedAllergies.isNotEmpty;
  bool get hasClassAllergy => matchedClassAllergies.isNotEmpty;
  bool get hasConditionWarning => matchedConditions.isNotEmpty;
  bool get hasDrugInteraction => matchedDrugInteractions.isNotEmpty;
  bool get hasFoodWarning => foodInteractions.isNotEmpty;
  bool get hasDuplicateTherapy => matchedDuplicates.isNotEmpty;

  String get riskLevel {
    // 1. Direct allergies are always high risk
    if (matchedAllergies.isNotEmpty) return 'high';

    // 2. Severe drug interactions are high risk
    if (matchedDrugInteractions.any(
      (d) => d.severity.toLowerCase() == 'severe',
    )) {
      return 'high';
    }

    // 3. Check for contraindications in condition warnings
    final isContraindicated = matchedConditions.any((c) {
      final lower = c.toLowerCase();
      // Expanded keyword list for high-risk detection
      return lower.contains('contraindicated') ||
          lower.contains('avoid') ||
          lower.contains('highly toxic') ||
          lower.contains('fatal') ||
          lower.contains('severe') ||
          lower.contains('danger') ||
          lower.contains('risk of harm') ||
          lower.contains('fetal harm');
    });
    if (isContraindicated) return 'high';

    // 4. Moderate interactions, conditions, or any food/alcohol risks are medium risk
    if (matchedConditions.isNotEmpty) return 'medium';
    if (matchedDrugInteractions.isNotEmpty) return 'medium';
    if (matchedDuplicates.isNotEmpty) return 'medium';
    if (drug.hasAlcoholWarning) return 'medium';
    if (foodInteractions.isNotEmpty) return 'medium';

    // 6. Food or mild restrictions are low risk
    if (hasWarnings) return 'low';

    return 'none';
  }
}
