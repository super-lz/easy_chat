import 'package:flutter/material.dart';

ThemeData buildEasyChatTheme() {
  const seed = Color(0xFF1D1D1F);

  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: const Color(0xFFFFFEFC),
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F4F1),
    useMaterial3: true,
  );
}
