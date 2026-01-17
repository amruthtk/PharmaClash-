import 'package:flutter/material.dart';

class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // Premium dark theme colors (kept for reference)
  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color deepTeal = Color(0xFF0F766E);
  static const Color mintGreen = Color(0xFF5EEAD4);
  static const Color lightMint = Color(0xFFCCFBF1);
  static const Color darkBg = Color(0xFF0F172A);
  static const Color cardBg = Color(0xFF1E293B);
  static const Color lightText = Color(0xFFF1F5F9);
  static const Color darkText = Color(
    0xFF1E293B,
  ); // Darker text for light theme
  static const Color mutedText = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFF334155);

  // Light theme colors - Cool grey/slate palette for teal contrast
  static const Color softWhite = Color(
    0xFFF1F5F9,
  ); // Slate-50: Cool grey background
  static const Color accentGreen = Color(0xFF10B981);
  static const Color grayText = Color(
    0xFF475569,
  ); // Slate-600: Darker for readability
  static const Color inputBg = Color(0xFFE2E8F0); // Slate-200: Input fields
  static const Color lightCardBg = Color(0xFFFFFFFF); // Pure white cards
  static const Color lightBorderColor = Color(
    0xFFCBD5E1,
  ); // Slate-300: Visible borders
}
