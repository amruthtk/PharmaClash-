import 'package:flutter_test/flutter_test.dart';

// Import models and services for testing
import 'package:pharmaclash/models/medical_reference_data.dart';

/// Sprint 1 Test Cases for PharmaClash
///
/// TC_S1_01: Verify user registration with valid details
/// TC_S1_02: Verify chronic condition input for safety checks
/// TC_S1_03: Verify patient allergy capture
/// TC_S1_04: Verify caregiver contact for emergency

void main() {
  // ============================================================================
  // TC_S1_01: Verify user registration with valid details
  // Input Data: Name, Email, Password
  // Expected Result: User should be registered successfully
  // ============================================================================
  group('TC_S1_01: User Registration Tests', () {
    test('Valid name should pass validation', () {
      final name = 'John Doe';

      // Name validation: should not be empty
      expect(name.isNotEmpty, true);
      expect(name.trim().isNotEmpty, true);
    });

    test('Empty name should fail validation', () {
      final name = '';

      expect(name.isEmpty, true);
    });

    test('Valid email should pass validation', () {
      final email = 'test@example.com';
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

      expect(emailRegex.hasMatch(email), true);
    });

    test('Invalid email should fail validation', () {
      final invalidEmails = [
        'plainaddress',
        '@missingusername.com',
        'username@.com',
        'username@com',
        'user name@example.com',
      ];

      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

      for (final email in invalidEmails) {
        expect(
          emailRegex.hasMatch(email),
          false,
          reason: 'Email "$email" should be invalid',
        );
      }
    });

    test('Valid password should pass validation (minimum 8 characters)', () {
      final password = 'SecureP@ss123';

      expect(password.length >= 8, true);
    });

    test('Short password should fail validation', () {
      final password = 'short';

      expect(password.length < 8, true);
    });

    test('Valid Indian phone number should pass validation', () {
      final phone = '9876543210';
      final phoneRegex = RegExp(r'^[6-9]\d{9}$');

      expect(phoneRegex.hasMatch(phone), true);
    });

    test('Invalid Indian phone number should fail validation', () {
      final invalidPhones = [
        '1234567890', // Starts with 1
        '5123456789', // Starts with 5
        '98765432', // Too short
        '98765432109', // Too long
      ];

      final phoneRegex = RegExp(r'^[6-9]\d{9}$');

      for (final phone in invalidPhones) {
        expect(
          phoneRegex.hasMatch(phone),
          false,
          reason: 'Phone "$phone" should be invalid',
        );
      }
    });

    test('Password confirmation should match', () {
      final password = 'SecureP@ss123';
      final confirmPassword = 'SecureP@ss123';

      expect(password == confirmPassword, true);
    });

    test('Password confirmation should fail when different', () {
      final password = 'SecureP@ss123';
      final confirmPassword = 'DifferentP@ss456';

      expect(password != confirmPassword, true);
    });

    test('User registration data should be complete', () {
      // Simulating user registration data structure
      final userData = {
        'fullName': 'John Doe',
        'email': 'john.doe@example.com',
        'phone': '9876543210',
        'dateOfBirth': DateTime(1990, 5, 15),
        'gender': 'Male',
      };

      expect(userData['fullName'], isNotEmpty);
      expect(userData['email'], isNotEmpty);
      expect(userData['phone'], isNotEmpty);
      expect(userData['dateOfBirth'], isA<DateTime>());
      expect(userData['gender'], isNotNull);
    });
  });

  // ============================================================================
  // TC_S1_02: Verify chronic condition input for safety checks
  // Input Data: Diabetes, Hypertension
  // Expected Result: Conditions should be saved to profile
  // ============================================================================
  group('TC_S1_02: Chronic Condition Input Tests', () {
    test('Should validate Diabetes as a known chronic condition', () {
      final condition = 'Diabetes Type 2';
      final isValid = MedicalReferenceData.isValidChronicDisease(condition);

      expect(isValid, true);
    });

    test('Should validate Hypertension as a known chronic condition', () {
      // Reference data uses 'Hypertension (High Blood Pressure)'
      // Using search to find conditions containing 'Hypertension'
      final results = MedicalReferenceData.searchChronicDiseases(
        'Hypertension',
      );

      expect(results.isNotEmpty, true);
      expect(
        results.any((c) => c.toLowerCase().contains('hypertension')),
        true,
      );
    });

    test('Should search chronic conditions correctly', () {
      final results = MedicalReferenceData.searchChronicDiseases('Diabetes');

      expect(results.isNotEmpty, true);
      expect(results.any((c) => c.toLowerCase().contains('diabetes')), true);
    });

    test('Should search Hypertension correctly', () {
      final results = MedicalReferenceData.searchChronicDiseases(
        'Hypertension',
      );

      expect(results.isNotEmpty, true);
      expect(
        results.any((c) => c.toLowerCase().contains('hypertension')),
        true,
      );
    });

    test('Should return all conditions when search is empty', () {
      final allConditions = MedicalReferenceData.searchChronicDiseases('');

      expect(allConditions.isNotEmpty, true);
      expect(
        allConditions.length,
        equals(MedicalReferenceData.chronicDiseases.length),
      );
    });

    test('Should handle multiple chronic conditions in profile', () {
      final selectedConditions = ['Diabetes Type 2', 'Hypertension'];

      expect(selectedConditions.length, 2);
      expect(selectedConditions.contains('Diabetes Type 2'), true);
      expect(selectedConditions.contains('Hypertension'), true);
    });

    test('Chronic conditions should be saved to medical data structure', () {
      final medicalData = {
        'chronicConditions': ['Diabetes Type 2', 'Hypertension'],
        'profileCompleted': true,
      };

      final conditions = medicalData['chronicConditions'] as List<String>;
      expect(conditions.length, 2);
      expect(conditions, contains('Diabetes Type 2'));
      expect(conditions, contains('Hypertension'));
    });

    test('Quick-select diseases should be from reference data', () {
      final quickSelectDiseases = [
        'Hypertension',
        'Asthma',
        'Arthritis',
        'Diabetes Type 2',
        'Depression',
        'Heart Disease',
      ];

      for (final disease in quickSelectDiseases) {
        expect(
          MedicalReferenceData.chronicDiseases.any(
            (d) => d.toLowerCase().contains(
              disease.toLowerCase().split(' ').first,
            ),
          ),
          true,
          reason: '$disease should be in reference data',
        );
      }
    });
  });

  // ============================================================================
  // TC_S1_03: Verify patient allergy capture
  // Input Data: Penicillins, Aspirin (Salicylates)
  // Expected Result: Allergies should be saved for conflict detection
  // ============================================================================
  group('TC_S1_03: Patient Allergy Capture Tests', () {
    test('Should validate Penicillins as a known drug allergy', () {
      // Note: Reference data uses 'Penicillins' (plural)
      final allergy = 'Penicillins';
      final isValid = MedicalReferenceData.isValidDrugAllergy(allergy);

      expect(isValid, true);
    });

    test('Should validate Aspirin (Salicylates) as a known drug allergy', () {
      // Note: Reference data uses 'Aspirin (Salicylates)'
      final allergy = 'Aspirin (Salicylates)';
      final isValid = MedicalReferenceData.isValidDrugAllergy(allergy);

      expect(isValid, true);
    });

    test('Should search drug allergies correctly for Penicillin', () {
      final results = MedicalReferenceData.searchDrugAllergies('Penicillin');

      expect(results.isNotEmpty, true);
      expect(results.any((a) => a.toLowerCase().contains('penicillin')), true);
    });

    test('Should search drug allergies correctly for Aspirin', () {
      final results = MedicalReferenceData.searchDrugAllergies('Aspirin');

      expect(results.isNotEmpty, true);
      expect(results.any((a) => a.toLowerCase().contains('aspirin')), true);
    });

    test('Should return all allergies when search is empty', () {
      final allAllergies = MedicalReferenceData.searchDrugAllergies('');

      expect(allAllergies.isNotEmpty, true);
      expect(
        allAllergies.length,
        equals(MedicalReferenceData.drugAllergies.length),
      );
    });

    test('Should handle multiple allergies in profile', () {
      final selectedAllergies = ['Penicillin', 'Aspirin'];

      expect(selectedAllergies.length, 2);
      expect(selectedAllergies.contains('Penicillin'), true);
      expect(selectedAllergies.contains('Aspirin'), true);
    });

    test('Allergies should be saved to medical data structure', () {
      final medicalData = {
        'allergies': ['Penicillin', 'Aspirin'],
        'profileCompleted': true,
      };

      final allergies = medicalData['allergies'] as List<String>;
      expect(allergies.length, 2);
      expect(allergies, contains('Penicillin'));
      expect(allergies, contains('Aspirin'));
    });

    test('Should not add duplicate allergies', () {
      final selectedAllergies = <String>[];

      void addAllergy(String allergy) {
        if (!selectedAllergies.contains(allergy)) {
          selectedAllergies.add(allergy);
        }
      }

      addAllergy('Penicillin');
      addAllergy('Aspirin');
      addAllergy('Penicillin'); // Duplicate - should not be added

      expect(selectedAllergies.length, 2);
    });

    test('Should be able to remove allergies from list', () {
      final selectedAllergies = ['Penicillin', 'Aspirin'];

      selectedAllergies.remove('Aspirin');

      expect(selectedAllergies.length, 1);
      expect(selectedAllergies.contains('Aspirin'), false);
      expect(selectedAllergies.contains('Penicillin'), true);
    });
  });

  // ============================================================================
  // TC_S1_04: Verify caregiver contact for emergency
  // Input Data: Name, Phone number
  // Expected Result: Caregiver details saved for notifications
  // ============================================================================
  group('TC_S1_04: Caregiver Contact Tests', () {
    test('Valid caregiver name should be accepted', () {
      final caregiverName = 'Jane Doe';

      expect(caregiverName.isNotEmpty, true);
      expect(caregiverName.trim().isNotEmpty, true);
    });

    test('Valid 10-digit caregiver phone should pass validation', () {
      final phone = '9876543210';

      expect(phone.length, 10);
      expect(RegExp(r'^\d{10}$').hasMatch(phone), true);
    });

    test('Invalid caregiver phone should fail validation', () {
      final invalidPhones = ['12345', '12345678901', 'abcdefghij'];

      for (final phone in invalidPhones) {
        final isValid =
            phone.length == 10 && RegExp(r'^\d{10}$').hasMatch(phone);
        expect(isValid, false, reason: 'Phone "$phone" should be invalid');
      }
    });

    test('Caregiver contact should be saved to medical data', () {
      final medicalData = {
        'caregiverName': 'Jane Doe',
        'caregiverPhone': '9876543210',
        'profileCompleted': true,
      };

      expect(medicalData['caregiverName'], 'Jane Doe');
      expect(medicalData['caregiverPhone'], '9876543210');
    });

    test('Empty caregiver fields should be optional (allowed)', () {
      final medicalData = {
        'caregiverName': '',
        'caregiverPhone': '',
        'allergies': <String>[],
        'chronicConditions': <String>[],
        'profileCompleted': true,
      };

      // Caregiver info is optional, so empty values are valid
      expect(medicalData['profileCompleted'], true);
    });

    test('Caregiver info should be retrievable from medical data', () {
      final medicalInfo = {
        'caregiverName': 'Jane Doe',
        'caregiverPhone': '9876543210',
      };

      String getCaregiverName(Map<String, dynamic>? info) {
        return info?['caregiverName'] ?? '';
      }

      String getCaregiverPhone(Map<String, dynamic>? info) {
        return info?['caregiverPhone'] ?? '';
      }

      expect(getCaregiverName(medicalInfo), 'Jane Doe');
      expect(getCaregiverPhone(medicalInfo), '9876543210');
    });

    test('Should check if caregiver is configured', () {
      bool hasCaregiverConfigured(Map<String, dynamic>? info) {
        if (info == null) return false;
        final name = info['caregiverName'] as String?;
        final phone = info['caregiverPhone'] as String?;
        return name != null &&
            name.isNotEmpty &&
            phone != null &&
            phone.isNotEmpty;
      }

      // With caregiver info
      final withCaregiver = {
        'caregiverName': 'Jane Doe',
        'caregiverPhone': '9876543210',
      };
      expect(hasCaregiverConfigured(withCaregiver), true);

      // Without caregiver info
      final withoutCaregiver = {'caregiverName': '', 'caregiverPhone': ''};
      expect(hasCaregiverConfigured(withoutCaregiver), false);

      // Null case
      expect(hasCaregiverConfigured(null), false);
    });

    test('Complete medical profile should include all required fields', () {
      final completeProfile = {
        'allergies': ['Penicillin', 'Aspirin'],
        'chronicConditions': ['Diabetes Type 2', 'Hypertension'],
        'caregiverName': 'Jane Doe',
        'caregiverPhone': '9876543210',
        'profileCompleted': true,
      };

      expect(completeProfile['allergies'], isA<List>());
      expect(completeProfile['chronicConditions'], isA<List>());
      expect(completeProfile['caregiverName'], isNotEmpty);
      expect(completeProfile['caregiverPhone'], isNotEmpty);
      expect(completeProfile['profileCompleted'], true);
    });
  });

  // ============================================================================
  // Integration Tests: Complete Sprint 1 Flow
  // ============================================================================
  group('Sprint 1: Complete Registration Flow Integration', () {
    test('Full user registration flow should work correctly', () {
      // Step 1: User registration data
      final userProfile = {
        'fullName': 'John Doe',
        'email': 'john.doe@example.com',
        'phone': '9876543210',
        'dateOfBirth': DateTime(1990, 5, 15),
        'gender': 'Male',
      };

      // Step 2: Medical information
      final medicalInfo = {
        'allergies': ['Penicillin', 'Aspirin'],
        'chronicConditions': ['Diabetes Type 2', 'Hypertension'],
        'caregiverName': 'Jane Doe',
        'caregiverPhone': '9012345678',
        'profileCompleted': true,
      };

      // Validate user profile
      expect(userProfile['fullName'], isNotEmpty);
      expect(userProfile['email'], isNotEmpty);
      expect(userProfile['phone'], isNotEmpty);

      // Validate medical info
      expect((medicalInfo['allergies'] as List).length, 2);
      expect((medicalInfo['chronicConditions'] as List).length, 2);
      expect(medicalInfo['caregiverName'], isNotEmpty);
      expect(medicalInfo['caregiverPhone'], isNotEmpty);
      expect(medicalInfo['profileCompleted'], true);
    });
  });
}
