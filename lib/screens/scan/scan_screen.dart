import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'scan.dart';
import '../../models/drug_model.dart';
import '../../services/drug_service.dart';
import '../../services/firebase_service.dart';
import '../../services/emergency_service.dart';
import '../../services/telemetry_service.dart';
import '../../services/medicine_inventory_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/medicine_add_setup_sheet.dart';
import '../../services/ai_service.dart';

enum ScanState { scanning, verifying, results }

/// Coordinator screen for the scan feature
/// Manages camera state and switches between scanner, verification, and results overlays
class ScanScreen extends StatefulWidget {
  final bool isGuestMode;

  const ScanScreen({super.key, this.isGuestMode = false});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  final DrugService _drugService = DrugService();
  final FirebaseService _firebaseService = FirebaseService();
  final MedicineInventoryService _inventoryService = MedicineInventoryService();
  final EmergencyService _emergencyService = EmergencyService();

  CameraController? _cameraController;
  late OcrProcessor _ocrProcessor;

  ScanState _scanState = ScanState.scanning;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isOffline = false;
  bool _isFlashOn = false;
  bool _isAiSearching = false;

  List<DrugModel> _detectedDrugs = [];
  List<DrugWarningResult> _warningResults = [];
  final List<DrugModel> _searchResults = [];

  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkConnectivity();
    _initScanner();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() async {
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() => _searchResults.clear());
      return;
    }

    final results = await _drugService.searchDrugs(query);
    setState(() {
      _searchResults.clear();
      _searchResults.addAll(results);
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = result.contains(ConnectivityResult.none);
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      setState(() {
        _isOffline = results.contains(ConnectivityResult.none);
        _ocrProcessor = OcrProcessor(
          drugService: _drugService,
          isOffline: _isOffline,
        );
      });
    });
  }

  Future<void> _initScanner() async {
    _ocrProcessor = OcrProcessor(
      drugService: _drugService,
      isOffline: _isOffline,
    );

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _ocrProcessor.dispose();
    _connectivitySubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initScanner();
    }
  }

  Future<void> _processImage() async {
    if (_isProcessing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await _ocrProcessor.processImage(_cameraController!);

      if (mounted) {
        if (result.matchedDrugs.isNotEmpty) {
          // Log guest scan success
          if (widget.isGuestMode) {
            TelemetryService().logEvent(
              'guest_scan_success',
              details: 'Identified: ${result.matchedDrugs.map((d) => d.displayName).join(", ")}',
            );
          }
          setState(() {
            _detectedDrugs = result.matchedDrugs;
            _scanState = ScanState.verifying;
            _isProcessing = false;
          });
        } else if (result.rawText.trim().length > 3) {
          // Log guest scan failure (no match, but text detected)
          if (widget.isGuestMode) {
            TelemetryService().logEvent('guest_scan_fail', details: 'No drugs identified in database, raw text: ${result.rawText}');
          }
          setState(() => _isProcessing = false);
          _showNoResultsDialog(result.rawText);
        } else {
          // Log guest scan failure (no text detected)
          if (widget.isGuestMode) {
            TelemetryService().logEvent('guest_scan_fail', details: 'No medicine names detected.');
          }
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No medicine names detected. Try again.'),
            ),
          );
        }
      }
    } catch (e) {
      // Log guest scan failure (error during processing)
      if (widget.isGuestMode) {
        TelemetryService().logEvent('guest_scan_fail', details: 'Error: $e');
      }
      setState(() => _isProcessing = false);
      debugPrint('Scan error: $e');
    }
  }

  void _showNoResultsDialog(String rawText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.search_off_rounded, color: Colors.orange),
            const SizedBox(width: 12),
            const Text('No Match Found'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We detected some text but couldn\'t find a matching medicine in our standard database:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.softWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightBorderColor),
              ),
              child: Text(
                rawText.length > 100
                    ? '${rawText.substring(0, 100)}...'
                    : rawText,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: AppColors.grayText,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _performDeepAISearch(rawText);
                  },
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Try Gemini AI Deep Search'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _detectedDrugs = [];
                          _scanState = ScanState.verifying;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Manual Entry'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Rescan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _performDeepAISearch(String text) async {
    setState(() => _isAiSearching = true);
    try {
      final aiDrug = await AIService().fetchDrugInfo(text);
      if (mounted) {
        if (aiDrug != null) {
          setState(() {
            _detectedDrugs = [aiDrug];
            _scanState = ScanState.verifying;
            _isAiSearching = false;
            _searchController.clear();
            _searchResults.clear();
          });
        } else {
          setState(() => _isAiSearching = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI couldn\'t identify this medicine either.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isAiSearching = false);
    }
  }

  void _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    try {
      final newMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newMode);
      setState(() => _isFlashOn = !_isFlashOn);
    } catch (e) {
      debugPrint('Flash toggle error: $e');
    }
  }

  void _confirmDrugs() async {
    setState(() => _isProcessing = true);

    try {
      List<String> allergies = [];
      List<String> conditions = [];
      List<DrugModel> activeDrugs = [];

      // Only load profile data if authenticated
      if (!widget.isGuestMode) {
        final user = _firebaseService.currentUser;
        if (user == null) {
          setState(() => _isProcessing = false);
          return;
        }

        final userMedications = await _inventoryService.getUserMedicines(
          user.uid,
        );

        for (var userMed in userMedications) {
          final drug = await _drugService.getDrugByName(userMed.medicineName);
          if (drug != null) activeDrugs.add(drug);
        }

        final medicalInfo = await _firebaseService.getMedicalInfo(user.uid);
        allergies = List<String>.from(medicalInfo?['allergies'] ?? []);
        conditions = List<String>.from(
          medicalInfo?['healthConditions'] ?? [],
        );
      }

      final results = <DrugWarningResult>[];

      debugPrint('=== ALLERGY CHECK ===');
      debugPrint('User allergies: $allergies');
      debugPrint('User conditions: $conditions');
      debugPrint(
        'Active drugs in cabinet: ${activeDrugs.map((d) => d.displayName).toList()}',
      );
      debugPrint(
        'Drugs to check: ${_detectedDrugs.map((d) => d.displayName).toList()}',
      );

      for (var drug in _detectedDrugs) {
        final result = _drugService.checkDrugWarnings(
          drug,
          allergies,
          conditions,
          activeDrugs,
        );

        debugPrint('Drug: ${drug.displayName}');
        debugPrint('  Allergy matches: ${result.matchedAllergies}');
        debugPrint('  Condition matches: ${result.matchedConditions}');
        debugPrint(
          '  Drug interactions: ${result.matchedDrugInteractions.map((i) => i.drugName).toList()}',
        );
        debugPrint('  Risk level: ${result.riskLevel}');

        results.add(result);
      }
      debugPrint('=====================');

      if (mounted) {
        setState(() {
          _warningResults = results;
          _scanState = ScanState.results;
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      debugPrint('Verification error: $e');
    }
  }

  void _addToCabinet() async {
    // Guest mode: add-to-cabinet not available (CTA is handled in ResultsOverlay)
    if (widget.isGuestMode) return;

    final user = _firebaseService.currentUser;
    if (user == null) return;

    if (_warningResults.isEmpty) return;

    // If only one drug, show setup sheet first
    if (_warningResults.length == 1) {
      final result = _warningResults.first;

      MedicineSetupSheet.show(
        context,
        medicineName: result.drug.displayName,
        onConfirm:
            (quantity, scheduleTimes, expiryDate, doseIntervalDays) async {
              setState(() => _isProcessing = true);
              try {
                await _inventoryService.addDrugToCabinet(
                  user.uid,
                  result.drug,
                  tabletCount: quantity,
                  scheduleTimes: scheduleTimes,
                  expiryDate: expiryDate,
                  doseIntervalDays: doseIntervalDays,
                );
                _completeCabinetAddition();
              } catch (e) {
                _handleCabinetError(e);
              }
            },
      );
    } else {
      // Fallback for multiple drugs - adds with defaults
      setState(() => _isProcessing = true);
      try {
        for (var result in _warningResults) {
          await _inventoryService.addDrugToCabinet(user.uid, result.drug);
        }
        _completeCabinetAddition();
      } catch (e) {
        _handleCabinetError(e);
      }
    }
  }

  void _completeCabinetAddition() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Medicines added to cabinet!')),
    );

    // Return to main page
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      setState(() {
        _scanState = ScanState.scanning;
        _detectedDrugs = [];
        _warningResults = [];
        _isProcessing = false;
      });
    }
  }

  void _handleCabinetError(Object e) {
    if (mounted) setState(() => _isProcessing = false);
    debugPrint('Cabinet error: $e');
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding to cabinet: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Camera Viewfinder (Layer 0)
          CameraViewfinder(
            cameraController: _cameraController,
            isInitialized: _isInitialized,
            isCameraPermissionDenied: false, // Handle this if needed
            isScanning: _scanState == ScanState.scanning,
          ),

          // 2. Back Button (Top Left)
          if (_scanState == ScanState.scanning)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: GestureDetector(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

          // 3. Scan Controls (Overlaid on scanner only)
          if (_scanState == ScanState.scanning)
            ScanBottomControls(
              isProcessing: _isProcessing,
              isFlashOn: _isFlashOn,
              onCapture: () {
                // Log guest scan start
                if (widget.isGuestMode) {
                  TelemetryService().logEvent('guest_scan_start');
                }
                _processImage();
              },
              onFlashToggle: _toggleFlash,
              onManualAdd: () {
                setState(() {
                  _detectedDrugs = [];
                  _scanState = ScanState.verifying;
                });
              },
            ),

          // 3. Verification Overlay
          if (_scanState == ScanState.verifying)
            VerificationOverlay(
              detectedDrugs: _detectedDrugs,
              searchResults: _searchResults,
              searchController: _searchController,
              onRescan: () => setState(() => _scanState = ScanState.scanning),
              onConfirm: _confirmDrugs,
              onAddDrug: (drug) {
                if (_detectedDrugs.contains(drug)) return;

                if (_detectedDrugs.isNotEmpty) {
                  // Show replacement dialog if a medicine is already scanned/selected
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Row(
                        children: [
                          Icon(
                            Icons.swap_horiz_rounded,
                            color: AppColors.primaryTeal,
                          ),
                          SizedBox(width: 12),
                          Text('Replace Medicine?'),
                        ],
                      ),
                      content: Text(
                        'Selection unique medicine: "${drug.displayName}" will replace your current selection. Proceed?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _detectedDrugs.clear();
                              _detectedDrugs.add(drug);
                              _searchController.clear();
                              _searchResults.clear();
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Replace'),
                        ),
                      ],
                    ),
                  );
                } else {
                  setState(() => _detectedDrugs.add(drug));
                }
              },
              onRemoveDrug: (drug) {
                setState(() => _detectedDrugs.remove(drug));
                if (_detectedDrugs.isEmpty) {
                  setState(() => _scanState = ScanState.scanning);
                }
              },
              onDeepSearch: () => _performDeepAISearch(_searchController.text),
              isAiSearching: _isAiSearching,
            ),

          // 4. Results Overlay
          if (_scanState == ScanState.results)
            ResultsOverlay(
              verifiedDrugs: _warningResults,
              onRescan: () => setState(() => _scanState = ScanState.scanning),
              onAddToCabinet: _addToCabinet,
              onHighRiskOverride: _addToCabinet,
              emergencyService: _emergencyService,
              isGuestMode: widget.isGuestMode,
            ),
        ],
      ),
    );
  }
}
