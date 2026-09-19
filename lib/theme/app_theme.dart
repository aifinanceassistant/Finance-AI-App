import 'package:flutter/material.dart';

/// FinanceAI brand tokens for the mobile app.
abstract final class AppColors {
  static const Color brand = Color(0xFF3B9AE0);
  static const Color brandDark = Color(0xFF2A7FC4);
  static const Color accent = Color(0xFF635BFF);
  static const Color accentHover = Color(0xFF5851EA);
  static const Color ink = Color(0xFF0A2540);
  static const Color mute = Color(0xFF697386);
  static const Color softMute = Color(0xFF8898AA);
  static const Color surface = Color(0xFFF6F9FC);
  static const Color line = Color(0xFFE3E8EE);
  static const Color success = Color(0xFF0D9488);
  static const Color danger = Color(0xFFC53030);
  static const Color warning = Color(0xFFB7791F);

  static const Color inkDark = Color(0xFFE8EEF5);
  static const Color muteDark = Color(0xFF9AA8B8);
  static const Color softMuteDark = Color(0xFF7A8798);
  static const Color surfaceDark = Color(0xFF0F1419);
  static const Color panelDark = Color(0xFF1A222D);
  static const Color lineDark = Color(0xFF243040);
}

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        primary: AppColors.brand,
        surface: AppColors.surface,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardColor: Colors.white,
      dividerColor: AppColors.line,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: Brightness.dark,
        primary: AppColors.brand,
        surface: AppColors.surfaceDark,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surfaceDark,
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.inkDark,
        displayColor: AppColors.inkDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.panelDark,
        foregroundColor: AppColors.inkDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardColor: AppColors.panelDark,
      dividerColor: AppColors.lineDark,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
