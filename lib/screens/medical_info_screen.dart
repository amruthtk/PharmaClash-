import 'package:flutter/material.dart';
import '../models/medical_reference_data.dart';
import '../theme/app_colors.dart';
import '../services/firebase_service.dart';
import '../widgets/medical/medical_section_card.dart';
import '../widgets/medical/medical_autocomplete_field.dart';
import '../widgets/medical/medical_progress_indicator.dart';
import '../widgets/medical/medical_background.dart';
import '../widgets/medical/medical_chip.dart';
import '../widgets/medical/medical_app_bar.dart';
import '../widgets/medical/medical_bottom_buttons.dart';
import '../widgets/medical/medical_condition_tile.dart';
import '../widgets/medical/medical_security_notice.dart';
import '../widgets/medical/medical_input_field.dart';

class MedicalInfoScreen extends StatefulWidget {
  const MedicalInfoScreen({super.key});

  @override
  State<MedicalInfoScreen> createState() => _MedicalInfoScreenState();
}

class _MedicalInfoScreenState extends State<MedicalInfoScreen>
    with TickerProviderStateMixin {
  final _allergyController = TextEditingController();
  final _conditionController = TextEditingController();
  final _caregiverNameController = TextEditingController();
  final _caregiverEmailController = TextEditingController();
  final _allergyFocusNode = FocusNode();
  final _conditionFocusNode = FocusNode();

  final FirebaseService _firebaseService = FirebaseService();

  // Selected items from Reference Database
  final List<String> _selectedAllergies = [];
  final List<String> _selectedConditions = [];

  // Quick-select health conditions (subset of Reference Data)
  final Map<String, bool> _quickSelectDiseases = {
    'Hypertension': false,
    'Asthma': false,
    'Arthritis': false,
    'Diabetes Type 2': false,
    'Depression': false,
    'Heart Disease': false,
  };

  bool _isLoading = false;
  bool _showAllergySuggestions = false;
  bool _showConditionSuggestions = false;

  late AnimationController _animationController;
  late AnimationController _floatController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _animationController.forward();

    // Listen to text changes for autocomplete
    _allergyController.addListener(_onAllergyTextChanged);
    _conditionController.addListener(_onConditionTextChanged);
  }

  @override
  void dispose() {
    _allergyController.removeListener(_onAllergyTextChanged);
    _conditionController.removeListener(_onConditionTextChanged);
    _allergyController.dispose();
    _conditionController.dispose();
    _caregiverNameController.dispose();
    _caregiverEmailController.dispose();
    _allergyFocusNode.dispose();
    _conditionFocusNode.dispose();
    _animationController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _onAllergyTextChanged() {
    setState(() {
      _showAllergySuggestions = _allergyController.text.isNotEmpty;
    });
  }

  void _onConditionTextChanged() {
    setState(() {
      _showConditionSuggestions = _conditionController.text.isNotEmpty;
    });
  }

  void _addAllergy(String allergy) {
    if (!_selectedAllergies.contains(allergy)) {
      setState(() {
        _selectedAllergies.add(allergy);
        _allergyController.clear();
        _showAllergySuggestions = false;
      });
    }
  }

  void _removeAllergy(String allergy) {
    setState(() => _selectedAllergies.remove(allergy));
  }

  void _addCondition(String condition) {
    if (!_selectedConditions.contains(condition) &&
        !_quickSelectDiseases.containsKey(condition)) {
      setState(() {
        _selectedConditions.add(condition);
        _conditionController.clear();
        _showConditionSuggestions = false;
      });
    }
  }

  void _removeCondition(String condition) {
    setState(() => _selectedConditions.remove(condition));
  }

  List<String> _getAllSelectedConditions() {
    final conditions = <String>[];
    // Add quick-select diseases that are checked
    _quickSelectDiseases.forEach((disease, isSelected) {
      if (isSelected) conditions.add(disease);
    });
    // Add manually selected conditions
    conditions.addAll(_selectedConditions);
    return conditions;
  }

  Future<void> _handleSave() async {
    final caregiverEmail = _caregiverEmailController.text.trim();
    if (caregiverEmail.isNotEmpty &&
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(caregiverEmail)) {
      _showSnackBar('Please enter a valid email address', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        await _firebaseService.saveMedicalInfo(
          uid: user.uid,
          medicalData: {
            'allergies': _selectedAllergies,
            'healthConditions': _getAllSelectedConditions(),
            'caregiverName': _caregiverNameController.text.trim(),
            'caregiverEmail': caregiverEmail,
            'profileCompleted': true,
          },
        );
      }

      if (mounted) {
        _showSnackBar('Medical information saved!');
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error saving information: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade400 : AppColors.primaryTeal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inputBg,
      body: Stack(
        children: [
          MedicalBackground(floatAnimation: _floatController),
          Column(
            children: [
              MedicalAppBar(
                onBack: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/register');
                  }
                },
              ),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MedicalProgressIndicator(),
                          const SizedBox(height: 24),

                          MedicalSectionCard(
                            icon: Icons.warning_amber_rounded,
                            iconColor: Colors.orange,
                            title: 'Drug Allergies',
                            subtitle:
                                'Select any medications you are allergic to',
                            child: _buildAllergySection(),
                          ),
                          const SizedBox(height: 20),

                          MedicalSectionCard(
                            icon: Icons.medical_services_outlined,
                            iconColor: AppColors.primaryTeal,
                            title: 'Health Conditions',
                            subtitle: 'Select any conditions that apply to you',
                            child: _buildHealthConditionsSection(),
                          ),
                          const SizedBox(height: 20),

                          MedicalSectionCard(
                            icon: Icons.contact_phone_outlined,
                            iconColor: Colors.blue,
                            title: 'Caregiver Contact',
                            subtitle: 'Emergency contact for email alerts',
                            child: _buildCaregiverSection(),
                          ),
                          const SizedBox(height: 20),

                          const MedicalSecurityNotice(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          MedicalBottomButtons(onSave: _handleSave, isLoading: _isLoading),
        ],
      ),
    );
  }

  Widget _buildAllergySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Autocomplete search field
        MedicalAutocompleteField(
          controller: _allergyController,
          focusNode: _allergyFocusNode,
          hint: 'Search drug allergies...',
          showSuggestions: _showAllergySuggestions,
          getSuggestions: () => MedicalReferenceData.searchDrugAllergies(
            _allergyController.text,
          ).where((a) => !_selectedAllergies.contains(a)).toList(),
          onSelected: _addAllergy,
          onDismiss: () => setState(() => _showAllergySuggestions = false),
        ),

        // Selected allergies chips
        if (_selectedAllergies.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedAllergies.map((allergy) {
              return MedicalChip(
                label: allergy,
                color: Colors.red,
                onRemove: () => _removeAllergy(allergy),
              );
            }).toList(),
          ),
        ],

        // Hint text
        if (_selectedAllergies.isEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: AppColors.grayText.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                'Select from verified drug allergies only',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.grayText.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildHealthConditionsSection() {
    return Column(
      children: [
        // Quick-select common conditions
        ...(_quickSelectDiseases.keys.map((disease) {
          return MedicalConditionTile(
            title: disease,
            subtitle: _getConditionSubtitle(disease),
            isSelected: _quickSelectDiseases[disease]!,
            onChanged: (v) =>
                setState(() => _quickSelectDiseases[disease] = v ?? false),
          );
        })),

        const SizedBox(height: 16),
        Container(height: 1, color: AppColors.lightBorderColor),
        const SizedBox(height: 16),

        // Search for more conditions
        Text(
          'Search for more conditions',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.grayText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),

        MedicalAutocompleteField(
          controller: _conditionController,
          focusNode: _conditionFocusNode,
          hint: 'Search conditions...',
          showSuggestions: _showConditionSuggestions,
          getSuggestions: () =>
              MedicalReferenceData.searchHealthConditions(
                    _conditionController.text,
                  )
                  .where(
                    (c) =>
                        !_selectedConditions.contains(c) &&
                        !_quickSelectDiseases.containsKey(c),
                  )
                  .toList(),
          onSelected: _addCondition,
          onDismiss: () => setState(() => _showConditionSuggestions = false),
        ),

        // Additional selected conditions
        if (_selectedConditions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedConditions.map((condition) {
              return MedicalChip(
                label: condition,
                color: AppColors.primaryTeal,
                onRemove: () => _removeCondition(condition),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  String _getConditionSubtitle(String condition) {
    switch (condition) {
      case 'Hypertension':
        return 'High blood pressure';
      case 'Asthma':
        return 'Respiratory condition';
      case 'Arthritis':
        return 'Joint inflammation';
      case 'Diabetes Type 2':
        return 'Blood sugar disorder';
      case 'Depression':
        return 'Mental health condition';
      case 'Heart Disease':
        return 'Cardiovascular condition';
      default:
        return '';
    }
  }

  Widget _buildCaregiverSection() {
    return Column(
      children: [
        MedicalInputField(
          controller: _caregiverNameController,
          hint: 'Caregiver name (optional)',
          prefixIcon: Icons.person_outline,
        ),
        const SizedBox(height: 14),
        MedicalInputField(
          controller: _caregiverEmailController,
          hint: 'Caregiver Gmail / Email (optional)',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }
}
