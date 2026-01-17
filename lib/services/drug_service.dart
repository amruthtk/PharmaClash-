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

    // Split into words and enhance
    final words = lowerText
        .split(RegExp(r'[\s\n\r,.:;!?()]+'))
        .where((w) => w.length >= 3)
        .toList();

    final enhancedWords = <String>[];
    for (final word in words) {
      enhancedWords.add(word);
      final alphaOnly = word.replaceAll(RegExp(r'[0-9]'), '');
      if (alphaOnly.length >= 3 && !enhancedWords.contains(alphaOnly)) {
        enhancedWords.add(alphaOnly);
      }
      if (word.contains('-')) {
        for (final part in word.split('-')) {
          if (part.length >= 3 && !enhancedWords.contains(part)) {
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
      bool found = false;

      // Check brand names first (most specific match)
      for (final brand in drug.brandNames) {
        final brandLower = brand.toLowerCase();
        // Remove spaces and hyphens for flexible matching
        final brandClean = brandLower.replaceAll(RegExp(r'[-\s]'), '');

        if (lowerText.contains(brandLower) || lowerText.contains(brandClean)) {
          found = true;
          break;
        }

        // Check if any word matches brand
        for (final word in enhancedWords) {
          if (word.length >= 4) {
            if (brandLower.startsWith(word) || brandClean.startsWith(word)) {
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
        foundDrugs.add(drug);
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

      bool found = false;

      // Check generic name
      if (lowerText.contains(genericLower)) {
        found = true;
      }

      // Check words against generic name
      if (!found) {
        for (final word in enhancedWords) {
          if (word.length >= 3 && word == genericLower) {
            found = true;
            break;
          }
          if (genericLower.startsWith(word) && word.length >= 4) {
            found = true;
            break;
          }
        }
      }

      // Check brand names
      if (!found) {
        for (final brand in drug.brandNames) {
          final brandLower = brand.toLowerCase();
          if (lowerText.contains(brandLower)) {
            found = true;
            break;
          }
          for (final word in enhancedWords) {
            if (word.length >= 3) {
              if (word == brandLower ||
                  word.startsWith(brandLower) ||
                  brandLower.startsWith(word)) {
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
          foundDrugs.add(drug);
        }
      }
    }

    return foundDrugs;
  }

  /// Check drug warnings against user profile
  DrugWarningResult checkDrugWarnings(
    DrugModel drug,
    List<String> userAllergies,
    List<String> userConditions,
    List<DrugModel> otherDrugs,
  ) {
    final allergyMatches = <String>[];
    final conditionMatches = <String>[];
    final drugMatches = <DrugInteraction>[];
    final foodMatches = drug.foodInteractions;

    // Check allergies
    for (final warning in drug.allergyWarnings) {
      if (userAllergies.any((a) => a.toLowerCase() == warning.toLowerCase())) {
        allergyMatches.add(warning);
      }
    }

    // Check conditions
    for (final warning in drug.conditionWarnings) {
      if (userConditions.any((c) => c.toLowerCase() == warning.toLowerCase())) {
        conditionMatches.add(warning);
      }
    }

    // Check drug-drug interactions
    for (final interaction in drug.drugInteractions) {
      for (final otherDrug in otherDrugs) {
        if (otherDrug.genericName.toLowerCase() ==
                interaction.drugName.toLowerCase() ||
            otherDrug.brandNames.any(
              (b) => b.toLowerCase() == interaction.drugName.toLowerCase(),
            )) {
          drugMatches.add(interaction);
        }
      }
    }

    return DrugWarningResult(
      drug: drug,
      matchedAllergies: allergyMatches,
      matchedConditions: conditionMatches,
      matchedDrugInteractions: drugMatches,
      foodInteractions: foodMatches,
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
  final List<String> matchedAllergies;
  final List<String> matchedConditions;
  final List<DrugInteraction> matchedDrugInteractions;
  final List<FoodInteraction> foodInteractions;

  DrugWarningResult({
    required this.drug,
    required this.matchedAllergies,
    required this.matchedConditions,
    required this.matchedDrugInteractions,
    required this.foodInteractions,
  });

  bool get hasWarnings =>
      matchedAllergies.isNotEmpty ||
      matchedConditions.isNotEmpty ||
      matchedDrugInteractions.isNotEmpty;

  bool get hasAllergyWarning => matchedAllergies.isNotEmpty;
  bool get hasConditionWarning => matchedConditions.isNotEmpty;
  bool get hasDrugInteraction => matchedDrugInteractions.isNotEmpty;
  bool get hasFoodWarning => foodInteractions.isNotEmpty;

  String get riskLevel {
    if (matchedAllergies.isNotEmpty) return 'high';
    if (matchedDrugInteractions.any((d) => d.severity == 'severe')) {
      return 'high';
    }
    if (matchedConditions.isNotEmpty) return 'medium';
    if (matchedDrugInteractions.isNotEmpty) return 'medium';
    return 'low';
  }
}
