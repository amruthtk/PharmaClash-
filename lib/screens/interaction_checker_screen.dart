import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/drug_model.dart';
import '../services/drug_service.dart';
import '../services/ai_service.dart';
import '../services/firebase_service.dart';
import '../services/medicine_inventory_service.dart';
import '../services/telemetry_service.dart';
import '../theme/app_colors.dart';
import '../widgets/medical/medical_section_card.dart';
import '../widgets/medical/medical_input_field.dart';

/// Interaction Checker following the classic structured UI from the User Screenshot.
class InteractionCheckerScreen extends StatefulWidget {
  final bool isGuestMode;

  const InteractionCheckerScreen({super.key, this.isGuestMode = false});

  @override
  State<InteractionCheckerScreen> createState() =>
      _InteractionCheckerScreenState();
}

class _InteractionCheckerScreenState extends State<InteractionCheckerScreen> {
  final DrugService _drugService = DrugService();
  final AIService _aiService = AIService();
  final FirebaseService _firebaseService = FirebaseService();
  final MedicineInventoryService _inventoryService = MedicineInventoryService();

  final TextEditingController _drugAController = TextEditingController();
  final TextEditingController _drugBController = TextEditingController();

  List<DrugModel> _drugAResults = [];
  List<DrugModel> _drugBResults = [];

  DrugModel? _selectedDrugA;
  DrugModel? _selectedDrugB;

  List<DrugInteraction> _interactions = [];
  bool _isChecking = false;
  bool _hasChecked = false;
  bool _isAISearchingA = false;
  bool _isAISearchingB = false;
  bool _isSearchingA = false;
  bool _isSearchingB = false;

  // --- Profile Mode ---
  bool _isProfileMode = false;
  bool _isLoadingProfile = false;
  bool _profileLoaded = false;
  List<String> _allergies = [];
  List<String> _conditions = [];
  List<DrugModel> _cabinetDrugs = [];
  DrugWarningResult? _profileWarningResult;

  @override
  void initState() {
    super.initState();
    _drugAController.addListener(() => _onSearch(_drugAController.text, true));
    _drugBController.addListener(() => _onSearch(_drugBController.text, false));
  }

  @override
  void dispose() {
    _drugAController.dispose();
    _drugBController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    if (_profileLoaded || _isLoadingProfile) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoadingProfile = true);

    try {
      final medicalInfo = await _firebaseService.getMedicalInfo(user.uid);
      final allergies = List<String>.from(medicalInfo?['allergies'] ?? []);
      final conditions = List<String>.from(
        medicalInfo?['healthConditions'] ?? [],
      );

      final userMedicines = await _inventoryService.getUserMedicines(user.uid);
      final cabinetDrugs = <DrugModel>[];
      for (final med in userMedicines) {
        final drug = await _drugService.getDrugByName(med.medicineName);
        if (drug != null) cabinetDrugs.add(drug);
      }

      if (mounted) {
        setState(() {
          _allergies = allergies;
          _conditions = conditions;
          _cabinetDrugs = cabinetDrugs;
          _profileLoaded = true;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _onSearch(String query, bool isDrugA) async {
    final selected = isDrugA ? _selectedDrugA : _selectedDrugB;
    if (selected != null &&
        (query == selected.displayName || query == selected.matchedBrandName)) {
      return;
    }

    if (query.length < 2) {
      if (mounted) {
        setState(() {
          if (isDrugA) _drugAResults = [];
          if (!isDrugA) _drugBResults = [];
        });
      }
      return;
    }

    // Fallback: Ensure guest is authenticated before search
    if (widget.isGuestMode && FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseService().signInAnonymously();
      } catch (e) {
        debugPrint('Fallback guest auth failed: $e');
      }
    }

    setState(() {
      if (isDrugA) _isSearchingA = true;
      if (!isDrugA) _isSearchingB = true;
    });

    try {
      final results = await _drugService.searchDrugs(query);
      if (mounted) {
        setState(() {
          if (isDrugA) _drugAResults = results;
          if (!isDrugA) _drugBResults = results;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isDrugA) _isSearchingA = false;
          if (!isDrugA) _isSearchingB = false;
        });
      }
    }
  }

  Future<void> _performAISearch(bool isDrugA) async {
    final query = isDrugA ? _drugAController.text : _drugBController.text;
    if (query.length < 2) return;

    setState(() {
      if (isDrugA) {
        _isAISearchingA = true;
        _drugAResults = [];
      } else {
        _isAISearchingB = true;
        _drugBResults = [];
      }
    });

    try {
      final aiDrug = await _aiService.fetchDrugInfo(query);
      if (mounted && aiDrug != null) {
        _selectDrug(aiDrug, isDrugA);
      } else if (mounted) {
        _showError('Could not find medication details even with AI.');
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isDrugA) {
            _isAISearchingA = false;
          } else {
            _isAISearchingB = false;
          }
        });
      }
    }
  }

  void _selectDrug(DrugModel drug, bool isDrugA) {
    setState(() {
      if (isDrugA) {
        _selectedDrugA = drug;
        _drugAController.text = drug.displayName;
        _drugAResults = [];
      } else {
        _selectedDrugB = drug;
        _drugBController.text = drug.displayName;
        _drugBResults = [];
      }
      _hasChecked = false;
      _interactions = [];
    });
  }

  Future<void> _checkInteraction({bool useDeepAI = false}) async {
    if (_selectedDrugA == null) return;

    // Profile mode: use checkDrugWarnings
    if (_isProfileMode) {
      // Log guest interaction check
      // Telemetry will be logged after result is computed


      setState(() {
        _isChecking = true; // Assuming _isAnalyzing is _isChecking
        _profileWarningResult = null; // Assuming _analysisResult is _profileWarningResult
      });

      try {
        final result = _drugService.checkDrugWarnings(
          _selectedDrugA!,
          _allergies,
          _conditions,
          _cabinetDrugs,
        );

        if (mounted) {
          setState(() {
            _profileWarningResult = result;
            _isChecking = false;
            _hasChecked = true;
          });

          if (widget.isGuestMode) {
            String peakSeverity = 'safe';
            if (result.hasAllergyWarning) {
              peakSeverity = 'severe';
            } else if (result.matchedDrugInteractions.isNotEmpty) {
              final severities = result.matchedDrugInteractions.map((i) => i.severity.toLowerCase()).toList();
              if (severities.contains('severe')) {
                peakSeverity = 'severe';
              } else if (severities.contains('moderate')) peakSeverity = 'moderate';
              else if (severities.contains('mild')) peakSeverity = 'mild';
            }

            TelemetryService().logEvent(
              'guest_interaction_check',
              details: '${_drugAController.text} + Profile',
              extraData: {'severity': peakSeverity},
            );
          }
        }
      } catch (e) {
        debugPrint('Profile check error: $e');
        if (mounted) setState(() => _isChecking = false);
      }
      return;
    }

    // Drug-vs-Drug mode (existing)
    if (_selectedDrugB == null) return;

    setState(() {
      _isChecking = true;
      _interactions = [];
    });

      // Telemetry will be logged after result is computed


    final Map<String, DrugInteraction> matchedInteractions = {};

    // 1. Run Local Logic
    final allNamesA = {
      _selectedDrugA!.displayName.toLowerCase(),
      _selectedDrugA!.genericName.toLowerCase(),
      ..._selectedDrugA!.activeIngredients.map((i) => i.name.toLowerCase()),
      ..._selectedDrugA!.brandNames.map((b) => b.toLowerCase()),
    };

    final allNamesB = {
      _selectedDrugB!.displayName.toLowerCase(),
      _selectedDrugB!.genericName.toLowerCase(),
      ..._selectedDrugB!.activeIngredients.map((i) => i.name.toLowerCase()),
      ..._selectedDrugB!.brandNames.map((b) => b.toLowerCase()),
    };

    for (final interaction in _selectedDrugA!.drugInteractions) {
      final target = interaction.drugName.toLowerCase();
      if (allNamesB.any(
        (name) => name.contains(target) || target.contains(name),
      )) {
        matchedInteractions[interaction.description] = interaction;
      }
    }

    for (final interaction in _selectedDrugB!.drugInteractions) {
      final target = interaction.drugName.toLowerCase();
      if (allNamesA.any(
        (name) => name.contains(target) || target.contains(name),
      )) {
        matchedInteractions[interaction.description] = interaction;
      }
    }

    // Always attempt Deep AI if it's missing from local but we have a connection
    // Or if the user explicitly wants "Deep" analysis
    if (useDeepAI || matchedInteractions.isEmpty) {
      try {
        final aiInteractions = await _aiService.checkDirectInteraction(
          _selectedDrugA!.displayName,
          _selectedDrugB!.displayName,
        );
        for (final interaction in aiInteractions) {
          matchedInteractions[interaction.description] = interaction;
        }
      } catch (e) {
        debugPrint('AI Deep Interaction failure: $e');
      }
    }

    if (mounted) {
      setState(() {
        _interactions = matchedInteractions.values.toList();
        _isChecking = false;
        _hasChecked = true;
      });

      // Log guest interaction check (Drug vs Drug) with severity context
      if (widget.isGuestMode) {
        String peakSeverity = 'safe';
        if (_interactions.isNotEmpty) {
          final severities = _interactions.map((i) => i.severity.toLowerCase()).toList();
          if (severities.contains('severe')) {
            peakSeverity = 'severe';
          } else if (severities.contains('moderate')) peakSeverity = 'moderate';
          else if (severities.contains('mild')) peakSeverity = 'mild';
        }

        TelemetryService().logEvent(
          'guest_interaction_check',
          details: '${_drugAController.text} + ${_drugBController.text}',
          extraData: {'severity': peakSeverity},
        );
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Info Box
          MedicalSectionCard(
            icon: Icons.search,
            iconColor: AppColors.primaryTeal,
            title: 'Check Drug Compatibility',
            subtitle: _isProfileMode
                ? 'Check if a drug is safe for your health profile, allergies, and current medicines.'
                : 'Select two drugs below to check for interactions, clashes, or shared ingredients.',
            child: const SizedBox.shrink(),
          ),
          const SizedBox(height: 30),

          // Drug A Input
          _buildDrugInputSection(
            label: 'Drug A',
            icon: Icons.medication_outlined,
            labelColor: AppColors.primaryTeal,
            controller: _drugAController,
            results: _drugAResults,
            isSearching: _isSearchingA || _isAISearchingA,
            selectedDrug: _selectedDrugA,
            isDrugA: true,
          ),

          // Swap Icon (only in drug-vs-drug mode)
          if (!_isProfileMode)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _swapDrugs,
                    icon: const Icon(
                      Icons.swap_vert,
                      color: AppColors.grayText,
                      size: 24,
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 20),

          // --- Segmented Toggle (hidden for guests — no profile) ---
          if (!widget.isGuestMode) ...[
            _buildModeToggle(),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 16),

          // Drug B Input OR Health Profile Summary
          if (_isProfileMode)
            _buildProfileSummaryCard()
          else
            _buildDrugInputSection(
              label: 'Drug B',
              icon: Icons.medication_outlined,
              labelColor: Colors.orange,
              controller: _drugBController,
              results: _drugBResults,
              isSearching: _isSearchingB || _isAISearchingB,
              selectedDrug: _selectedDrugB,
              isDrugA: false,
            ),

          const SizedBox(height: 30),

          // Check Button
          _buildCheckButton(),

          // Results Section
          if (_hasChecked || _isChecking) ...[
            const SizedBox(height: 40),
            if (_isProfileMode && _profileWarningResult != null)
              _buildProfileResultsSection()
            else if (!_isProfileMode)
              _buildResultsSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildDrugInputSection({
    required String label,
    required IconData icon,
    required Color labelColor,
    required TextEditingController controller,
    required List<DrugModel> results,
    required bool isSearching,
    required DrugModel? selectedDrug,
    required bool isDrugA,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: labelColor, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (selectedDrug == null)
          Column(
            children: [
              MedicalInputField(
                controller: controller,
                hint: 'Search drug name...',
                prefixIcon: Icons.search,
              ),
              if (isSearching)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (results.isNotEmpty ||
                  (controller.text.length >= 2 && !isSearching))
                _buildSearchResults(results, isDrugA),
            ],
          )
        else
          _buildSelectedDrugCard(selectedDrug, labelColor, isDrugA),
      ],
    );
  }

  Widget _buildSearchResults(List<DrugModel> results, bool isDrugA) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightBorderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          ...results
              .take(4)
              .map(
                (drug) => ListTile(
                  dense: true,
                  title: Text(
                    drug.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    drug.category,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.grayText,
                    ),
                  ),
                  onTap: () => _selectDrug(drug, isDrugA),
                ),
              ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(
              Icons.auto_awesome,
              color: AppColors.primaryTeal,
              size: 18,
            ),
            title: const Text(
              'AI Deep Search',
              style: TextStyle(
                color: AppColors.primaryTeal,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            onTap: () => _performAISearch(isDrugA),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDrugCard(DrugModel drug, Color color, bool isDrugA) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.medication, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drug.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  drug.category,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grayText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              if (isDrugA) {
                _selectedDrugA = null;
                _drugAController.clear();
              } else {
                _selectedDrugB = null;
                _drugBController.clear();
              }
              _hasChecked = false;
              _interactions = [];
            }),
            icon: const Icon(Icons.close, size: 20, color: AppColors.grayText),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckButton() {
    final ready = _isProfileMode
        ? _selectedDrugA != null && _profileLoaded
        : _selectedDrugA != null && _selectedDrugB != null;
    final label = _isChecking
        ? 'Checking...'
        : _isProfileMode
        ? 'Check Against My Profile'
        : 'Check Interaction';
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: ready && !_isChecking ? () => _checkInteraction() : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: ready ? AppColors.lightCardBg : Colors.grey.shade200,
          foregroundColor: ready ? AppColors.darkText : Colors.grey,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: ready ? AppColors.lightBorderColor : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_isProfileMode ? Icons.shield : Icons.bolt, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_isChecking) {
      return const Column(
        children: [
          SizedBox(height: 20),
          Center(
            child: CircularProgressIndicator(color: AppColors.primaryTeal),
          ),
          SizedBox(height: 20),
          Text(
            'Analyzing potential interactions...',
            style: TextStyle(color: AppColors.grayText),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analysis Results',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        if (_interactions.isEmpty)
          _buildSafeState()
        else
          ..._interactions.map((i) => _buildInteractionCard(i)),

        const SizedBox(height: 30),
        _buildAIDeepScanOption(),

        // Guest mode hook CTA
        if (widget.isGuestMode) ...[
          const SizedBox(height: 20),
          _buildGuestHookCard(),
        ],
      ],
    );
  }

  Widget _buildSafeState() {
    return MedicalSectionCard(
      icon: Icons.check_circle,
      iconColor: AppColors.accentGreen,
      title: 'No Clashes Found',
      subtitle: 'Safe to take together based on local database check.',
      child: const Text(
        'For critical safety, we recommend performing an AI Deep Scan below.',
        style: TextStyle(fontSize: 12, color: AppColors.grayText),
      ),
    );
  }

  Widget _buildInteractionCard(DrugInteraction interaction) {
    final isSevere = interaction.severity == 'severe';
    final color = isSevere ? Colors.red : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  interaction.severity.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: color,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  interaction.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.darkText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIDeepScanOption() {
    return GestureDetector(
      onTap: () => _checkInteraction(useDeepAI: true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryTeal.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryTeal.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.auto_awesome,
              color: AppColors.primaryTeal,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Try AI Deep Scan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  Text(
                    'Real-time clinical analysis by Gemini AI',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryTeal.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primaryTeal),
          ],
        ),
      ),
    );
  }

  void _swapDrugs() {
    setState(() {
      final temp = _selectedDrugA;
      _selectedDrugA = _selectedDrugB;
      _selectedDrugB = temp;

      final tempText = _drugAController.text;
      _drugAController.text = _drugBController.text;
      _drugBController.text = tempText;

      _hasChecked = false;
      _interactions = [];
    });
  }

  // ==================== Mode Toggle ====================

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isProfileMode) {
                  setState(() {
                    _isProfileMode = false;
                    _hasChecked = false;
                    _profileWarningResult = null;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isProfileMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: !_isProfileMode
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 16,
                      color: !_isProfileMode
                          ? AppColors.primaryTeal
                          : AppColors.grayText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Another Drug',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: !_isProfileMode
                            ? AppColors.darkText
                            : AppColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isProfileMode) {
                  setState(() {
                    _isProfileMode = true;
                    _hasChecked = false;
                    _interactions = [];
                  });
                  _loadProfileData();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isProfileMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: _isProfileMode
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: _isProfileMode
                          ? AppColors.primaryTeal
                          : AppColors.grayText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'My Health Profile',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isProfileMode
                            ? AppColors.darkText
                            : AppColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Profile Summary Card ====================

  Widget _buildProfileSummaryCard() {
    if (_isLoadingProfile) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lightBorderColor),
        ),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: AppColors.primaryTeal),
              SizedBox(height: 12),
              Text(
                'Loading your health profile...',
                style: TextStyle(color: AppColors.grayText, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final hasData =
        _allergies.isNotEmpty ||
        _conditions.isNotEmpty ||
        _cabinetDrugs.isNotEmpty;

    if (!hasData && _profileLoaded) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade700, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Health Profile Data',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add your allergies, conditions, and medicines in your Profile to use this feature.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryTeal.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.primaryTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Checking against your profile',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.darkText,
                  ),
                ),
              ),
              // Refresh
              GestureDetector(
                onTap: () {
                  _profileLoaded = false;
                  _loadProfileData();
                },
                child: const Icon(
                  Icons.refresh,
                  size: 20,
                  color: AppColors.grayText,
                ),
              ),
            ],
          ),

          if (_allergies.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'ALLERGIES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.grayText,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _allergies
                  .map(
                    (a) => _buildChip(
                      a,
                      Colors.red.shade50,
                      Colors.red.shade700,
                      Icons.warning_amber_rounded,
                    ),
                  )
                  .toList(),
            ),
          ],

          if (_conditions.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'CONDITIONS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.grayText,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _conditions
                  .map(
                    (c) => _buildChip(
                      c,
                      Colors.orange.shade50,
                      Colors.orange.shade700,
                      Icons.health_and_safety,
                    ),
                  )
                  .toList(),
            ),
          ],

          if (_cabinetDrugs.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'CABINET MEDICINES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.grayText,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _cabinetDrugs
                  .map(
                    (d) => _buildChip(
                      d.displayName,
                      AppColors.primaryTeal.withOpacity(0.1),
                      AppColors.primaryTeal,
                      Icons.medication,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color bgColor, Color fgColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fgColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Profile Results ====================

  Widget _buildProfileResultsSection() {
    if (_isChecking) {
      return const Column(
        children: [
          SizedBox(height: 20),
          Center(
            child: CircularProgressIndicator(color: AppColors.primaryTeal),
          ),
          SizedBox(height: 20),
          Text(
            'Analyzing against your health profile...',
            style: TextStyle(color: AppColors.grayText),
          ),
        ],
      );
    }

    final result = _profileWarningResult!;
    final hasAnyWarning = result.hasWarnings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profile Analysis',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        if (!hasAnyWarning) ...[
          MedicalSectionCard(
            icon: Icons.check_circle,
            iconColor: AppColors.accentGreen,
            title: 'All Clear!',
            subtitle:
                '${_selectedDrugA!.displayName} appears safe based on your profile.',
            child: const Text(
              'No allergy, condition, or drug interaction issues detected.',
              style: TextStyle(fontSize: 12, color: AppColors.grayText),
            ),
          ),
        ],

        // Allergy warnings
        if (result.hasAllergyWarning) ...[
          _buildProfileWarningCard(
            title: 'Allergy Alert',
            icon: Icons.dangerous,
            color: Colors.red,
            items: [
              ...result.matchedAllergies.map((a) => 'Direct allergy: $a'),
              ...result.matchedClassAllergies.map(
                (a) => 'Class sensitivity: $a',
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Condition warnings
        if (result.hasConditionWarning) ...[
          _buildProfileWarningCard(
            title: 'Condition Conflict',
            icon: Icons.health_and_safety,
            color: Colors.orange,
            items: result.matchedConditions,
          ),
          const SizedBox(height: 12),
        ],

        // Drug-drug interactions
        if (result.hasDrugInteraction) ...[
          _buildProfileWarningCard(
            title: 'Drug Interactions',
            icon: Icons.warning_amber_rounded,
            color:
                result.matchedDrugInteractions.any(
                  (i) => i.severity == 'severe',
                )
                ? Colors.red
                : Colors.orange,
            items: result.matchedDrugInteractions
                .map(
                  (i) =>
                      '${i.severity.toUpperCase()} with ${i.drugName}: ${i.description}',
                )
                .toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Duplicate therapy
        if (result.hasDuplicateTherapy) ...[
          _buildProfileWarningCard(
            title: 'Duplicate Therapy',
            icon: Icons.content_copy,
            color: Colors.orange,
            items: result.matchedDuplicates
                .map(
                  (d) =>
                      '${d.displayName} in your cabinet shares active ingredients',
                )
                .toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Food interactions (informational)
        if (result.hasFoodWarning) ...[
          _buildProfileWarningCard(
            title: 'Food Interactions',
            icon: Icons.restaurant,
            color: Colors.amber.shade700,
            items: result.foodInteractions
                .map((f) => '${f.food} (${f.severity}): ${f.description}')
                .toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Alcohol warning
        if (result.drug.hasAlcoholWarning) ...[
          _buildProfileWarningCard(
            title: 'Alcohol Warning',
            icon: Icons.local_bar,
            color: Colors.deepOrange,
            items: [
              result.drug.alcoholWarningDescription ??
                  'Alcohol restriction: ${result.drug.alcoholRestriction}',
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildProfileWarningCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: color.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Guest Hook CTA ====================

  Widget _buildGuestHookCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryTeal.withValues(alpha: 0.08),
            AppColors.deepTeal.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryTeal.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_add_alt_1_rounded,
            color: AppColors.primaryTeal,
            size: 32,
          ),
          const SizedBox(height: 12),
          const Text(
            'Never forget a clash again',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Link your daily meds to your profile for automatic safety checks.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.grayText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/register',
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Register Now — It\'s Free',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
