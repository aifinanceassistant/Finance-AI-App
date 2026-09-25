import 'package:flutter/material.dart';

enum AppAppearance { light, dark, system }

extension AppAppearanceX on AppAppearance {
  String get label => switch (this) {
        AppAppearance.light => 'Light',
        AppAppearance.dark => 'Dark',
        AppAppearance.system => 'Auto',
      };

  String get blurb => switch (this) {
        AppAppearance.light => 'Bright surfaces and navy ink',
        AppAppearance.dark => 'Dim chrome for low-light sessions',
        AppAppearance.system => 'Follow your device preference',
      };

  ThemeMode get themeMode => switch (this) {
        AppAppearance.light => ThemeMode.light,
        AppAppearance.dark => ThemeMode.dark,
        AppAppearance.system => ThemeMode.system,
      };
}

/// Locked to Classic home (kept for style wiring).
enum DashboardVariation { briefing }

extension DashboardVariationX on DashboardVariation {
  String get label => 'Classic';
  String get blurb => 'Greeting, net worth, and recent transactions';
  IconData get icon => Icons.wb_sunny_outlined;
}

/// Agent-mode layout candidates (web-faithful).
enum AgentLayoutVariation { web, drawer, strip }

extension AgentLayoutVariationX on AgentLayoutVariation {
  String get label => switch (this) {
        AgentLayoutVariation.web => 'Web',
        AgentLayoutVariation.drawer => 'Drawer',
        AgentLayoutVariation.strip => 'Strip',
      };

  String get blurb => switch (this) {
        AgentLayoutVariation.web =>
          'Agents + recents sidebar beside chat (web desktop)',
        AgentLayoutVariation.drawer =>
          'Full chat; hamburger opens agents + history',
        AgentLayoutVariation.strip =>
          'Pixel agent strip under header, chat below',
      };

  IconData get icon => switch (this) {
        AgentLayoutVariation.web => Icons.view_sidebar_outlined,
        AgentLayoutVariation.drawer => Icons.menu_open_rounded,
        AgentLayoutVariation.strip => Icons.view_week_outlined,
      };
}

class VariationController extends ChangeNotifier {
  AppAppearance appearance = AppAppearance.light;
  DashboardVariation dashboard = DashboardVariation.briefing;
  AgentLayoutVariation agentLayout = AgentLayoutVariation.web;

  void setAppearance(AppAppearance value) {
    if (appearance == value) return;
    appearance = value;
    notifyListeners();
  }

  void setDashboard(DashboardVariation value) {
    if (dashboard == value) return;
    dashboard = value;
    notifyListeners();
  }

  void setAgentLayout(AgentLayoutVariation value) {
    if (agentLayout == value) return;
    agentLayout = value;
    notifyListeners();
  }
}

class VariationScope extends InheritedNotifier<VariationController> {
  const VariationScope({
    super.key,
    required VariationController controller,
    required super.child,
  }) : super(notifier: controller);

  static VariationController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<VariationScope>();
    assert(scope != null, 'VariationScope not found');
    return scope!.notifier!;
  }

  static VariationController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<VariationScope>();
    assert(scope != null, 'VariationScope not found');
    return scope!.notifier!;
  }
}
