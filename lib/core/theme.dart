import 'package:flutter/material.dart';

class ResonXColors {
  static const Color deepGraphite = Color(0xFF121316);
  static const Color surfaceBlack = Color(0xFF0D0E11);
  static const Color cardBorder = Color(0xFF262A33);
  static const Color cyberJade = Color(0xFF00E599);
  static const Color neonCyan = Color(0xFF00C2FF);
  static const Color accentPurple = Color(0xFF9D00FF);
  static const Color textPrimary = Color(0xFFF0F2F5);
  static const Color textSecondary = Color(0xFF949BA4);
  static const Color errorRed = Color(0xFFFF4D4D);
}

class ResonXTheme {
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ResonXColors.deepGraphite,
        primaryColor: ResonXColors.cyberJade,
        colorScheme: const ColorScheme.dark(
          primary: ResonXColors.cyberJade,
          secondary: ResonXColors.neonCyan,
          surface: ResonXColors.deepGraphite,
          onSurface: ResonXColors.textPrimary,
        ),
        fontFamily: 'Roboto',
        listTileTheme: const ListTileThemeData(
          iconColor: ResonXColors.textSecondary,
          textColor: ResonXColors.textPrimary,
          selectedColor: ResonXColors.cyberJade,
          tileColor: Colors.transparent,
        ),
        // Poprawione typowanie zgodne z Twoją wersją SDK Fluttera
        dialogTheme: DialogThemeData(
          backgroundColor: ResonXColors.surfaceBlack,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            color: ResonXColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          contentTextStyle: const TextStyle(
            color: ResonXColors.textSecondary,
            fontSize: 16,
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: ResonXColors.surfaceBlack,
          surfaceTintColor: Colors.transparent,
          modalBackgroundColor: ResonXColors.surfaceBlack,
        ),
        cardTheme: CardThemeData(
          color: ResonXColors.surfaceBlack,
          surfaceTintColor: Colors.transparent,
          elevation: 4,
        ),
      );
}