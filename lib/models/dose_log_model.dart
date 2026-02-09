import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a logged dose when user marks medicine as taken
class DoseLog {
  final String? id;
  final String medicineId; // Reference to UserMedicine
  final String medicineName; // Denormalized for quick display
  final DateTime takenAt; // When the user marked dose as taken
  final String? scheduledTime; // "08:00" - which dose slot this was for
  final int quantityTaken; // Number of tablets taken (1, 2, 3)

  DoseLog({
    this.id,
    required this.medicineId,
    required this.medicineName,
    required this.takenAt,
    this.scheduledTime,
    this.quantityTaken = 1,
  });

  // ==================== Firestore Serialization ====================

  Map<String, dynamic> toMap() {
    return {
      'medicineId': medicineId,
      'medicineName': medicineName,
      'takenAt': Timestamp.fromDate(takenAt),
      'scheduledTime': scheduledTime,
      'quantityTaken': quantityTaken,
    };
  }

  factory DoseLog.fromMap(Map<String, dynamic> map, String id) {
    return DoseLog(
      id: id,
      medicineId: map['medicineId'] ?? '',
      medicineName: map['medicineName'] ?? '',
      takenAt: (map['takenAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scheduledTime: map['scheduledTime'],
      quantityTaken: map['quantityTaken'] ?? 1,
    );
  }

  // ==================== Helper Methods ====================

  /// Format taken time for display (e.g., "2:30 PM")
  String get formattedTakenTime {
    final hour = takenAt.hour;
    final minute = takenAt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Format date for display (e.g., "Jan 28, 2026")
  String get formattedDate {
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
    return '${months[takenAt.month - 1]} ${takenAt.day}, ${takenAt.year}';
  }

  /// Check if this dose was taken today
  bool get isTakenToday {
    final now = DateTime.now();
    return takenAt.year == now.year &&
        takenAt.month == now.month &&
        takenAt.day == now.day;
  }

  @override
  String toString() {
    return 'DoseLog($medicineName x$quantityTaken at $formattedTakenTime)';
  }
}
