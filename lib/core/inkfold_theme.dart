import 'package:flutter/material.dart';

abstract final class InkfoldTheme {
  static const Color ink = Color(0xff202827);
  static const Color oxblood = Color(0xff8f3b42);
  static const Color teal = Color(0xff2f6f6a);
  static const Color paper = Color(0xfff4f0e7);

  static ThemeData light() => _theme(
    brightness: Brightness.light,
    surface: const Color(0xfffbfaf7),
    scaffold: const Color(0xfff0f1ed),
    foreground: ink,
  );

  static ThemeData dark() => _theme(
    brightness: Brightness.dark,
    surface: const Color(0xff202726),
    scaffold: const Color(0xff171c1c),
    foreground: const Color(0xffedf0ea),
  );

  static ThemeData _theme({
    required Brightness brightness,
    required Color surface,
    required Color scaffold,
    required Color foreground,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: brightness,
      surface: surface,
    ).copyWith(
      primary: brightness == Brightness.light ? ink : const Color(0xffb8d6d2),
      secondary: oxblood,
      onSurface: foreground,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      fontFamily: 'Arial',
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        foregroundColor: foreground,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
      tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 450)),
    );
  }
}
