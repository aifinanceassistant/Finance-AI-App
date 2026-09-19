import 'package:flutter/material.dart';

import 'accounts_controller.dart';

class AccountsScope extends InheritedNotifier<AccountsController> {
  const AccountsScope({
    super.key,
    required AccountsController controller,
    required super.child,
  }) : super(notifier: controller);

  static AccountsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AccountsScope>();
    assert(scope != null, 'AccountsScope not found');
    return scope!.notifier!;
  }

  static AccountsController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AccountsScope>();
    assert(scope != null, 'AccountsScope not found');
    return scope!.notifier!;
  }
}
