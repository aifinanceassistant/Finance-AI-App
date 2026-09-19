import 'package:flutter/material.dart';

import 'recurring_controller.dart';

class RecurringScope extends InheritedNotifier<RecurringController> {
  const RecurringScope({
    super.key,
    required RecurringController controller,
    required super.child,
  }) : super(notifier: controller);

  static RecurringController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RecurringScope>();
    assert(scope != null, 'RecurringScope not found');
    return scope!.notifier!;
  }

  static RecurringController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<RecurringScope>();
    assert(scope != null, 'RecurringScope not found');
    return scope!.notifier!;
  }
}
