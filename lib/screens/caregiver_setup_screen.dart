import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/caregiver_notification_service.dart';
import '../theme/app_colors.dart';

/// Screen for linking caregivers and patients.
/// Patients generate a code; caregivers enter it.
class CaregiverSetupScreen extends StatefulWidget {
  const CaregiverSetupScreen({super.key});

  @override
  State<CaregiverSetupScreen> createState() => _CaregiverSetupScreenState();
}

class _CaregiverSetupScreenState extends State<CaregiverSetupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = CaregiverNotificationService();

  // Patient tab
  String? _linkCode;
  bool _generatingCode = false;
  List<Map<String, dynamic>> _linkedCaregivers = [];
  bool _missedDoseEnabled = false;

  // Caregiver tab
  final _codeController = TextEditingController();
  bool _redeeming = false;
  List<Map<String, dynamic>> _linkedPatients = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _service.getLinkedCaregivers(),
        _service.getLinkedPatients(),
        _service.getMissedDoseAlerts(),
      ]);
      if (mounted) {
        setState(() {
          _linkedCaregivers = results[0] as List<Map<String, dynamic>>;
          _linkedPatients = results[1] as List<Map<String, dynamic>>;
          _missedDoseEnabled = results[2] as bool;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateCode() async {
    setState(() => _generatingCode = true);
    final code = await _service.generateLinkCode();
    if (mounted) {
      setState(() {
        _linkCode = code;
        _generatingCode = false;
      });
      if (code == null) {
        _showSnackBar(
          'Failed to generate code. Please check your connection.',
          isError: true,
        );
      }
    }
  }

  Future<void> _redeemCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showSnackBar('Please enter a valid 6-digit code', isError: true);
      return;
    }

    setState(() => _redeeming = true);
    final result = await _service.redeemLinkCode(code);
    if (mounted) {
      setState(() => _redeeming = false);
      if (result != null) {
        _codeController.clear();
        _showSnackBar('You are now ${result['patientName']}\'s caregiver! 🎉');
        _loadData();
      } else {
        _showSnackBar('Invalid or expired code', isError: true);
      }
    }
  }

  Future<void> _unlinkCaregiver(String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Unlink Caregiver',
          style: TextStyle(color: AppColors.lightText),
        ),
        content: Text(
          'This caregiver will no longer receive your alerts.',
          style: TextStyle(color: AppColors.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.unlinkCaregiver(uid);
      _showSnackBar('Caregiver unlinked');
      _loadData();
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade600 : AppColors.primaryTeal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Caregiver Setup',
          style: TextStyle(
            color: AppColors.lightText,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryTeal,
          labelColor: AppColors.mintGreen,
          unselectedLabelColor: AppColors.mutedText,
          tabs: const [
            Tab(text: "I'm a Patient"),
            Tab(text: "I'm a Caregiver"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primaryTeal),
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildPatientTab(), _buildCaregiverTab()],
            ),
    );
  }

  // ────────────────────── PATIENT TAB ──────────────────────

  Widget _buildPatientTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Generate code section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.link_rounded,
                  color: AppColors.primaryTeal,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  'Link a Caregiver',
                  style: TextStyle(
                    color: AppColors.lightText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate a 6-digit code and share it with your caregiver. They\'ll enter it in their app to link accounts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (_linkCode != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryTeal),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _linkCode!,
                          style: TextStyle(
                            color: AppColors.mintGreen,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _linkCode!));
                            _showSnackBar('Code copied!');
                          },
                          icon: Icon(
                            Icons.copy_rounded,
                            color: AppColors.mintGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Expires in 15 minutes',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 11),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _generatingCode ? null : _generateCode,
                      icon: _generatingCode
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.vpn_key_rounded),
                      label: Text(
                        _generatingCode ? 'Generating...' : 'Generate Code',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Missed dose toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.amber,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Missed Dose Alerts',
                        style: TextStyle(
                          color: AppColors.lightText,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Notify caregiver if a dose is overdue by 2+ hours',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _missedDoseEnabled,
                  onChanged: (val) {
                    setState(() => _missedDoseEnabled = val);
                    _service.setMissedDoseAlerts(val);
                  },
                  activeThumbColor: AppColors.primaryTeal,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Linked caregivers
          Text(
            'Linked Caregivers',
            style: TextStyle(
              color: AppColors.lightText,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_linkedCaregivers.isEmpty)
            _buildEmptyCard(
              'No caregivers linked yet',
              Icons.people_outline_rounded,
            )
          else
            ..._linkedCaregivers.map(
              (c) => _buildLinkedUserTile(
                name: c['name'],
                email: c['email'],
                onRemove: () => _unlinkCaregiver(c['uid']),
              ),
            ),
        ],
      ),
    );
  }

  // ────────────────────── CAREGIVER TAB ──────────────────────

  Widget _buildCaregiverTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enter code section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.primaryTeal,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter Patient\'s Code',
                  style: TextStyle(
                    color: AppColors.lightText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ask the patient to generate a link code from their app, then enter it below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: TextStyle(
                    color: AppColors.lightText,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: TextStyle(
                      color: AppColors.mutedText.withValues(alpha: 0.3),
                      letterSpacing: 8,
                    ),
                    filled: true,
                    fillColor: AppColors.darkBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryTeal),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _redeeming ? null : _redeemCode,
                    icon: _redeeming
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.link_rounded),
                    label: Text(_redeeming ? 'Linking...' : 'Link Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Linked patients
          Text(
            'Your Patients',
            style: TextStyle(
              color: AppColors.lightText,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_linkedPatients.isEmpty)
            _buildEmptyCard(
              'No patients linked yet',
              Icons.person_search_rounded,
            )
          else
            ..._linkedPatients.map(
              (p) => _buildLinkedUserTile(
                name: p['name'],
                email: p['email'],
                isPatient: true,
              ),
            ),

          if (_linkedPatients.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/caregiver-notifications');
                },
                icon: Icon(
                  Icons.notifications_rounded,
                  color: AppColors.mintGreen,
                ),
                label: Text(
                  'View Alert History',
                  style: TextStyle(color: AppColors.mintGreen),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primaryTeal),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ────────────────────── SHARED WIDGETS ──────────────────────

  Widget _buildEmptyCard(String text, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.mutedText, size: 36),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(color: AppColors.mutedText, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedUserTile({
    required String name,
    required String email,
    VoidCallback? onRemove,
    bool isPatient = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryTeal.withValues(alpha: 0.2),
            child: Icon(
              isPatient
                  ? Icons.person_rounded
                  : Icons.health_and_safety_rounded,
              color: AppColors.mintGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: AppColors.lightText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  email,
                  style: TextStyle(color: AppColors.mutedText, fontSize: 11),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: Icon(
                Icons.link_off_rounded,
                color: Colors.red.shade300,
                size: 20,
              ),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
