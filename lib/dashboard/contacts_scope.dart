import 'package:flutter/widgets.dart';

import 'contacts_controller.dart';

class ContactsScope extends InheritedNotifier<ContactsController> {
  const ContactsScope({
    super.key,
    required ContactsController controller,
    required super.child,
  }) : super(notifier: controller);

  static ContactsController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ContactsScope>();
    assert(scope != null, 'ContactsScope not found');
    return scope!.notifier!;
  }

  static ContactsController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ContactsScope>()
        ?.notifier;
  }
}
