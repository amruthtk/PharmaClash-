import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/drug_model.dart';
import '../models/user_medicine_model.dart';
import '../services/drug_service.dart';
import '../services/firebase_service.dart';
import '../services/emergency_service.dart';
import '../services/medicine_inventory_service.dart';
import '../widgets/expiry_date_picker.dart';
import '../theme/app_colors.dart';

/// Scan states for the flow
enum ScanState {
  scanning, // Camera viewfinder active
  verifying, // User confirms detected drug
  results, // Show warnings/results
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isCameraPermissionDenied = false;
  String? _errorMessage;

  // OCR
  final TextRecognizer _textRecognizer = TextRecognizer();
  Timer? _scanTimer;

  // Scan state
  ScanState _scanState = ScanState.scanning;

  // Detected drugs (from OCR)
  List<DrugModel> _detectedDrugs = [];

  // Verified/confirmed drugs (after user confirmation)
  List<DrugWarningResult> _verifiedDrugs = [];

  // For manual search
  final TextEditingController _searchController = TextEditingController();
  List<DrugModel> _searchResults = [];

  // User profile data
  List<String> _userAllergies = [];
  List<String> _userConditions = [];

  final FirebaseService _firebaseService = FirebaseService();
  final DrugService _drugService = DrugService();
  final EmergencyService _emergencyService = EmergencyService();
  final MedicineInventoryService _inventoryService = MedicineInventoryService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _loadUserProfile();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanTimer?.cancel();
    _cameraController?.dispose();
    _textRecognizer.close();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  void _onSearchChanged() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
    } else {
      final results = await _drugService.searchDrugs(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        final medical = await _firebaseService.getMedicalInfo(user.uid);
        if (mounted && medical != null) {
          setState(() {
            _userAllergies = List<String>.from(medical['allergies'] ?? []);
            _userConditions = List<String>.from(
              medical['chronicConditions'] ?? [],
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras available on this device';
        });
        return;
      }

      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium, // Lower resolution = less CPU usage
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _startScanning();
      }
    } catch (e) {
      if (e.toString().contains('permission')) {
        setState(() {
          _isCameraPermissionDenied = true;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to initialize camera: $e';
        });
      }
    }
  }

  void _startScanning() {
    // Cancel any existing timer first
    _scanTimer?.cancel();
    // Scan every 3.5 seconds to reduce CPU load
    _scanTimer = Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isProcessing &&
          _isInitialized &&
          _scanState == ScanState.scanning &&
          _cameraController != null &&
          _cameraController!.value.isInitialized) {
        _captureAndProcess();
      }
    });
  }

  Future<void> _captureAndProcess() async {
    // Safety checks
    if (!mounted) return;
    if (_cameraController == null) return;
    if (!_cameraController!.value.isInitialized) return;

    // Check if controller is disposed (prevent exception)
    try {
      // Quick check to see if controller is still valid
      final _ = _cameraController!.value;
    } catch (e) {
      debugPrint('Camera controller disposed, skipping capture');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Debug: Print what OCR detected
      if (recognizedText.text.isNotEmpty) {
        debugPrint('=== OCR DETECTED TEXT ===');
        debugPrint(recognizedText.text);
        debugPrint('=========================');

        _processOCRText(recognizedText.text);
      } else {
        debugPrint('OCR: No text detected in image');
      }
    } catch (e) {
      // Only log if not a disposed controller error
      if (!e.toString().contains('Disposed')) {
        debugPrint('Error processing image: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _processOCRText(String text) async {
    final foundDrugs = await _drugService.findDrugsInText(text);

    debugPrint('=== DRUG MATCHING ===');
    debugPrint(
      'Found ${foundDrugs.length} drugs: ${foundDrugs.map((d) => d.genericName).join(", ")}',
    );
    debugPrint('=====================');

    if (foundDrugs.isNotEmpty && mounted) {
      _scanTimer?.cancel();
      setState(() {
        _detectedDrugs = foundDrugs;
        _scanState = ScanState.verifying;
      });
    }
  }

  void _confirmDrugs(List<DrugModel> confirmedDrugs) {
    final results = confirmedDrugs.map((drug) {
      return _drugService.checkDrugWarnings(
        drug,
        _userAllergies,
        _userConditions,
        confirmedDrugs.where((d) => d != drug).toList(),
      );
    }).toList();

    // Sort by risk level (high first)
    results.sort((a, b) {
      final order = {'high': 0, 'medium': 1, 'low': 2};
      return (order[a.riskLevel] ?? 2).compareTo(order[b.riskLevel] ?? 2);
    });

    setState(() {
      _verifiedDrugs = results;
      _scanState = ScanState.results;
    });
  }

  void _addManualDrug(DrugModel drug) {
    if (!_detectedDrugs.contains(drug)) {
      setState(() {
        _detectedDrugs.add(drug);
        _searchController.clear();
        _searchResults = [];
      });
    }
  }

  void _removeDrug(DrugModel drug) {
    setState(() {
      _detectedDrugs.remove(drug);
    });
  }

  void _resetScan() {
    setState(() {
      _detectedDrugs = [];
      _verifiedDrugs = [];
      _scanState = ScanState.scanning;
      _searchController.clear();
      _searchResults = [];
    });
    _startScanning();
  }

  /// Show bottom sheet to add medicines to cabinet with expiry date
  void _showAddToCabinetSheet() {
    final user = _firebaseService.currentUser;
    if (user == null || _verifiedDrugs.isEmpty) return;

    // Get the first drug to add (or could allow selecting multiple)
    final drugResult = _verifiedDrugs.first;
    final drug = drugResult.drug;

    DateTime selectedExpiryDate = DateTime(
      DateTime.now().year,
      DateTime.now().month + 6,
      1,
    );
    int selectedQuantity = 10;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.add_box_rounded,
                          color: AppColors.primaryTeal,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add to Cabinet',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkText,
                              ),
                            ),
                            Text(
                              drug.displayName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.grayText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Expiry Date Section
                  const Text(
                    'Expiry Date (check your medicine strip)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ExpiryDatePickerCompact(
                    initialDate: selectedExpiryDate,
                    onDateSelected: (date) {
                      setModalState(() => selectedExpiryDate = date);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Quantity Section
                  const Text(
                    'Tablets in Strip',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildQuantityOption(10, selectedQuantity, (q) {
                        setModalState(() => selectedQuantity = q);
                      }),
                      const SizedBox(width: 12),
                      _buildQuantityOption(15, selectedQuantity, (q) {
                        setModalState(() => selectedQuantity = q);
                      }),
                      const SizedBox(width: 12),
                      _buildQuantityOption(30, selectedQuantity, (q) {
                        setModalState(() => selectedQuantity = q);
                      }),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Add button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context); // Close sheet
                        await _addMedicineToCabinet(
                          drug: drug,
                          expiryDate: selectedExpiryDate,
                          quantity: selectedQuantity,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Add to My Cabinet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuantityOption(int quantity, int selected, Function(int) onTap) {
    final isSelected = quantity == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(quantity),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryTeal.withValues(alpha: 0.1)
                : AppColors.inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryTeal
                  : AppColors.lightBorderColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$quantity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.primaryTeal
                      : AppColors.darkText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'tablets',
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? AppColors.primaryTeal
                      : AppColors.grayText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addMedicineToCabinet({
    required DrugModel drug,
    required DateTime expiryDate,
    required int quantity,
  }) async {
    final user = _firebaseService.currentUser;
    if (user == null) return;

    try {
      // Check if already in cabinet
      final existing = await _inventoryService.findMedicineByDrugId(
        user.uid,
        drug.id ?? '',
      );

      if (existing != null) {
        // Update existing with new strip
        await _inventoryService.updateStrip(
          user.uid,
          existing.id!,
          newExpiryDate: expiryDate,
          addQuantity: quantity,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Updated ${drug.displayName} in your cabinet!'),
              backgroundColor: AppColors.primaryTeal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } else {
        // Add new medicine
        final newMedicine = UserMedicine(
          drugId: drug.id ?? '',
          medicineName: drug.displayName,
          category: drug.category,
          expiryDate: expiryDate,
          tabletCount: quantity,
        );
        await _inventoryService.addMedicine(user.uid, newMedicine);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${drug.displayName} added to your cabinet!'),
              backgroundColor: AppColors.primaryTeal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }

      // Reset scan
      _resetScan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.softWhite,
      child: Stack(
        children: [
          // Camera preview (always in background)
          if (_isInitialized && _cameraController != null)
            Positioned.fill(
              child: Opacity(
                opacity: _scanState == ScanState.scanning ? 1.0 : 0.3,
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            _buildCameraPlaceholder(),

          // State-based UI
          if (_scanState == ScanState.scanning) ...[
            _buildScanOverlay(),
            _buildBottomControls(),
          ] else if (_scanState == ScanState.verifying)
            _buildVerificationOverlay()
          else if (_scanState == ScanState.results)
            _buildResultsOverlay(),

          // Top bar
          _buildTopBar(),
        ],
      ),
    );
  }

  Widget _buildCameraPlaceholder() {
    return Container(
      color: AppColors.softWhite,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isCameraPermissionDenied) ...[
              Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: AppColors.grayText,
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera Permission Required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please grant camera access to scan medications',
                style: TextStyle(fontSize: 14, color: AppColors.grayText),
                textAlign: TextAlign.center,
              ),
            ] else if (_errorMessage != null) ...[
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(fontSize: 14, color: AppColors.grayText),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              const CircularProgressIndicator(color: AppColors.primaryTeal),
              const SizedBox(height: 16),
              Text(
                'Initializing camera...',
                style: TextStyle(fontSize: 14, color: AppColors.grayText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    String title;
    String subtitle;

    // Check for high risk in results state
    final bool isHighRisk =
        _scanState == ScanState.results && _hasHighRiskWarning;

    switch (_scanState) {
      case ScanState.scanning:
        title = 'Scan Medicine';
        subtitle = 'Point camera at medicine label';
        break;
      case ScanState.verifying:
        title = 'Verify Drug';
        subtitle = 'Confirm the detected medicine';
        break;
      case ScanState.results:
        if (isHighRisk) {
          title = '🚨 DANGER DETECTED';
          subtitle = 'High-risk drug warning!';
        } else {
          title = 'Scan Results';
          subtitle = '${_verifiedDrugs.length} drug(s) analyzed';
        }
        break;
    }

    // For scanning state, use dark overlay for camera visibility
    // For high risk results, use red overlay
    final bool isDarkMode = _scanState == ScanState.scanning || isHighRisk;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 12,
          20,
          12,
        ),
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isHighRisk
                      ? [
                          // 🔴 Red gradient for HIGH RISK
                          Colors.red.shade900,
                          Colors.red.shade800,
                          Colors.red.shade700,
                        ]
                      : [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                )
              : null,
          color: isDarkMode ? null : Colors.white,
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : AppColors.darkText,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.grayText,
                  ),
                ),
              ],
            ),
            if (_isProcessing)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.mintGreen,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanOverlay() {
    return Positioned.fill(
      child: CustomPaint(
        painter: ScanOverlayPainter(
          borderColor: _isProcessing
              ? AppColors.mintGreen
              : AppColors.primaryTeal,
          overlayColor: Colors.black.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  // ==================== VERIFICATION SCREEN ====================

  Widget _buildVerificationOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppColors.softWhite,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 80),

              // Detected drugs section
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primaryTeal.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTeal.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.document_scanner,
                                color: AppColors.primaryTeal,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Detected Medicine',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.darkText,
                                    ),
                                  ),
                                  Text(
                                    'Please verify the scanned medicine is correct',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.grayText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Detected drug cards
                      if (_detectedDrugs.isEmpty)
                        _buildEmptyDetectionCard()
                      else
                        ..._detectedDrugs.map(
                          (drug) => _buildDetectedDrugCard(drug),
                        ),

                      const SizedBox(height: 24),

                      // Manual search section
                      const Text(
                        'Not the right medicine?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grayText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSearchField(),

                      // Search results
                      if (_searchResults.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ..._searchResults
                            .take(5)
                            .map((drug) => _buildSearchResultTile(drug)),
                      ],

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),

              // Action buttons
              _buildVerificationActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDetectionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 48, color: AppColors.grayText),
          const SizedBox(height: 12),
          const Text(
            'No medicine detected',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use the search below to find your medicine',
            style: TextStyle(fontSize: 13, color: AppColors.grayText),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedDrugCard(DrugModel drug) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Drug icon - different for combinations
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: drug.isCombination
                    ? [
                        Colors.purple.withValues(alpha: 0.15),
                        Colors.purple.withValues(alpha: 0.05),
                      ]
                    : [
                        AppColors.primaryTeal.withValues(alpha: 0.15),
                        AppColors.deepTeal.withValues(alpha: 0.05),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              drug.isCombination
                  ? Icons.layers_rounded
                  : Icons.medication_rounded,
              color: drug.isCombination
                  ? Colors.purple.shade400
                  : AppColors.primaryTeal,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),

          // Drug info - Elder-Friendly design
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main Name (Large, Bold) - What the user sees on the strip
                Text(
                  drug.displayName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                // Show brand names
                if (drug.brandNames.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    drug.brandNames.take(3).join(', '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.grayText,
                    ),
                  ),
                ],
                // Show ingredients for combination drugs (Small, Grey)
                if (drug.isCombination &&
                    drug.activeIngredients.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '(${drug.ingredientsDisplay})',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.grayText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                // Category tag
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        drug.category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryTeal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (drug.isCombination) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'COMBO',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.purple.shade400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                // Dietary and Alcohol Warning Icons
                if (drug.hasDietaryWarning || drug.hasAlcoholWarning) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Dietary/Food restriction icons
                      if (drug.hasDietaryWarning)
                        ...drug.foodInteractions.map(
                          (food) => _buildWarningIcon(
                            icon: Icons.restaurant,
                            label: food.food,
                            severity: food.severity,
                            isFood: true,
                          ),
                        ),
                      // Alcohol restriction icon
                      if (drug.hasAlcoholWarning)
                        _buildWarningIcon(
                          icon: Icons.local_bar,
                          label: 'Alcohol',
                          severity: drug.alcoholRestriction,
                          isFood: false,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Remove button
          IconButton(
            onPressed: () => _removeDrug(drug),
            icon: Icon(Icons.close_rounded, color: Colors.red.shade500),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a small warning icon for dietary/alcohol restrictions
  Widget _buildWarningIcon({
    required IconData icon,
    required String label,
    required String severity,
    required bool isFood,
  }) {
    // Determine color based on severity
    Color bgColor;
    Color iconColor;

    switch (severity.toLowerCase()) {
      case 'avoid':
        bgColor = Colors.red.shade100;
        iconColor = Colors.red.shade700;
        break;
      case 'caution':
        bgColor = Colors.orange.shade100;
        iconColor = Colors.orange.shade700;
        break;
      case 'limit':
        bgColor = Colors.amber.shade100;
        iconColor = Colors.amber.shade700;
        break;
      default:
        bgColor = Colors.grey.shade100;
        iconColor = Colors.grey.shade600;
    }

    return Tooltip(
      message: isFood ? '$label: $severity' : 'Alcohol: $severity',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 3),
            Text(
              label.length > 10 ? '${label.substring(0, 8)}...' : label,
              style: TextStyle(
                fontSize: 9,
                color: iconColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: AppColors.darkText),
      decoration: InputDecoration(
        hintText: 'Search medicine by name...',
        hintStyle: TextStyle(color: AppColors.grayText.withValues(alpha: 0.7)),
        prefixIcon: const Icon(Icons.search, color: AppColors.grayText),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.grayText,
                onPressed: () {
                  _searchController.clear();
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.lightBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.lightBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildSearchResultTile(DrugModel drug) {
    final isAlreadyAdded = _detectedDrugs.contains(drug);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAlreadyAdded ? null : () => _addManualDrug(drug),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isAlreadyAdded
                  ? AppColors.primaryTeal.withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isAlreadyAdded
                    ? AppColors.primaryTeal.withValues(alpha: 0.3)
                    : AppColors.lightBorderColor,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAlreadyAdded
                      ? Icons.check_circle
                      : Icons.add_circle_outline,
                  color: isAlreadyAdded
                      ? AppColors.primaryTeal
                      : AppColors.primaryTeal,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drug.displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
                      Text(
                        drug.category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.grayText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAlreadyAdded)
                  const Text(
                    'Added',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryTeal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationActions() {
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
        child: Row(
          children: [
            // Rescan button
            Expanded(
              child: GestureDetector(
                onTap: _resetScan,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.inputBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.lightBorderColor),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_rounded,
                        color: AppColors.grayText,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Rescan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grayText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Confirm button
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _detectedDrugs.isEmpty
                    ? null
                    : () => _confirmDrugs(_detectedDrugs),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _detectedDrugs.isEmpty
                        ? null
                        : const LinearGradient(
                            colors: [AppColors.primaryTeal, AppColors.deepTeal],
                          ),
                    color: _detectedDrugs.isEmpty ? AppColors.inputBg : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _detectedDrugs.isEmpty
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.primaryTeal.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: _detectedDrugs.isEmpty
                            ? AppColors.grayText
                            : Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Confirm & Check',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _detectedDrugs.isEmpty
                              ? AppColors.grayText
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== RESULTS SCREEN ====================

  /// Check if any verified drug has HIGH RISK warning
  bool get _hasHighRiskWarning {
    return _verifiedDrugs.any((result) => result.riskLevel == 'high');
  }

  Widget _buildResultsOverlay() {
    final bool isHighRisk = _hasHighRiskWarning;

    return Positioned.fill(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          // 🔴 RED SCREEN for HIGH RISK - The "PharmaClash" moment!
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
              // Add extra spacing to clear the top bar header
              const SizedBox(height: 70),

              // 🚨 HIGH RISK BANNER
              if (isHighRisk) _buildHighRiskBanner(),

              const SizedBox(height: 10),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _verifiedDrugs.length,
                  itemBuilder: (context, index) {
                    return _buildDrugResultCard(_verifiedDrugs[index]);
                  },
                ),
              ),
              _buildResultActions(),
            ],
          ),
        ),
      ),
    );
  }

  /// Dramatic HIGH RISK banner with pulsing animation
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

                // Warning title
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

                // Warning subtitle
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

  Widget _buildDrugResultCard(DrugWarningResult result) {
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
            // Food interaction warnings
            if (result.drug.foodInteractions.isNotEmpty)
              ...result.drug.foodInteractions.map(
                (food) => _buildWarningSection(
                  'FOOD RESTRICTION',
                  '${food.food}: ${food.description}',
                  food.severity == 'avoid' ? Colors.red : Colors.amber,
                ),
              ),
            // Alcohol warning
            if (result.drug.hasAlcoholWarning)
              _buildWarningSection(
                'ALCOHOL WARNING',
                result.drug.alcoholWarningDescription ??
                    'Avoid alcohol while taking this medication.',
                result.drug.alcoholRestriction == 'avoid'
                    ? Colors.red
                    : Colors.amber,
              ),
            // Emergency Alert Button for high-risk
            if (result.riskLevel == 'high') _buildEmergencyAlertButton(result),
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

  Widget _buildEmergencyAlertButton(DrugWarningResult result) {
    // Collect warning details
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
          _emergencyService.showEmergencyOptions(
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

  Widget _buildResultActions() {
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
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _resetScan,
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
                onTap: _showAddToCabinetSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryTeal, AppColors.deepTeal],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryTeal.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.medication_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Save to Cabinet',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.black.withValues(alpha: 0.4),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  if (!_isProcessing) {
                    _captureAndProcess();
                  }
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryTeal, AppColors.deepTeal],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryTeal.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isProcessing
                        ? Icons.hourglass_empty
                        : Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tap to capture or wait for auto-scan',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for scan overlay
class ScanOverlayPainter extends CustomPainter {
  final Color borderColor;
  final Color overlayColor;

  ScanOverlayPainter({required this.borderColor, required this.overlayColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;

    final scanWidth = size.width * 0.85;
    final scanHeight = size.height * 0.25;
    final scanLeft = (size.width - scanWidth) / 2;
    final scanTop = (size.height - scanHeight) / 2 - 50;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(scanLeft, scanTop, scanWidth, scanHeight),
          const Radius.circular(20),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(scanLeft, scanTop, scanWidth, scanHeight),
        const Radius.circular(20),
      ),
      borderPaint,
    );

    final accentPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final cornerLength = 30.0;

    canvas.drawLine(
      Offset(scanLeft, scanTop + cornerLength),
      Offset(scanLeft, scanTop + 10),
      accentPaint,
    );
    canvas.drawLine(
      Offset(scanLeft + cornerLength, scanTop),
      Offset(scanLeft + 10, scanTop),
      accentPaint,
    );

    canvas.drawLine(
      Offset(scanLeft + scanWidth, scanTop + cornerLength),
      Offset(scanLeft + scanWidth, scanTop + 10),
      accentPaint,
    );
    canvas.drawLine(
      Offset(scanLeft + scanWidth - cornerLength, scanTop),
      Offset(scanLeft + scanWidth - 10, scanTop),
      accentPaint,
    );

    canvas.drawLine(
      Offset(scanLeft, scanTop + scanHeight - cornerLength),
      Offset(scanLeft, scanTop + scanHeight - 10),
      accentPaint,
    );
    canvas.drawLine(
      Offset(scanLeft + cornerLength, scanTop + scanHeight),
      Offset(scanLeft + 10, scanTop + scanHeight),
      accentPaint,
    );

    canvas.drawLine(
      Offset(scanLeft + scanWidth, scanTop + scanHeight - cornerLength),
      Offset(scanLeft + scanWidth, scanTop + scanHeight - 10),
      accentPaint,
    );
    canvas.drawLine(
      Offset(scanLeft + scanWidth - cornerLength, scanTop + scanHeight),
      Offset(scanLeft + scanWidth - 10, scanTop + scanHeight),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ScanOverlayPainter oldDelegate) {
    return borderColor != oldDelegate.borderColor ||
        overlayColor != oldDelegate.overlayColor;
  }
}
