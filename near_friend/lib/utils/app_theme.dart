import 'package:flutter/material.dart';

class AppTheme {
  // iOS Light Theme Colors
  static const Color iosBlue = Color(0xFF007AFF);
  static const Color iosGreen = Color(0xFF34C759);
  static const Color iosRed = Color(0xFFFF3B30);
  static const Color iosOrange = Color(0xFFFF9500);
  static const Color iosPurple = Color(0xFFAF52DE);
  static const Color iosPink = Color(0xFFFF2D92);
  static const Color iosYellow = Color(0xFFFFCC02);

  // iOS Light Background Colors
  static const Color iosBackground = Color(0xFFF2F2F7);
  static const Color iosSecondaryBackground = Color(0xFFFFFFFF);
  static const Color iosTertiaryBackground = Color(0xFFF2F2F7);

  // iOS Light Text Colors
  static const Color iosPrimaryText = Color(0xFF000000);
  static const Color iosSecondaryText = Color(0xFF8E8E93);
  static const Color iosTertiaryText = Color(0xFFC7C7CC);

  // iOS Dark Theme Colors (same accent colors)
  static const Color iosDarkBackground = Color(0xFF000000);
  static const Color iosDarkSecondaryBackground = Color(0xFF1C1C1E);
  static const Color iosDarkTertiaryBackground = Color(0xFF2C2C2E);

  // iOS Dark Text Colors
  static const Color iosDarkPrimaryText = Color(0xFFFFFFFF);
  static const Color iosDarkSecondaryText = Color(0xFF8E8E93);
  static const Color iosDarkTertiaryText = Color(0xFF48484A);

  // iOS Style Font - SFPro
  static TextStyle get iosFont => const TextStyle(
        fontFamily: 'SFPro',
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.41,
      );

  static TextStyle get iosFontBold => const TextStyle(
        fontFamily: 'SFPro',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.41,
      );

  static TextStyle get iosFontLarge => const TextStyle(
        fontFamily: 'SFPro',
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.37,
      );

  static TextStyle get iosFontMedium => const TextStyle(
        fontFamily: 'SFPro',
        fontSize: 22,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.35,
      );

  static TextStyle get iosFontSmall => const TextStyle(
        fontFamily: 'SFPro',
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.24,
      );

  static TextStyle get iosFontCaption => const TextStyle(
        fontFamily: 'SFPro',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      );

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'SFPro',

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: iosBlue,
        secondary: iosGreen,
        surface: iosSecondaryBackground,
        background: iosBackground,
        error: iosRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: iosPrimaryText,
        onBackground: iosPrimaryText,
        onError: Colors.white,
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: iosSecondaryBackground,
        foregroundColor: iosPrimaryText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: iosFontBold.copyWith(fontSize: 17),
        iconTheme: const IconThemeData(color: iosBlue),
      ),

      // Card Theme
      cardTheme: CardTheme(
        color: iosSecondaryBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: iosBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: iosFontBold,
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: iosBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: iosFontBold,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: iosTertiaryBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: iosBlue, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: iosFont.copyWith(color: iosSecondaryText),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: iosSecondaryBackground,
        selectedItemColor: iosBlue,
        unselectedItemColor: iosSecondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle: iosFontBold,
        subtitleTextStyle: iosFontSmall.copyWith(color: iosSecondaryText),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: iosBlue,
        size: 24,
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'SFPro',

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: iosBlue,
        secondary: iosGreen,
        surface: iosDarkSecondaryBackground,
        background: iosDarkBackground,
        error: iosRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: iosDarkPrimaryText,
        onBackground: iosDarkPrimaryText,
        onError: Colors.white,
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: iosDarkSecondaryBackground,
        foregroundColor: iosDarkPrimaryText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: iosFontBold.copyWith(fontSize: 17),
        iconTheme: const IconThemeData(color: iosBlue),
      ),

      // Card Theme
      cardTheme: CardTheme(
        color: iosDarkSecondaryBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: iosBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: iosFontBold,
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: iosBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: iosFontBold,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: iosDarkTertiaryBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: iosBlue, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: iosFont.copyWith(color: iosDarkSecondaryText),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: iosDarkSecondaryBackground,
        selectedItemColor: iosBlue,
        unselectedItemColor: iosDarkSecondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle: iosFontBold,
        subtitleTextStyle: iosFontSmall.copyWith(color: iosDarkSecondaryText),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: iosBlue,
        size: 24,
      ),
    );
  }
}
