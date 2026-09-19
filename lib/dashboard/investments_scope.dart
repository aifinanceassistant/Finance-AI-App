import 'package:flutter/material.dart';

import 'investments_controller.dart';

class InvestmentsScope extends InheritedNotifier<InvestmentsController> {
  const InvestmentsScope({
    super.key,
    required InvestmentsController controller,
    required super.child,
  }) : super(notifier: controller);

  static InvestmentsController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<InvestmentsScope>();
    assert(scope != null, 'InvestmentsScope not found');
    return scope!.notifier!;
  }

  static InvestmentsController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<InvestmentsScope>();
    assert(scope != null, 'InvestmentsScope not found');
    return scope!.notifier!;
  }
}
