import 'package:flutter/material.dart';

/// Archival Atelier & Frosted Milk Glass Design Tokens
abstract final class ArchivalTheme {
  // Light Palette: Warm Archival Paper & Milk Glass
  static const Color paperLight = Color(0xFFF4F3EF);
  static const Color surfaceLight = Color(0xFFFDFCFA);
  static const Color milkGlass = Color(0xFFFEFDF8);
  static const Color textMainLight = Color(0xFF141414);
  static const Color textMutedLight = Color(0xFF757470);
  static const Color lineHairlineLight = Color(0xFFE2DFD7);
  static const Color stampBgLight = Color(0xFF141414);
  static const Color stampFgLight = Color(0xFFFFFFFF);

  // Dark Palette: Obsidian Chamber
  static const Color paperDark = Color(0xFF191919);
  static const Color surfaceDark = Color(0xFF242424);
  static const Color darkRaised = Color(0xFF2D2D2D);
  static const Color textMainDark = Color(0xFFF2F2F2);
  static const Color textMutedDark = Color(0xFFB7B7B7);
  static const Color lineHairlineDark = Color(0xFF3C3C3C);
  static const Color stampBgDark = Color(0xFFF2F2F2);
  static const Color stampFgDark = Color(0xFF191919);

  // E-Ink High Contrast Mode (Pure Binary)
  static const Color einkBlack = Color(0xFF000000);
  static const Color einkWhite = Color(0xFFFFFFFF);

  // Geometry
  static const double cornerRadius = 4.0;
  static const double hairlineThickness = 0.6;
  static const double registrationInset = 2.0;

  // Monospace code text style
  static TextStyle codeStyle({
    Color? color,
    double fontSize = 10.0,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 1.1,
      color: color,
    );
  }

  // Archival serif typography for literary text
  static TextStyle serifStyle({
    Color? color,
    double fontSize = 16.0,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.75,
  }) {
    return TextStyle(
      fontFamily: 'SourceHanSerifCN',
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      color: color,
    );
  }

  // Theme Data Builders
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: paperLight,
      colorScheme: const ColorScheme.light(
        surface: surfaceLight,
        onSurface: textMainLight,
        onSurfaceVariant: textMutedLight,
        outline: lineHairlineLight,
        primary: stampBgLight,
        onPrimary: stampFgLight,
      ),
      fontFamily: 'SourceHanSerifCN',
      dividerTheme: const DividerThemeData(
        color: lineHairlineLight,
        thickness: hairlineThickness,
        space: 1.0,
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: paperDark,
      colorScheme: const ColorScheme.dark(
        surface: surfaceDark,
        onSurface: textMainDark,
        onSurfaceVariant: textMutedDark,
        outline: lineHairlineDark,
        primary: stampBgDark,
        onPrimary: stampFgDark,
      ),
      fontFamily: 'SourceHanSerifCN',
      dividerTheme: const DividerThemeData(
        color: lineHairlineDark,
        thickness: hairlineThickness,
        space: 1.0,
      ),
    );
  }
}
