import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import '../models/drug_model.dart';
import 'drug_service.dart';
import 'admin_analytics_service.dart';

/// Service for interacting with Gemini AI via Firebase AI Logic
class AIService {
  // Singleton pattern
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  // Using Gemini 2.5 Flash as requested.
  final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash',
  );

  /// Fetches drug information using AI based on a brand name, generic name, or OCR text
  Future<DrugModel?> fetchDrugInfo(String query) async {
    // Normalize query: remove parentheses content if it's a "Generic (Brand)" format
    final normalizedQuery = query.replaceAll(RegExp(r'\(.*\)'), '').trim();

    debugPrint(
      'AI Service: Starting search for "$query" (Normalized: "$normalizedQuery")...',
    );
    final prompt =
        '''
      You are a world-class clinical pharmacologist and medical AI. Your task is to identify a medication and provide clinical safety data.
      
      Query: "$query"
      
      STEPS:
      1. Identify the medication. The query might be a Brand Name, a Generic Name, or a combination like "Generic (Brand)".
      2. If it's a Brand Name, resolve it to its primary active ingredient(s) (Generic Name).
      3. If the query contains BOTH (e.g., "Escitalopram (Lexapro)"), acknowledge both.
      4. Provide the full safety profile in the JSON format below using the Generic Name as the primary identity.
      
      Respond ONLY with a valid JSON object. Do not include markdown formatting or explanations.
      
      Format:
      {
        "displayName": "Generic Name (e.g. Escitalopram)",
        "brandNames": ["Common brand names including the query if it was a brand"],
        "category": "Therapeutic class (e.g., 'SSRI Antidepressant', 'ACE Inhibitor')",
        "isCombination": true/false,
        "activeIngredients": [
          {"name": "Ingredient Name", "strength": "Typical strength if known, or empty"}
        ],
        "allergyWarnings": ["Generic allergy groups like 'NSAIDs', 'Penicillins', 'SSRIs'"],
        "conditionWarnings": ["List specific contraindications. Format: 'Condition: Risk description'"],
        "drugInteractions": [
          {"drugName": "Commonly interacted drug", "severity": "severe/moderate/mild", "description": "Interaction detail"}
        ],
        "foodInteractions": [
          {"food": "Food item", "severity": "avoid/caution/limit", "description": "Reason"}
        ],
        "alcoholRestriction": "avoid/caution/limit/none",
        "alcoholWarningDescription": "Detailed alcohol safety info"
      }

      CRITICAL CLINICAL RULES:
      1. LISINOPRIL/ACE INHIBITORS: Must include 'Pregnancy: Critical risk', 'Angioedema history', and 'High Potassium'.
      2. SERTRALINE/ESCITALOPRAM/SSRIs: Must include 'Serotonin Syndrome risk with MAOIs/Tramadol', 'Bipolar Disorder warning', and 'Increased bleeding risk with NSAIDs'.
      3. LEXAPRO: This is Escitalopram. Resolve it accordingly.
      4. ACCURACY: If you are 70% sure, provide the data. If completely unknown, return {}.
      5. FORMAT: "severity" MUST be lowercase: 'severe', 'moderate', or 'mild'.
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      String? jsonText = response.text;

      if (jsonText == null || jsonText.isEmpty) {
        debugPrint('AI Service: Empty response from Gemini');
        return null;
      }

      // Clean the response if Gemini included markdown or extra text
      final rawContent = jsonText;
      jsonText = _cleanJsonResponse(jsonText);

      try {
        final Map<String, dynamic> data = jsonDecode(jsonText);
        if (data.isEmpty) {
          debugPrint('AI Service: AI returned empty JSON {}. Result unknown.');
          return null;
        }

        if (data['displayName'] == null) {
          debugPrint('AI Service: JSON missing displayName. Raw: $rawContent');
          return null;
        }

        // Map to DrugModel
        final aiDrug = DrugModel.fromMap(
          data,
          'ai_${DateTime.now().millisecondsSinceEpoch}',
        );

        // LEARNING FEATURE: Save this new drug to the global database
        // so it's found locally next time and for other users.
        try {
          final drugService = DrugService();
          final existing = await drugService.getDrugByName(aiDrug.displayName);

          if (existing == null) {
            final newId = await drugService.addDrug(aiDrug);
            if (newId != null) {
              debugPrint(
                'AI Service: Learned new drug "$query" -> Saved with ID: $newId',
              );

              // Log to admin audit trail
              AdminAnalyticsService().logAdminAction(
                action: 'AI Auto-Learned',
                details: 'New drug "${aiDrug.displayName}" discovered via AI search for "$query"',
                targetId: newId,
              );

              return aiDrug.copyWith(id: newId);
            }
          } else {
            debugPrint(
              'AI Service: Drug "${aiDrug.displayName}" already exists. Using existing.',
            );
            return existing;
          }
        } catch (dbError) {
          debugPrint('AI Service: Error saving learned drug: $dbError');
        }

        return aiDrug;
      } catch (parseError) {
        debugPrint('AI Service JSON Parse Error: $parseError');
        debugPrint('Raw response before cleaning: $rawContent');
        debugPrint('Cleaned content: $jsonText');
        return null;
      }
    } catch (e) {
      debugPrint('AI Service Exception: $e');
      if (e.toString().contains('quota') ||
          e.toString().contains('rate limit')) {
        debugPrint(
          'CRITICAL: Gemini API Quota Exceeded. Using local fallback.',
        );
      }
      return null;
    }
  }

  /// Cleans the response text to extract only the JSON part
  String _cleanJsonResponse(String text) {
    String cleaned = text.trim();

    // Remove markdown code blocks
    if (cleaned.contains('```')) {
      final regex = RegExp(r'```(?:json)?\s*(\{[\s\S]*\}|\[[\s\S]*\])\s*```');
      final match = regex.firstMatch(cleaned);
      if (match != null) {
        cleaned = match.group(1) ?? cleaned;
      } else {
        // Fallback: search for first { and last } or [ and ]
        final startBrace = cleaned.indexOf('{');
        final endBrace = cleaned.lastIndexOf('}');
        final startBracket = cleaned.indexOf('[');
        final endBracket = cleaned.lastIndexOf(']');

        if (startBrace != -1 &&
            endBrace > startBrace &&
            (startBracket == -1 || startBrace < startBracket)) {
          cleaned = cleaned.substring(startBrace, endBrace + 1);
        } else if (startBracket != -1 && endBracket > startBracket) {
          cleaned = cleaned.substring(startBracket, endBracket + 1);
        }
      }
    } else {
      final startBrace = cleaned.indexOf('{');
      final endBrace = cleaned.lastIndexOf('}');
      final startBracket = cleaned.indexOf('[');
      final endBracket = cleaned.lastIndexOf(']');

      if (startBrace != -1 &&
          endBrace > startBrace &&
          (startBracket == -1 || startBrace < startBracket)) {
        cleaned = cleaned.substring(startBrace, endBrace + 1);
      } else if (startBracket != -1 && endBracket > startBracket) {
        cleaned = cleaned.substring(startBracket, endBracket + 1);
      }
    }

    return cleaned;
  }

  /// Performs a specialized AI check for interactions BETWEEN two specific drugs.
  Future<List<DrugInteraction>> checkDirectInteraction(
    String drugA,
    String drugB,
  ) async {
    debugPrint('AI Service: Deep analysis for "$drugA" vs "$drugB"...');
    final prompt =
        '''
      You are a senior clinical pharmacologist. Conduct a deep safety analysis between these two medications:
      - Medication A: "$drugA"
      - Medication B: "$drugB"

      Analyze for:
      1. Synergistic toxicity (e.g., duplicate classes like two NSAIDs).
      2. Pharmacokinetic interactions (e.g., CYP450 inhibition/induction).
      3. Pharmacodynamic interactions (e.g., additive QT prolongation, serotonin syndrome).
      4. Shared active ingredients (Duplicate therapy).

      Provide the analysis in a JSON array. If NO interaction exists, return [].
      
      Format:
      [
        {
          "drugName": "Medication name causing the clash",
          "severity": "severe/moderate/mild",
          "description": "Clear clinical explanation of the risk."
        }
      ]

      CLINICAL RULES:
      1. CRITICAL: If both are SSRIs/SNRIs, flag for Serotonin Syndrome (Severe).
      2. CRITICAL: If both are NSAIDs, flag for GI Hemorrhage (Severe).
      3. CRITICAL: If one is an ACE Inhibitor and other is an NSAID, flag for Acute Kidney Injury (Moderate/Severe).
      4. DO NOT return preamble. Respond ONLY with the JSON array.
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      String? jsonText = response.text;

      if (jsonText == null || jsonText.isEmpty) return [];

      jsonText = _cleanJsonResponse(jsonText);

      try {
        final List<dynamic> data = jsonDecode(jsonText);
        return data
            .map((e) => DrugInteraction.fromMap(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('AI Deep Analysis Parse Error: $e');
        debugPrint('Raw Content: $jsonText');
        return [];
      }
    } catch (e) {
      debugPrint('AI Deep Analysis Error: $e');
      if (e.toString().contains('quota') ||
          e.toString().contains('rate limit')) {
        debugPrint('CRITICAL: Gemini Deep Analysis Quota Exceeded.');
      }
      return [];
    }
  }
}
