import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Matches web dashboard tokens (`variations.tsx` / `globals.css`).
abstract final class AppColors {
  static const Color brand = Color(0xFF3B9AE0);
  static const Color brandDark = Color(0xFF2A7FC4);
  static const Color accent = Color(0xFF3B9AE0);
  static const Color accentHover = Color(0xFF2A7FC4);
  static const Color ink = Color(0xFF0A2540);
  static const Color mute = Color(0xFF697386);
  static const Color softMute = Color(0xFF8898AA);
  static const Color surface = Color(0xFFF6F9FC);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFE3E8EE);
  static const Color success = Color(0xFF0D9488);
  static const Color danger = Color(0xFFC53030);
  static const Color warning = Color(0xFFB7791F);
  static const Color wash = Color(0xFFDBEAF8);

  static const Color inkDark = Color(0xFFE8EEF5);
  static const Color muteDark = Color(0xFF9AA8B8);
  static const Color softMuteDark = Color(0xFF7A8798);
  static const Color surfaceDark = Color(0xFF0F1419);
  static const Color panelDark = Color(0xFF1A222D);
  static const Color lineDark = Color(0xFF243040);
  static const Color sidebarDark = Color(0xFF151B23);
}

abstract final class AppTheme {
  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;
    final ink =
        brightness == Brightness.light ? AppColors.ink : AppColors.inkDark;
    return GoogleFonts.plusJakartaSansTextTheme(base).apply(
      bodyColor: ink,
      displayColor: ink,
    );
  }

  static ThemeData get light {
    final text = _textTheme(Brightness.light);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brand,
        onPrimary: Colors.white,
        secondary: AppColors.mute,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        outline: AppColors.line,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.panel,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardColor: AppColors.panel,
      dividerColor: AppColors.line,
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.panel,
        indicatorColor: AppColors.brand.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.1,
            color: selected ? AppColors.ink : AppColors.mute,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? AppColors.brand : AppColors.mute,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.panel,
        selectedColor: AppColors.wash,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final text = _textTheme(Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brand,
        onPrimary: Colors.white,
        secondary: AppColors.muteDark,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.inkDark,
        outline: AppColors.lineDark,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.surfaceDark,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.panelDark,
        foregroundColor: AppColors.inkDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.inkDark,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardColor: AppColors.panelDark,
      dividerColor: AppColors.lineDark,
      dividerTheme: const DividerThemeData(
        color: AppColors.lineDark,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.panelDark,
        indicatorColor: AppColors.brand.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.1,
            color: selected ? AppColors.inkDark : AppColors.muteDark,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? AppColors.brand : AppColors.muteDark,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.panelDark,
        selectedColor: AppColors.brand.withValues(alpha: 0.16),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.inkDark,
        ),
        side: const BorderSide(color: AppColors.lineDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkDark,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.lineDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
