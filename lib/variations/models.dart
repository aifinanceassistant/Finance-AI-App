import 'package:flutter/material.dart';

enum DashboardVariation { briefing }

extension DashboardVariationX on DashboardVariation {
  String get label => 'Briefing';

  String get blurb =>
      'Classic labeled nav with a morning digest, focus goal, and next actions';
}

enum AppAppearance { light, dark, system }

extension AppAppearanceX on AppAppearance {
  String get label => switch (this) {
        AppAppearance.light => 'Light',
        AppAppearance.dark => 'Dark',
        AppAppearance.system => 'Auto',
      };

  String get blurb => switch (this) {
        AppAppearance.light => 'Bright surfaces and dark ink',
        AppAppearance.dark => 'Dim chrome for low-light sessions',
        AppAppearance.system => 'Follow your device preference',
      };

  ThemeMode get themeMode => switch (this) {
        AppAppearance.light => ThemeMode.light,
        AppAppearance.dark => ThemeMode.dark,
        AppAppearance.system => ThemeMode.system,
      };
}

class VariationController extends ChangeNotifier {
  DashboardVariation dashboard = DashboardVariation.briefing;
  AppAppearance appearance = AppAppearance.light;

  void setDashboard(DashboardVariation value) {
    if (dashboard == value) return;
    dashboard = value;
    notifyListeners();
  }

  void setAppearance(AppAppearance value) {
    if (appearance == value) return;
    appearance = value;
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
