// Drug model for Firestore database
// This model represents a drug with all its interaction data
// Supports both single-ingredient and combination medicines

/// Represents an active ingredient in a combination medicine
class ActiveIngredient {
  final String name;
  final String? strength; // e.g., "400mg", "325mg"

  ActiveIngredient({required this.name, this.strength});

  Map<String, dynamic> toMap() {
    return {'name': name, 'strength': strength};
  }

  factory ActiveIngredient.fromMap(Map<String, dynamic> map) {
    return ActiveIngredient(name: map['name'] ?? '', strength: map['strength']);
  }

  @override
  String toString() {
    if (strength != null && strength!.isNotEmpty) {
      return '$name $strength';
    }
    return name;
  }
}

class DrugInteraction {
  final String drugName;
  final String severity; // "severe", "moderate", "mild"
  final String description;

  DrugInteraction({
    required this.drugName,
    required this.severity,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'drugName': drugName,
      'severity': severity,
      'description': description,
    };
  }

  factory DrugInteraction.fromMap(Map<String, dynamic> map) {
    return DrugInteraction(
      drugName: map['drugName'] ?? '',
      severity: map['severity'] ?? 'mild',
      description: map['description'] ?? '',
    );
  }
}

class FoodInteraction {
  final String food;
  final String severity; // "avoid", "caution", "limit"
  final String description;

  FoodInteraction({
    required this.food,
    required this.severity,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {'food': food, 'severity': severity, 'description': description};
  }

  factory FoodInteraction.fromMap(Map<String, dynamic> map) {
    return FoodInteraction(
      food: map['food'] ?? '',
      severity: map['severity'] ?? 'caution',
      description: map['description'] ?? '',
    );
  }
}

/// Main drug model supporting the Parent-Ingredient pattern
///
/// For single-ingredient drugs:
///   displayName = "Paracetamol"
///   isCombination = false
///   activeIngredients = [] (or single item)
///
/// For combination drugs:
///   displayName = "Combiflam"
///   isCombination = true
///   activeIngredients = [Ibuprofen 400mg, Paracetamol 325mg]
class DrugModel {
  final String? id;

  /// The name shown to user (Brand name for combinations, generic for singles)
  final String displayName;

  /// Alias for displayName for backward compatibility
  String get genericName => displayName;

  /// Brand names for this medicine
  final List<String> brandNames;

  /// Drug category (e.g., "NSAID", "Antibiotic", "NSAID + Muscle Relaxant")
  final String category;

  /// Whether this is a combination medicine with multiple active ingredients
  final bool isCombination;

  /// Physical form: "Tablet", "Capsule", "Syrup", "Injection", etc.
  final String physicalForm;

  /// List of active ingredients (for combination drugs)
  /// For single drugs, this contains one item matching displayName
  final List<ActiveIngredient> activeIngredients;

  /// Allergy groups this drug belongs to
  final List<String> allergyWarnings;

  /// Medical conditions that conflict with this drug
  final List<String> conditionWarnings;

  /// Drug-drug interactions (combined from all ingredients)
  final List<DrugInteraction> drugInteractions;

  /// Food interactions (combined from all ingredients)
  final List<FoodInteraction> foodInteractions;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  DrugModel({
    this.id,
    required this.displayName,
    required this.brandNames,
    required this.category,
    this.isCombination = false,
    this.physicalForm = 'Tablet',
    this.activeIngredients = const [],
    this.allergyWarnings = const [],
    this.conditionWarnings = const [],
    this.drugInteractions = const [],
    this.foodInteractions = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Get a formatted string of all ingredients for display
  String get ingredientsDisplay {
    if (activeIngredients.isEmpty) {
      return displayName;
    }
    return activeIngredients.map((i) => i.name).join(' + ');
  }

  /// Get all ingredient names for safety checking
  List<String> get ingredientNames {
    if (activeIngredients.isEmpty) {
      return [displayName];
    }
    return activeIngredients.map((i) => i.name).toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'brandNames': brandNames,
      'category': category,
      'isCombination': isCombination,
      'physicalForm': physicalForm,
      'activeIngredients': activeIngredients.map((e) => e.toMap()).toList(),
      'allergyWarnings': allergyWarnings,
      'conditionWarnings': conditionWarnings,
      'drugInteractions': drugInteractions.map((e) => e.toMap()).toList(),
      'foodInteractions': foodInteractions.map((e) => e.toMap()).toList(),
      'createdAt': createdAt ?? DateTime.now(),
      'updatedAt': DateTime.now(),
      // Keep genericName for backward compatibility
      'genericName': displayName,
    };
  }

  factory DrugModel.fromMap(Map<String, dynamic> map, String id) {
    // Support both old format (genericName) and new format (displayName)
    final displayName = map['displayName'] ?? map['genericName'] ?? '';

    return DrugModel(
      id: id,
      displayName: displayName,
      brandNames: List<String>.from(map['brandNames'] ?? []),
      category: map['category'] ?? '',
      isCombination: map['isCombination'] ?? false,
      physicalForm: map['physicalForm'] ?? 'Tablet',
      activeIngredients:
          (map['activeIngredients'] as List<dynamic>?)
              ?.map((e) => ActiveIngredient.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      allergyWarnings: List<String>.from(map['allergyWarnings'] ?? []),
      conditionWarnings: List<String>.from(map['conditionWarnings'] ?? []),
      drugInteractions:
          (map['drugInteractions'] as List<dynamic>?)
              ?.map((e) => DrugInteraction.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      foodInteractions:
          (map['foodInteractions'] as List<dynamic>?)
              ?.map((e) => FoodInteraction.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: map['createdAt']?.toDate(),
      updatedAt: map['updatedAt']?.toDate(),
    );
  }

  DrugModel copyWith({
    String? id,
    String? displayName,
    List<String>? brandNames,
    String? category,
    bool? isCombination,
    String? physicalForm,
    List<ActiveIngredient>? activeIngredients,
    List<String>? allergyWarnings,
    List<String>? conditionWarnings,
    List<DrugInteraction>? drugInteractions,
    List<FoodInteraction>? foodInteractions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DrugModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      brandNames: brandNames ?? this.brandNames,
      category: category ?? this.category,
      isCombination: isCombination ?? this.isCombination,
      physicalForm: physicalForm ?? this.physicalForm,
      activeIngredients: activeIngredients ?? this.activeIngredients,
      allergyWarnings: allergyWarnings ?? this.allergyWarnings,
      conditionWarnings: conditionWarnings ?? this.conditionWarnings,
      drugInteractions: drugInteractions ?? this.drugInteractions,
      foodInteractions: foodInteractions ?? this.foodInteractions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrugModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    if (isCombination && activeIngredients.isNotEmpty) {
      return '$displayName ($ingredientsDisplay)';
    }
    return displayName;
  }
}
