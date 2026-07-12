/// SGP-Agent 통합 디자인 시스템 — 세련된 다크 모드 (Material 3).
library;

import 'package:flutter/material.dart';

/// 현대적·저자극 다크 테마 팔레트.
abstract final class SgpAppTheme {
  static const background = Color(0xFF121218);
  static const surface = Color(0xFF1A1D26);
  static const surfaceHigh = Color(0xFF242836);
  static const surfaceOverlay = Color(0xFF2C3040);
  static const border = Color(0xFF2E3344);
  static const borderSubtle = Color(0xFF232736);
  static const primary = Color(0xFF6366F1);
  static const primaryLight = Color(0xFF818CF8);
  static const accent = Color(0xFF22D3EE);
  static const accentMuted = Color(0xFF67E8F9);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const textOnAccent = Color(0xFF0F172A);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);
  static const info = Color(0xFF38BDF8);
  static const cotPrimary = Color(0xFF818CF8);
  static const cotSecondary = Color(0xFF38BDF8);
  static const cotAggressor = Color(0xFFFB923C);
  static const cotVictim = Color(0xFF38BDF8);
  static const cotCaution = Color(0xFFFBBF24);
  static const cotNeutral = Color(0xFF94A3B8);
  static const appBar = Color(0xFF1A1D26);

  static Color sectionAccent(String title) {
    if (title.contains('2단계')) return cotSecondary;
    if (title.contains('3단계')) return cotPrimary;
    if (title.contains('1단계') || title.contains('4단계')) return cotNeutral;
    return accent;
  }

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          onPrimary: textOnAccent,
          secondary: accent,
          onSecondary: textOnAccent,
          surface: surface,
          onSurface: textPrimary,
          error: error,
          outline: border,
        ),
        cardColor: surface,
        dividerColor: border,
        appBarTheme: const AppBarTheme(
          backgroundColor: appBar,
          foregroundColor: textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: textOnAccent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceHigh,
          hintStyle: const TextStyle(color: textMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryLight, width: 1.5),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primary;
            return Colors.transparent;
          }),
          checkColor: WidgetStateProperty.all(textOnAccent),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: surfaceHigh,
          contentTextStyle: const TextStyle(color: textPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      );

  static BoxDecoration cardDecoration({Color? borderColor}) => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? border),
      );

  static BoxDecoration analysisPanelDecoration({Color? accentBorder}) =>
      BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [surface, surfaceHigh],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentBorder ?? border),
      );
}

/// CoT·분석 UI 색상 (SgpAppTheme 별칭).
abstract final class SgpCotColors {
  static const brand = SgpAppTheme.primary;
  static const neon = SgpAppTheme.accent;
  static const onDark = SgpAppTheme.textSecondary;
  static const surface = SgpAppTheme.surface;
  static const border = SgpAppTheme.border;
  static const highlight = SgpAppTheme.cotAggressor;
  static const shield = SgpAppTheme.cotVictim;
  static const caution = SgpAppTheme.cotCaution;
  static Color sectionAccent(String title) => SgpAppTheme.sectionAccent(title);
}

/// 현장 UI 색상 (SgpAppTheme 별칭).
abstract final class SgpFieldColors {
  static const background = SgpAppTheme.background;
  static const surface = SgpAppTheme.surface;
  static const surfaceHigh = SgpAppTheme.surfaceHigh;
  static const border = SgpAppTheme.border;
  static const textPrimary = SgpAppTheme.textPrimary;
  static const textSecondary = SgpAppTheme.textSecondary;
  static const accentBlue = SgpAppTheme.accent;
  static const safeGreen = SgpAppTheme.success;
  static const cautionOrange = SgpAppTheme.warning;
  static const criticalRed = SgpAppTheme.error;
  static const navy = SgpAppTheme.primary;
  static const textOnAccent = SgpAppTheme.textOnAccent;
  /// 밝은 배경(미란다 고지·타임라인 카드)용 고대비 본문.
  static const fieldGuideNavy = Color(0xFF0D233A);
  /// 연녹/연회색 카드 내부 설명 본문.
  static const fieldGuideBody = Color(0xFF2C3E50);
}
