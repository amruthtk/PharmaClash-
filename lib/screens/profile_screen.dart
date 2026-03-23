import 'package:flutter/material.dart';
import '../models/medical_reference_data.dart';
import '../theme/app_colors.dart';
import '../services/firebase_service.dart';
import '../services/emergency_service.dart';
import '../services/biometric_service.dart';
import '../widgets/profile/profile_background.dart';
import '../widgets/profile/profile_personal_details_card.dart';
import '../widgets/profile/profile_header.dart';
import '../widgets/profile/profile_section_title.dart';
import '../widgets/profile/profile_caregiver_card.dart';
import '../widgets/profile/profile_tag_card.dart';
import '../widgets/profile/profile_account_card.dart';
import '../widgets/profile/profile_biometric_dialog.dart';
import '../widgets/profile/profile_edit_tags_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final EmergencyService _emergencyService = EmergencyService();
  final BiometricService _biometricService = BiometricService();

  // User data
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _medicalInfo;
  bool _isLoading = true;

  // Biometric settings
  bool _canUseBiometrics = false;
  bool _biometricEnabled = false;

  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _loadUserData();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        final profile = await _firebaseService.getUserProfile(user.uid);
        final medical = await _firebaseService.getMedicalInfo(user.uid);

        if (mounted) {
          setState(() {
            _userProfile = profile;
            _medicalInfo = medical;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading profile: $e', isError: true);
      }
    }
  }

  Future<void> _checkBiometrics() async {
    try {
      final canUse = await _biometricService.canUseBiometrics();
      final isEnabled = await _biometricService.isBiometricEnabled();
      if (mounted) {
        setState(() {
          _canUseBiometrics = canUse;
          _biometricEnabled = isEnabled;
        });
      }
    } catch (e) {
      debugPrint('Error checking biometrics: $e');
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

  String get _userName {
    return _userProfile?['fullName'] ??
        _firebaseService.currentUser?.displayName ??
        'User';
  }

  String get _userEmail {
    return _userProfile?['email'] ??
        _firebaseService.currentUser?.email ??
        'No email';
  }

  String get _userGender {
    return _userProfile?['gender'] ?? 'Not provided';
  }

  String get _userDOB {
    final dob = _userProfile?['dateOfBirth'];
    if (dob == null) return 'Not provided';
    try {
      final date = DateTime.parse(dob);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Not provided';
    }
  }

  List<String> get _allergies {
    final allergies = _medicalInfo?['allergies'];
    if (allergies == null) return [];
    return List<String>.from(allergies);
  }

  List<String> get _conditions {
    final conditions = _medicalInfo?['healthConditions'];
    if (conditions == null) return [];
    return List<String>.from(conditions);
  }

  String get _caregiverName {
    return _medicalInfo?['caregiverName'] ?? '';
  }

  String get _caregiverEmail {
    return _medicalInfo?['caregiverEmail'] ?? '';
  }

  bool get _hasCaregiverConfigured {
    return _caregiverEmail.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: AppColors.softWhite,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryTeal),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: Stack(
        children: [
          // Animated background
          ProfileBackground(floatAnimation: _floatController),

          // Main content
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 12,
              20,
              100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button row
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryTeal.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Profile Header Card
                ProfileHeader(userName: _userName, userEmail: _userEmail),
                const SizedBox(height: 24),

                // Personal Details Section
                const ProfileSectionTitle(
                  title: 'Personal Details',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 12),
                ProfilePersonalDetailsCard(
                  fullName: _userName,
                  email: _userEmail,
                  dob: _userDOB,
                  gender: _userGender,
                ),
                const SizedBox(height: 24),

                // Drug Allergies Section
                const ProfileSectionTitle(
                  title: 'Drug Allergies',
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(height: 12),
                ProfileTagCard(
                  tags: _allergies,
                  emptyMessage: 'No allergies recorded',
                  countLabelSingular: 'allergy',
                  countLabelPlural: 'allergies',
                  tagIcon: Icons.warning_amber_rounded,
                  tagColor: Colors.red,
                  onEdit: _showEditAllergiesDialog,
                ),
                const SizedBox(height: 24),

                // Health Conditions Section
                const ProfileSectionTitle(
                  title: 'Health Conditions',
                  icon: Icons.medical_services_outlined,
                ),
                const SizedBox(height: 12),
                ProfileTagCard(
                  tags: _conditions,
                  emptyMessage: 'No conditions recorded',
                  countLabelSingular: 'condition',
                  countLabelPlural: 'conditions',
                  tagIcon: Icons.medical_services_outlined,
                  tagColor: AppColors.primaryTeal,
                  onEdit: _showEditConditionsDialog,
                ),
                const SizedBox(height: 24),

                // Emergency Caregiver Section
                const ProfileSectionTitle(
                  title: 'Emergency Caregiver',
                  icon: Icons.contact_emergency_rounded,
                ),
                const SizedBox(height: 12),
                ProfileCaregiverCard(
                  hasCaregiver: _hasCaregiverConfigured,
                  name: _caregiverName,
                  email: _caregiverEmail,
                  onEdit: () => Navigator.pushNamed(context, '/medical-info'),
                  onEmail: () => _emergencyService.sendEmailAlert(
                    email: _caregiverEmail,
                    patientName: _userName,
                  ),
                  onAdd: () => Navigator.pushNamed(context, '/medical-info'),
                ),
                const SizedBox(height: 12),
                // Push notification caregiver link
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/caregiver-setup'),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primaryTeal.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryTeal.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: AppColors.primaryTeal,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Caregiver Alerting',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkText,
                                ),
                              ),
                              Text(
                                'Manage email and real-time in-app alerts',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.grayText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: AppColors.grayText,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Account Actions
                const ProfileSectionTitle(
                  title: 'Account',
                  icon: Icons.settings_outlined,
                ),
                const SizedBox(height: 12),
                ProfileAccountCard(
                  canUseBiometrics: _canUseBiometrics,
                  biometricEnabled: _biometricEnabled,
                  onBiometricChanged: (value) async {
                    if (value) {
                      await _enableBiometric();
                    } else {
                      await _disableBiometric();
                    }
                  },
                  onSignOut: () async {
                    await _firebaseService.signOut();
                    if (mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enableBiometric() async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => ProfileBiometricDialog(userEmail: _userEmail),
    );

    if (password != null && password.isNotEmpty) {
      final success = await _biometricService.enableBiometricLogin(
        email: _userEmail,
        password: password,
      );
      if (success && mounted) {
        setState(() => _biometricEnabled = true);
        _showSnackBar('Biometric login enabled!');
      } else if (mounted) {
        // Offer to save without verification
        final retry = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Verification Failed'),
            content: const Text(
              'Fingerprint verification was cancelled or failed. Would you like to enable biometric login without verification?\n\nYou can use your fingerprint or device PIN to login later.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Enable Anyway'),
              ),
            ],
          ),
        );

        if (retry == true) {
          final retrySuccess = await _biometricService.enableBiometricLogin(
            email: _userEmail,
            password: password,
            skipVerification: true,
          );
          if (retrySuccess && mounted) {
            setState(() => _biometricEnabled = true);
            _showSnackBar('Biometric login enabled!');
          } else if (mounted) {
            _showSnackBar('Failed to enable biometric login', isError: true);
          }
        }
      }
    }
  }

  Future<void> _disableBiometric() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Disable Biometric'),
        content: const Text(
          'Are you sure you want to disable biometric login? You will need to enter your email and password to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (result == true) {
      final success = await _biometricService.disableBiometricLogin();
      if (success && mounted) {
        setState(() => _biometricEnabled = false);
        _showSnackBar('Biometric login disabled');
      }
    }
  }

  // ==================== Edit Dialogs ====================

  void _showEditAllergiesDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileEditTagsDialog(
        title: 'Edit Drug Allergies',
        initialTags: _allergies,
        searchFunction: MedicalReferenceData.searchDrugAllergies,
        searchHint: 'Search allergies...',
        activeColor: Colors.red,
        onSave: _saveAllergies,
      ),
    );
  }

  void _showEditConditionsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileEditTagsDialog(
        title: 'Edit Health Conditions',
        initialTags: _conditions,
        searchFunction: MedicalReferenceData.searchHealthConditions,
        searchHint: 'Search conditions...',
        activeColor: AppColors.primaryTeal,
        onSave: _saveConditions,
      ),
    );
  }

  Future<void> _saveAllergies(List<String> allergies) async {
    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        await _firebaseService.updateMedicalInfo(user.uid, {
          'allergies': allergies,
        });
        await _loadUserData();
        _showSnackBar('Allergies updated successfully!');
      }
    } catch (e) {
      _showSnackBar('Error saving allergies: $e', isError: true);
    }
  }

  Future<void> _saveConditions(List<String> conditions) async {
    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        await _firebaseService.updateMedicalInfo(user.uid, {
          'healthConditions': conditions,
        });
        await _loadUserData();
        _showSnackBar('Conditions updated successfully!');
      }
    } catch (e) {
      _showSnackBar('Error saving conditions: $e', isError: true);
    }
  }
}
