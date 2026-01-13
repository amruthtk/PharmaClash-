/// Medical Reference Data - Source of Truth for validated medical terms
/// This class contains the master list of all valid allergies and chronic diseases.
/// Users can only select from these verified items.
///
/// Note: In a production app, this would be fetched from a backend database
/// managed by an Admin (User Story 20).
class MedicalReferenceData {
  // Private constructor to prevent instantiation
  MedicalReferenceData._();

  /// List of verified chronic diseases/conditions
  static const List<String> chronicDiseases = [
    'Diabetes Type 1',
    'Diabetes Type 2',
    'Hypertension',
    'Asthma',
    'Arthritis',
    'Chronic Kidney Disease',
    'COPD (Chronic Obstructive Pulmonary Disease)',
    'Thyroid Disorder',
    'Epilepsy',
    'Heart Disease',
    'Depression',
    'Anxiety Disorder',
    'Osteoporosis',
    'Liver Disease',
    'Anemia',
  ];

  /// List of verified drug/medication allergies
  static const List<String> drugAllergies = [
    'Penicillin',
    'Sulfa Drugs (Sulfonamides)',
    'Aspirin',
    'Ibuprofen',
    'Naproxen',
    'Morphine',
    'Codeine',
    'Tetracycline',
    'Erythromycin',
    'Amoxicillin',
    'Cephalosporins',
    'Fluoroquinolones',
    'ACE Inhibitors',
    'NSAIDs (Non-Steroidal Anti-Inflammatory)',
    'Latex',
    'Iodine/Contrast Dye',
    'Local Anesthetics',
    'Insulin',
    'Anticonvulsants',
    'Chemotherapy Drugs',
  ];

  /// Search chronic diseases by query (case-insensitive)
  static List<String> searchChronicDiseases(String query) {
    if (query.isEmpty) return chronicDiseases;
    final lowerQuery = query.toLowerCase();
    return chronicDiseases
        .where((disease) => disease.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Search drug allergies by query (case-insensitive)
  static List<String> searchDrugAllergies(String query) {
    if (query.isEmpty) return drugAllergies;
    final lowerQuery = query.toLowerCase();
    return drugAllergies
        .where((allergy) => allergy.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Check if a chronic disease is valid
  static bool isValidChronicDisease(String disease) {
    return chronicDiseases
        .map((d) => d.toLowerCase())
        .contains(disease.toLowerCase());
  }

  /// Check if a drug allergy is valid
  static bool isValidDrugAllergy(String allergy) {
    return drugAllergies
        .map((a) => a.toLowerCase())
        .contains(allergy.toLowerCase());
  }
}
