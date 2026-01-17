import 'package:flutter/material.dart';
import '../../models/drug_model.dart';
import '../../services/drug_service.dart';
import '../../theme/app_colors.dart';

/// Data Migration Screen - One-time import of drug data to Firebase
class DataMigrationScreen extends StatefulWidget {
  const DataMigrationScreen({super.key});

  @override
  State<DataMigrationScreen> createState() => _DataMigrationScreenState();
}

class _DataMigrationScreenState extends State<DataMigrationScreen> {
  final DrugService _drugService = DrugService();
  bool _isLoading = false;
  int _uploadedCount = 0;
  int _totalCount = 0;
  String _currentDrug = '';
  final List<String> _logs = [];

  // Theme colors

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    });
  }

  Future<void> _startMigration() async {
    setState(() {
      _isLoading = true;
      _uploadedCount = 0;
      _logs.clear();
    });

    _addLog('Starting data migration...');

    try {
      final drugs = _getSeedData();
      _totalCount = drugs.length;
      _addLog('Found $_totalCount drugs to upload');

      for (int i = 0; i < drugs.length; i++) {
        final drug = drugs[i];
        setState(() {
          _currentDrug = drug.genericName;
        });

        final result = await _drugService.addDrug(drug);
        if (result != null) {
          setState(() {
            _uploadedCount++;
          });
          _addLog('✓ Uploaded: ${drug.genericName}');
        } else {
          _addLog('✗ Failed: ${drug.genericName}');
        }
      }

      _addLog(
        'Migration complete! $_uploadedCount/$_totalCount drugs uploaded.',
      );
    } catch (e) {
      _addLog('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _currentDrug = '';
      });
    }
  }

  Future<void> _startComboMigration() async {
    setState(() {
      _isLoading = true;
      _uploadedCount = 0;
      _logs.clear();
    });

    _addLog('Starting COMBINATION drugs migration...');

    try {
      final drugs = _getComboDrugs();
      _totalCount = drugs.length;
      _addLog('Found $_totalCount combination drugs to upload');

      for (int i = 0; i < drugs.length; i++) {
        final drug = drugs[i];
        setState(() {
          _currentDrug = drug.displayName;
        });

        final result = await _drugService.addDrug(drug);
        if (result != null) {
          setState(() {
            _uploadedCount++;
          });
          _addLog('✓ Uploaded: ${drug.displayName}');
        } else {
          _addLog('✗ Failed: ${drug.displayName}');
        }
      }

      _addLog(
        'Combo migration complete! $_uploadedCount/$_totalCount drugs uploaded.',
      );
    } catch (e) {
      _addLog('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _currentDrug = '';
      });
    }
  }

  List<DrugModel> _getComboDrugs() {
    return [
      // Sepiclo-PT4 / Zerodol-SP type
      DrugModel(
        displayName: 'Aceclofenac + Paracetamol + Thiocolchicoside',
        brandNames: ['Sepiclo-PT4', 'Zerodol-SP', 'Hifenac-TH', 'Aceclo-SP'],
        category: 'NSAID + Muscle Relaxant',
        isCombination: true,
        physicalForm: 'Tablet',
        activeIngredients: [
          ActiveIngredient(name: 'Aceclofenac', strength: '100mg'),
          ActiveIngredient(name: 'Paracetamol', strength: '325mg'),
          ActiveIngredient(name: 'Thiocolchicoside', strength: '4mg'),
        ],
        allergyWarnings: ['NSAIDs', 'Muscle Relaxants'],
        conditionWarnings: [
          'Peptic Ulcer: Avoid - high risk of stomach bleeding',
          'Liver Disease: Use with caution',
          'Kidney Disease: Avoid - can worsen kidney function',
          'Coronary Artery Bypass Surgery: Do not use before or after heart surgery',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Aspirin',
            severity: 'severe',
            description: 'Increased risk of GI ulcers and bleeding',
          ),
          DrugInteraction(
            drugName: 'Warfarin',
            severity: 'severe',
            description: 'Increased bleeding risk',
          ),
          DrugInteraction(
            drugName: 'Methotrexate',
            severity: 'moderate',
            description: 'Increased Methotrexate toxicity',
          ),
        ],
        foodInteractions: [
          FoodInteraction(
            food: 'Alcohol',
            severity: 'avoid',
            description: 'Severe stomach bleeding and liver damage risk',
          ),
          FoodInteraction(
            food: 'Spicy Food',
            severity: 'caution',
            description: 'Worsens drug-induced acidity',
          ),
        ],
      ),
      // Combiflam
      DrugModel(
        displayName: 'Ibuprofen + Paracetamol',
        brandNames: ['Combiflam', 'Ibugesic Plus', 'Brufen Plus'],
        category: 'NSAID + Analgesic',
        isCombination: true,
        physicalForm: 'Tablet',
        activeIngredients: [
          ActiveIngredient(name: 'Ibuprofen', strength: '400mg'),
          ActiveIngredient(name: 'Paracetamol', strength: '325mg'),
        ],
        allergyWarnings: ['NSAIDs', 'Salicylates'],
        conditionWarnings: [
          'Peptic Ulcers: Can cause stomach perforation',
          'Asthma: May trigger bronchospasm',
          'Kidney Disease: Blocks blood flow to kidneys',
          'Liver Cirrhosis: Paracetamol can be toxic',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Aspirin',
            severity: 'severe',
            description: 'Blocks heart-protective effect of Aspirin',
          ),
          DrugInteraction(
            drugName: 'Warfarin',
            severity: 'severe',
            description: 'Increased bleeding risk',
          ),
        ],
        foodInteractions: [
          FoodInteraction(
            food: 'Alcohol',
            severity: 'avoid',
            description: 'Severe liver damage and stomach bleeding',
          ),
        ],
      ),
      // Augmentin
      DrugModel(
        displayName: 'Amoxicillin + Clavulanic Acid',
        brandNames: ['Augmentin', 'Moxikind-CV', 'Clavam'],
        category: 'Antibiotic (Penicillin)',
        isCombination: true,
        physicalForm: 'Tablet',
        activeIngredients: [
          ActiveIngredient(name: 'Amoxicillin', strength: '500mg'),
          ActiveIngredient(name: 'Clavulanic Acid', strength: '125mg'),
        ],
        allergyWarnings: ['Penicillins', 'Cephalosporins'],
        conditionWarnings: [
          'Mononucleosis: Causes massive skin rash',
          'Liver Disease: Clavulanic acid may cause liver damage',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Methotrexate',
            severity: 'severe',
            description: 'Increases Methotrexate toxicity',
          ),
          DrugInteraction(
            drugName: 'Birth Control Pills',
            severity: 'moderate',
            description: 'May reduce contraceptive effectiveness',
          ),
        ],
        foodInteractions: [],
      ),
      // Saridon
      DrugModel(
        displayName: 'Paracetamol + Propyphenazone + Caffeine',
        brandNames: ['Saridon', 'Dart'],
        category: 'Analgesic + Stimulant',
        isCombination: true,
        physicalForm: 'Tablet',
        activeIngredients: [
          ActiveIngredient(name: 'Paracetamol', strength: '250mg'),
          ActiveIngredient(name: 'Propyphenazone', strength: '150mg'),
          ActiveIngredient(name: 'Caffeine', strength: '50mg'),
        ],
        allergyWarnings: ['Pyrazolones'],
        conditionWarnings: [
          'Liver Disease: Paracetamol can be toxic',
          'Heart Conditions: Caffeine may worsen palpitations',
        ],
        drugInteractions: [],
        foodInteractions: [
          FoodInteraction(
            food: 'Alcohol',
            severity: 'avoid',
            description: 'Severe liver damage risk',
          ),
          FoodInteraction(
            food: 'Coffee/Tea',
            severity: 'caution',
            description: 'Additional caffeine may cause jitters',
          ),
        ],
      ),
      // Crocin Advance
      DrugModel(
        displayName: 'Paracetamol + Caffeine',
        brandNames: ['Crocin Advance', 'Pacimol Plus'],
        category: 'Analgesic + Stimulant',
        isCombination: true,
        physicalForm: 'Tablet',
        activeIngredients: [
          ActiveIngredient(name: 'Paracetamol', strength: '500mg'),
          ActiveIngredient(name: 'Caffeine', strength: '65mg'),
        ],
        allergyWarnings: [],
        conditionWarnings: ['Liver Disease: Paracetamol can be toxic'],
        drugInteractions: [],
        foodInteractions: [
          FoodInteraction(
            food: 'Alcohol',
            severity: 'avoid',
            description: 'Severe liver damage',
          ),
        ],
      ),
      // Moxikind-CV Duo
      DrugModel(
        displayName: 'Amoxicillin + Potassium Clavulanate',
        brandNames: ['Moxikind-CV', 'Augmentin 625', 'Clavam 625'],
        category: 'Antibiotic',
        isCombination: true,
        physicalForm: 'Tablet',
        activeIngredients: [
          ActiveIngredient(name: 'Amoxicillin', strength: '500mg'),
          ActiveIngredient(name: 'Potassium Clavulanate', strength: '125mg'),
        ],
        allergyWarnings: ['Penicillins'],
        conditionWarnings: ['Penicillin Allergy: Risk of anaphylaxis'],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Warfarin',
            severity: 'moderate',
            description: 'May increase bleeding time',
          ),
        ],
        foodInteractions: [],
      ),
      // Disprin CV
      DrugModel(
        displayName: 'Aspirin + Atorvastatin + Clopidogrel',
        brandNames: ['Ecosprin AV', 'CV75', 'Polycap'],
        category: 'Cardiac Triple Therapy',
        isCombination: true,
        physicalForm: 'Capsule',
        activeIngredients: [
          ActiveIngredient(name: 'Aspirin', strength: '75mg'),
          ActiveIngredient(name: 'Atorvastatin', strength: '10mg'),
          ActiveIngredient(name: 'Clopidogrel', strength: '75mg'),
        ],
        allergyWarnings: ['NSAIDs', 'Statins'],
        conditionWarnings: [
          'Active Bleeding: Extreme bleeding risk',
          'Peptic Ulcer: Can cause stomach perforation',
          'Liver Disease: Statins can damage liver',
          'Dengue Fever: NEVER take - fatal hemorrhage risk',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Warfarin',
            severity: 'severe',
            description: 'Fatal bleeding risk',
          ),
          DrugInteraction(
            drugName: 'Omeprazole',
            severity: 'severe',
            description: 'Blocks Clopidogrel effectiveness',
          ),
        ],
        foodInteractions: [
          FoodInteraction(
            food: 'Grapefruit',
            severity: 'avoid',
            description: 'Increases statin toxicity',
          ),
          FoodInteraction(
            food: 'Alcohol',
            severity: 'avoid',
            description: 'Stomach bleeding risk',
          ),
        ],
      ),
      // Pan D
      DrugModel(
        displayName: 'Pantoprazole + Domperidone',
        brandNames: ['Pan D', 'Pantocid-D', 'Nexpro-D'],
        category: 'PPI + Antiemetic',
        isCombination: true,
        physicalForm: 'Capsule',
        activeIngredients: [
          ActiveIngredient(name: 'Pantoprazole', strength: '40mg'),
          ActiveIngredient(name: 'Domperidone', strength: '10mg'),
        ],
        allergyWarnings: ['PPIs'],
        conditionWarnings: [
          'Heart Disease: Domperidone may cause heart rhythm issues',
          'Pituitary Tumor: May increase prolactin',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Ketoconazole',
            severity: 'severe',
            description: 'Increases Domperidone to dangerous levels',
          ),
        ],
        foodInteractions: [],
      ),
      // Sinarest
      DrugModel(
        displayName: 'Paracetamol + Phenylephrine + Chlorpheniramine',
        brandNames: ['Sinarest', 'Nasivion', 'Coldarin'],
        category: 'Cold & Flu Combination',
        isCombination: true,
        physicalForm: 'Tablet',
        activeIngredients: [
          ActiveIngredient(name: 'Paracetamol', strength: '500mg'),
          ActiveIngredient(name: 'Phenylephrine', strength: '10mg'),
          ActiveIngredient(name: 'Chlorpheniramine', strength: '2mg'),
        ],
        allergyWarnings: ['Antihistamines'],
        conditionWarnings: [
          'High Blood Pressure: Phenylephrine raises BP dangerously',
          'Enlarged Prostate: May cause urinary retention',
          'Glaucoma: Can increase eye pressure',
          'Liver Disease: Paracetamol risk',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'MAO Inhibitors',
            severity: 'severe',
            description: 'Hypertensive crisis risk',
          ),
          DrugInteraction(
            drugName: 'Beta Blockers',
            severity: 'moderate',
            description: 'Reduced BP control',
          ),
        ],
        foodInteractions: [
          FoodInteraction(
            food: 'Alcohol',
            severity: 'avoid',
            description: 'Extreme drowsiness and liver damage',
          ),
        ],
      ),
      // Benadryl
      DrugModel(
        displayName: 'Diphenhydramine + Ammonium Chloride',
        brandNames: ['Benadryl', 'Benadryl DR', 'Cough Syrup'],
        category: 'Cough Suppressant',
        isCombination: true,
        physicalForm: 'Syrup',
        activeIngredients: [
          ActiveIngredient(name: 'Diphenhydramine', strength: '14mg/5ml'),
          ActiveIngredient(name: 'Ammonium Chloride', strength: '138mg/5ml'),
        ],
        allergyWarnings: ['Antihistamines'],
        conditionWarnings: [
          'Asthma: May thicken secretions',
          'Glaucoma: Increases eye pressure',
          'Liver Disease: Avoid in severe cases',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Sedatives',
            severity: 'severe',
            description: 'Excessive sedation',
          ),
          DrugInteraction(
            drugName: 'Antidepressants',
            severity: 'moderate',
            description: 'Increased anticholinergic effects',
          ),
        ],
        foodInteractions: [
          FoodInteraction(
            food: 'Alcohol',
            severity: 'avoid',
            description: 'Dangerous sedation',
          ),
        ],
      ),
      // Gelusil
      DrugModel(
        displayName: 'Aluminium Hydroxide + Magnesium Hydroxide + Simethicone',
        brandNames: ['Gelusil', 'Digene', 'Mucaine'],
        category: 'Antacid',
        isCombination: true,
        physicalForm: 'Syrup',
        activeIngredients: [
          ActiveIngredient(name: 'Aluminium Hydroxide', strength: '250mg'),
          ActiveIngredient(name: 'Magnesium Hydroxide', strength: '250mg'),
          ActiveIngredient(name: 'Simethicone', strength: '50mg'),
        ],
        allergyWarnings: [],
        conditionWarnings: [
          'Kidney Disease: Aluminium and Magnesium accumulation',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Ciprofloxacin',
            severity: 'severe',
            description: 'Antacids block antibiotic absorption',
          ),
          DrugInteraction(
            drugName: 'Tetracycline',
            severity: 'severe',
            description: 'Blocks antibiotic absorption',
          ),
          DrugInteraction(
            drugName: 'Levothyroxine',
            severity: 'moderate',
            description: 'Reduces thyroid medication absorption',
          ),
        ],
        foodInteractions: [],
      ),
      // Wikoryl
      DrugModel(
        displayName: 'Paracetamol + Phenylephrine + Cetirizine',
        brandNames: ['Wikoryl', 'Cetzine Cold', 'Alex Cold'],
        category: 'Cold & Flu Combination',
        isCombination: true,
        physicalForm: 'Tablet',
        activeIngredients: [
          ActiveIngredient(name: 'Paracetamol', strength: '325mg'),
          ActiveIngredient(name: 'Phenylephrine', strength: '5mg'),
          ActiveIngredient(name: 'Cetirizine', strength: '5mg'),
        ],
        allergyWarnings: ['Antihistamines'],
        conditionWarnings: [
          'Hypertension: Phenylephrine increases BP',
          'Kidney Disease: Cetirizine dose adjustment needed',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'MAO Inhibitors',
            severity: 'severe',
            description: 'Hypertensive crisis',
          ),
        ],
        foodInteractions: [
          FoodInteraction(
            food: 'Alcohol',
            severity: 'avoid',
            description: 'Increased drowsiness',
          ),
        ],
      ),
      // Disprin
      DrugModel(
        displayName: 'Aspirin + Caffeine',
        brandNames: ['Disprin', 'Aspro Clear'],
        category: 'Analgesic',
        isCombination: true,
        physicalForm: 'Tablet',
        activeIngredients: [
          ActiveIngredient(name: 'Aspirin', strength: '350mg'),
          ActiveIngredient(name: 'Caffeine', strength: '30mg'),
        ],
        allergyWarnings: ['NSAIDs', 'Salicylates'],
        conditionWarnings: [
          'Peptic Ulcer: Severe bleeding risk',
          'Asthma: May trigger bronchospasm',
          'Dengue Fever: NEVER take - fatal hemorrhage risk',
          'Children under 12: Reye syndrome risk',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Warfarin',
            severity: 'severe',
            description: 'Fatal bleeding risk',
          ),
          DrugInteraction(
            drugName: 'Methotrexate',
            severity: 'severe',
            description: 'Methotrexate toxicity',
          ),
        ],
        foodInteractions: [
          FoodInteraction(
            food: 'Alcohol',
            severity: 'avoid',
            description: 'Stomach bleeding',
          ),
        ],
      ),
      // Glycomet GP
      DrugModel(
        displayName: 'Metformin + Glimepiride',
        brandNames: ['Glycomet GP', 'Glimy M', 'Gluconorm G'],
        category: 'Diabetes Combination',
        isCombination: true,
        physicalForm: 'Tablet',
        activeIngredients: [
          ActiveIngredient(name: 'Metformin', strength: '500mg'),
          ActiveIngredient(name: 'Glimepiride', strength: '1mg'),
        ],
        allergyWarnings: ['Sulfonamides'],
        conditionWarnings: [
          'Kidney Disease: Metformin accumulation - lactic acidosis',
          'Liver Disease: Avoid Glimepiride',
          'Heart Failure: Metformin risk',
          'Before Surgery/CT Scan: Stop Metformin 48 hours before',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Alcohol',
            severity: 'severe',
            description: 'Severe hypoglycemia and lactic acidosis',
          ),
          DrugInteraction(
            drugName: 'IV Contrast Dye',
            severity: 'severe',
            description: 'Kidney failure risk',
          ),
        ],
        foodInteractions: [
          FoodInteraction(
            food: 'Alcohol',
            severity: 'avoid',
            description: 'Dangerous blood sugar drop',
          ),
        ],
      ),
      // Telma AM
      DrugModel(
        displayName: 'Telmisartan + Amlodipine',
        brandNames: ['Telma AM', 'Telmikind AM', 'Cresar AM'],
        category: 'BP Combination',
        isCombination: true,
        physicalForm: 'Tablet',
        activeIngredients: [
          ActiveIngredient(name: 'Telmisartan', strength: '40mg'),
          ActiveIngredient(name: 'Amlodipine', strength: '5mg'),
        ],
        allergyWarnings: ['ARBs', 'Calcium Channel Blockers'],
        conditionWarnings: [
          'Pregnancy: CONTRAINDICATED - causes fetal harm',
          'Bilateral Renal Artery Stenosis: Kidney failure risk',
          'Severe Liver Disease: Avoid',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Potassium Supplements',
            severity: 'severe',
            description: 'Dangerous potassium levels',
          ),
          DrugInteraction(
            drugName: 'Lithium',
            severity: 'severe',
            description: 'Lithium toxicity',
          ),
          DrugInteraction(
            drugName: 'NSAIDs',
            severity: 'moderate',
            description: 'Reduces BP-lowering effect',
          ),
        ],
        foodInteractions: [
          FoodInteraction(
            food: 'Grapefruit',
            severity: 'avoid',
            description: 'Increases Amlodipine levels',
          ),
          FoodInteraction(
            food: 'Potassium-rich foods',
            severity: 'caution',
            description: 'High potassium risk',
          ),
        ],
      ),
      // Shelcal
      DrugModel(
        displayName: 'Calcium Carbonate + Vitamin D3',
        brandNames: ['Shelcal', 'CCM', 'Calcimax'],
        category: 'Calcium Supplement',
        isCombination: true,
        physicalForm: 'Tablet',
        activeIngredients: [
          ActiveIngredient(name: 'Calcium Carbonate', strength: '500mg'),
          ActiveIngredient(name: 'Vitamin D3', strength: '250 IU'),
        ],
        allergyWarnings: [],
        conditionWarnings: [
          'Hypercalcemia: Already high calcium',
          'Kidney Stones: May worsen',
          'Sarcoidosis: Increased vitamin D sensitivity',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Levothyroxine',
            severity: 'severe',
            description: 'Blocks thyroid absorption - take 4 hours apart',
          ),
          DrugInteraction(
            drugName: 'Ciprofloxacin',
            severity: 'severe',
            description: 'Calcium blocks antibiotic',
          ),
          DrugInteraction(
            drugName: 'Bisphosphonates',
            severity: 'moderate',
            description: 'Take at least 30 min apart',
          ),
        ],
        foodInteractions: [
          FoodInteraction(
            food: 'High-fiber foods',
            severity: 'caution',
            description: 'May reduce calcium absorption',
          ),
        ],
      ),
      // Zincovit
      DrugModel(
        displayName: 'Multivitamin + Multimineral + Zinc',
        brandNames: ['Zincovit', 'Becosules Z', 'Supradyn'],
        category: 'Multivitamin',
        isCombination: true,
        physicalForm: 'Tablet',
        activeIngredients: [
          ActiveIngredient(name: 'Vitamin B Complex'),
          ActiveIngredient(name: 'Vitamin C', strength: '150mg'),
          ActiveIngredient(name: 'Zinc', strength: '22mg'),
        ],
        allergyWarnings: [],
        conditionWarnings: ['Kidney Disease: Avoid excess vitamins'],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Levodopa',
            severity: 'moderate',
            description: 'Vitamin B6 reduces Levodopa effect',
          ),
          DrugInteraction(
            drugName: 'Antibiotics (Quinolones)',
            severity: 'moderate',
            description: 'Zinc blocks absorption',
          ),
        ],
        foodInteractions: [],
      ),
      // Chymoral Forte
      DrugModel(
        displayName: 'Trypsin + Chymotrypsin',
        brandNames: ['Chymoral Forte', 'ChymoForte', 'Trypsin'],
        category: 'Anti-inflammatory Enzyme',
        isCombination: true,
        physicalForm: 'Tablet',
        activeIngredients: [
          ActiveIngredient(name: 'Trypsin', strength: '48mg'),
          ActiveIngredient(name: 'Chymotrypsin', strength: '2mg'),
        ],
        allergyWarnings: ['Pork/Beef allergy (animal-derived)'],
        conditionWarnings: [
          'Bleeding Disorders: May increase bleeding',
          'Before Surgery: Stop 2 weeks prior',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Warfarin',
            severity: 'moderate',
            description: 'May increase bleeding time',
          ),
          DrugInteraction(
            drugName: 'Aspirin',
            severity: 'moderate',
            description: 'Increased bleeding risk',
          ),
        ],
        foodInteractions: [],
      ),
      // Liv 52
      DrugModel(
        displayName: 'Caper Bush + Chicory + Other Herbs',
        brandNames: ['Liv 52', 'Liv 52 DS', 'Livogen'],
        category: 'Hepatoprotective (Ayurvedic)',
        isCombination: true,
        physicalForm: 'Tablet',
        activeIngredients: [
          ActiveIngredient(name: 'Caper Bush (Himsra)'),
          ActiveIngredient(name: 'Chicory (Kasani)'),
          ActiveIngredient(name: 'Black Nightshade'),
        ],
        allergyWarnings: ['Herbal allergies'],
        conditionWarnings: ['Pregnancy: Safety not established'],
        drugInteractions: [],
        foodInteractions: [],
      ),
      // Ascoril LS
      DrugModel(
        displayName: 'Ambroxol + Levosalbutamol + Guaifenesin',
        brandNames: ['Ascoril LS', 'Alex Syrup', 'Kofarest'],
        category: 'Cough Expectorant',
        isCombination: true,
        physicalForm: 'Syrup',
        activeIngredients: [
          ActiveIngredient(name: 'Ambroxol', strength: '30mg'),
          ActiveIngredient(name: 'Levosalbutamol', strength: '1mg'),
          ActiveIngredient(name: 'Guaifenesin', strength: '50mg'),
        ],
        allergyWarnings: ['Sulfonamides'],
        conditionWarnings: [
          'Heart Disease: Levosalbutamol may cause palpitations',
          'Hyperthyroidism: Worsens symptoms',
          'Diabetes: May affect blood sugar',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Beta Blockers',
            severity: 'moderate',
            description: 'Reduces bronchodilator effect',
          ),
          DrugInteraction(
            drugName: 'MAO Inhibitors',
            severity: 'moderate',
            description: 'Cardiovascular effects',
          ),
        ],
        foodInteractions: [],
      ),
      // Meftal Spas
      DrugModel(
        displayName: 'Mefenamic Acid + Dicyclomine',
        brandNames: ['Meftal Spas', 'Drotin M', 'Cyclopam MF'],
        category: 'Antispasmodic + Analgesic',
        isCombination: true,
        physicalForm: 'Tablet',
        activeIngredients: [
          ActiveIngredient(name: 'Mefenamic Acid', strength: '250mg'),
          ActiveIngredient(name: 'Dicyclomine', strength: '10mg'),
        ],
        allergyWarnings: ['NSAIDs'],
        conditionWarnings: [
          'Peptic Ulcer: Bleeding risk',
          'Kidney Disease: NSAIDs worsen function',
          'Glaucoma: Dicyclomine increases eye pressure',
          'Enlarged Prostate: Urinary retention risk',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Warfarin',
            severity: 'severe',
            description: 'Bleeding risk',
          ),
          DrugInteraction(
            drugName: 'Lithium',
            severity: 'moderate',
            description: 'Lithium toxicity',
          ),
        ],
        foodInteractions: [
          FoodInteraction(
            food: 'Alcohol',
            severity: 'avoid',
            description: 'Stomach bleeding and drowsiness',
          ),
        ],
      ),
      // Becosules
      DrugModel(
        displayName: 'Vitamin B Complex + Vitamin C',
        brandNames: ['Becosules', 'Cobadex CZS', 'Neurobion Forte'],
        category: 'Vitamin Supplement',
        isCombination: true,
        physicalForm: 'Capsule',
        activeIngredients: [
          ActiveIngredient(name: 'Vitamin B1', strength: '10mg'),
          ActiveIngredient(name: 'Vitamin B6', strength: '3mg'),
          ActiveIngredient(name: 'Vitamin B12', strength: '15mcg'),
          ActiveIngredient(name: 'Vitamin C', strength: '150mg'),
        ],
        allergyWarnings: [],
        conditionWarnings: [],
        drugInteractions: [
          DrugInteraction(
            drugName: 'Levodopa',
            severity: 'moderate',
            description: 'Vitamin B6 reduces Parkinson drug effect',
          ),
        ],
        foodInteractions: [],
      ),
      // ORS
      DrugModel(
        displayName: 'Sodium Chloride + Potassium Chloride + Dextrose',
        brandNames: ['Electral', 'ORS', 'Enerzal'],
        category: 'Oral Rehydration',
        isCombination: true,
        physicalForm: 'Powder',
        activeIngredients: [
          ActiveIngredient(name: 'Sodium Chloride', strength: '2.6g/L'),
          ActiveIngredient(name: 'Potassium Chloride', strength: '1.5g/L'),
          ActiveIngredient(name: 'Dextrose', strength: '13.5g/L'),
        ],
        allergyWarnings: [],
        conditionWarnings: [
          'Kidney Failure: Potassium may accumulate',
          'Heart Failure: Sodium retention',
        ],
        drugInteractions: [
          DrugInteraction(
            drugName: 'ACE Inhibitors',
            severity: 'moderate',
            description: 'High potassium risk',
          ),
          DrugInteraction(
            drugName: 'Spironolactone',
            severity: 'moderate',
            description: 'Dangerous potassium levels',
          ),
        ],
        foodInteractions: [],
      ),
      // Volini Spray (topical)
      DrugModel(
        displayName: 'Diclofenac + Methyl Salicylate + Linseed Oil',
        brandNames: ['Volini', 'Moov', 'Iodex'],
        category: 'Topical Pain Relief',
        isCombination: true,
        physicalForm: 'Gel/Spray',
        activeIngredients: [
          ActiveIngredient(name: 'Diclofenac Diethylamine', strength: '1.16%'),
          ActiveIngredient(name: 'Methyl Salicylate', strength: '10%'),
          ActiveIngredient(name: 'Linseed Oil', strength: '3%'),
        ],
        allergyWarnings: ['NSAIDs', 'Salicylates'],
        conditionWarnings: [
          'Open Wounds: Do not apply',
          'Aspirin-sensitive Asthma: Can trigger attack even topically',
        ],
        drugInteractions: [],
        foodInteractions: [],
      ),
    ];
  }

  String _mapRiskToSeverity(String risk) {
    switch (risk.toLowerCase()) {
      case 'critical':
        return 'severe';
      case 'high':
        return 'severe';
      case 'med':
      case 'medium':
        return 'moderate';
      case 'low':
        return 'mild';
      case 'positive impact':
        return 'info';
      default:
        return 'moderate';
    }
  }

  String _mapFoodRiskToSeverity(String risk) {
    switch (risk.toLowerCase()) {
      case 'critical':
      case 'high':
        return 'avoid';
      case 'med':
      case 'medium':
        return 'caution';
      case 'low':
        return 'limit';
      case 'positive impact':
        return 'beneficial';
      default:
        return 'caution';
    }
  }

  List<DrugModel> _getSeedData() {
    // This contains all 50 drugs from your dataset
    final rawData = [
      {
        "id": "ciprofloxacin",
        "name": "Ciprofloxacin",
        "brands": ["Ciplox", "Cifran", "Ciprobid"],
        "salt": "Fluoroquinolone",
        "allergy_group": "Quinolones",
        "food_clashes": [
          {
            "item": "Dairy (Milk, Curd, Cheese)",
            "risk": "High",
            "note":
                "Dairy binds to the medicine, reducing effectiveness by 50%. Wait 2 hours.",
          },
          {
            "item": "Caffeine (Tea, Coffee, Cola)",
            "risk": "Med",
            "note":
                "Medicine increases caffeine levels, causing severe heart palpitations and jitters.",
          },
          {
            "item": "Calcium Fortified Juices",
            "risk": "High",
            "note": "Blocks absorption similarly to milk.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Myasthenia Gravis",
            "risk": "Critical",
            "note": "Can cause fatal muscle weakness and respiratory failure.",
          },
          {
            "condition": "Epilepsy",
            "risk": "High",
            "note": "Increases risk of seizures.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Warfarin",
            "risk": "High",
            "note": "Massively increases bleeding risk.",
          },
          {
            "target": "Theophylline",
            "risk": "High",
            "note": "Causes toxic buildup leading to seizures.",
          },
        ],
      },
      {
        "id": "telmisartan",
        "name": "Telmisartan",
        "brands": ["Telma", "Telmikind", "Telvas"],
        "salt": "Angiotensin II Receptor Blocker (ARB)",
        "allergy_group": "Sartans",
        "food_clashes": [
          {
            "item": "High Potassium Food (Bananas, Spinach)",
            "risk": "High",
            "note":
                "Telmisartan raises potassium; adding these can cause heart rhythm failure (Hyperkalemia).",
          },
          {
            "item": "Salt Substitutes (Lona Salt)",
            "risk": "High",
            "note":
                "Usually made of Potassium Chloride. Extremely dangerous with BP meds.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Kidney Artery Stenosis",
            "risk": "High",
            "note": "Can lead to acute kidney failure.",
          },
          {
            "condition": "Pregnancy",
            "risk": "Critical",
            "note": "Highly toxic to fetal development.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Ibuprofen",
            "risk": "Med",
            "note":
                "Reduces the Blood Pressure lowering effect and harms kidneys.",
          },
          {
            "target": "Spironolactone",
            "risk": "High",
            "note": "Fatal potassium buildup risk.",
          },
        ],
      },
      {
        "id": "metronidazole",
        "name": "Metronidazole",
        "brands": ["Flagyl", "Metrogyl"],
        "salt": "Nitroimidazole",
        "allergy_group": "Nitroimidazoles",
        "food_clashes": [
          {
            "item": "Alcohol",
            "risk": "Critical",
            "note":
                "Causes 'Disulfiram reaction': Violent vomiting, rapid heartbeat, and severe headache.",
          },
          {
            "item": "Vinegar / Sauces",
            "risk": "Med",
            "note": "Trace alcohol in fermented foods can trigger nausea.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Liver Disease",
            "risk": "High",
            "note": "Drug accumulates to toxic levels.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Warfarin",
            "risk": "High",
            "note": "Increases blood thinning, leading to internal bleeding.",
          },
          {
            "target": "Lithium",
            "risk": "High",
            "note": "Can cause lithium toxicity (kidney damage).",
          },
        ],
      },
      {
        "id": "aspirin",
        "name": "Aspirin",
        "brands": ["Ecosprin", "Delisprin"],
        "salt": "Acetylsalicylic Acid",
        "allergy_group": "NSAIDs / Salicylates",
        "food_clashes": [
          {
            "item": "Alcohol",
            "risk": "High",
            "note":
                "Irritates stomach lining, causing severe gastric bleeding.",
          },
          {
            "item": "Garlic, Ginger, Ginseng",
            "risk": "Med",
            "note":
                "Natural blood thinners. Combined with Aspirin, they increase bruising/bleeding.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Peptic Ulcers",
            "risk": "Critical",
            "note": "Can cause stomach perforation (holes).",
          },
          {
            "condition": "Asthma",
            "risk": "High",
            "note":
                "Can trigger a severe bronchospasm (Aspirin-induced asthma).",
          },
          {
            "condition": "Dengue Fever",
            "risk": "Critical",
            "note":
                "NEVER take during Dengue as it prevents clotting, leading to fatal hemorrhage.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Ibuprofen",
            "risk": "High",
            "note": "Blocks the heart-protective effect of Aspirin.",
          },
          {
            "target": "Clopidogrel",
            "risk": "Med",
            "note": "Double blood-thinning effect; needs doctor supervision.",
          },
        ],
      },
      {
        "id": "metformin",
        "name": "Metformin",
        "brands": ["Glycomet", "Metsmall"],
        "salt": "Biguanide",
        "allergy_group": "Biguanides",
        "food_clashes": [
          {
            "item": "Alcohol",
            "risk": "High",
            "note":
                "Massively increases risk of Lactic Acidosis (a life-threatening condition).",
          },
          {
            "item": "Very High Fiber Meals",
            "risk": "Low",
            "note": "May slightly reduce the absorption of the drug.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Severe Kidney Disease",
            "risk": "Critical",
            "note":
                "Metformin is cleared by kidneys; failure to clear it causes fatal toxicity.",
          },
          {
            "condition": "Heart Failure",
            "risk": "High",
            "note": "Increased risk of oxygen deprivation in tissues.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Contrast Dye (X-ray/CT Scan)",
            "risk": "High",
            "note":
                "Must stop Metformin 48h before scans to prevent kidney shut down.",
          },
        ],
      },
      {
        "id": "atorvastatin",
        "name": "Atorvastatin",
        "brands": ["Atorva", "Lipicure", "Tonact"],
        "salt": "HMG-CoA Reductase Inhibitor",
        "allergy_group": "Statins",
        "food_clashes": [
          {
            "item": "Grapefruit / Grapefruit Juice",
            "risk": "High",
            "note":
                "Blocks the enzyme that breaks down the statin, leading to muscle damage.",
          },
          {
            "item": "Red Yeast Rice",
            "risk": "Med",
            "note": "Contains natural statins; causes overdose effect.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Active Liver Disease",
            "risk": "High",
            "note": "Statins can increase liver enzymes to dangerous levels.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Clarithromycin",
            "risk": "High",
            "note":
                "Severe muscle pain and kidney damage risk (Rhabdomyolysis).",
          },
          {
            "target": "Fluconazole",
            "risk": "Med",
            "note": "Increases statin levels in blood.",
          },
        ],
      },
      {
        "id": "levothyroxine",
        "name": "Levothyroxine",
        "brands": ["Thyronorm", "Eltroxin"],
        "salt": "Synthetic T4 Hormone",
        "allergy_group": "Hormones",
        "food_clashes": [
          {
            "item": "Soyabean Flour / Milk",
            "risk": "High",
            "note":
                "Soy prevents the body from absorbing thyroid hormone. Take 4 hours apart.",
          },
          {
            "item": "Walnuts / High Fiber",
            "risk": "Med",
            "note":
                "Reduces absorption. Must be taken on a completely empty stomach.",
          },
          {
            "item": "Espresso / Coffee",
            "risk": "High",
            "note": "Caffeine significantly lowers absorption of thyroid meds.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Adrenal Insufficiency",
            "risk": "High",
            "note": "May trigger an acute adrenal crisis.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Calcium Carbonate",
            "risk": "High",
            "note": "Calcium binds to the hormone. Never take together.",
          },
          {
            "target": "Iron Supplements",
            "risk": "High",
            "note": "Iron blocks thyroid medicine absorption.",
          },
        ],
      },
      {
        "id": "warfarin",
        "name": "Warfarin",
        "brands": ["Uniwarfin", "Coumadin"],
        "salt": "Coumarin Derivative",
        "allergy_group": "Anticoagulants",
        "food_clashes": [
          {
            "item": "Leafy Greens (Palak, Sarson, Methi)",
            "risk": "High",
            "note":
                "High Vitamin K in these greens acts as an 'antidote' to Warfarin, making the medicine fail.",
          },
          {
            "item": "Cranberry Juice",
            "risk": "High",
            "note":
                "Increases Warfarin effect, leading to spontaneous internal bleeding.",
          },
          {
            "item": "Green Tea",
            "risk": "Med",
            "note": "Contains Vitamin K which opposes the drug's effect.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Recent Surgery",
            "risk": "Critical",
            "note": "Will cause wound hemorrhage.",
          },
          {
            "condition": "High Blood Pressure",
            "risk": "High",
            "note": "Increased risk of brain hemorrhage (Stroke).",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Aspirin",
            "risk": "Critical",
            "note": "Extreme bleeding risk. Often fatal.",
          },
          {
            "target": "Diclofenac",
            "risk": "High",
            "note": "Causes stomach bleeding.",
          },
        ],
      },
      {
        "id": "amoxicillin",
        "name": "Amoxicillin",
        "brands": ["Mox", "Novamox"],
        "salt": "Penicillin",
        "allergy_group": "Penicillins",
        "food_clashes": [],
        "condition_clashes": [
          {
            "condition": "Mononucleosis (Kissing Disease)",
            "risk": "High",
            "note": "Causes a massive non-allergic skin rash.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Methotrexate",
            "risk": "High",
            "note":
                "Amoxicillin prevents the body from clearing this cancer drug, causing toxicity.",
          },
          {
            "target": "Birth Control Pills",
            "risk": "Med",
            "note": "May reduce the effectiveness of the contraceptive.",
          },
        ],
      },
      {
        "id": "digoxin",
        "name": "Digoxin",
        "brands": ["Lanoxin"],
        "salt": "Cardiac Glycoside",
        "allergy_group": "Digitalis",
        "food_clashes": [
          {
            "item": "Licorice (Mulethi)",
            "risk": "High",
            "note":
                "Mulethi lowers potassium, which makes Digoxin toxic, causing heart failure.",
          },
          {
            "item": "High Fiber Bran",
            "risk": "Med",
            "note":
                "Fibers absorb the drug and pull it out of the body before it can work.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Hypokalemia (Low Potassium)",
            "risk": "High",
            "note":
                "Digoxin becomes toxic very quickly in low potassium environments.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Frusemide (Lasix)",
            "risk": "High",
            "note":
                "Lasix flushes out potassium, triggering Digoxin poisoning.",
          },
        ],
      },
      {
        "id": "amlodipine",
        "name": "Amlodipine",
        "brands": ["Stamlo", "Amlokind"],
        "salt": "Calcium Channel Blocker",
        "allergy_group": "Dihydropyridines",
        "food_clashes": [
          {
            "item": "Grapefruit Juice",
            "risk": "High",
            "note":
                "Increases the amount of drug in your body, causing fainting and dangerously low BP.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Severe Aortic Stenosis",
            "risk": "High",
            "note": "Risk of heart collapse.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Simvastatin",
            "risk": "Med",
            "note": "Increases simvastatin levels; can cause muscle pain.",
          },
        ],
      },
      {
        "id": "paracetamol",
        "name": "Paracetamol",
        "brands": ["Dolo 650", "Crocin", "Calpol"],
        "salt": "Aniline Analgesic",
        "allergy_group": "None",
        "food_clashes": [
          {
            "item": "Alcohol",
            "risk": "High",
            "note": "Severe risk of permanent liver failure.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Liver Cirrhosis",
            "risk": "Critical",
            "note": "Even small doses can be toxic.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Isoniazid (TB Meds)",
            "risk": "High",
            "note": "Increases liver toxicity risk.",
          },
        ],
      },
      {
        "id": "doxycycline",
        "name": "Doxycycline",
        "brands": ["Doxicip", "Microdox"],
        "salt": "Tetracycline",
        "allergy_group": "Tetracyclines",
        "food_clashes": [
          {
            "item": "Milk / Dairy / Paneer",
            "risk": "High",
            "note":
                "Calcium prevents absorption. The antibiotic will not work.",
          },
          {
            "item": "Iron-rich food",
            "risk": "Med",
            "note": "Iron binds to the drug and stops its action.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Liver Disease",
            "risk": "Med",
            "note": "Metabolism is slowed.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Isotretinoin (Acne Meds)",
            "risk": "High",
            "note": "Can cause permanent brain pressure (Pseudotumor cerebri).",
          },
        ],
      },
      {
        "id": "montelukast",
        "name": "Montelukast",
        "brands": ["Montek", "Telekast"],
        "salt": "Leukotriene Receptor Antagonist",
        "allergy_group": "Leukotriene Modifiers",
        "food_clashes": [],
        "condition_clashes": [
          {
            "condition": "Depression / Anxiety",
            "risk": "High",
            "note":
                "Known to cause vivid nightmares and suicidal thoughts (Neuropsychiatric events).",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Phenobarbital",
            "risk": "Med",
            "note": "Reduces Montelukast effectiveness.",
          },
        ],
      },
      {
        "id": "salbutamol",
        "name": "Salbutamol",
        "brands": ["Asthalin", "Ventolin"],
        "salt": "Beta-2 Agonist",
        "allergy_group": "Bronchodilators",
        "food_clashes": [
          {
            "item": "Caffeine",
            "risk": "Med",
            "note":
                "Both stimulate the heart; causes racing heart and tremors.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Hyperthyroidism",
            "risk": "Med",
            "note": "Worsens tremors and heart rate.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Atenolol / Propropanolol",
            "risk": "Critical",
            "note":
                "Beta-blockers stop Salbutamol from opening the lungs. Can lead to fatal asthma attack.",
          },
        ],
      },
      {
        "id": "pantoprazole",
        "name": "Pantoprazole",
        "brands": ["Pan 40", "Pantocid"],
        "salt": "Proton Pump Inhibitor (PPI)",
        "allergy_group": "PPIs",
        "food_clashes": [
          {
            "item": "Fried / Oily Foods",
            "risk": "Low",
            "note":
                "Delays the action of the drug. Take on empty stomach for best results.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Osteoporosis",
            "risk": "Med",
            "note":
                "Long term use reduces calcium absorption, increasing bone fracture risk.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Iron Salts",
            "risk": "High",
            "note": "PPIs reduce stomach acid needed to absorb iron.",
          },
          {
            "target": "Ketoconazole",
            "risk": "High",
            "note": "Blocks antifungal absorption.",
          },
        ],
      },
      {
        "id": "levocetirizine",
        "name": "Levocetirizine",
        "brands": ["Levocet", "Cezin"],
        "salt": "Third Gen Antihistamine",
        "allergy_group": "Antihistamines",
        "food_clashes": [
          {
            "item": "Alcohol",
            "risk": "High",
            "note":
                "Severe impairment of mental alertness and motor coordination.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Kidney Failure",
            "risk": "High",
            "note": "Drug cannot be cleared from the body.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Sleep Medications",
            "risk": "High",
            "note": "Dangerous levels of sedation.",
          },
        ],
      },
      {
        "id": "fluconazole",
        "name": "Fluconazole",
        "brands": ["Forcan", "Zocon"],
        "salt": "Azole Antifungal",
        "allergy_group": "Azoles",
        "food_clashes": [],
        "condition_clashes": [
          {
            "condition": "Long QT Syndrome (Heart)",
            "risk": "High",
            "note": "Can cause fatal heart rhythm disturbances.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Erythromycin",
            "risk": "Critical",
            "note": "Sudden cardiac death risk due to heart rhythm clash.",
          },
          {
            "target": "Glimepiride",
            "risk": "Med",
            "note":
                "Increases risk of dangerously low blood sugar (Hypoglycemia).",
          },
        ],
      },
      {
        "id": "iron_ferrous_ascorbate",
        "name": "Iron (Ferrous Ascorbate)",
        "brands": ["Orofer XT", "Livogen"],
        "salt": "Iron Mineral",
        "allergy_group": "None",
        "food_clashes": [
          {
            "item": "Tea / Coffee (Tannins)",
            "risk": "High",
            "note":
                "Tannins block iron absorption by 70%. Never take together.",
          },
          {
            "item": "Dairy / Milk",
            "risk": "High",
            "note": "Calcium blocks iron absorption.",
          },
          {
            "item": "Eggs",
            "risk": "Med",
            "note": "Contain phosvitin which prevents iron absorption.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Hemochromatosis",
            "risk": "Critical",
            "note": "Causes iron overload and organ damage.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Tetracycline",
            "risk": "High",
            "note": "Both drugs block each other; neither will work.",
          },
        ],
      },
      {
        "id": "prednisolone",
        "name": "Prednisolone",
        "brands": ["Wysolone", "Omnacortil"],
        "salt": "Glucocorticoid (Steroid)",
        "allergy_group": "Steroids",
        "food_clashes": [
          {
            "item": "High Salt / Sodium (Pickles, Namkeen)",
            "risk": "High",
            "note":
                "Steroids cause salt retention; can cause massive swelling (Edema) and high BP.",
          },
          {
            "item": "Sugar / Sweets",
            "risk": "High",
            "note":
                "Steroids raise blood sugar; risk of sudden Diabetes spike.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Diabetes",
            "risk": "High",
            "note": "Will make blood sugar impossible to control.",
          },
          {
            "condition": "Fungal Infections",
            "risk": "Critical",
            "note":
                "Steroids suppress immunity, allowing fungus to spread rapidly.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Ibuprofen",
            "risk": "High",
            "note": "Guaranteed stomach ulcer risk.",
          },
        ],
      },
      {
        "id": "azithromycin",
        "name": "Azithromycin",
        "brands": ["Azithral", "Azee"],
        "salt": "Macrolide Antibiotic",
        "allergy_group": "Macrolides",
        "food_clashes": [
          {
            "item": "Antacids (Digene, Gelusil)",
            "risk": "High",
            "note":
                "Magnesium/Aluminum in antacids blocks the antibiotic from entering the blood.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Arrhythmia (Heart)",
            "risk": "High",
            "note": "Risk of life-threatening irregular heartbeat.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Atorvastatin",
            "risk": "Med",
            "note": "Increases risk of muscle breakdown.",
          },
        ],
      },
      {
        "id": "diclofenac",
        "name": "Diclofenac",
        "brands": ["Voveran", "Dynapar"],
        "salt": "NSAID",
        "allergy_group": "NSAIDs",
        "food_clashes": [
          {
            "item": "Alcohol",
            "risk": "High",
            "note": "Major stomach bleeding risk.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Heart Failure",
            "risk": "High",
            "note": "Causes fluid retention, worsening the heart's workload.",
          },
          {
            "condition": "Kidney Disease",
            "risk": "High",
            "note": "Blocks blood flow to kidneys.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Warfarin",
            "risk": "Critical",
            "note": "Fatal internal bleeding risk.",
          },
        ],
      },
      {
        "id": "glimepiride",
        "name": "Glimepiride",
        "brands": ["Amaryl", "Glimy"],
        "salt": "Sulfonylurea",
        "allergy_group": "Sulfa Drugs",
        "food_clashes": [
          {
            "item": "Skipping Meals",
            "risk": "Critical",
            "note":
                "Will cause a 'Hypoglycemic Attack' (Fainting/Seizure from low sugar).",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Sulfa Allergy",
            "risk": "High",
            "note": "Can trigger severe allergic skin reactions.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Aspirin",
            "risk": "Med",
            "note":
                "Aspirin makes Glimepiride stronger, causing sugar crashes.",
          },
        ],
      },
      {
        "id": "metoprolol",
        "name": "Metoprolol",
        "brands": ["Metolar", "Seloken"],
        "salt": "Beta-Blocker",
        "allergy_group": "Beta-Blockers",
        "food_clashes": [
          {
            "item": "Alcohol",
            "risk": "High",
            "note":
                "Blood pressure drops too low, leading to dizziness and falls.",
          },
          {
            "item": "High Protein Meals",
            "risk": "Low",
            "note": "Increases the amount of drug absorbed.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Asthma",
            "risk": "Critical",
            "note": "Triggers airway constriction, making breathing difficult.",
          },
          {
            "condition": "Bradycardia (Slow Heart)",
            "risk": "High",
            "note": "May cause the heart to stop.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Diltiazem",
            "risk": "High",
            "note": "Heart rate drops to dangerously low levels.",
          },
        ],
      },
      {
        "id": "calcium_carbonate",
        "name": "Calcium Carbonate",
        "brands": ["Shelcal", "Calcirol"],
        "salt": "Mineral Supplement",
        "allergy_group": "None",
        "food_clashes": [
          {
            "item": "Spinach (Oxalates)",
            "risk": "Med",
            "note":
                "Oxalates in spinach bind with calcium, preventing its absorption.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Kidney Stones",
            "risk": "High",
            "note": "May increase stone size/formation.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Ciprofloxacin",
            "risk": "High",
            "note":
                "Calcium renders the antibiotic useless. Take 4 hours apart.",
          },
        ],
      },
      {
        "id": "albendazole",
        "name": "Albendazole",
        "brands": ["Zentel", "Bandicard"],
        "salt": "Anthelmintic",
        "allergy_group": "Benzimidazoles",
        "food_clashes": [
          {
            "item": "High Fat Meals (Ghee, Butter)",
            "risk": "Positive Impact",
            "note":
                "Actually increases absorption by 5x; required if treating tissue infections (Neurocysticercosis).",
          },
        ],
        "condition_clashes": [],
        "drug_drug_interactions": [
          {
            "target": "Dexamethasone",
            "risk": "Med",
            "note": "Increases Albendazole levels in blood.",
          },
        ],
      },
      {
        "id": "rosuvastatin",
        "name": "Rosuvastatin",
        "brands": ["Rosuvas", "Crestor"],
        "salt": "Statin",
        "allergy_group": "Statins",
        "food_clashes": [
          {
            "item": "Excessive Fiber (Oat Bran)",
            "risk": "Low",
            "note": "May slightly decrease the absorption.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Active Liver Disease",
            "risk": "High",
            "note": "Risk of liver toxicity.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Antacids",
            "risk": "Med",
            "note": "Antacids lower Rosuvastatin absorption. Take 2h apart.",
          },
        ],
      },
      {
        "id": "enalapril",
        "name": "Enalapril",
        "brands": ["Envas", "BPLat"],
        "salt": "ACE Inhibitor",
        "allergy_group": "ACE Inhibitors",
        "food_clashes": [
          {
            "item": "Potassium (Bananas, Oranges)",
            "risk": "Med",
            "note": "Increases potassium levels in blood.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "History of Angioedema (Swelling)",
            "risk": "Critical",
            "note": "Risk of throat swelling shut (Life-threatening).",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Lithium",
            "risk": "High",
            "note": "Toxic lithium buildup.",
          },
        ],
      },
      {
        "id": "losartan",
        "name": "Losartan",
        "brands": ["Losacar", "Repace"],
        "salt": "ARB",
        "allergy_group": "Sartans",
        "food_clashes": [
          {
            "item": "Salt Substitutes",
            "risk": "High",
            "note": "Dangerous potassium buildup.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Severe Dehydration",
            "risk": "High",
            "note": "Risk of sudden kidney failure.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Aliskiren",
            "risk": "Critical",
            "note": "High risk of kidney failure and stroke.",
          },
        ],
      },
      {
        "id": "vildagliptin",
        "name": "Vildagliptin",
        "brands": ["Galvus", "Vildapure"],
        "salt": "DPP-4 Inhibitor",
        "allergy_group": "Gliptins",
        "food_clashes": [],
        "condition_clashes": [
          {
            "condition": "History of Pancreatitis",
            "risk": "High",
            "note": "May trigger severe pancreatic inflammation.",
          },
        ],
        "drug_drug_interactions": [],
      },
      {
        "id": "teneligliptin",
        "name": "Teneligliptin",
        "brands": ["Teneza", "Dynaglipt"],
        "salt": "DPP-4 Inhibitor",
        "allergy_group": "Gliptins",
        "food_clashes": [],
        "condition_clashes": [
          {
            "condition": "Heart Failure",
            "risk": "Med",
            "note": "Needs close monitoring for edema.",
          },
        ],
        "drug_drug_interactions": [],
      },
      {
        "id": "folic_acid",
        "name": "Folic Acid",
        "brands": ["Folvite"],
        "salt": "Vitamin B9",
        "allergy_group": "None",
        "food_clashes": [],
        "condition_clashes": [
          {
            "condition": "Pernicious Anemia",
            "risk": "High",
            "note":
                "Folic acid can hide Vitamin B12 deficiency symptoms while nerve damage continues.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Phenytoin",
            "risk": "Med",
            "note": "Lowers anti-seizure drug levels.",
          },
        ],
      },
      {
        "id": "levofloxacin",
        "name": "Levofloxacin",
        "brands": ["Loxof", "Levoquid"],
        "salt": "Quinolone",
        "allergy_group": "Quinolones",
        "food_clashes": [
          {
            "item": "Dairy / Calcium",
            "risk": "High",
            "note": "Reduces antibiotic strength.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "History of Tendonitis",
            "risk": "High",
            "note": "Risk of Achilles tendon rupture.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Prednisolone",
            "risk": "High",
            "note": "Increases risk of tendon rupture significantly.",
          },
        ],
      },
      {
        "id": "aceclofenac",
        "name": "Aceclofenac",
        "brands": ["Zerodol", "Aceclo"],
        "salt": "NSAID",
        "allergy_group": "NSAIDs",
        "food_clashes": [
          {
            "item": "Spicy Food",
            "risk": "Med",
            "note": "Worsens drug-induced acidity and ulcer risk.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Coronary Artery Bypass Surgery",
            "risk": "Critical",
            "note": "Do not use before or after heart surgery.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Aspirin",
            "risk": "High",
            "note": "Increased GI ulcer risk.",
          },
        ],
      },
      {
        "id": "mefenamic_acid",
        "name": "Mefenamic Acid",
        "brands": ["Meftal", "Mefkind"],
        "salt": "NSAID",
        "allergy_group": "NSAIDs",
        "food_clashes": [],
        "condition_clashes": [
          {
            "condition": "Inflammatory Bowel Disease (IBD)",
            "risk": "High",
            "note": "Can trigger a flare-up and bleeding.",
          },
        ],
        "drug_drug_interactions": [
          {"target": "Warfarin", "risk": "High", "note": "Bleeding risk."},
        ],
      },
      {
        "id": "cefixime",
        "name": "Cefixime",
        "brands": ["Taxim-O", "Zifi"],
        "salt": "Cephalosporin",
        "allergy_group": "Cephalosporins",
        "food_clashes": [],
        "condition_clashes": [
          {
            "condition": "Penicillin Allergy",
            "risk": "Med",
            "note": "10% cross-reactivity risk. May cause allergic shock.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Warfarin",
            "risk": "Med",
            "note":
                "Alters gut bacteria, potentially increasing blood thinning.",
          },
        ],
      },
      {
        "id": "omeprazole",
        "name": "Omeprazole",
        "brands": ["Omez", "Omecip"],
        "salt": "PPI",
        "allergy_group": "PPIs",
        "food_clashes": [
          {
            "item": "Caffeine",
            "risk": "Low",
            "note":
                "Caffeine triggers acid production, opposing the drug's goal.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "B12 Deficiency",
            "risk": "Med",
            "note": "Long-term acid suppression prevents B12 absorption.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Clopidogrel",
            "risk": "High",
            "note":
                "Omeprazole stops Clopidogrel from working, increasing heart attack risk.",
          },
        ],
      },
      {
        "id": "clopidogrel",
        "name": "Clopidogrel",
        "brands": ["Clopilet", "Deplatt"],
        "salt": "Anti-platelet",
        "allergy_group": "Thienopyridines",
        "food_clashes": [
          {
            "item": "Papaya",
            "risk": "Med",
            "note": "May increase the anti-clotting effect.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Intracranial Hemorrhage",
            "risk": "Critical",
            "note": "Will prevent brain blood from clotting.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Omeprazole",
            "risk": "High",
            "note": "Renders Clopidogrel ineffective.",
          },
        ],
      },
      {
        "id": "ranitidine",
        "name": "Ranitidine",
        "brands": ["Rantac", "Zinetac"],
        "salt": "H2 Blocker",
        "allergy_group": "H2 Antagonists",
        "food_clashes": [
          {
            "item": "Alcohol",
            "risk": "Med",
            "note": "May increase blood alcohol concentrations.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Porphyria",
            "risk": "High",
            "note": "Can trigger an acute porphyria attack.",
          },
        ],
        "drug_drug_interactions": [],
      },
      {
        "id": "domperidone",
        "name": "Domperidone",
        "brands": ["Domstal", "Motinorm"],
        "salt": "Dopamine Antagonist",
        "allergy_group": "Antiemetics",
        "food_clashes": [],
        "condition_clashes": [
          {
            "condition": "Pituitary Tumor",
            "risk": "High",
            "note": "May increase prolactin levels further.",
          },
          {
            "condition": "Heart Disease",
            "risk": "High",
            "note": "Risk of sudden cardiac death in high doses.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Ketoconazole",
            "risk": "Critical",
            "note":
                "Massively increases Domperidone levels; high heart failure risk.",
          },
        ],
      },
      {
        "id": "levocetirizine_ambroxol",
        "name": "Levocetirizine + Ambroxol",
        "brands": ["Levolin", "Ambrodil-LX"],
        "salt": "Antihistamine + Mucolytic",
        "allergy_group": "Combination",
        "food_clashes": [
          {
            "item": "Alcohol",
            "risk": "High",
            "note": "Excessive drowsiness and breathing depression.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Severe Gastric Ulcer",
            "risk": "Med",
            "note": "Ambroxol may irritate the stomach lining.",
          },
        ],
        "drug_drug_interactions": [],
      },
      {
        "id": "cetirizine",
        "name": "Cetirizine",
        "brands": ["Okacet", "Zyrtec"],
        "salt": "Antihistamine",
        "allergy_group": "Antihistamines",
        "food_clashes": [
          {"item": "Alcohol", "risk": "High", "note": "Severe sedation risk."},
        ],
        "condition_clashes": [
          {
            "condition": "Enlarged Prostate",
            "risk": "Med",
            "note": "May cause difficulty in passing urine.",
          },
        ],
        "drug_drug_interactions": [],
      },
      {
        "id": "ofloxacin_ornidazole",
        "name": "Ofloxacin + Ornidazole",
        "brands": ["O2", "Zenflox-OZ"],
        "salt": "Quinolone + Nitroimidazole",
        "allergy_group": "Combination",
        "food_clashes": [
          {
            "item": "Dairy / Milk",
            "risk": "High",
            "note": "Ofloxacin component is blocked by calcium.",
          },
          {
            "item": "Alcohol",
            "risk": "High",
            "note": "Disulfiram reaction due to Ornidazole.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Epilepsy",
            "risk": "High",
            "note": "Lower seizure threshold.",
          },
        ],
        "drug_drug_interactions": [],
      },
      {
        "id": "sitagliptin",
        "name": "Sitagliptin",
        "brands": ["Januvia", "Istavel"],
        "salt": "DPP-4 Inhibitor",
        "allergy_group": "Gliptins",
        "food_clashes": [],
        "condition_clashes": [
          {
            "condition": "Moderate Kidney Disease",
            "risk": "Med",
            "note": "Requires dose adjustment.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Digoxin",
            "risk": "Med",
            "note": "May slightly increase Digoxin levels.",
          },
        ],
      },
      {
        "id": "frusemide",
        "name": "Frusemide (Furosemide)",
        "brands": ["Lasix"],
        "salt": "Loop Diuretic",
        "allergy_group": "Sulfonamides",
        "food_clashes": [
          {
            "item": "Licorice (Mulethi)",
            "risk": "High",
            "note": "Causes severe loss of potassium.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Sulfa Allergy",
            "risk": "High",
            "note": "May trigger severe allergic reaction.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Gentamicin",
            "risk": "High",
            "note": "Permanent hearing loss risk.",
          },
        ],
      },
      {
        "id": "spironolactone",
        "name": "Spironolactone",
        "brands": ["Aldactone"],
        "salt": "Potassium-sparing Diuretic",
        "allergy_group": "Diuretics",
        "food_clashes": [
          {
            "item": "Bananas / Spinach",
            "risk": "High",
            "note": "Life-threatening potassium levels.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Addison's Disease",
            "risk": "Critical",
            "note": "Worsens hormonal imbalance.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Telmisartan",
            "risk": "High",
            "note": "Extreme potassium spike risk.",
          },
        ],
      },
      {
        "id": "bisoprolol",
        "name": "Bisoprolol",
        "brands": ["Concor"],
        "salt": "Beta-Blocker",
        "allergy_group": "Beta-Blockers",
        "food_clashes": [],
        "condition_clashes": [
          {
            "condition": "Asthma",
            "risk": "High",
            "note": "Worsens lung capacity.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Diltiazem",
            "risk": "High",
            "note": "Heart blockage risk.",
          },
        ],
      },
      {
        "id": "vitamin_d3_cholecalciferol",
        "name": "Vitamin D3 (Cholecalciferol)",
        "brands": ["Uprise D3", "Calcirol"],
        "salt": "Vitamin",
        "allergy_group": "None",
        "food_clashes": [
          {
            "item": "Butter / Oily food",
            "risk": "Positive Impact",
            "note":
                "D3 is fat-soluble. Absorption improves when taken with fat.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Hypercalcemia",
            "risk": "High",
            "note": "Toxic levels of calcium in blood.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Weight Loss Meds (Orlistat)",
            "risk": "Med",
            "note": "Orlistat prevents D3 absorption.",
          },
        ],
      },
      {
        "id": "norfloxacin",
        "name": "Norfloxacin",
        "brands": ["Norflox-400"],
        "salt": "Quinolone",
        "allergy_group": "Quinolones",
        "food_clashes": [
          {
            "item": "Milk / Yogurt",
            "risk": "High",
            "note": "Calcium blocks absorption.",
          },
        ],
        "condition_clashes": [],
        "drug_drug_interactions": [
          {
            "target": "Antacids",
            "risk": "High",
            "note": "Renders drug ineffective.",
          },
        ],
      },
      {
        "id": "clarithromycin",
        "name": "Clarithromycin",
        "brands": ["Crixan", "Klarim"],
        "salt": "Macrolide",
        "allergy_group": "Macrolides",
        "food_clashes": [
          {
            "item": "Fruit Juices",
            "risk": "Med",
            "note": "May decrease absorption.",
          },
        ],
        "condition_clashes": [
          {
            "condition": "Liver Impairment",
            "risk": "High",
            "note": "Causes metabolic toxic strain.",
          },
        ],
        "drug_drug_interactions": [
          {
            "target": "Atorvastatin",
            "risk": "Critical",
            "note": "Can cause fatal kidney failure due to statin buildup.",
          },
        ],
      },
    ];

    // Convert raw data to DrugModel list
    return rawData.map((data) {
      // Convert food clashes
      final foodInteractions = (data['food_clashes'] as List)
          .map(
            (f) => FoodInteraction(
              food: f['item'] as String,
              severity: _mapFoodRiskToSeverity(f['risk'] as String),
              description: f['note'] as String,
            ),
          )
          .toList();

      // Convert drug-drug interactions
      final drugInteractions = (data['drug_drug_interactions'] as List)
          .map(
            (d) => DrugInteraction(
              drugName: d['target'] as String,
              severity: _mapRiskToSeverity(d['risk'] as String),
              description: d['note'] as String,
            ),
          )
          .toList();

      // Extract condition warnings
      final conditionWarnings = (data['condition_clashes'] as List)
          .map((c) => '${c['condition']}: ${c['note']}')
          .toList();

      // Extract allergy warnings
      final allergyWarnings = <String>[];
      if (data['allergy_group'] != 'None' && data['allergy_group'] != null) {
        allergyWarnings.add(data['allergy_group'] as String);
      }

      return DrugModel(
        displayName: data['name'] as String,
        brandNames: List<String>.from(data['brands'] as List),
        category: data['salt'] as String,
        allergyWarnings: allergyWarnings,
        conditionWarnings: conditionWarnings,
        drugInteractions: drugInteractions,
        foodInteractions: foodInteractions,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Data Migration',
          style: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.mintGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This will upload 50 drugs to your Firebase database. This is a one-time operation.',
                      style: TextStyle(color: AppColors.lightText, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Progress Section
            if (_isLoading || _uploadedCount > 0) ...[
              Text(
                'Progress',
                style: TextStyle(
                  color: AppColors.lightText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _totalCount > 0 ? _uploadedCount / _totalCount : 0,
                backgroundColor: AppColors.cardBg,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.mintGreen),
              ),
              const SizedBox(height: 8),
              Text(
                _isLoading
                    ? 'Uploading: $_currentDrug ($_uploadedCount/$_totalCount)'
                    : 'Completed: $_uploadedCount/$_totalCount drugs',
                style: TextStyle(color: AppColors.mutedText, fontSize: 13),
              ),
              const SizedBox(height: 24),
            ],

            // Logs Section
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final isError = log.contains('✗') || log.contains('Error');
                    final isSuccess = log.contains('✓');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: isError
                              ? Colors.red
                              : isSuccess
                              ? AppColors.mintGreen
                              : AppColors.mutedText,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Single Drugs Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startMigration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('Uploading...'),
                        ],
                      )
                    : Text(
                        'Import Single Drugs (50)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            // Combo Drugs Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startComboMigration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.layers_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Import Combo Drugs (25)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

