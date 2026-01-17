# PharmaClash - Complete Code Walkthrough
**A comprehensive guide to understanding the codebase**

---

## 📁 Project Structure Overview

```
lib/
├── main.dart                    # App entry point & routing
├── firebase_options.dart        # Firebase configuration (auto-generated)
│
├── models/                      # Data models
│   ├── drug_model.dart          # Drug, Interactions, Ingredients
│   └── medical_reference_data.dart  # Reference data for allergies/conditions
│
├── screens/                     # UI Screens
│   ├── splash_screen.dart       # Animated app launch screen
│   ├── login_screen.dart        # User authentication
│   ├── registration_screen.dart # New user signup
│   ├── medical_info_screen.dart # Health profile setup
│   ├── dashboard_screen.dart    # Main app dashboard
│   ├── scan_screen.dart         # Camera OCR scanning
│   ├── profile_screen.dart      # User profile & settings
│   └── admin/                   # Admin panel screens
│       ├── admin_login_screen.dart
│       ├── admin_dashboard_screen.dart
│       ├── drug_list_screen.dart
│       ├── add_edit_drug_screen.dart
│       └── data_migration_screen.dart
│
├── services/                    # Business logic
│   ├── firebase_service.dart    # Authentication & Firestore
│   ├── drug_service.dart        # Drug database operations
│   └── emergency_service.dart   # Caregiver alerts
│
├── theme/                       # Styling
│   └── app_colors.dart          # Centralized color palette
│
└── widgets/                     # Reusable components
    └── [shared widgets]
```

---

## 🚀 1. App Entry Point: `main.dart`

### What it does:
- Initializes Firebase
- Sets up the MaterialApp with theme
- Defines all navigation routes

### Key Code Explained:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // Required for async operations before runApp
  await Firebase.initializeApp(               // Initialize Firebase
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```

### Route Definitions:
```dart
routes: {
  '/': (context) => const SplashScreen(),           // App starts here
  '/login': (context) => const LoginScreen(),       // User login
  '/register': (context) => const RegistrationScreen(),
  '/medical-info': (context) => const MedicalInfoScreen(),
  '/dashboard': (context) => const DashboardScreen(),
  '/scan': (context) => const ScanScreen(),
  '/profile': (context) => const ProfileScreen(),
  '/admin-login': (context) => const AdminLoginScreen(),
  '/admin': (context) => const AdminDashboardScreen(),
}
```

**Flow:** Splash → Login → Registration → Medical Info → Dashboard

---

## 🔐 2. Authentication: `firebase_service.dart`

### What it does:
- Handles user signup/login
- Google Sign-In integration
- Saves/retrieves user data from Firestore

### Key Classes & Methods:

```dart
class FirebaseService {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get currently logged in user
  User? get currentUser => _auth.currentUser;
```

### Authentication Methods:

#### 1. Email/Password Signup
```dart
Future<UserCredential?> signUpWithEmailAndPassword({
  required String email,
  required String password,
}) async {
  // Creates a new Firebase Auth user
  return await _auth.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
}
```

#### 2. Email/Password Login
```dart
Future<UserCredential?> signInWithEmailAndPassword({
  required String email,
  required String password,
}) async {
  return await _auth.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
}
```

#### 3. Google Sign-In
```dart
Future<UserCredential?> signInWithGoogle() async {
  // Step 1: Open Google Sign-In dialog
  final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
  
  // Step 2: Get authentication details
  final GoogleSignInAuthentication googleAuth = await googleUser!.authentication;
  
  // Step 3: Create Firebase credential
  final credential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );
  
  // Step 4: Sign in to Firebase
  return await _auth.signInWithCredential(credential);
}
```

### Firestore Data Storage:

#### User Profile Structure:
```dart
// Collection: 'users' → Document: userId
{
  'email': 'user@example.com',
  'fullName': 'John Doe',
  'phone': '9876543210',
  'dateOfBirth': Timestamp,
  'gender': 'Male',
  'isAdmin': false,
  'createdAt': Timestamp,
}
```

#### Medical Info Structure:
```dart
// Collection: 'medical_info' → Document: userId
{
  'allergies': ['Penicillin', 'Sulfa'],
  'chronicConditions': ['Diabetes Type 2', 'Hypertension'],
  'caregiverName': 'Jane Doe',
  'caregiverPhone': '9876543210',
  'profileCompleted': true,
}
```

---

## 💊 3. Drug Model: `drug_model.dart`

### What it represents:
A medicine with all its safety information

### Key Classes:

#### 1. DrugModel (Main class)
```dart
class DrugModel {
  final String? id;                    // Firestore document ID
  final String displayName;            // "Paracetamol" or "Combiflam"
  final List<String> brandNames;       // ["Crocin", "Dolo 650"]
  final String category;               // "NSAID", "Antibiotic"
  final bool isCombination;            // true for combo drugs
  final String physicalForm;           // "Tablet", "Syrup"
  final List<ActiveIngredient> activeIngredients;  // For combo drugs
  final List<String> allergyWarnings;  // ["Penicillin allergy"]
  final List<String> conditionWarnings; // ["Liver disease"]
  final List<DrugInteraction> drugInteractions;
  final List<FoodInteraction> foodInteractions;
}
```

#### 2. ActiveIngredient (For combination drugs)
```dart
class ActiveIngredient {
  final String name;      // "Ibuprofen"
  final String? strength; // "400mg"
}
```

#### 3. DrugInteraction (Drug-drug warnings)
```dart
class DrugInteraction {
  final String drugName;     // "Aspirin"
  final String severity;     // "severe", "moderate", "mild"
  final String description;  // "May increase bleeding risk"
}
```

#### 4. FoodInteraction (Food/alcohol warnings)
```dart
class FoodInteraction {
  final String food;         // "Alcohol", "Grapefruit"
  final String severity;     // "avoid", "caution", "limit"
  final String description;  // "May cause severe drowsiness"
}
```

### Example Drug Data:
```dart
DrugModel(
  displayName: 'Combiflam',
  brandNames: ['Combiflam', 'Ibugesic Plus'],
  category: 'NSAID + Analgesic',
  isCombination: true,
  activeIngredients: [
    ActiveIngredient(name: 'Ibuprofen', strength: '400mg'),
    ActiveIngredient(name: 'Paracetamol', strength: '325mg'),
  ],
  allergyWarnings: ['NSAIDs', 'Aspirin'],
  conditionWarnings: ['Stomach ulcer', 'Kidney disease'],
  drugInteractions: [
    DrugInteraction(
      drugName: 'Aspirin',
      severity: 'moderate',
      description: 'Increased risk of stomach bleeding',
    ),
  ],
  foodInteractions: [
    FoodInteraction(
      food: 'Alcohol',
      severity: 'avoid',
      description: 'Increases liver damage risk',
    ),
  ],
)
```

---

## 🔍 4. Drug Service: `drug_service.dart`

### What it does:
- Fetches drugs from Firestore
- Searches for drugs
- Checks drug warnings against user profile

### Key Methods:

#### 1. Get All Drugs (with caching)
```dart
Future<List<DrugModel>> getAllDrugs({bool forceRefresh = false}) async {
  // Check cache first (valid for 5 minutes)
  if (!forceRefresh && _cachedDrugs != null && 
      DateTime.now().difference(_lastFetch!) < Duration(minutes: 5)) {
    return _cachedDrugs!;
  }
  
  // Fetch from Firestore
  final snapshot = await _firestore.collection('drugs').get();
  _cachedDrugs = snapshot.docs.map((doc) => 
    DrugModel.fromMap(doc.data(), doc.id)
  ).toList();
  
  return _cachedDrugs!;
}
```

#### 2. Search Drugs
```dart
Future<List<DrugModel>> searchDrugs(String query) async {
  final drugs = await getAllDrugs();
  final lowerQuery = query.toLowerCase();
  
  return drugs.where((drug) {
    // Match generic name
    if (drug.genericName.toLowerCase().contains(lowerQuery)) return true;
    // Match any brand name
    if (drug.brandNames.any((b) => b.toLowerCase().contains(lowerQuery))) {
      return true;
    }
    return false;
  }).toList();
}
```

#### 3. Find Drugs in OCR Text (Most Important!)
```dart
Future<List<DrugModel>> findDrugsInText(String ocrText) async {
  // This method is called after camera scans medicine packaging
  
  // Step 1: Get all drugs from database
  final drugs = await getAllDrugs();
  
  // Step 2: Split OCR text into words
  final words = ocrText.toLowerCase().split(RegExp(r'[\s\n\r,.:;]+'));
  
  // Step 3: Priority - Check combo drugs first
  // (So "Combiflam" is matched instead of separate "Ibuprofen" + "Paracetamol")
  
  // Step 4: Match against brand names and generic names
  // Returns list of matched drugs
}
```

#### 4. Check Drug Warnings (Core Safety Logic!)
```dart
DrugWarningResult checkDrugWarnings(
  DrugModel drug,
  List<String> userAllergies,      // User's allergies from profile
  List<String> userConditions,     // User's chronic conditions
  List<DrugModel> otherDrugs,      // Other drugs user is taking
) {
  final allergyMatches = <String>[];
  final conditionMatches = <String>[];
  final drugMatches = <DrugInteraction>[];
  
  // Check allergies
  for (final warning in drug.allergyWarnings) {
    if (userAllergies.any((a) => a.toLowerCase() == warning.toLowerCase())) {
      allergyMatches.add(warning);  // DANGER! User has this allergy
    }
  }
  
  // Check conditions
  for (final warning in drug.conditionWarnings) {
    if (userConditions.any((c) => c.toLowerCase() == warning.toLowerCase())) {
      conditionMatches.add(warning);  // WARNING! Drug conflicts with condition
    }
  }
  
  // Check drug-drug interactions
  for (final interaction in drug.drugInteractions) {
    for (final otherDrug in otherDrugs) {
      if (otherDrug.genericName == interaction.drugName) {
        drugMatches.add(interaction);  // WARNING! These drugs interact
      }
    }
  }
  
  return DrugWarningResult(
    drug: drug,
    matchedAllergies: allergyMatches,
    matchedConditions: conditionMatches,
    matchedDrugInteractions: drugMatches,
    foodInteractions: drug.foodInteractions,
  );
}
```

### DrugWarningResult (The output of safety check)
```dart
class DrugWarningResult {
  final DrugModel drug;
  final List<String> matchedAllergies;
  final List<String> matchedConditions;
  final List<DrugInteraction> matchedDrugInteractions;
  final List<FoodInteraction> foodInteractions;
  
  // Helper getters
  bool get hasWarnings => matchedAllergies.isNotEmpty || 
                          matchedConditions.isNotEmpty || 
                          matchedDrugInteractions.isNotEmpty;
  
  String get riskLevel {
    if (matchedAllergies.isNotEmpty) return 'high';      // RED - Allergy detected
    if (matchedDrugInteractions.any((d) => d.severity == 'severe')) {
      return 'high';  // RED - Severe interaction
    }
    if (matchedConditions.isNotEmpty) return 'medium';   // ORANGE - Condition conflict
    return 'low';                                         // GREEN - Safe
  }
}
```

---

## 📸 5. Scan Screen: `scan_screen.dart`

### What it does:
The heart of the app! Uses camera + OCR to identify medicines and check safety.

### How it works (Step by Step):

```
┌─────────────────────────────────────────────────────────────┐
│  STEP 1: Camera Scanning                                    │
│  ┌─────────────────┐                                        │
│  │  📷 Camera      │  → User points at medicine label       │
│  │  Viewfinder     │  → Auto-capture every 3 seconds        │
│  └─────────────────┘                                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 2: OCR Processing                                     │
│  Google ML Kit Text Recognition reads:                      │
│  "Paracetamol 500mg Tablets"                               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 3: Drug Detection                                     │
│  DrugService.findDrugsInText() matches "Paracetamol"        │
│  Returns: [DrugModel: Paracetamol]                         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 4: Verification                                       │
│  Shows detected drugs - user can:                           │
│  ✅ Confirm  ❌ Remove  🔍 Search to add more               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 5: Safety Check                                       │
│  DrugService.checkDrugWarnings() for each drug              │
│  Checks against user's allergies & conditions               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 6: Results Display                                    │
│  🔴 HIGH RISK - Allergy Alert!                              │
│  🟠 CAUTION - Condition Warning                             │
│  🟢 SAFE TO USE                                             │
│                                                             │
│  [🚨 Alert Caregiver]  [📱 Save to Cabinet]                 │
└─────────────────────────────────────────────────────────────┘
```

### Key State Management:
```dart
// Three states of the scan flow
enum ScanState {
  scanning,   // Camera active, looking for medicine
  verifying,  // User confirms detected drugs
  results,    // Show safety warnings
}

class _ScanScreenState extends State<ScanScreen> {
  ScanState _currentState = ScanState.scanning;
  
  // Detected drugs before confirmation
  List<DrugModel> _detectedDrugs = [];
  
  // Results after safety check
  List<DrugWarningResult> _verifiedDrugs = [];
  
  // User profile data for checking
  List<String> _userAllergies = [];
  List<String> _userConditions = [];
}
```

### Key Methods:

#### 1. Initialize Camera
```dart
Future<void> _initializeCamera() async {
  final cameras = await availableCameras();
  _cameraController = CameraController(
    cameras.first,
    ResolutionPreset.high,
  );
  await _cameraController!.initialize();
}
```

#### 2. Capture and Process (OCR)
```dart
Future<void> _captureAndProcess() async {
  // Take picture
  final image = await _cameraController!.takePicture();
  
  // Run OCR using ML Kit
  final inputImage = InputImage.fromFilePath(image.path);
  final recognizer = TextRecognizer();
  final result = await recognizer.processImage(inputImage);
  
  // Extract text from result
  final ocrText = result.text;
  
  // Find matching drugs
  await _processOCRText(ocrText);
}
```

#### 3. Process OCR Text
```dart
Future<void> _processOCRText(String text) async {
  // Use DrugService to find drugs in the text
  final drugs = await _drugService.findDrugsInText(text);
  
  if (drugs.isNotEmpty) {
    setState(() {
      _detectedDrugs = drugs;
      _currentState = ScanState.verifying;  // Move to verification
    });
  }
}
```

#### 4. Confirm and Check Safety
```dart
void _confirmDrugs(List<DrugModel> confirmedDrugs) async {
  // Load user's medical profile
  await _loadUserProfile();
  
  // Check each drug against user's profile
  final results = <DrugWarningResult>[];
  for (final drug in confirmedDrugs) {
    final result = _drugService.checkDrugWarnings(
      drug,
      _userAllergies,
      _userConditions,
      confirmedDrugs.where((d) => d != drug).toList(),  // Other drugs
    );
    results.add(result);
  }
  
  setState(() {
    _verifiedDrugs = results;
    _currentState = ScanState.results;  // Show results
  });
}
```

---

## 🚨 6. Emergency Service: `emergency_service.dart`

### What it does:
Sends alerts to caregiver when high-risk warning is detected

### Key Methods:

#### 1. Get Caregiver Info
```dart
Future<Map<String, String>?> getCaregiverInfo() async {
  final user = _firebaseService.currentUser;
  final doc = await _firebaseService.getMedicalInfo(user!.uid);
  return {
    'name': doc?['caregiverName'] ?? '',
    'phone': doc?['caregiverPhone'] ?? '',
  };
}
```

#### 2. Send SMS Alert
```dart
Future<bool> sendSMSAlert({required String message}) async {
  final info = await getCaregiverInfo();
  final phone = info?['phone'];
  
  // Uses url_launcher to open SMS app with pre-filled message
  final uri = Uri(
    scheme: 'sms',
    path: phone,
    queryParameters: {'body': message},
  );
  
  return await launchUrl(uri);
}
```

#### 3. Call Caregiver
```dart
Future<bool> callCaregiver() async {
  final info = await getCaregiverInfo();
  final phone = info?['phone'];
  
  // Uses url_launcher to open phone dialer
  final uri = Uri(scheme: 'tel', path: phone);
  return await launchUrl(uri);
}
```

#### 4. Generate Alert Message
```dart
String generateDrugAlertMessage({
  required String patientName,
  required String drugName,
  required String warningType,
  required List<String> details,
}) {
  return '''
🚨 PHARMACLASH EMERGENCY ALERT

Patient: $patientName
Drug: $drugName
Warning: $warningType

Details:
${details.join('\n')}

Please check on the patient immediately.
''';
}
```

---

## 👤 7. Medical Info Screen: `medical_info_screen.dart`

### What it does:
Collects user's health profile after registration

### Data Collected:
1. **Drug Allergies** - From predefined list (searchable)
2. **Chronic Conditions** - Quick-select common ones + search
3. **Caregiver Contact** - Name and phone for emergencies

### Key UI Components:

#### Allergy Section
```dart
Widget _buildAllergySection() {
  // Search field with autocomplete
  // Shows MedicalReferenceData.searchDrugAllergies()
  // Selected allergies shown as chips that can be removed
}
```

#### Chronic Conditions Section
```dart
// Quick-select common conditions
final Map<String, bool> _quickSelectDiseases = {
  'Hypertension': false,
  'Asthma': false,
  'Arthritis': false,
  'Diabetes Type 2': false,
  'Depression': false,
  'Heart Disease': false,
};
```

#### Save to Firebase
```dart
Future<void> _handleSave() async {
  await _firebaseService.saveMedicalInfo(
    uid: user.uid,
    medicalData: {
      'allergies': _selectedAllergies,
      'chronicConditions': _getAllSelectedConditions(),
      'caregiverName': _caregiverNameController.text,
      'caregiverPhone': _caregiverPhoneController.text,
      'profileCompleted': true,
    },
  );
  Navigator.pushReplacementNamed(context, '/dashboard');
}
```

---

## 🎨 8. Theme & Colors: `app_colors.dart`

### Centralized Color Palette:
```dart
class AppColors {
  // Primary Teal Theme
  static const Color primaryTeal = Color(0xFF0D9488);    // Main brand color
  static const Color deepTeal = Color(0xFF0F766E);       // Darker teal
  static const Color mintGreen = Color(0xFF34D399);      // Success/accent
  static const Color lightMint = Color(0xFF6EE7B7);      // Lighter mint
  
  // Text Colors
  static const Color darkText = Color(0xFF1F2937);       // Primary text
  static const Color grayText = Color(0xFF6B7280);       // Secondary text
  
  // Background Colors
  static const Color inputBg = Color(0xFFF9FAFB);        // Input fields
  static const Color softWhite = Color(0xFFF8FAFC);      // Page backgrounds
  
  // Admin Panel (Dark theme)
  static const Color darkBg = Color(0xFF0F172A);         // Dark background
  static const Color cardBg = Color(0xFF1E293B);         // Card backgrounds
}
```

---

## 🔄 9. Complete User Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     APP LAUNCH                               │
│                         ↓                                    │
│                  SplashScreen                                │
│                         ↓                                    │
│            ┌───── Is Logged In? ─────┐                      │
│            ↓                          ↓                      │
│         LoginScreen              DashboardScreen             │
│            ↓                                                 │
│    ┌─── Sign In Method ───┐                                 │
│    ↓                      ↓                                  │
│  Email Login        Google Sign-In                          │
│    ↓                      ↓                                  │
│            RegistrationScreen                                │
│                         ↓                                    │
│              MedicalInfoScreen                               │
│           (Allergies, Conditions,                            │
│            Caregiver Contact)                                │
│                         ↓                                    │
│               DashboardScreen                                │
│                         ↓                                    │
│    ┌────────────────────┴────────────────────┐              │
│    ↓                    ↓                    ↓               │
│ ScanScreen        ProfileScreen        [Other Tabs]         │
│    ↓                                                         │
│ Camera → OCR → Drug Detection → Safety Check → Results      │
│    ↓                                                         │
│ [Alert Caregiver if High Risk]                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔥 10. Firebase Data Structure

### Collections Overview:

```
Firestore
├── users/                    # User profiles
│   └── {userId}/
│       ├── email
│       ├── fullName
│       ├── phone
│       ├── dateOfBirth
│       ├── gender
│       └── isAdmin
│
├── medical_info/             # Health profiles
│   └── {userId}/
│       ├── allergies[]
│       ├── chronicConditions[]
│       ├── caregiverName
│       ├── caregiverPhone
│       └── profileCompleted
│
└── drugs/                    # Drug database (Admin managed)
    └── {drugId}/
        ├── displayName
        ├── brandNames[]
        ├── category
        ├── isCombination
        ├── activeIngredients[]
        ├── allergyWarnings[]
        ├── conditionWarnings[]
        ├── drugInteractions[]
        └── foodInteractions[]
```

---

## 📚 Key Flutter Concepts Used

### 1. State Management
- `StatefulWidget` with `setState()` for local state
- Controller pattern for text inputs

### 2. Firebase Integration
- `FirebaseAuth` for authentication
- `Cloud Firestore` for database
- `GoogleSignIn` for social login

### 3. Camera & ML
- `camera` package for viewfinder
- `google_mlkit_text_recognition` for OCR

### 4. URL Launcher
- `url_launcher` for SMS/Phone actions

### 5. Animations
- `AnimationController` for screen transitions
- `FadeTransition`, `SlideTransition`

---

## 💡 Tips for Understanding the Code

1. **Start with `main.dart`** - See the app structure
2. **Follow the user flow** - Splash → Login → Dashboard → Scan
3. **Understand the models** - `DrugModel` is central to everything
4. **Study the services** - Business logic is separated from UI
5. **Look at one screen at a time** - Each screen is self-contained

---

*Happy Learning! 🎓*
