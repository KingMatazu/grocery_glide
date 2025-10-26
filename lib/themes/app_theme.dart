import 'package:flutter/material.dart';
import 'package:grocery_glide/themes/app_colors.dart';

class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      primaryColor: AppColors.lightPrimary,
      
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightPrimary,
        secondary: AppColors.lightSecondary,
        surface: AppColors.lightSurface,
        error: AppColors.lightError,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.lightTextPrimary,
        onError: Colors.white,
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      
      cardTheme: CardThemeData(
        color: AppColors.lightCardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.lightPrimary,
        foregroundColor: Colors.white,
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightPrimary, width: 2),
        ),
      ),
      
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.lightTextPrimary),
        displayMedium: TextStyle(color: AppColors.lightTextPrimary),
        displaySmall: TextStyle(color: AppColors.lightTextPrimary),
        headlineMedium: TextStyle(color: AppColors.lightTextPrimary),
        headlineSmall: TextStyle(color: AppColors.lightTextPrimary),
        titleLarge: TextStyle(color: AppColors.lightTextPrimary),
        bodyLarge: TextStyle(color: AppColors.lightTextPrimary),
        bodyMedium: TextStyle(color: AppColors.lightTextSecondary),
      ),
      
      iconTheme: const IconThemeData(
        color: AppColors.lightTextPrimary,
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      primaryColor: AppColors.darkPrimary,
      
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        secondary: AppColors.darkSecondary,
        surface: AppColors.darkSurface,
        error: AppColors.darkError,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.darkTextPrimary,
        onError: Colors.white,
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      
      cardTheme: CardThemeData(
        color: AppColors.darkCardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.darkPrimary,
        foregroundColor: Colors.white,
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkPrimary, width: 2),
        ),
      ),
      
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.darkTextPrimary),
        displayMedium: TextStyle(color: AppColors.darkTextPrimary),
        displaySmall: TextStyle(color: AppColors.darkTextPrimary),
        headlineMedium: TextStyle(color: AppColors.darkTextPrimary),
        headlineSmall: TextStyle(color: AppColors.darkTextPrimary),
        titleLarge: TextStyle(color: AppColors.darkTextPrimary),
        bodyLarge: TextStyle(color: AppColors.darkTextPrimary),
        bodyMedium: TextStyle(color: AppColors.darkTextSecondary),
      ),
      
      iconTheme: const IconThemeData(
        color: AppColors.darkTextPrimary,
      ),
    );
  }
}
