import 'package:flutter/material.dart';

import 'transactions_controller.dart';

class TransactionsScope extends InheritedNotifier<TransactionsController> {
  const TransactionsScope({
    super.key,
    required TransactionsController controller,
    required super.child,
  }) : super(notifier: controller);

  static TransactionsController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<TransactionsScope>();
    assert(scope != null, 'TransactionsScope not found');
    return scope!.notifier!;
  }

  static TransactionsController read(BuildContext context) {
    final scope =
        context.getInheritedWidgetOfExactType<TransactionsScope>();
    assert(scope != null, 'TransactionsScope not found');
    return scope!.notifier!;
  }
}
