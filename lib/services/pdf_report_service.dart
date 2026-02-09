import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_medicine_model.dart';
import '../models/dose_log_model.dart';

/// Service for generating PDF reports for doctors
class PdfReportService {
  /// Generate and share a PDF report
  static Future<void> generateAndShareReport({
    required BuildContext context,
    required String userName,
    dynamic dateOfBirth,
    required List<String> allergies,
    required List<String> conditions,
    required List<UserMedicine> medicines,
    required List<DoseLog> doseLogs,
  }) async {
    final pdf = pw.Document();

    // Filter to last 30 days
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final recentLogs = doseLogs
        .where((log) => log.takenAt.isAfter(thirtyDaysAgo))
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(userName, dateOfBirth),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Medical Profile Section
          _buildSection('Medical Profile'),
          _buildTextItem(
            'Allergies',
            allergies.isEmpty ? 'None reported' : allergies.join(', '),
          ),
          _buildTextItem(
            'Chronic Conditions',
            conditions.isEmpty ? 'None reported' : conditions.join(', '),
          ),
          pw.SizedBox(height: 20),

          // Current Medications Section
          _buildSection('Current Medications'),
          if (medicines.isEmpty)
            pw.Text(
              'No medications in cabinet',
              style: const pw.TextStyle(fontSize: 12),
            )
          else
            _buildMedicationsTable(medicines),
          pw.SizedBox(height: 20),

          // Dose History Section
          _buildSection('Dose History (Last 30 Days)'),
          if (recentLogs.isEmpty)
            pw.Text(
              'No doses logged in the last 30 days',
              style: const pw.TextStyle(fontSize: 12),
            )
          else
            _buildDoseHistoryTable(recentLogs),
        ],
      ),
    );

    // Show print/share dialog
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'medication_report_${DateTime.now().toIso8601String().split('T')[0]}.pdf',
    );
  }

  static pw.Widget _buildHeader(String userName, dynamic dateOfBirth) {
    String dobString = 'N/A';
    if (dateOfBirth != null) {
      try {
        if (dateOfBirth is String) {
          final dob = DateTime.parse(dateOfBirth);
          dobString = '${dob.day}/${dob.month}/${dob.year}';
        } else if (dateOfBirth is Timestamp) {
          final dob = dateOfBirth.toDate();
          dobString = '${dob.day}/${dob.month}/${dob.year}';
        }
      } catch (_) {}
    }

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '💊 PharmaClash',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal700,
                ),
              ),
              pw.Text(
                'Medical Report',
                style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Patient Name: $userName',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Date of Birth: $dobString',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Report Date:',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    _formatDate(DateTime.now()),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
      ),
    );
  }

  static pw.Widget _buildSection(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.teal800,
        ),
      ),
    );
  }

  static pw.Widget _buildTextItem(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMedicationsTable(List<UserMedicine> medicines) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellPadding: const pw.EdgeInsets.all(6),
      headers: ['Medicine', 'Category', 'Doses/Day', 'Stock', 'Expiry'],
      data: medicines
          .map(
            (med) => [
              med.medicineName,
              med.category ?? 'N/A',
              '${med.dosesPerDay}x daily',
              '${med.tabletCount} tabs',
              med.expiryDate != null ? _formatDate(med.expiryDate!) : 'N/A',
            ],
          )
          .toList(),
    );
  }

  static pw.Widget _buildDoseHistoryTable(List<DoseLog> logs) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellPadding: const pw.EdgeInsets.all(6),
      headers: ['Date', 'Time', 'Medicine', 'Quantity'],
      data: logs
          .map(
            (log) => [
              log.formattedDate,
              log.formattedTakenTime,
              log.medicineName,
              '${log.quantityTaken} tablet${log.quantityTaken > 1 ? 's' : ''}',
            ],
          )
          .toList(),
    );
  }

  static String _formatDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
