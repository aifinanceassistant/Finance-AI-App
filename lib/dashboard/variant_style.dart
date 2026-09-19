import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../variations/models.dart';

enum DashHomeLayout { briefing }

enum DashNavStyle { material }

class DashVariantStyle {
  const DashVariantStyle({
    required this.primary,
    required this.scaffold,
    required this.radius,
    required this.showTopBar,
    required this.navStyle,
    required this.homeLayout,
    required this.navLabel,
    required this.navBackground,
    required this.topBarTinted,
    required this.denseTopBar,
    required this.inkTopBar,
    required this.extendBody,
    required this.minimalChrome,
  });

  final Color primary;
  final Color scaffold;
  final double radius;
  final bool showTopBar;
  final DashNavStyle navStyle;
  final DashHomeLayout homeLayout;
  final String navLabel;
  final Color navBackground;
  final bool topBarTinted;
  final bool denseTopBar;
  final bool inkTopBar;
  final bool extendBody;
  final bool minimalChrome;

  static DashVariantStyle forVariation(DashboardVariation v) => switch (v) {
        DashboardVariation.briefing => const DashVariantStyle(
            primary: AppColors.brand,
            scaffold: AppColors.surface,
            radius: 12,
            showTopBar: false,
            navStyle: DashNavStyle.material,
            homeLayout: DashHomeLayout.briefing,
            navLabel: 'Activity',
            navBackground: Colors.white,
            topBarTinted: false,
            denseTopBar: false,
            inkTopBar: false,
            extendBody: false,
            minimalChrome: false,
          ),
      };
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
