import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jogak/core/theme/app_colors.dart';

class AppTheme {
  static ThemeData get dark {
    final baseTextTheme = GoogleFonts.gowunBatangTextTheme();
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.background,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        onSurface: AppColors.textPrimary,
        onPrimary: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
      
      // 타이틀 스타일: 고운 바탕 (명조 계열의 우아한 느낌)
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.gowunBatang(
          color: AppColors.textPrimary, 
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
        titleLarge: GoogleFonts.gowunBatang(
          color: AppColors.textPrimary, 
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
        bodyLarge: GoogleFonts.gowunBatang(
          color: AppColors.textPrimary,
          fontSize: 18,
        ),
        bodyMedium: GoogleFonts.gowunBatang(
          color: AppColors.textSecondary,
          fontSize: 16,
        ),
        // 감정 문구용 손글씨 스타일 (나눔손글씨 펜)
        labelLarge: GoogleFonts.nanumPenScript(
          color: AppColors.secondary,
          fontSize: 24,
        ),
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      
      cardTheme: CardThemeData(
        color: AppColors.surface.withValues(alpha: 0.6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.divider.withValues(alpha: 0.3)),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: const BorderSide(color: AppColors.primary, width: 0.5),
          ),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
      ),
    );
  }
}
