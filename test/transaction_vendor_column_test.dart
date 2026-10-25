import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:financeai_app/auth/auth_controller.dart';
import 'package:financeai_app/auth/auth_scope.dart';
import 'package:financeai_app/dashboard/shell.dart';
import 'package:financeai_app/variations/models.dart';

void main() {
  testWidgets('transactions show a Vendor column on a phone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AuthScope(
        controller: AuthController.fake(),
        child: VariationScope(
          controller: VariationController(),
          child: const MaterialApp(
            home: DashboardShell(initialTab: DashTab.transactions),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Vendor'), findsOneWidget);
    expect(find.text('Amount'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
