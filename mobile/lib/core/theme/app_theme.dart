import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  // Logodaki antrasit ton; tema siyah-beyaz-gri tonlarda üretilir
  static const Color primary = Color(0xFF18181B);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        // Renk tonu yerine yalnız gri tonlar; hata rengi kırmızı kalır
        dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      ),
      useMaterial3: true,
    );
  }
}
