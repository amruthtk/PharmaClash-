import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/medical_reference_data.dart';
import '../theme/app_colors.dart';
import '../services/firebase_service.dart';
import '../services/emergency_service.dart';
import '../services/biometric_service.dart';

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

  String get _userPhone {
    return _userProfile?['phone'] ?? 'Not provided';
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
    final conditions = _medicalInfo?['chronicConditions'];
    if (conditions == null) return [];
    return List<String>.from(conditions);
  }

  String get _caregiverName {
    return _medicalInfo?['caregiverName'] ?? '';
  }

  String get _caregiverPhone {
    return _medicalInfo?['caregiverPhone'] ?? '';
  }

  bool get _hasCaregiverConfigured {
    return _caregiverPhone.isNotEmpty;
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

    return Container(
      color: AppColors.softWhite,
      child: Stack(
        children: [
          // Animated background
          _buildAnimatedBackground(),

          // Main content
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header Card
                _buildProfileHeader(),
                const SizedBox(height: 24),

                // Personal Details Section
                _buildSectionTitle('Personal Details', Icons.person_outline),
                const SizedBox(height: 12),
                _buildPersonalDetailsCard(),
                const SizedBox(height: 24),

                // Drug Allergies Section
                _buildSectionTitle(
                  'Drug Allergies',
                  Icons.warning_amber_rounded,
                ),
                const SizedBox(height: 12),
                _buildAllergiesCard(),
                const SizedBox(height: 24),

                // Chronic Conditions Section
                _buildSectionTitle(
                  'Chronic Conditions',
                  Icons.medical_services_outlined,
                ),
                const SizedBox(height: 12),
                _buildConditionsCard(),
                const SizedBox(height: 24),

                // Emergency Caregiver Section
                _buildSectionTitle(
                  'Emergency Caregiver',
                  Icons.contact_emergency_rounded,
                ),
                const SizedBox(height: 12),
                _buildCaregiverCard(),
                const SizedBox(height: 24),

                // Account Actions
                _buildSectionTitle('Account', Icons.settings_outlined),
                const SizedBox(height: 12),
                _buildAccountActionsCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: 50 + (math.sin(_floatController.value * math.pi) * 10),
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.lightMint.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 200 + (math.cos(_floatController.value * math.pi) * 15),
              left: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.mintGreen.withValues(alpha: 0.15),
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

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryTeal.withValues(alpha: 0.1),
            AppColors.lightMint.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryTeal, AppColors.deepTeal],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryTeal.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.grayText,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified,
                        size: 14,
                        color: AppColors.primaryTeal,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Verified Account',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.grayText, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.grayText,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDetailRow('Full Name', _userName, Icons.person_outline),
          _buildDivider(),
          _buildDetailRow('Email', _userEmail, Icons.email_outlined),
          _buildDivider(),
          _buildDetailRow('Phone', _userPhone, Icons.phone_outlined),
          _buildDivider(),
          _buildDetailRow('Date of Birth', _userDOB, Icons.cake_outlined),
          _buildDivider(),
          _buildDetailRow('Gender', _userGender, Icons.wc_outlined),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryTeal, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grayText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.darkText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 1, color: AppColors.lightBorderColor);
  }

  Widget _buildAllergiesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightBorderColor),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _allergies.isEmpty
                    ? 'No allergies recorded'
                    : '${_allergies.length} ${_allergies.length == 1 ? 'allergy' : 'allergies'}',
                style: const TextStyle(fontSize: 14, color: AppColors.grayText),
              ),
              _buildEditButton(onTap: () => _showEditAllergiesDialog()),
            ],
          ),
          if (_allergies.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allergies.map((allergy) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: Colors.red.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        allergy,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConditionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightBorderColor),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _conditions.isEmpty
                    ? 'No conditions recorded'
                    : '${_conditions.length} ${_conditions.length == 1 ? 'condition' : 'conditions'}',
                style: const TextStyle(fontSize: 14, color: AppColors.grayText),
              ),
              _buildEditButton(onTap: () => _showEditConditionsDialog()),
            ],
          ),
          if (_conditions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _conditions.map((condition) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryTeal.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.medical_services_outlined,
                        size: 14,
                        color: AppColors.primaryTeal,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        condition,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primaryTeal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryTeal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primaryTeal.withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 14, color: AppColors.primaryTeal),
            SizedBox(width: 4),
            Text(
              'Edit',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaregiverCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _hasCaregiverConfigured
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Emergency contact configured',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.grayText,
                      ),
                    ),
                    _buildEditButton(
                      onTap: () {
                        Navigator.pushNamed(context, '/medical-info');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Caregiver info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryTeal.withValues(alpha: 0.2),
                    ),
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
                          Icons.person,
                          color: AppColors.primaryTeal,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _caregiverName.isNotEmpty
                                  ? _caregiverName
                                  : 'Caregiver',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkText,
                              ),
                            ),
                            Text(
                              _caregiverPhone,
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
                ),
                const SizedBox(height: 16),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildCaregiverActionButton(
                        icon: Icons.phone_rounded,
                        label: 'Call',
                        color: Colors.green,
                        onTap: () async {
                          await _emergencyService.callCaregiver(
                            customPhone: _caregiverPhone,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCaregiverActionButton(
                        icon: Icons.message_rounded,
                        label: 'Send SMS',
                        color: Colors.blue,
                        onTap: () async {
                          await _emergencyService.sendSMSAlert(
                            message:
                                'Hello, this is a test message from PharmaClash.',
                            customPhone: _caregiverPhone,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              children: [
                Icon(
                  Icons.person_add_rounded,
                  size: 48,
                  color: AppColors.grayText.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No emergency contact',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add a caregiver to receive emergency alerts',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.grayText),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/medical-info');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryTeal, AppColors.deepTeal],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryTeal.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Add Caregiver',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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

  Widget _buildCaregiverActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountActionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Biometric Login Toggle
          if (_canUseBiometrics) ...[
            _buildBiometricTile(),
            Container(height: 1, color: AppColors.lightBorderColor),
          ],
          _buildActionTile(
            icon: Icons.refresh_rounded,
            title: 'Refresh Profile',
            subtitle: 'Reload your profile data',
            onTap: _loadUserData,
          ),
          Container(height: 1, color: AppColors.lightBorderColor),
          _buildActionTile(
            icon: Icons.logout_rounded,
            title: 'Sign Out',
            subtitle: 'Log out of your account',
            isDestructive: true,
            onTap: () async {
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
    );
  }

  Widget _buildBiometricTile() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            _biometricEnabled ? _disableBiometric() : _enableBiometric(),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.fingerprint,
                  color: AppColors.primaryTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Biometric Login',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                    ),
                    Text(
                      _biometricEnabled
                          ? 'Enabled - Use fingerprint to login'
                          : 'Disabled - Tap to enable',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _biometricEnabled,
                onChanged: (value) {
                  if (value) {
                    _enableBiometric();
                  } else {
                    _disableBiometric();
                  }
                },
                activeTrackColor: AppColors.primaryTeal,
                thumbColor: WidgetStateProperty.all(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enableBiometric() async {
    // Show dialog to get password for secure storage
    final passwordController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.fingerprint,
                color: AppColors.primaryTeal,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Enable Biometric'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your password to enable fingerprint login. Your credentials will be stored securely on this device.',
              style: TextStyle(fontSize: 14, color: AppColors.grayText),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
          ],
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (result == true && passwordController.text.isNotEmpty) {
      final email = _userEmail;
      final password = passwordController.text;

      final success = await _biometricService.enableBiometricLogin(
        email: email,
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
            email: email,
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

    passwordController.dispose();
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

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red.shade500 : AppColors.primaryTeal;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDestructive
                            ? Colors.red.shade600
                            : AppColors.darkText,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.grayText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== Edit Dialogs ====================

  void _showEditAllergiesDialog() {
    final selectedAllergies = List<String>.from(_allergies);
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredAllergies = MedicalReferenceData.searchDrugAllergies(
            searchController.text,
          );

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.lightBorderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Drug Allergies',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _saveAllergies(selectedAllergies);
                        },
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: AppColors.primaryTeal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(color: AppColors.darkText),
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search allergies...',
                      hintStyle: TextStyle(
                        color: AppColors.grayText.withValues(alpha: 0.7),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.grayText,
                      ),
                      filled: true,
                      fillColor: AppColors.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.lightBorderColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.lightBorderColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primaryTeal,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Selected chips
                if (selectedAllergies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedAllergies.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final allergy = selectedAllergies[index];
                          return Chip(
                            label: Text(
                              allergy,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                            deleteIcon: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.red.shade600,
                            ),
                            onDeleted: () {
                              setModalState(() {
                                selectedAllergies.remove(allergy);
                              });
                            },
                            side: BorderSide.none,
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Allergy list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredAllergies.length,
                    itemBuilder: (context, index) {
                      final allergy = filteredAllergies[index];
                      final isSelected = selectedAllergies.contains(allergy);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setModalState(() {
                              if (isSelected) {
                                selectedAllergies.remove(allergy);
                              } else {
                                selectedAllergies.add(allergy);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : AppColors.inputBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.red.withValues(alpha: 0.3)
                                    : AppColors.lightBorderColor,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.red
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.red
                                          : AppColors.lightBorderColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 16,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    allergy,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected
                                          ? Colors.red.shade700
                                          : AppColors.darkText,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
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
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditConditionsDialog() {
    final selectedConditions = List<String>.from(_conditions);
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredConditions = MedicalReferenceData.searchChronicDiseases(
            searchController.text,
          );

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.lightBorderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Chronic Conditions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _saveConditions(selectedConditions);
                        },
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: AppColors.primaryTeal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(color: AppColors.darkText),
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search conditions...',
                      hintStyle: TextStyle(
                        color: AppColors.grayText.withValues(alpha: 0.7),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.grayText,
                      ),
                      filled: true,
                      fillColor: AppColors.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.lightBorderColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.lightBorderColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primaryTeal,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Selected chips
                if (selectedConditions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedConditions.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final condition = selectedConditions[index];
                          return Chip(
                            label: Text(
                              condition,
                              style: const TextStyle(
                                color: AppColors.primaryTeal,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: AppColors.primaryTeal.withValues(
                              alpha: 0.1,
                            ),
                            deleteIcon: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.primaryTeal,
                            ),
                            onDeleted: () {
                              setModalState(() {
                                selectedConditions.remove(condition);
                              });
                            },
                            side: BorderSide.none,
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Condition list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredConditions.length,
                    itemBuilder: (context, index) {
                      final condition = filteredConditions[index];
                      final isSelected = selectedConditions.contains(condition);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setModalState(() {
                              if (isSelected) {
                                selectedConditions.remove(condition);
                              } else {
                                selectedConditions.add(condition);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryTeal.withValues(alpha: 0.1)
                                  : AppColors.inputBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryTeal.withValues(
                                        alpha: 0.3,
                                      )
                                    : AppColors.lightBorderColor,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryTeal
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primaryTeal
                                          : AppColors.lightBorderColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 16,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    condition,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected
                                          ? AppColors.primaryTeal
                                          : AppColors.darkText,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
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
              ],
            ),
          );
        },
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
          'chronicConditions': conditions,
        });
        await _loadUserData();
        _showSnackBar('Conditions updated successfully!');
      }
    } catch (e) {
      _showSnackBar('Error saving conditions: $e', isError: true);
    }
  }
}
