import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../services/biometric_service.dart';
import '../services/telemetry_service.dart';
import '../theme/app_colors.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedGender;
  bool _agreedToTerms = false;
  bool _hasReadDisclaimer = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animationController;
  late AnimationController _floatController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final FirebaseService _firebaseService = FirebaseService();
  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

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
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
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

    // Pre-fill data if user is already authenticated
    final currentUser = _firebaseService.currentUser;
    if (currentUser != null) {
      _fullNameController.text = currentUser.displayName ?? '';
      _emailController.text = currentUser.email ?? '';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  bool get _isGoogleUser {
    final user = _firebaseService.currentUser;
    if (user == null) return false;
    for (final info in user.providerData) {
      if (info.providerId == 'google.com') return true;
    }
    return false;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      // Default to 1990 for better UX - elderly users won't have to scroll far
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year, // Start with year selection
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryTeal,
              onPrimary: Colors.white,
              onSurface: AppColors.darkText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      _showSnackBar('Please select your date of birth', isError: true);
      return;
    }

    if (_selectedGender == null) {
      _showSnackBar('Please select your gender', isError: true);
      return;
    }

    if (!_agreedToTerms) {
      _showSnackBar(
        'Please read and accept the Medical Disclaimer',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim().toLowerCase();

      final user = _firebaseService.currentUser;

      // ONLY check Firestore if we are ALREADY authenticated (like Google Users)
      // For new Email/Password users, user is NULL and we lack permission to query.
      // But that's okay, because Firebase Auth will catch duplicates anyway!
      if (user != null) {
        // Find if this email exists under ANY UID in our users collection
        final querySnapshot = await _firebaseService.usersCollection
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final existingDoc = querySnapshot.docs.first;
          // If the UID is DIFFERENT than our current authenticated UID, block it
          if (existingDoc.id != user.uid) {
            _showSnackBar(
              'This email already has an account. Please Log In with your password to link them.',
              isError: true,
            );
            
            // Clean up the "phantom" auth user if they are using Google
            if (_isGoogleUser) await _firebaseService.signOut();
            
            if (mounted) {
              setState(() => _isLoading = false);
              Navigator.pushReplacementNamed(context, '/login');
            }
            return;
          }
        }
      }

      if (_firebaseService.currentUser == null) {
        final credential = await _firebaseService.signUpWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (credential.user != null) {
          await Future.wait([
            _firebaseService.saveUserProfile(
              uid: credential.user!.uid,
              email: _emailController.text.trim(),
              fullName: _fullNameController.text.trim(),
              dateOfBirth: _selectedDate,
              gender: _selectedGender,
            ),
            _firebaseService.updateDisplayName(_fullNameController.text.trim()),
          ]);
        }
      } else {
        final user = _firebaseService.currentUser!;
        await Future.wait([
          _firebaseService.saveUserProfile(
            uid: user.uid,
            email: _emailController.text.trim(),
            fullName: _fullNameController.text.trim(),
            dateOfBirth: _selectedDate,
            gender: _selectedGender,
          ),
          _firebaseService.updateDisplayName(_fullNameController.text.trim()),
        ]);
      }

      if (mounted) {
        // Log registration success for conversion funnel
        TelemetryService().logEvent(
          'registration_success',
          details: 'Guest successfully registered as a patient.',
        );

        BiometricService.isSessionUnlocked = true;
        _showSnackBar('Registration successful!');
        Navigator.pushReplacementNamed(context, '/medical-info');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString(), isError: true);
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

  void _showDisclaimerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
        child: Column(
          children: [
            Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Medical Disclaimer',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDisclaimerBullet(
                      'Information Accuracy',
                      'The information provided by PharmaClash is for reference only and is NOT 100% accurate. AI-powered scanning and database results may contain errors.',
                    ),
                    const SizedBox(height: 16),
                    _buildDisclaimerBullet(
                      'Not a Doctor Replacement',
                      'This application is NOT a substitute for professional medical advice, diagnosis, or treatment by a qualified doctor.',
                    ),
                    const SizedBox(height: 16),
                    _buildDisclaimerBullet(
                      'Prescription Changes',
                      'Never change your medication, dosage, or start new drugs based solely on this app without explicit consent from your doctor.',
                    ),
                    const SizedBox(height: 16),
                    _buildDisclaimerBullet(
                      'Emergency Situations',
                      'If you are experiencing a medical emergency, call your local emergency services or visit a hospital immediately.',
                    ),
                    const Divider(height: 40),
                    const Text(
                      'Acknowledgement',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'By accepting this disclaimer, you understand and acknowledge that the doctor is the final authority for your health decisions.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.grayText,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasReadDisclaimer = true;
                    _agreedToTerms = true; // Auto-check if they click accept
                  });
                  Navigator.pop(context);
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
                  'I Understand & Accept',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimerBullet(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryTeal,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.darkText,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Animated background
          _buildBackgroundDecorations(),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),

                          // Back button
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _buildBackButton(),
                          ),
                          const SizedBox(height: 30),

                          // Header
                          _buildHeader(),
                          const SizedBox(height: 36),

                          // Form Fields
                          _buildInputLabel('Full Name'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _fullNameController,
                            hint: 'Enter your full name',
                            prefixIcon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInputLabel('Date of Birth'),
                                    const SizedBox(height: 8),
                                    _buildDatePicker(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInputLabel('Gender'),
                                    const SizedBox(height: 8),
                                    _buildGenderDropdown(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          _buildInputLabel('Email Address'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _emailController,
                            hint: 'Enter your email',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            readOnly: _isGoogleUser,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value)) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          if (!_isGoogleUser) ...[
                            _buildInputLabel('Create Password'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _passwordController,
                              hint: 'Minimum 8 characters',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.grayText,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a password';
                                }
                                if (value.length < 8) {
                                  return 'Must be at least 8 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            _buildInputLabel('Confirm Password'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _confirmPasswordController,
                              hint: 'Re-enter password',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscureConfirmPassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.grayText,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  );
                                },
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                          ],

                          // Medical Disclaimer Checkbox
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _agreedToTerms,
                                  onChanged: (value) {
                                    if (!_hasReadDisclaimer) {
                                      _showDisclaimerSheet();
                                      return;
                                    }
                                    setState(
                                      () => _agreedToTerms = value ?? false,
                                    );
                                  },
                                  activeColor: AppColors.primaryTeal,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _showDisclaimerSheet,
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.grayText,
                                        height: 1.4,
                                      ),
                                      children: [
                                        const TextSpan(
                                          text:
                                              'I acknowledge and agree to the ',
                                        ),
                                        TextSpan(
                                          text: 'Medical Disclaimer',
                                          style: TextStyle(
                                            color: AppColors.primaryTeal,
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Sign Up Button
                          _buildPrimaryButton(),
                          const SizedBox(height: 24),

                          // Login Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Already have an account? ',
                                style: TextStyle(
                                  color: AppColors.grayText,
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacementNamed(
                                    context,
                                    '/login',
                                  );
                                },
                                child: const Text(
                                  'Log In',
                                  style: TextStyle(
                                    color: AppColors.primaryTeal,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecorations() {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          return Stack(
            children: [
              Positioned(
                top: 40 + (math.sin(_floatController.value * math.pi) * 10),
                right: 20,
                child: Opacity(
                  opacity: 0.4,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [AppColors.lightMint, Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 200 + (math.cos(_floatController.value * math.pi) * 15),
                left: 20,
                child: Opacity(
                  opacity: 0.3,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.mintGreen.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackButton() {
    return Container(
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
            Navigator.pushReplacementNamed(context, '/splash');
          }
        },
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: AppColors.darkText,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isGoogleUser = _firebaseService.currentUser != null;

    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.deepTeal, AppColors.primaryTeal],
          ).createShader(bounds),
          child: Text(
            isGoogleUser ? 'Complete Profile' : 'Create Account',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isGoogleUser
              ? 'Signed in as ${_emailController.text}'
              : 'Sign up to start your health journey',
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.grayText,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (isGoogleUser) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              await _firebaseService.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/splash',
                  (route) => false,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 16,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Use a different account',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      readOnly: readOnly,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(
        fontSize: 16,
        color: AppColors.darkText,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.grayText.withValues(alpha: 0.7),
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 4),
          child: Icon(prefixIcon, color: AppColors.grayText, size: 22),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.lightBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.lightBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lightBorderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: AppColors.grayText,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedDate != null
                    ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                    : 'Select',
                style: TextStyle(
                  fontSize: 15,
                  color: _selectedDate != null
                      ? AppColors.darkText
                      : AppColors.grayText.withValues(alpha: 0.7),
                  fontWeight: _selectedDate != null
                      ? FontWeight.w500
                      : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightBorderColor),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedGender,
        isExpanded: true,
        hint: Text(
          'Select',
          style: TextStyle(
            color: AppColors.grayText.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: AppColors.grayText,
          size: 20,
        ),
        dropdownColor: Colors.white,
        style: const TextStyle(color: AppColors.darkText, fontSize: 14),
        items: _genderOptions.map((String gender) {
          return DropdownMenuItem<String>(
            value: gender,
            child: Text(
              gender,
              style: const TextStyle(color: AppColors.darkText, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() => _selectedGender = newValue);
        },
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : _handleSignUp,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryTeal, AppColors.deepTeal],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryTeal.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
