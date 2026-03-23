import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'screens/registration_screen.dart';
import 'screens/medical_info_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/caregiver_setup_screen.dart';
import 'screens/caregiver_notifications_screen.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/biometric_service.dart';
import 'screens/biometric_lock_screen.dart';

import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (required before app starts)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firestore offline persistence with larger cache
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize Notification Service in background (non-blocking)
  NotificationService().initialize();

  // Create Android notification channels for caregiver alerts
  await _createNotificationChannels();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const HealthTrackerApp());
}

/// Create Android notification channels for caregiver emergency alerts.
/// FCM needs these channels to exist BEFORE a push arrives.
Future<void> _createNotificationChannels() async {
  final plugin = FlutterLocalNotificationsPlugin();
  final androidPlugin = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  if (androidPlugin != null) {
    // Emergency channel — max priority, bypasses DND
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'caregiver_emergency',
        'Emergency Alerts',
        description: 'Emergency alerts for severe drug interaction overrides',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Standard caregiver channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'caregiver_alerts',
        'Caregiver Alerts',
        description: 'Notifications for missed doses and caregiver updates',
        importance: Importance.high,
        playSound: true,
      ),
    );

    // Nightly missed dose "last call" channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'nightly_dose_check',
        'Nightly Dose Check',
        description: 'Nightly reminder to confirm all doses were taken',
        importance: Importance.high,
        playSound: true,
      ),
    );
  }
}

class HealthTrackerApp extends StatelessWidget {
  const HealthTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: AppColors.softWhite,
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.primaryTeal,
              width: 2,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryTeal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/medical-info': (context) => const MedicalInfoScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/caregiver-setup': (context) => const CaregiverSetupScreen(),
        '/caregiver-notifications': (context) =>
            const CaregiverNotificationsScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryTeal),
            ),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;

          // Anonymous users stay on the splash screen — they are guests
          if (user.isAnonymous) {
            return const SplashScreen();
          }

          // Check if user has a profile in Firestore AND if biometrics are needed
          return FutureBuilder<Map<String, dynamic>>(
            future: _getInitialData(user),
            builder: (context, dataSnapshot) {
              if (dataSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryTeal,
                    ),
                  ),
                );
              }

              if (dataSnapshot.hasError) {
                return Scaffold(
                  body: Center(child: Text('Error: ${dataSnapshot.error}')),
                );
              }

              final profile =
                  dataSnapshot.data?['profile'] as Map<String, dynamic>?;
              final isBioEnabled = dataSnapshot.data?['isBioEnabled'] == true;

              if (profile == null || profile['email'] == null) {
                return const RegistrationScreen();
              }

              // ENFORCE BIOMETRIC LOCK
              // If biometrics enabled but not unlocked for this session, show lock screen
              if (isBioEnabled && !BiometricService.isSessionUnlocked) {
                return const BiometricLockScreen();
              }

              // Check if user is admin
              final isAdmin = profile['isAdmin'] == true;

              if (isAdmin) {
                return const AdminDashboardScreen();
              }

              return const DashboardScreen();
            },
          );
        }

        return const SplashScreen();
      },
    );
  }

  /// Get both profile and biometric status.
  /// If no profile found for UID, try searching by email for unification.
  Future<Map<String, dynamic>> _getInitialData(User user) async {
    Map<String, dynamic>? profile = await _getProfileFast(user.uid);

    // UNIFICATION LOGIC:
    // If we have NO profile for this UID, but a profile exists with this EMAIL,
    // we "adopt" that profile for this new sign-in method.
    if (profile == null && user.email != null) {
      profile = await _findExistingProfileByEmail(user.email!);
      
      // If found, "unify" it — save it back to Firestore under this UID
      if (profile != null) {
        await FirebaseService().saveUserProfile(
          uid: user.uid,
          email: profile['email'] ?? user.email!,
          fullName: profile['fullName'] ?? user.displayName ?? '',
          dateOfBirth: profile['dateOfBirth'] != null ? DateTime.parse(profile['dateOfBirth']) : null,
          gender: profile['gender'],
          isAdmin: profile['isAdmin'], // Preserve admin status
        );
        // Refresh local profile
        profile = await FirebaseService().getUserProfile(user.uid);
      }
    }

    final isBioEnabled = await BiometricService().isBiometricEnabled();
    return {'profile': profile, 'isBioEnabled': isBioEnabled};
  }

  /// Search for any user document with a matching email
  Future<Map<String, dynamic>?> _findExistingProfileByEmail(String email) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    
    if (query.docs.isNotEmpty) {
      return query.docs.first.data();
    }
    return null;
  }

  /// Try cache first for faster profile loading, fallback to server
  Future<Map<String, dynamic>?> _getProfileFast(String uid) async {
    try {
      final cachedDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.cache));
      if (cachedDoc.exists) return cachedDoc.data();
    } catch (_) {}
    return FirebaseService().getUserProfile(uid);
  }
}
