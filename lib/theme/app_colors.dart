import 'package:flutter/material.dart';

/// Fendo — light modern palette (stone + forest + mint).
class AppColors {
  AppColors._();

  static const Color canvas = Color(0xFFF3F7F5);
  static const Color canvasDeep = Color(0xFFE6F0EC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFECF2EF);

  static const Color forest = Color(0xFF0D2B24);
  static const Color forestSoft = Color(0xFF1A3D34);
  static const Color mint = Color(0xFF00B894);
  static const Color mintSoft = Color(0xFF26C9A5);
  static const Color mintWash = Color(0xFFD4F5EC);

  static const Color amber = Color(0xFFF0A500);
  static const Color coral = Color(0xFFE85D4C);

  static const Color textPrimary = Color(0xFF0D2B24);
  static const Color textSecondary = Color(0xFF5A6F68);
  static const Color textMuted = Color(0xFF8A9B94);

  static const Color border = Color(0xFFD5E0DB);
  static const Color borderFocus = Color(0xFF00B894);
  static const Color error = Color(0xFFE85D4C);
  static const Color success = Color(0xFF00B894);

  // Legacy aliases used by older screens during redesign
  static const Color ink = forest;
  static const Color inkElevated = forestSoft;
  static const Color surfaceSoft = surfaceMuted;
  static const Color mintDim = Color(0xFF008F74);
  static const Color textPrimaryDark = Color(0xFFF2F7F5);

  static const LinearGradient heroWash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFE8F6F1),
      Color(0xFFF3F7F5),
      Color(0xFFF7FAF8),
    ],
  );

  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D2B24),
      Color(0xFF164A3D),
    ],
  );

  static const LinearGradient brandMark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00B894),
      Color(0xFF0D2B24),
    ],
  );
}
