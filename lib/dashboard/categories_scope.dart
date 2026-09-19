import 'package:flutter/material.dart';

import 'categories_controller.dart';

class CategoriesScope extends InheritedNotifier<CategoriesController> {
  const CategoriesScope({
    super.key,
    required CategoriesController controller,
    required super.child,
  }) : super(notifier: controller);

  static CategoriesController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<CategoriesScope>();
    assert(scope != null, 'CategoriesScope not found');
    return scope!.notifier!;
  }

  static CategoriesController read(BuildContext context) {
    final scope =
        context.getInheritedWidgetOfExactType<CategoriesScope>();
    assert(scope != null, 'CategoriesScope not found');
    return scope!.notifier!;
  }
}
