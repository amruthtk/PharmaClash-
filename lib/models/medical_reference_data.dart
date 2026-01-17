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
  /// Grouped by system for comprehensive coverage
  static const List<String> chronicDiseases = [
    // Cardiovascular
    'Hypertension (High Blood Pressure)',
    'Hypotension (Low Blood Pressure)',
    'Coronary Artery Disease',
    'Heart Failure',
    'Atrial Fibrillation',
    'Arrhythmia',
    'History of Myocardial Infarction (Heart Attack)',
    'Deep Vein Thrombosis (DVT)',
    'Peripheral Artery Disease',
    'Stroke / TIA',

    // Metabolic & Endocrine
    'Diabetes Type 1',
    'Diabetes Type 2',
    'Gestational Diabetes',
    'Hypothyroidism',
    'Hyperthyroidism',
    'Gout',
    'PCOS/PCOD',
    'Obesity',
    'High Cholesterol (Hyperlipidemia)',
    'Addison\'s Disease',
    'Cushing\'s Syndrome',

    // Respiratory
    'Asthma',
    'COPD (Chronic Obstructive Pulmonary Disease)',
    'Chronic Bronchitis',
    'Emphysema',
    'Cystic Fibrosis',
    'Tuberculosis (Active/History)',
    'Sleep Apnea',

    // Gastrointestinal
    'GERD (Acid Reflux)',
    'Peptic Ulcer Disease',
    'Gastritis',
    'IBS (Irritable Bowel Syndrome)',
    'IBD (Crohn\'s Disease)',
    'Ulcerative Colitis',
    'Liver Cirrhosis',
    'Fatty Liver Disease',
    'Hepatitis B',
    'Hepatitis C',
    'Gallstones',
    'Pancreatitis',
    'Celiac Disease',

    // Renal (Kidney)
    'Chronic Kidney Disease (Stage 1-2)',
    'Chronic Kidney Disease (Stage 3-5)',
    'Kidney Stones',
    'Nephrotic Syndrome',
    'Polycystic Kidney Disease',

    // Neurological & Psychiatric
    'Migraine',
    'Epilepsy / Seizures',
    'Parkinson\'s Disease',
    'Alzheimer\'s / Dementia',
    'Multiple Sclerosis',
    'Depression',
    'Anxiety Disorder',
    'Bipolar Disorder',
    'Schizophrenia',
    'Insomnia',
    'Neuropathy',

    // Hematological (Blood)
    'Anemia (Iron Deficiency)',
    'Pernicious Anemia (B12 Deficiency)',
    'Thalassemia',
    'Sickle Cell Anemia',
    'Hemophilia',
    'G6PD Deficiency',
    'Bleeding Disorders',

    // Musculoskeletal & Autoimmune
    'Osteoarthritis',
    'Rheumatoid Arthritis',
    'Osteoporosis',
    'Lupus (SLE)',
    'Psoriatic Arthritis',
    'Gouty Arthritis',
    'Fibromyalgia',

    // Others
    'Glaucoma',
    'Cataracts',
    'Benign Prostatic Hyperplasia (Enlarged Prostate)',
    'Erectile Dysfunction',
    'Pregnancy',
    'Breastfeeding',
  ];

  /// List of verified drug/medication allergies
  static const List<String> drugAllergies = [
    // Antibiotics - Penicillins
    'Penicillins',
    'Amoxicillin',
    'Ampicillin',
    'Augmentin',

    // Antibiotics - Cephalosporins
    'Cephalosporins (General)',
    'Cephalexin (Keflex)',
    'Cefixime',
    'Cefuroxime',

    // Antibiotics - Sulfonamides
    'Sulfa Drugs (Sulfonamides)',
    'Bactrim / Septra',

    // Antibiotics - Macrolides
    'Macrolides (General)',
    'Azithromycin',
    'Erythromycin',
    'Clarithromycin',

    // Antibiotics - Quinolones
    'Fluoroquinolones',
    'Ciprofloxacin',
    'Levofloxacin',

    // Antibiotics - Others
    'Tetracyclines',
    'Doxycycline',
    'Vancomycin',
    'Metronidazole',

    // Painkillers - NSAIDs
    'NSAIDs (General)',
    'Aspirin (Salicylates)',
    'Ibuprofen',
    'Diclofenac',
    'Naproxen',
    'Aceclofenac',

    // Painkillers - Opioids
    'Opioids (General)',
    'Morphine',
    'Codeine',
    'Tramadol',
    'Fentanyl',

    // Anticonvulsants
    'Anticonvulsants (General)',
    'Phenytoin',
    'Carbamazepine',
    'Lamotrigine',

    // Miscellaneous
    'ACE Inhibitors (Lisinopril, Enalapril)',
    'ARBs (Telmisartan, Losartan)',
    'Statins (Atorvastatin, Rosuvastatin)',
    'Metformin',
    'Insulin',
    'Contrast Dye (Iodine)',
    'Local Anesthetics (Lidocaine)',
    'General Anesthesia',
    'Latex',
    'Adhesive Tape',
    'Soy',
    'Peanut',
    'Egg Protein (Vaccines)',
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
