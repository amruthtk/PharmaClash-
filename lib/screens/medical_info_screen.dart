import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/medical_reference_data.dart';
import '../theme/app_colors.dart';
import '../services/firebase_service.dart';

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
  final _caregiverPhoneController = TextEditingController();
  final _allergyFocusNode = FocusNode();
  final _conditionFocusNode = FocusNode();

  final FirebaseService _firebaseService = FirebaseService();

  // Selected items from Reference Database
  final List<String> _selectedAllergies = [];
  final List<String> _selectedConditions = [];

  // Quick-select chronic diseases (subset of Reference Data)
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
    _caregiverPhoneController.dispose();
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
    final phone = _caregiverPhoneController.text.trim();

    if (phone.isNotEmpty && phone.length != 10) {
      _showSnackBar(
        'Please enter a valid 10-digit phone number',
        isError: true,
      );
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
            'chronicConditions': _getAllSelectedConditions(),
            'caregiverName': _caregiverNameController.text.trim(),
            'caregiverPhone': phone,
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

  void _handleSkip() {
    Navigator.pushReplacementNamed(context, '/dashboard');
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
          // Animated background
          _buildBackgroundDecorations(),

          // Main content
          Column(
            children: [
              // Premium App Bar
              _buildAppBar(),

              // Scrollable content
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
                          // Progress indicator
                          _buildProgressIndicator(),
                          const SizedBox(height: 24),

                          // Allergies Section
                          _buildSectionCard(
                            icon: Icons.warning_amber_rounded,
                            iconColor: Colors.orange,
                            title: 'Drug Allergies',
                            subtitle:
                                'Select any medications you are allergic to',
                            child: _buildAllergySection(),
                          ),
                          const SizedBox(height: 20),

                          // Chronic Diseases Section
                          _buildSectionCard(
                            icon: Icons.medical_services_outlined,
                            iconColor: AppColors.primaryTeal,
                            title: 'Chronic Conditions',
                            subtitle: 'Select any conditions that apply to you',
                            child: _buildChronicDiseasesSection(),
                          ),
                          const SizedBox(height: 20),

                          // Emergency Contact Section
                          _buildSectionCard(
                            icon: Icons.contact_phone_outlined,
                            iconColor: Colors.blue,
                            title: 'Caregiver Contact',
                            subtitle:
                                'Emergency contact for medication reminders',
                            child: _buildCaregiverSection(),
                          ),
                          const SizedBox(height: 20),

                          // Security Notice
                          _buildSecurityNotice(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Bottom Buttons
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecorations() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: -60 + (math.sin(_floatController.value * math.pi) * 10),
              right: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.lightMint.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 150 + (math.cos(_floatController.value * math.pi) * 15),
              left: -100,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.mintGreen.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightBorderColor),
            ),
            child: IconButton(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, '/register');
                }
              },
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.darkText,
                size: 18,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.deepTeal, AppColors.primaryTeal],
                ).createShader(bounds),
                child: const Text(
                  'Medical Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryTeal.withValues(alpha: 0.1),
            AppColors.mintGreen.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: AppColors.primaryTeal,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Step 2 of 2',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.grayText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Complete your health profile',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.darkText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 1.0,
                    backgroundColor: AppColors.lightBorderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryTeal),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightCardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      iconColor.withValues(alpha: 0.15),
                      iconColor.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: AppColors.grayText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildAllergySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Autocomplete search field
        _buildAutocompleteField(
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
              return _buildChip(
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

  Widget _buildChronicDiseasesSection() {
    return Column(
      children: [
        // Quick-select common conditions
        ...(_quickSelectDiseases.keys.map((disease) {
          return _buildConditionTile(
            disease,
            _getConditionSubtitle(disease),
            _quickSelectDiseases[disease]!,
            (v) => setState(() => _quickSelectDiseases[disease] = v ?? false),
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

        _buildAutocompleteField(
          controller: _conditionController,
          focusNode: _conditionFocusNode,
          hint: 'Search conditions...',
          showSuggestions: _showConditionSuggestions,
          getSuggestions: () =>
              MedicalReferenceData.searchChronicDiseases(
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
              return _buildChip(
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

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool showSuggestions,
    required List<String> Function() getSuggestions,
    required Function(String) onSelected,
    required VoidCallback onDismiss,
  }) {
    final suggestions = getSuggestions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(fontSize: 15, color: AppColors.darkText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.grayText.withValues(alpha: 0.6)),
            prefixIcon: const Icon(Icons.search, color: AppColors.grayText, size: 20),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      controller.clear();
                      onDismiss();
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
        ),

        // Suggestions dropdown
        if (showSuggestions && suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelected(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 18,
                            color: AppColors.primaryTeal,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              suggestion,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // No results message
        if (showSuggestions &&
            suggestions.isEmpty &&
            controller.text.length > 1)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No matching items found. Please select from the verified list.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildConditionTile(
    String title,
    String subtitle,
    bool value,
    Function(bool?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: value ? AppColors.primaryTeal.withValues(alpha: 0.08) : AppColors.inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value ? AppColors.primaryTeal.withValues(alpha: 0.3) : AppColors.lightBorderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: value ? AppColors.primaryTeal : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: value ? AppColors.primaryTeal : AppColors.lightBorderColor,
                    width: 2,
                  ),
                ),
                child: value
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: value ? AppColors.darkText : AppColors.grayText,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: value
                              ? AppColors.grayText
                              : AppColors.grayText.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaregiverSection() {
    return Column(
      children: [
        _buildInputField(
          controller: _caregiverNameController,
          hint: 'Caregiver name (optional)',
          prefixIcon: Icons.person_outline,
        ),
        const SizedBox(height: 14),
        _buildInputField(
          controller: _caregiverPhoneController,
          hint: '10-digit phone number (optional)',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 15, color: AppColors.darkText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.grayText.withValues(alpha: 0.6)),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.grayText, size: 20)
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

  Widget _buildChip({
    required String label,
    required Color color,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _darkenColor(color),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 16, color: _darkenColor(color)),
          ),
        ],
      ),
    );
  }

  Color _darkenColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade50.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.shield_outlined,
              color: Colors.blue.shade700,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Your medical information is encrypted and stored securely.',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : _handleSkip,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.lightBorderColor),
                      ),
                      child: const Center(
                        child: Text(
                          'Skip for now',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.grayText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : _handleSave,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryTeal, AppColors.deepTeal],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryTeal.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isLoading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else ...[
                            const Text(
                              'Save & Continue',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



