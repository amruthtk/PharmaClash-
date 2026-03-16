import 'package:flutter/material.dart';
import '../../../models/drug_model.dart';
import '../../../services/auto_email_service.dart';
import '../../../services/caregiver_notification_service.dart';
import '../../../services/drug_service.dart';
import '../../../services/emergency_service.dart';
import '../../../theme/app_colors.dart';
import '../../drug_details_screen.dart';

/// Premium Results overlay with animated clash detection UI
class ResultsOverlay extends StatefulWidget {
  final List<DrugWarningResult> verifiedDrugs;
  final VoidCallback onRescan;
  final VoidCallback onAddToCabinet;
  final VoidCallback onHighRiskOverride;
  final EmergencyService emergencyService;
  final bool isGuestMode;

  const ResultsOverlay({
    super.key,
    required this.verifiedDrugs,
    required this.onRescan,
    required this.onAddToCabinet,
    required this.onHighRiskOverride,
    required this.emergencyService,
    this.isGuestMode = false,
  });

  bool get _hasHighRiskWarning {
    return verifiedDrugs.any((result) => result.riskLevel == 'high');
  }

  @override
  State<ResultsOverlay> createState() => _ResultsOverlayState();
}

class _ResultsOverlayState extends State<ResultsOverlay>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  bool _medicalConsentGiven = false;
  double _longPressProgress = 0.0;
  bool _isLongPressing = false;
  bool _hasCaregiverLinked = false;
  String _caregiverName = '';

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget._hasHighRiskWarning) {
      _shakeController.repeat(reverse: true);
    }

    // Start the fade-in first, then slide
    _fadeController.forward();
    _slideController.forward();

    // Check if patient has linked caregivers
    _checkCaregiverStatus();
  }

  Future<void> _checkCaregiverStatus() async {
    try {
      final service = CaregiverNotificationService();
      final caregivers = await service.getLinkedCaregivers();
      if (mounted && caregivers.isNotEmpty) {
        setState(() {
          _hasCaregiverLinked = true;
          _caregiverName = caregivers.first['name'] as String? ?? 'Caregiver';
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isHighRisk = widget._hasHighRiskWarning;
    final bool hasMediumRisk = widget.verifiedDrugs.any(
      (r) => r.riskLevel == 'medium',
    );
    final bool hasLowRisk = widget.verifiedDrugs.any(
      (r) => r.riskLevel == 'low',
    );

    return Positioned.fill(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: isHighRisk ? const Color(0xFF0F0505) : AppColors.softWhite,
          ),
          child: Stack(
            children: [
              // 1. Dynamic Background Gradients
              _buildBackgroundGradients(isHighRisk, hasMediumRisk),

              SafeArea(
                child: Column(
                  children: [
                    // 2. Bold Immersive Header
                    _buildSafariHeader(context, isHighRisk),

                    Expanded(
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          children: [
                            // 3. Central Safety Status Card
                            _buildSafetyStatusCard(
                              isHighRisk,
                              hasMediumRisk,
                              hasLowRisk,
                            ),
                            const SizedBox(height: 24),

                            // 4. Drug Results List
                            ...widget.verifiedDrugs.map(
                              (result) =>
                                  _buildPremiumDrugCard(context, result),
                            ),

                            const SizedBox(
                              height: 120,
                            ), // Bottom padding for FAB
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 5. Floating Bottom Navigation
              _buildFloatingActions(context, isHighRisk),
            ],
          ),
        ),
      ),
    );
  }

  // ======================== BACKGROUND ========================

  Widget _buildBackgroundGradients(bool isHighRisk, bool hasMediumRisk) {
    return Stack(
      children: [
        Positioned(
          top: -200,
          right: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isHighRisk
                  ? Colors.red.withValues(alpha: 0.15)
                  : (hasMediumRisk
                        ? Colors.orange.withValues(alpha: 0.1)
                        : AppColors.primaryTeal.withValues(alpha: 0.08)),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isHighRisk
                  ? Colors.red.withValues(alpha: 0.1)
                  : AppColors.mintGreen.withValues(alpha: 0.05),
            ),
          ),
        ),
      ],
    );
  }

  // ======================== HEADER ========================

  Widget _buildSafariHeader(BuildContext context, bool isHighRisk) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: widget.onRescan,
                icon: Icon(
                  Icons.close_rounded,
                  color: isHighRisk ? Colors.white70 : AppColors.darkText,
                ),
              ),
              const Text(
                'PHARMACLASH VERIFY',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 3.0,
                  color: AppColors.mutedText,
                ),
              ),
              IconButton(
                onPressed: () {}, // Future info sheet
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: isHighRisk ? Colors.white70 : AppColors.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Safety Verification',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: isHighRisk ? Colors.white : AppColors.darkText,
              letterSpacing: -1.0,
            ),
          ),
          Text(
            '${widget.verifiedDrugs.length} items analyzed by Gemini AI',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isHighRisk ? Colors.red.shade200 : AppColors.grayText,
            ),
          ),
        ],
      ),
    );
  }

  // ======================== STATUS CARD ========================

  Widget _buildSafetyStatusCard(
    bool isHighRisk,
    bool isMediumRisk,
    bool isLowRisk,
  ) {
    final color = isHighRisk
        ? Colors.red
        : (isMediumRisk
              ? Colors.orange
              : (isLowRisk ? Colors.amber.shade700 : AppColors.accentGreen));
    final label = isHighRisk
        ? 'Critical Conflict'
        : (isMediumRisk ? 'Caution Required' : 'Safe to Proceed');
    final sub = isHighRisk
        ? 'Severe interactions or allergies detected.'
        : (isMediumRisk
              ? 'Minor clashes or food restrictions found.'
              : 'No conflicts found with your health profile.');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isHighRisk
            ? Colors.red.shade900.withValues(alpha: 0.3)
            : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isHighRisk
              ? Colors.red.withValues(alpha: 0.5)
              : AppColors.lightBorderColor.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isHighRisk
                        ? Icons.gpp_bad_rounded
                        : Icons.verified_user_rounded,
                    color: color,
                    size: 40,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            label,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isHighRisk ? Colors.white : AppColors.darkText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isHighRisk ? Colors.red.shade200 : AppColors.grayText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ======================== DRUG CARD ========================

  Widget _buildPremiumDrugCard(BuildContext context, DrugWarningResult result) {
    final config = _getCardConfig(result);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: widget._hasHighRiskWarning
            ? const Color(0xFF1E0A0A)
            : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: config.color.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Column(
          children: [
            // Clickable Header (Medicine Tab)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DrugDetailsScreen(drug: result.drug),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: config.color.withValues(alpha: 0.05),
                  border: Border(
                    bottom: BorderSide(
                      color: config.color.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: config.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(config.icon, color: config.color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.drug.matchedBrandName ??
                                result.drug.displayName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: widget._hasHighRiskWarning
                                  ? Colors.white
                                  : AppColors.darkText,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            result.drug.matchedBrandName != null
                                ? 'Generic: ${result.drug.displayName}'
                                : result.drug.category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: config.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: config.color.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (result.hasWarnings)
                    ...buildWarningsList(result, config)
                  else
                    _buildSafeIndicator(context, result.drug),

                  if (result.riskLevel == 'high')
                    _buildEmergencyAlertButton(context, result),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================== ACTIONS AREA ========================

  Widget _buildFloatingActions(BuildContext context, bool isHighRisk) {
    final bool hasAnyWarning = widget.verifiedDrugs.any((r) => r.hasWarnings);
    // Allow adding if no warnings OR if user gives explicit medical consent
    final bool canAdd = !hasAnyWarning || _medicalConsentGiven;

    // Guest mode: show sign-up CTA instead of add-to-cabinet
    if (widget.isGuestMode) {
      return _buildGuestSignUpCTA(context);
    }

    // For HIGH RISK: use escalated alerting design
    if (isHighRisk) {
      return _buildEscalatedActions(context);
    }

    // For non-high-risk: original flow
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasAnyWarning)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _medicalConsentGiven
                    ? AppColors.lightMint
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _medicalConsentGiven
                      ? AppColors.primaryTeal.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: InkWell(
                onTap: () => setState(
                  () => _medicalConsentGiven = !_medicalConsentGiven,
                ),
                child: Row(
                  children: [
                    Icon(
                      _medicalConsentGiven
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: _medicalConsentGiven
                          ? AppColors.primaryTeal
                          : Colors.orange.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'I have confirmed with my doctor that this is safe for me.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: widget.onRescan,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.inputBg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            color: AppColors.darkText,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'RESCAN',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              color: AppColors.darkText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: canAdd ? widget.onAddToCabinet : null,
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: canAdd ? 1.0 : 0.4,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: !canAdd
                                ? [Colors.grey.shade800, Colors.grey.shade900]
                                : [AppColors.primaryTeal, AppColors.deepTeal],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              !canAdd
                                  ? Icons.lock_rounded
                                  : Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              !canAdd ? 'LOCKED' : 'ADD TO CABINET',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======================== ESCALATED ALERTING ========================

  Widget _buildEscalatedActions(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Caregiver warning text
          if (_hasCaregiverLinked)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_rounded,
                    color: Colors.red.shade300,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'If you proceed, your caregiver $_caregiverName will be notified immediately.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade200,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2D0A0A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // "STOP & RESCAN" — large, green, primary
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: widget.onRescan,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade600,
                                Colors.green.shade800,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shield_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'STOP & RESCAN',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // "IGNORE & PROCEED" — small, red, long-press
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onLongPressStart: (_) => _startLongPress(),
                        onLongPressEnd: (_) => _cancelLongPress(),
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Progress overlay
                              if (_longPressProgress > 0)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: _longPressProgress,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade700.withValues(
                                            alpha: 0.6,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _isLongPressing ? 'HOLD...' : 'IGNORE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                        color: Colors.red.shade200,
                                      ),
                                    ),
                                    RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.red.shade300.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                        children: const [
                                          TextSpan(text: 'hold '),
                                          TextSpan(
                                            text: '3s',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
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
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startLongPress() {
    setState(() => _isLongPressing = true);
    _animateLongPress();
  }

  Future<void> _animateLongPress() async {
    const totalMs = 3000;
    const stepMs = 50;
    const steps = totalMs ~/ stepMs;

    for (int i = 0; i <= steps; i++) {
      if (!_isLongPressing || !mounted) return;
      await Future.delayed(const Duration(milliseconds: stepMs));
      if (!_isLongPressing || !mounted) return;
      setState(() => _longPressProgress = i / steps);
    }

    // Completed 3 seconds — trigger override
    if (mounted && _isLongPressing) {
      _isLongPressing = false;
      _longPressProgress = 0.0;
      await _triggerOverrideWithCaregiverAlert();
    }
  }

  void _cancelLongPress() {
    setState(() {
      _isLongPressing = false;
      _longPressProgress = 0.0;
    });
  }

  Future<void> _triggerOverrideWithCaregiverAlert() async {
    // Collect drug names from severe interactions
    final severeResults = widget.verifiedDrugs.where(
      (r) => r.riskLevel == 'high',
    );
    String drugA = '';
    String drugB = '';
    String description = '';

    for (final result in severeResults) {
      drugA = result.drug.displayName;
      if (result.matchedDrugInteractions.isNotEmpty) {
        drugB = result.matchedDrugInteractions.first.drugName;
        description = result.matchedDrugInteractions.first.description;
      } else if (result.matchedAllergies.isNotEmpty) {
        drugB = result.matchedAllergies.join(', ');
        description = 'Allergy match detected';
      }
      break;
    }

    // Send in-app caregiver alert (Firestore)
    if (_hasCaregiverLinked) {
      await CaregiverNotificationService().sendSevereOverrideAlert(
        drugA: drugA,
        drugB: drugB,
        severity: 'severe',
        interactionDescription: description,
      );
    }

    // ✅ Send AUTOMATIC email to caregiver — no user interaction needed
    final emailSent = await AutoEmailService().sendCaregiverOverrideAlert(
      drugA: drugA,
      drugB: drugB,
      interactionDescription: description,
    );
    debugPrint(
      emailSent
          ? '✅ Caregiver email sent automatically'
          : '⚠️ Caregiver email could not be sent',
    );

    // Proceed with adding to cabinet
    widget.onHighRiskOverride();
  }

  // ======================== REMAINING HELPERS ========================

  Widget _buildSafeIndicator(BuildContext context, DrugModel drug) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accentGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                color: AppColors.accentGreen,
                size: 28,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perfectly Compatible',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accentGreen,
                      ),
                    ),
                    Text(
                      'No personalized risks found.',
                      style: TextStyle(fontSize: 13, color: AppColors.grayText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> buildWarningsList(DrugWarningResult result, _CardConfig config) {
    final widgets = <Widget>[];

    // Priority 1: Drug Interactions
    if (result.matchedDrugInteractions.isNotEmpty) {
      for (final interaction in result.matchedDrugInteractions) {
        widgets.add(
          _buildClashWarningTile(
            icon: Icons.auto_fix_high_rounded,
            title: 'Interaction: ${interaction.drugName}',
            subtitle: interaction.description,
            severity: interaction.severity,
            color: interaction.severity == 'severe'
                ? Colors.red
                : Colors.orange,
          ),
        );
      }
    }

    // Priority 2: Direct Allergies
    if (result.matchedAllergies.isNotEmpty) {
      widgets.add(
        _buildClashWarningTile(
          icon: Icons.shield_rounded,
          title: 'Direct Allergy Match',
          subtitle:
              'Contains ${result.matchedAllergies.join(", ")} — matches your allergy profile.',
          severity: 'severe',
          color: Colors.red,
        ),
      );
    }

    // Priority 2.5: Class/Cross-Sensitivity
    if (result.matchedClassAllergies.isNotEmpty) {
      widgets.add(
        _buildClashWarningTile(
          icon: Icons.info_outline_rounded,
          title: 'Class Sensitivity',
          subtitle:
              'Contains ingredients related to: ${result.matchedClassAllergies.join(", ")}. Consult your doctor if you have a history of reactions to this class.',
          severity: 'caution',
          color: Colors.orange,
        ),
      );
    }

    // Priority 3: Conditions
    if (result.matchedConditions.isNotEmpty) {
      for (final condition in result.matchedConditions) {
        widgets.add(
          _buildClashWarningTile(
            icon: Icons.health_and_safety_rounded,
            title: 'Health Risk',
            subtitle: condition,
            severity: 'moderate',
            color: Colors.orange,
          ),
        );
      }
    }

    // Secondary: Food & Alcohol
    if (result.drug.foodInteractions.isNotEmpty ||
        result.drug.hasAlcoholWarning) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        const Text(
          'LIFESTYLE NOTES',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: AppColors.mutedText,
            letterSpacing: 1.5,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));

      for (final food in result.drug.foodInteractions) {
        widgets.add(
          _buildClashWarningTile(
            icon: Icons.restaurant_rounded,
            title: food.food,
            subtitle: food.description,
            severity: 'mild',
            color: Colors.amber.shade800,
          ),
        );
      }

      if (result.drug.hasAlcoholWarning) {
        widgets.add(
          _buildClashWarningTile(
            icon: Icons.local_bar_rounded,
            title: 'Alcohol Caution',
            subtitle:
                result.drug.alcoholWarningDescription ??
                'Avoid alcohol consumption.',
            severity: 'mild',
            color: Colors.amber.shade800,
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildClashWarningTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String severity,
    required Color color,
  }) {
    final isDark = widget._hasHighRiskWarning;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.darkText,
                        ),
                      ),
                    ),
                    Text(
                      severity.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : AppColors.grayText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyAlertButton(
    BuildContext context,
    DrugWarningResult result,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: InkWell(
        onTap: () {
          widget.emergencyService.showEmergencyOptions(
            context,
            drugName: result.drug.displayName,
            warningType: 'Allergy/Clash',
            details: [result.riskLevel],
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade600, Colors.red.shade800],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text(
              '🚨 CONTACT DOCTOR NOW',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ======================== GUEST SIGN-UP CTA ========================

  Widget _buildGuestSignUpCTA(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hook message
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.primaryTeal,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Want to track this medicine & get dose reminders?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                // Rescan button
                Expanded(
                  child: InkWell(
                    onTap: widget.onRescan,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.inputBg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            color: AppColors.darkText,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'RESCAN',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              color: AppColors.darkText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Sign Up CTA
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/register',
                        (route) => false,
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryTeal, AppColors.deepTeal],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryTeal.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_add_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'SIGN UP FREE',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
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
          ],
        ),
      ),
    );
  }
}

// ======================== CARD CONFIG ========================

class _CardConfig {
  final Color color;
  final IconData icon;
  final String label;

  const _CardConfig({
    required this.color,
    required this.icon,
    required this.label,
  });
}

_CardConfig _getCardConfig(DrugWarningResult result) {
  switch (result.riskLevel) {
    case 'high':
      return _CardConfig(
        color: Colors.red,
        icon: Icons.dangerous_rounded,
        label: 'HIGH RISK',
      );
    case 'medium':
      return _CardConfig(
        color: Colors.orange,
        icon: Icons.warning_rounded,
        label: 'CAUTION',
      );
    case 'low':
      return _CardConfig(
        color: Colors.amber.shade800,
        icon: Icons.info_outline_rounded,
        label: 'MILD WARNING',
      );
    default:
      return _CardConfig(
        color: AppColors.accentGreen,
        icon: Icons.check_circle_rounded,
        label: 'SAFE',
      );
  }
}
