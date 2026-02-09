import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric Authentication Service
/// Handles enabling/disabling biometric login and secure credential storage
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Storage keys
  static const String _emailKey = 'biometric_email';
  static const String _passwordKey = 'biometric_password';
  static const String _biometricEnabledKey = 'biometric_enabled';

  /// Check if device supports biometrics
  Future<bool> canUseBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      debugPrint('Biometrics check failed: $e');
      return false;
    }
  }

  /// Check if biometrics is enabled for this user
  Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _secureStorage.read(key: _biometricEnabledKey);
      return enabled == 'true';
    } catch (e) {
      debugPrint('Error checking biometric status: $e');
      return false;
    }
  }

  /// Enable biometric login and store credentials securely
  /// Set [skipVerification] to true to store credentials without biometric prompt
  Future<bool> enableBiometricLogin({
    required String email,
    required String password,
    bool skipVerification = false,
  }) async {
    try {
      if (!skipVerification) {
        // First authenticate to confirm user identity
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Verify your identity to enable biometric login',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false, // Allow PIN/pattern as fallback
          ),
        );

        if (!authenticated) {
          debugPrint('Biometric authentication was cancelled or failed');
          return false;
        }
      }

      // Store credentials securely
      await _secureStorage.write(key: _emailKey, value: email);
      await _secureStorage.write(key: _passwordKey, value: password);
      await _secureStorage.write(key: _biometricEnabledKey, value: 'true');

      debugPrint('Biometric login enabled successfully');
      return true;
    } catch (e) {
      debugPrint('Error enabling biometric login: $e');
      return false;
    }
  }

  /// Disable biometric login and clear stored credentials
  Future<bool> disableBiometricLogin() async {
    try {
      await _secureStorage.delete(key: _emailKey);
      await _secureStorage.delete(key: _passwordKey);
      await _secureStorage.write(key: _biometricEnabledKey, value: 'false');
      return true;
    } catch (e) {
      debugPrint('Error disabling biometric login: $e');
      return false;
    }
  }

  /// Authenticate with biometrics and return stored credentials
  Future<Map<String, String>?> authenticateAndGetCredentials() async {
    try {
      // Check if biometric is enabled
      final isEnabled = await isBiometricEnabled();
      if (!isEnabled) {
        return null;
      }

      // Authenticate
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan your fingerprint or use Face ID to login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!authenticated) {
        return null;
      }

      // Retrieve stored credentials
      final email = await _secureStorage.read(key: _emailKey);
      final password = await _secureStorage.read(key: _passwordKey);

      if (email != null && password != null) {
        return {'email': email, 'password': password};
      }

      return null;
    } catch (e) {
      debugPrint('Error during biometric authentication: $e');
      return null;
    }
  }

  /// Check if credentials are stored for biometric login
  Future<bool> hasStoredCredentials() async {
    try {
      final email = await _secureStorage.read(key: _emailKey);
      final password = await _secureStorage.read(key: _passwordKey);
      return email != null && password != null;
    } catch (e) {
      debugPrint('Error checking stored credentials: $e');
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }
}
