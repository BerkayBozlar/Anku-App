import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  // Ankara Üniversitesi lacivert tonu
  static const Color primary = Color(0xFF0B3D91);

  static ThemeData light() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: primary),
      useMaterial3: true,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }
}
