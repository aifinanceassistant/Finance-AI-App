import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../variations/models.dart';

enum DashNavStyle { material }

enum DashHomeLayout { briefing }

enum DashHeaderStyle { classic, terminal, minimal }

/// Briefing chrome — Classic home only.
class DashVariantStyle {
  const DashVariantStyle({
    required this.variation,
    required this.navStyle,
    required this.homeLayout,
    required this.headerStyle,
    required this.primary,
    required this.scaffold,
    required this.radius,
    required this.navLabel,
    required this.navBackground,
    required this.showSpaceBar,
    required this.denseTopBar,
  });

  final DashboardVariation variation;
  final DashNavStyle navStyle;
  final DashHomeLayout homeLayout;
  final DashHeaderStyle headerStyle;
  final Color primary;
  final Color scaffold;
  final double radius;
  final String navLabel;
  final Color navBackground;
  final bool showSpaceBar;
  final bool denseTopBar;

  static DashVariantStyle of(BuildContext context) {
    return forVariation(DashboardVariation.briefing, context);
  }

  static DashVariantStyle forVariation(
    DashboardVariation variation,
    BuildContext context,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppColors.surfaceDark : AppColors.surface;
    final panel = dark ? AppColors.panelDark : AppColors.panel;

    return DashVariantStyle(
      variation: DashboardVariation.briefing,
      navStyle: DashNavStyle.material,
      homeLayout: DashHomeLayout.briefing,
      headerStyle: DashHeaderStyle.classic,
      primary: AppColors.brand,
      scaffold: surface,
      radius: 12,
      navLabel: 'Activity',
      navBackground: panel,
      showSpaceBar: true,
      denseTopBar: false,
    );
  }
}

class DashStyleScope extends InheritedWidget {
  const DashStyleScope({
    super.key,
    required this.style,
    required super.child,
  });

  final DashVariantStyle style;

  static DashVariantStyle of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DashStyleScope>();
    assert(scope != null, 'DashStyleScope not found');
    return scope!.style;
  }

  static DashVariantStyle? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DashStyleScope>()?.style;
  }

  @override
  bool updateShouldNotify(DashStyleScope oldWidget) =>
      oldWidget.style != style;
}
