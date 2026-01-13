import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase Service - Handles all Firebase Authentication and Firestore operations
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  // ==================== Authentication ====================

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  /// Sign up with email and password
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Sign out first to force account selection
      await _googleSignIn.signOut();

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Save user profile to Firestore if new user
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await saveUserProfile(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email ?? '',
          fullName: userCredential.user!.displayName ?? '',
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      // Check for specific Google Sign-In errors
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('developer_error') ||
          errorString.contains('sign_in_failed')) {
        throw 'Google Sign-In configuration error. Please check SHA-1 fingerprint in Firebase Console.';
      } else if (errorString.contains('network_error') ||
          errorString.contains('network')) {
        throw 'Network error. Please check your internet connection.';
      } else if (errorString.contains('canceled') ||
          errorString.contains('cancelled')) {
        return null; // User cancelled, return null silently
      }
      throw 'Google Sign-In failed. Please try again.';
    }
  }

  /// Sign out (including Google)
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Update user display name
  Future<void> updateDisplayName(String displayName) async {
    await _auth.currentUser?.updateDisplayName(displayName);
  }

  // ==================== Firestore - Users ====================

  /// Collection reference for users
  CollectionReference<Map<String, dynamic>> get usersCollection =>
      _firestore.collection('users');

  /// Save user profile to Firestore
  Future<void> saveUserProfile({
    required String uid,
    required String email,
    required String fullName,
    String? phone,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    await usersCollection.doc(uid).set({
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await usersCollection.doc(uid).get();
    return doc.data();
  }

  /// Update user profile in Firestore
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await usersCollection.doc(uid).update(data);
  }

  /// Stream user profile changes
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserProfile(String uid) {
    return usersCollection.doc(uid).snapshots();
  }

  // ==================== Firestore - Medical Info ====================

  /// Collection reference for medical info
  CollectionReference<Map<String, dynamic>> get medicalInfoCollection =>
      _firestore.collection('medical_info');

  /// Save medical info to Firestore
  Future<void> saveMedicalInfo({
    required String uid,
    required Map<String, dynamic> medicalData,
  }) async {
    await medicalInfoCollection.doc(uid).set({
      ...medicalData,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get medical info from Firestore
  Future<Map<String, dynamic>?> getMedicalInfo(String uid) async {
    final doc = await medicalInfoCollection.doc(uid).get();
    return doc.data();
  }

  /// Update medical info in Firestore
  Future<void> updateMedicalInfo(String uid, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await medicalInfoCollection.doc(uid).update(data);
  }

  /// Stream medical info changes
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamMedicalInfo(String uid) {
    return medicalInfoCollection.doc(uid).snapshots();
  }

  // ==================== Helper Methods ====================

  /// Handle Firebase Auth exceptions and return user-friendly messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
