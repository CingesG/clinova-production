import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ClinovaTheme {
  static ThemeData light() {
    const primary = Color(0xFF2563EB);
    const secondary = Color(0xFF059669);
    const tertiary = Color(0xFF7C3AED);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          secondary: secondary,
          tertiary: tertiary,
          surface: Colors.white,
          onSurface: const Color(0xFF102A43),
          surfaceTint: Colors.transparent,
          outline: const Color(0xFFD7DFEA),
          outlineVariant: const Color(0xFFE6EDF5),
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      cupertinoOverrideTheme: const CupertinoThemeData(primaryColor: primary),
    );

    return base.copyWith(
      drawerTheme: DrawerThemeData(
        scrimColor: const Color(0xFF0F172A).withValues(alpha: 0.38),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F8FB),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF102A43)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF102A43),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineMedium: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
        ),
        headlineSmall: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF102A43),
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF102A43),
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          height: 1.45,
          color: Color(0xFF475467),
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.45,
          color: Color(0xFF667085),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF102A43),
          side: const BorderSide(color: Color(0xFFD7DFEA)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: Color(0xFF98A2B3)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFE6EDF5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
      ),
    );
  }
}
