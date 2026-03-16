import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';
import '../../../models/drug_model.dart';
import '../../../services/drug_service.dart';

/// Result of OCR processing
class OcrResult {
  final List<DrugModel> matchedDrugs;
  final String rawText;
  OcrResult({required this.matchedDrugs, required this.rawText});
}

/// OCR processor utility for extracting drug names from camera images
class OcrProcessor {
  final TextRecognizer _textRecognizer = TextRecognizer();
  final DrugService _drugService;
  final bool isOffline;

  OcrProcessor({required DrugService drugService, this.isOffline = false})
    : _drugService = drugService;

  /// Process a captured image and extract drug information
  /// Returns a result object containing matches and raw text
  Future<OcrResult> processImage(CameraController cameraController) async {
    try {
      final image = await cameraController.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.isNotEmpty) {
        debugPrint('=== OCR DETECTED TEXT ===');
        debugPrint(recognizedText.text);
        debugPrint('=========================');

        final drugs = await _processOCRText(recognizedText.text);
        return OcrResult(matchedDrugs: drugs, rawText: recognizedText.text);
      } else {
        debugPrint('OCR: No text detected in image');
        return OcrResult(matchedDrugs: [], rawText: '');
      }
    } catch (e) {
      if (!e.toString().contains('Disposed')) {
        debugPrint('Error processing image: $e');
      }
      return OcrResult(matchedDrugs: [], rawText: '');
    }
  }

  /// Process OCR text and find matching drugs
  Future<List<DrugModel>> _processOCRText(String text) async {
    List<DrugModel> foundDrugs = [];

    try {
      if (!isOffline) {
        // Online: Use full Firebase Search
        foundDrugs = await _drugService.findDrugsInText(text);
      } else {
        // Offline: Use Local Search (Cached top drugs)
        foundDrugs = await _drugService.findDrugsInTextOffline(text);
      }

      debugPrint('=== DRUG MATCHING ===');
      debugPrint('Mode: ${isOffline ? "OFFLINE" : "ONLINE"}');
      debugPrint(
        'Found ${foundDrugs.length} drugs: ${foundDrugs.map((d) => d.displayName).join(", ")}',
      );
      debugPrint('=====================');

      return foundDrugs;
    } catch (e) {
      debugPrint('Error processing OCR results: $e');
      return [];
    }
  }

  /// Clean up resources
  void dispose() {
    _textRecognizer.close();
  }
}
