import 'package:flutter/material.dart';

/// Fendo — light canvas with site violet accents (not full dark mode).
class AppColors {
  AppColors._();

  static const Color canvas = Color(0xFFF6F4FB);
  static const Color canvasDeep = Color(0xFFEDE8F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF0ECF8);

  static const Color forest = Color(0xFF1A1135);
  static const Color forestSoft = Color(0xFF2A2248);

  /// Brand violet — matches fendo.app CTAs
  static const Color mint = Color(0xFF7B61FF);
  static const Color mintSoft = Color(0xFF9B87FF);
  static const Color mintWash = Color(0xFFE8E2FF);
  static const Color mintDim = Color(0xFF5A45D6);

  static const Color amber = Color(0xFFF0A500);
  static const Color coral = Color(0xFFFF5A5F);

  static const Color textPrimary = Color(0xFF1A1135);
  static const Color textSecondary = Color(0xFF6B6285);
  static const Color textMuted = Color(0xFF9A93B0);

  static const Color border = Color(0xFFDDD6F0);
  static const Color borderFocus = Color(0xFF7B61FF);
  static const Color error = Color(0xFFFF5A5F);
  static const Color success = Color(0xFF2ECC71);

  static const Color ink = forest;
  static const Color inkElevated = forestSoft;
  static const Color surfaceSoft = surfaceMuted;
  static const Color textPrimaryDark = Color(0xFFF6F4FB);

  static const LinearGradient heroWash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF0ECFF),
      Color(0xFFF6F4FB),
      Color(0xFFFAF9FD),
    ],
  );

  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF7B61FF),
      Color(0xFF5A45D6),
    ],
  );

  static const LinearGradient brandMark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF9B87FF),
      Color(0xFF7B61FF),
    ],
  );

  static const LinearGradient headlineGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1A1135),
      Color(0xFF5A45D6),
    ],
  );
}
