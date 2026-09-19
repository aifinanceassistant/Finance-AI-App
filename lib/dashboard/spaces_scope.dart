import 'package:flutter/material.dart';

import 'spaces.dart';

class SpacesScope extends InheritedNotifier<SpacesController> {
  const SpacesScope({
    super.key,
    required SpacesController controller,
    required super.child,
  }) : super(notifier: controller);

  static SpacesController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SpacesScope>();
    assert(scope != null, 'SpacesScope not found');
    return scope!.notifier!;
  }

  static SpacesController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SpacesScope>();
    assert(scope != null, 'SpacesScope not found');
    return scope!.notifier!;
  }
}
