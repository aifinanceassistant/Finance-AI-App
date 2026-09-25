import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Theme-resolved dashboard colors (light / dark).
extension DashColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get dashInk => isDark ? AppColors.inkDark : AppColors.ink;
  Color get dashMute => isDark ? AppColors.muteDark : AppColors.mute;
  Color get dashSoftMute => isDark ? AppColors.softMuteDark : AppColors.softMute;
  Color get dashSurface => isDark ? AppColors.surfaceDark : AppColors.surface;
  Color get dashPanel => isDark ? AppColors.panelDark : AppColors.panel;
  Color get dashLine => isDark ? AppColors.lineDark : AppColors.line;
  Color get dashSidebar => isDark ? AppColors.sidebarDark : AppColors.ink;
  Color get dashBrand => AppColors.brand;

  /// Soft brand wash for chips / selected rows.
  Color get dashWash =>
      isDark ? AppColors.brand.withValues(alpha: 0.16) : AppColors.wash;

  /// Subtle fill slightly above surface (inputs, nested strips).
  Color get dashElevated =>
      isDark ? const Color(0xFF151C26) : const Color(0xFFF5F9FD);

  /// Success / warning / danger tint fills.
  Color get dashSuccessFill =>
      isDark ? AppColors.success.withValues(alpha: 0.16) : const Color(0xFFE6F9F1);
  Color get dashWarningFill =>
      isDark ? AppColors.warning.withValues(alpha: 0.18) : const Color(0xFFFFF8E6);
  Color get dashDangerFill =>
      isDark ? AppColors.danger.withValues(alpha: 0.18) : const Color(0xFFFDE8E8);
  Color get dashBrandFill =>
      isDark ? AppColors.brand.withValues(alpha: 0.16) : const Color(0xFFEEF4FF);
}
