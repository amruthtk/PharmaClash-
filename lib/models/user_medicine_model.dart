import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a medicine in the user's personal cabinet with expiry tracking
class UserMedicine {
  final String? id;
  final String drugId; // Reference to DrugModel in drugs collection
  final String medicineName; // Display name for quick access
  final String? category; // Drug category (e.g., "NSAID", "Antibiotic")
  final DateTime? expiryDate; // Month/Year expiry (set to 1st of month)
  final int tabletCount; // Current stock quantity
  final DateTime addedAt;
  final DateTime? updatedAt;
  final bool expiryAlertShown; // Track if first-time modal was shown

  // Dose scheduling fields
  final int dosesPerDay; // 1, 2, 3, or 4 times per day
  final List<String> scheduleTimes; // e.g., ["08:00", "20:00"]

  // Food/dietary warnings for pre-dose confirmation
  final List<String>
  foodWarnings; // e.g., ["Avoid alcohol", "Take 2hrs from dairy"]

  UserMedicine({
    this.id,
    required this.drugId,
    required this.medicineName,
    this.category,
    this.expiryDate,
    this.tabletCount = 0,
    DateTime? addedAt,
    this.updatedAt,
    this.expiryAlertShown = false,
    this.dosesPerDay = 1,
    this.scheduleTimes = const [],
    this.foodWarnings = const [],
  }) : addedAt = addedAt ?? DateTime.now();

  // ==================== Expiry Status Computed Properties ====================

  /// Check if medicine is expired (past current date)
  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  /// Check if medicine is expiring within 30 days
  bool get isExpiringSoon =>
      expiryDate != null &&
      !isExpired &&
      expiryDate!.difference(DateTime.now()).inDays <= 30;

  /// Days remaining until expiry (negative if expired)
  int get daysUntilExpiry => expiryDate != null
      ? expiryDate!.difference(DateTime.now()).inDays
      : 999; // No expiry set

  /// Check if stock is low (5 or fewer tablets)
  bool get isLowStock => tabletCount <= 5;

  /// Human-readable expiry status
  String get expiryStatusText {
    if (expiryDate == null) return 'No expiry set';
    if (isExpired) return 'Expired';
    if (isExpiringSoon) return 'Expiring in $daysUntilExpiry days';
    return 'Valid';
  }

  /// Formatted expiry date string (e.g., "Jan 2027")
  String get formattedExpiryDate {
    if (expiryDate == null) return 'Not set';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[expiryDate!.month - 1]} ${expiryDate!.year}';
  }

  // ==================== Firestore Serialization ====================

  Map<String, dynamic> toMap() {
    return {
      'drugId': drugId,
      'medicineName': medicineName,
      'category': category,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'tabletCount': tabletCount,
      'addedAt': Timestamp.fromDate(addedAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'expiryAlertShown': expiryAlertShown,
      'dosesPerDay': dosesPerDay,
      'scheduleTimes': scheduleTimes,
      'foodWarnings': foodWarnings,
    };
  }

  factory UserMedicine.fromMap(Map<String, dynamic> map, String id) {
    return UserMedicine(
      id: id,
      drugId: map['drugId'] ?? '',
      medicineName: map['medicineName'] ?? '',
      category: map['category'],
      expiryDate: (map['expiryDate'] as Timestamp?)?.toDate(),
      tabletCount: map['tabletCount'] ?? 0,
      addedAt: (map['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      expiryAlertShown: map['expiryAlertShown'] ?? false,
      dosesPerDay: map['dosesPerDay'] ?? 1,
      scheduleTimes: List<String>.from(map['scheduleTimes'] ?? []),
      foodWarnings: List<String>.from(map['foodWarnings'] ?? []),
    );
  }

  // ==================== Copy With ====================

  UserMedicine copyWith({
    String? id,
    String? drugId,
    String? medicineName,
    String? category,
    DateTime? expiryDate,
    int? tabletCount,
    DateTime? addedAt,
    DateTime? updatedAt,
    bool? expiryAlertShown,
    int? dosesPerDay,
    List<String>? scheduleTimes,
    List<String>? foodWarnings,
  }) {
    return UserMedicine(
      id: id ?? this.id,
      drugId: drugId ?? this.drugId,
      medicineName: medicineName ?? this.medicineName,
      category: category ?? this.category,
      expiryDate: expiryDate ?? this.expiryDate,
      tabletCount: tabletCount ?? this.tabletCount,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiryAlertShown: expiryAlertShown ?? this.expiryAlertShown,
      dosesPerDay: dosesPerDay ?? this.dosesPerDay,
      scheduleTimes: scheduleTimes ?? this.scheduleTimes,
      foodWarnings: foodWarnings ?? this.foodWarnings,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserMedicine &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserMedicine(name: $medicineName, expiry: $formattedExpiryDate, count: $tabletCount)';
  }
}
