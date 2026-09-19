import 'package:flutter/material.dart';

import '../dashboard/shell.dart';
import '../onboarding/onboarding_flow.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/landing_screen.dart';
import 'auth_controller.dart';
import 'auth_scope.dart';

Future<void> goAfterAuth(BuildContext context) async {
  final auth = AuthScope.read(context);
  if (auth.needsPasswordReset) {
    if (!context.mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const ResetPasswordScreen()),
      (route) => false,
    );
    return;
  }
  await auth.syncProfile();
  if (!context.mounted) return;
  final dest = auth.destinationForSession();
  final Widget page = switch (dest) {
    AuthDestination.resetPassword => const ResetPasswordScreen(),
    AuthDestination.onboarding => const OnboardingFlow(),
    AuthDestination.dashboard => const DashboardShell(),
    AuthDestination.landing => const LandingScreen(),
  };
  await Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => page),
    (route) => false,
  );
}

Future<void> goLoggedOut(BuildContext context) async {
  final auth = AuthScope.read(context);
  await auth.logout();
  if (!context.mounted) return;
  await Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LandingScreen()),
    (route) => false,
  );
}

void showAuthError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
