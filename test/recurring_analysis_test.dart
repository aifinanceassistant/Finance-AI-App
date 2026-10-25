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

Map<String, dynamic> pattern(String id, String name) => {
  'id': id,
  'name': name,
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
  'monthlyEstimate': 55,
  'history': [
    {'date': '2026-09-01', 'amount': 55, 'change': 5},
  ],
};
Map<String, dynamic> data() => {
  'transactionsAnalyzed': 6,
  'historyStart': '2026-07-01',
  'historyEnd': '2026-09-01',
  'patterns': [pattern('internet', 'Internet'), pattern('fitness', 'Fitness')],
  'totals': [],
};
const cardsPane = ValueKey('recurring-cards-pane');
const detailsPane = ValueKey('recurring-details-pane');
Future<void> open(
  WidgetTester tester,
  AnalysisController controller, {
  Size size = const Size(420, 1000),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showRecurringAnalysis(context, controller),
            child: const Text('Open analysis'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open analysis'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens full screen directly with concise empty state', (
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
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('No recurring transactions found yet.'), findsOneWidget);
    expect(find.text('Variation'), findsNothing);
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
    expect(find.text('0 recurring · 0 transactions'), findsOneWidget);
  });
  testWidgets('wide layout gives cards 30 percent and details 70 percent', (
    tester,
  ) async {
    final controller = AnalysisController(data());
    await open(tester, controller, size: const Size(1200, 900));
    final left = tester.getSize(find.byKey(cardsPane));
    final right = tester.getSize(find.byKey(detailsPane));
    expect(left.width, closeTo(360, 1));
    expect(right.width, closeTo(840, 1));
    expect(
      tester.getTopLeft(find.byKey(detailsPane)).dy,
      tester.getTopLeft(find.byKey(cardsPane)).dy,
    );
    expect(
      find.descendant(
        of: find.byKey(detailsPane),
        matching: find.text('Internet'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(cardsPane),
        matching: find.text('Fitness'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(detailsPane),
        matching: find.text('Fitness'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(detailsPane),
        matching: find.text('Internet'),
      ),
      findsNothing,
    );
    expect(controller.calls, 1);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('phone stacks cards and inline details without overflow', (
    tester,
  ) async {
    await open(tester, AnalysisController(data()));
    expect(
      tester.getTopLeft(find.byKey(detailsPane)).dy,
      greaterThan(tester.getTopLeft(find.byKey(cardsPane)).dy),
    );
    expect(
      find.descendant(
        of: find.byKey(detailsPane),
        matching: find.text('Internet'),
      ),
      findsOneWidget,
    );
    expect(find.text('+CAD 5.00 (10%)'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'search selects a matching card and clears stale details for no results',
    (tester) async {
      final controller = AnalysisController(data());
      await open(tester, controller, size: const Size(1200, 900));
      await tester.enterText(find.byType(TextField), 'Fitness');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(detailsPane),
          matching: find.text('Fitness'),
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'No matching payment');
      await tester.pumpAndSettle();
      expect(find.text('No matches.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(detailsPane),
          matching: find.text('Fitness'),
        ),
        findsNothing,
      );
      expect(controller.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
