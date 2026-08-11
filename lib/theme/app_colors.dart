import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand Colors (Modern Indigo / Purple Spectrum)
  static const Color primary = Color(0xFF6366F1); // Indigo Primary
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFFEEF2FF);
  static const Color accent = Color(0xFF8B5CF6); // Bright Violet

  // Dark Mode Surface & Card Colors
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color darkCard = Color(0xFF1E293B); // Slate 800
  static const Color darkSurface = Color(0xFF334155); // Slate 700

  // Light Mode Backgrounds
  static const Color background = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color scaffold = Color(0xFFF1F5F9);

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color hint = Color(0xFF94A3B8);
  static const Color textWhite = Colors.white;

  // Status Colors (Vibrant Badges)
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color successBg = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFEF4444); // Crimson Red
  static const Color errorBg = Color(0xFFFFF1F1);
  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color infoBg = Color(0xFFEFF6FF);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderFocused = Color(0xFF6366F1);
  static const Color divider = Color(0xFFF1F5F9);

  // Input Field
  static const Color inputFill = Color(0xFFF8FAFC);

  // Shadow
  static const Color shadow = Color(0x14000000);
  static const Color premiumShadow = Color(0x1F6366F1);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}