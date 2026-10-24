import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financeai_app/auth/auth_controller.dart';
import 'package:financeai_app/dashboard/recurring_analysis_dialog.dart';
import 'package:financeai_app/dashboard/transactions_controller.dart';

class AnalysisController extends TransactionsController {
  AnalysisController(this.response, {this.failFirst = false})
    : super(AuthController.fake());
  final Map<String, dynamic> response;
  final bool failFirst;
  int calls = 0;
  @override
  Future<Map<String, dynamic>> recurringAnalysis() async {
    calls++;
    if (failFirst && calls == 1) throw Exception('Offline');
    return response;
  }
}

Future<void> open(WidgetTester tester, AnalysisController controller) async {
  await tester.binding.setSurfaceSize(const Size(420, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: TextButton(
              onPressed: () => showRecurringAnalysis(context, controller),
              child: const Text('Open analysis'),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('Open analysis'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty history explains detection and makes no fake rules', (
    tester,
  ) async {
    await open(
      tester,
      AnalysisController({
        'transactionsAnalyzed': 0,
        'patterns': [],
        'totals': [],
      }),
    );
    expect(find.text('Recurring transactions'), findsOneWidget);
    expect(
      find.textContaining('At least three completed transactions'),
      findsOneWidget,
    );
    expect(find.text('Add recurring'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed analysis can be retried', (tester) async {
    final controller = AnalysisController({
      'transactionsAnalyzed': 0,
      'patterns': [],
      'totals': [],
    }, failFirst: true);
    await open(tester, controller);
    expect(find.text('Could not load recurring analysis.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(controller.calls, 2);
    expect(find.text('0 completed transactions · 0 patterns'), findsOneWidget);
  });
  testWidgets(
    'pattern expands to original currency price changes and payment history',
    (tester) async {
      await open(
        tester,
        AnalysisController({
          'transactionsAnalyzed': 3,
          'historyStart': '2026-07-01',
          'historyEnd': '2026-09-01',
          'asOf': '2026-09-05',
          'totals': [],
          'patterns': [
            {
              'name': 'Internet',
              'currency': 'CAD',
              'priceChange': 5,
              'cadence': 'Monthly',
              'count': 3,
              'latestAmount': 55,
              'state': 'Recent',
              'type': 'expense',
              'category': 'Bills',
              'account': 'Cash',
              'confidence': 85,
              'firstDate': '2026-07-01',
              'lastDate': '2026-09-01',
              'nextDate': '2026-10-01',
              'total': 155,
              'average': 51.67,
              'min': 50,
              'max': 55,
              'priceChangePercent': 10,
              'history': [
                {'date': '2026-09-01', 'amount': 55, 'change': 5},
              ],
            },
          ],
        }),
      );
      await tester.tap(find.text('Internet'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Latest change: +CAD 5.00 (10%)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Estimated next date: 2026-10-01'),
        findsOneWidget,
      );
      expect(find.text('CAD 55.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
