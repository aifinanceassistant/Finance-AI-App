import 'package:flutter/material.dart';

import '../dashboard/shell.dart';
import '../onboarding/onboarding_flow.dart';
import '../screens/auth/mfa_challenge_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/landing_screen.dart';
import 'auth_controller.dart';
import 'auth_scope.dart';

Future<void> goAfterAuth(BuildContext context) async {
  final auth = AuthScope.read(context);
  // Auth notifies multiple times (session, profile, FX). Navigate only once.
  if (!auth.beginPostAuthNavigation()) return;

  await auth.closeAuthBrowser();
  if (!context.mounted) return;

  if (auth.needsPasswordReset) {
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const ResetPasswordScreen()),
      (route) => false,
    );
    return;
  }
  if (!auth.mfaRequired) await auth.syncProfile();
  if (!context.mounted) return;
  await goToDestination(context);
}

Widget pageForDestination(AuthDestination dest) => switch (dest) {
  AuthDestination.resetPassword => const ResetPasswordScreen(),
  AuthDestination.mfa => const MfaChallengeScreen(),
  AuthDestination.onboarding => const OnboardingFlow(),
  AuthDestination.dashboard => const DashboardShell(),
  AuthDestination.landing => const LandingScreen(),
};

/// Replaces the stack with wherever the current session belongs.
Future<void> goToDestination(BuildContext context) async {
  final auth = AuthScope.read(context);
  await auth.waitForProfile();
  if (!context.mounted) return;
  final page = pageForDestination(auth.destinationForSession());
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
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
