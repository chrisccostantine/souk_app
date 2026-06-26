import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class SoukloraColors {
  static const leaf = Color(0xFF1F7A4D);
  static const saffron = Color(0xFFE7A72E);
  static const clay = Color(0xFFC8673A);
  static const paper = Color(0xFFF8F4EC);
  static const ink = Color(0xFF17211B);
}

ThemeData buildSoukloraTheme() {
  final softShadow = Colors.black.withValues(alpha: 0.08);
  final scheme = ColorScheme.fromSeed(
    seedColor: SoukloraColors.leaf,
    primary: SoukloraColors.leaf,
    secondary: SoukloraColors.saffron,
    tertiary: SoukloraColors.clay,
    surface: SoukloraColors.paper,
  );

  return ThemeData(
    textTheme: GoogleFonts.interTextTheme().apply(
      bodyColor: SoukloraColors.ink,
      displayColor: SoukloraColors.ink,
    ),
    primaryTextTheme: GoogleFonts.interTextTheme().apply(
      bodyColor: SoukloraColors.ink,
      displayColor: SoukloraColors.ink,
    ),
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: SoukloraColors.paper,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: SoukloraColors.paper,
      foregroundColor: SoukloraColors.ink,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shadowColor: softShadow,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.18)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: SoukloraColors.leaf.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    ),
  );
}
