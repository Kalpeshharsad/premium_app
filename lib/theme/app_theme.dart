import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF8AB4F8); // Reference Accent
  static const Color secondaryColor = Color(0xFFEC4899); // Pink
  static const Color backgroundColor = Color(0xFF1A1B1E); // Reference Dark
  static const Color cardColor = Color(0xFF282A2D); // Reference Card
  static const Color accentColor = Color(0xFF8AB4F8); // Emerald

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    fontFamily: 'Outfit',
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
      bodyLarge: TextStyle(fontSize: 16, color: Colors.white70),
    ),
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: cardColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
  );
}
