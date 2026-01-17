import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/registration_screen.dart';
import 'screens/medical_info_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'services/firebase_service.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const HealthTrackerApp());
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
          // Check if user has a profile in Firestore
          return FutureBuilder<Map<String, dynamic>?>(
            future: FirebaseService().getUserProfile(user.uid),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryTeal,
                    ),
                  ),
                );
              }

              if (profileSnapshot.hasError) {
                return Scaffold(
                  body: Center(child: Text('Error: ${profileSnapshot.error}')),
                );
              }

              // If no profile found (meaning they just signed up via Google and didn't finish registration)
              // or if critical fields like phone/DOB are missing
              final profile = profileSnapshot.data;

              // Debug logging
              debugPrint('=== AUTH WRAPPER DEBUG ===');
              debugPrint('Profile: $profile');
              debugPrint('isAdmin value: ${profile?['isAdmin']}');
              debugPrint('isAdmin type: ${profile?['isAdmin']?.runtimeType}');

              if (profile == null || profile['phone'] == null) {
                return const RegistrationScreen();
              }

              // Check if user is admin
              final isAdmin = profile['isAdmin'] == true;
              debugPrint('isAdmin check result: $isAdmin');

              if (isAdmin) {
                debugPrint('>>> Routing to ADMIN DASHBOARD');
                return const AdminDashboardScreen();
              }

              debugPrint('>>> Routing to USER DASHBOARD');
              return const DashboardScreen();
            },
          );
        }

        return const SplashScreen();
      },
    );
  }
}
