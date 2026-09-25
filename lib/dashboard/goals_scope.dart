import 'package:flutter/material.dart';

import 'goals_controller.dart';

class GoalsScope extends InheritedNotifier<GoalsController> {
  const GoalsScope({
    super.key,
    required GoalsController controller,
    required super.child,
  }) : super(notifier: controller);

  static GoalsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GoalsScope>();
    assert(scope != null, 'GoalsScope not found');
    return scope!.notifier!;
  }

  static GoalsController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GoalsScope>()?.notifier;
  }

  static GoalsController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<GoalsScope>();
    assert(scope != null, 'GoalsScope not found');
    return scope!.notifier!;
  }
}
