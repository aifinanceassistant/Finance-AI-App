import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financeai_app/auth/auth_controller.dart';
import 'package:financeai_app/auth/auth_scope.dart';
import 'package:financeai_app/dashboard/shell.dart';
import 'package:financeai_app/main.dart';
import 'package:financeai_app/onboarding/onboarding_flow.dart';
import 'package:financeai_app/screens/auth/login_screen.dart';
import 'package:financeai_app/screens/auth/register_screen.dart';
import 'package:financeai_app/variations/models.dart';

Widget wrapApp(Widget home, {AuthController? auth}) {
  final controller = auth ?? AuthController.fake();
  return AuthScope(
    controller: controller,
    child: VariationScope(
      controller: VariationController(),
      child: MaterialApp(home: home),
    ),
  );
}

void main() {
  testWidgets('Landing shows stacked hero with classic copy', (tester) async {
    await tester.pumpWidget(const FinanceAiApp());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('\$1,284,200'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
    expect(find.text('Variations'), findsNothing);
  });

  testWidgets('Dashboard opens briefing home without top bar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrapApp(const DashboardShell()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Good Morning, Alex'), findsOneWidget);
    expect(find.text('Family budget'), findsNothing);
    expect(find.text('Get help'), findsNothing);
    expect(find.text('Variations'), findsNothing);
    expect(find.text('Today\'s digest'), findsOneWidget);
  });

  testWidgets('Demo mode opens the dashboard', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const FinanceAiApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.tap(find.text('Demo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DashboardShell), findsOneWidget);
    expect(find.text('Good Morning, Alex'), findsOneWidget);
    expect(find.text('Variations'), findsNothing);
  });

  testWidgets('Get started opens register with social options', (tester) async {
    await tester.pumpWidget(const FinanceAiApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Sign up with Google'), findsOneWidget);
  });

  testWidgets('Log in opens login with forgot password', (tester) async {
    await tester.pumpWidget(const FinanceAiApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('Register continues into onboarding hear step', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final auth = AuthController.fake();
    await auth.init();

    await tester.pumpWidget(wrapApp(const RegisterScreen(), auth: auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Alex Rivera');
    await tester.enterText(find.byType(TextFormField).at(1), 'alex@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password1');

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    checkbox.onChanged?.call(true);
    await tester.pump();

    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(find.text('How did you hear about us?'), findsOneWidget);
  });

  testWidgets('Onboarding hear step advances to security', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrapApp(const OnboardingFlow()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Friend or Family'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('PROTECT YOUR LOGIN'), findsOneWidget);
  });

  testWidgets('Login opens dashboard home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final auth = AuthController.fake();
    await auth.init();

    await tester.pumpWidget(wrapApp(const LoginScreen(), auth: auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'alex@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password1');
    await tester.ensureVisible(find.text('Log in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Log in').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DashboardShell), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Good Morning, Alex'), findsOneWidget);
  });

  testWidgets('Dashboard more tab opens goals', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrapApp(const DashboardShell()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('More'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Emergency fund, trips, and more'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Emergency fund'), findsOneWidget);
    expect(find.text('Summer trip'), findsOneWidget);
  });
}
