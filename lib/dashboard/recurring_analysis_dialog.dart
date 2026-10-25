import 'package:flutter/material.dart';

import 'dash_colors.dart';
import 'recurring_price_chart.dart';
import 'transactions_controller.dart';

Future<void> showRecurringAnalysis(
  BuildContext context,
  TransactionsController controller,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => RecurringAnalysisScreen(controller: controller),
    ),
  );
}

class RecurringAnalysisScreen extends StatefulWidget {
  const RecurringAnalysisScreen({super.key, required this.controller});
  final TransactionsController controller;
  @override
  State<RecurringAnalysisScreen> createState() =>
      _RecurringAnalysisScreenState();
}

class _RecurringAnalysisScreenState extends State<RecurringAnalysisScreen> {
  late Future<Map<String, dynamic>> _request = widget.controller
      .recurringAnalysis();
  final _searchController = TextEditingController();
  String _search = '';
  String _filter = 'All';
  String? _selectedId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _list(Object? value) =>
      value is List ? value.whereType<Map<String, dynamic>>().toList() : [];
  String _id(Map<String, dynamic> pattern) =>
      (pattern['id'] ?? pattern['name']).toString();
  String _money(Object? value, String currency) =>
      '$currency ${((value as num?) ?? 0).toStringAsFixed(2)}';
  String _change(Map<String, dynamic> pattern) {
    final change = (pattern['priceChange'] as num).toDouble();
    return change == 0
        ? 'Unchanged'
        : '${change > 0 ? '+' : ''}${_money(change, pattern['currency'] as String)} (${pattern['priceChangePercent']}%)';
  }

  Color _changeColor(Map<String, dynamic> pattern) {
    final change = (pattern['priceChange'] as num).toDouble();
    if (change == 0) return const Color(0xFF697386);
    final favorable = pattern['type'] == 'income' ? change > 0 : change < 0;
    return favorable ? const Color(0xFF0D9488) : const Color(0xFFC24145);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring transactions')),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _request,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load recurring analysis.'),
                    TextButton(
                      onPressed: () {
                        final next = widget.controller.recurringAnalysis();
                        setState(() {
                          _request = next;
                        });
                      },
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              );
            }
            final data = snapshot.data!;
            final all = _list(data['patterns']);
            final patterns = all.where((pattern) {
              final matchesSearch =
                  '${pattern['name']} ${pattern['category']} ${pattern['account']}'
                      .toLowerCase()
                      .contains(_search.toLowerCase());
              return matchesSearch &&
                  switch (_filter) {
                    'Expenses' => pattern['type'] == 'expense',
                    'Income' => pattern['type'] == 'income',
                    'Price changed' => pattern['priceChange'] != 0,
                    'Possibly stopped' =>
                      pattern['state'] == 'Possibly stopped',
                    _ => true,
                  };
            }).toList();
            Map<String, dynamic>? selected;
            for (final pattern in patterns) {
              if (_id(pattern) == _selectedId) selected = pattern;
            }
            selected ??= patterns.isEmpty ? null : patterns.first;
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final cards = _cardsPane(patterns, selected, data, wide);
                final details = _detailsPane(selected);
                if (wide) {
                  return Row(
                    children: [
                      Expanded(flex: 3, child: cards),
                      Expanded(flex: 7, child: details),
                    ],
                  );
                }
                return Column(
                  children: [
                    Expanded(flex: 2, child: cards),
                    Expanded(flex: 3, child: details),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _cardsPane(
    List<Map<String, dynamic>> patterns,
    Map<String, dynamic>? selected,
    Map<String, dynamic> data,
    bool wide,
  ) {
    return Container(
      key: const ValueKey('recurring-cards-pane'),
      decoration: BoxDecoration(
        color: context.dashPanel,
        border: wide
            ? Border(right: BorderSide(color: context.dashLine))
            : Border(bottom: BorderSide(color: context.dashLine)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Search recurring transactions',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _filter,
            isExpanded: true,
            items: [
              for (final value in [
                'All',
                'Expenses',
                'Income',
                'Price changed',
                'Possibly stopped',
              ])
                DropdownMenuItem(
                  value: value,
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _filter = value ?? 'All'),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${patterns.length} recurring · ${data['transactionsAnalyzed']} transactions',
              style: TextStyle(fontSize: 12, color: context.dashMute),
            ),
          ),
          if (patterns.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _search.isNotEmpty || _filter != 'All'
                    ? 'No matches.'
                    : 'No recurring transactions found yet.',
              ),
            ),
          for (final pattern in patterns)
            _card(pattern, selected != null && _id(pattern) == _id(selected)),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> pattern, bool selected) {
    return Card(
      color: selected ? context.dashWash : context.dashPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? const Color(0xFF79B8E7) : context.dashLine,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        selected: selected,
        child: InkWell(
          onTap: () => setState(() => _selectedId = _id(pattern)),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pattern['name']}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${pattern['category']} · ${pattern['cadence']}',
                  style: TextStyle(fontSize: 12, color: context.dashMute),
                ),
                const SizedBox(height: 10),
                Text(
                  _money(
                    pattern['latestAmount'],
                    pattern['currency'] as String,
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _change(pattern),
                  style: TextStyle(color: _changeColor(pattern), fontSize: 12),
                ),
                const SizedBox(height: 10),
                if (pattern['evidence'] == 'Possible')
                  const Text(
                    'Possible',
                    style: TextStyle(fontSize: 11, color: Color(0xFF946200)),
                  ),
                RecurringPriceChart(
                  key: ValueKey('chart-${_id(pattern)}'),
                  history: _list(pattern['history']),
                  currency: pattern['currency'] as String,
                  name: '${pattern['name']}',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${pattern['count']} transactions',
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      pattern['state'] == 'Possibly stopped'
                          ? 'Possibly stopped'
                          : 'Next ${pattern['nextDate']}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailsPane(Map<String, dynamic>? pattern) {
    return Container(
      key: const ValueKey('recurring-details-pane'),
      color: context.dashSurface,
      child: pattern == null
          ? const Center(child: Text('Select a recurring transaction'))
          : ListView(
              key: ValueKey('details-${_id(pattern)}'),
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '${pattern['name']}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: context.dashInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${pattern['category']} · ${pattern['account']} · ${pattern['cadence']}',
                  style: TextStyle(color: context.dashMute),
                ),
                const SizedBox(height: 20),
                Text(
                  _money(
                    pattern['latestAmount'],
                    pattern['currency'] as String,
                  ),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _change(pattern),
                  style: TextStyle(color: _changeColor(pattern)),
                ),
                const SizedBox(height: 20),
                _metric(
                  'Total recorded',
                  _money(pattern['total'], pattern['currency'] as String),
                ),
                _metric(
                  'Average',
                  _money(pattern['average'], pattern['currency'] as String),
                ),
                _metric('Transactions', '${pattern['count']}'),
                _metric(
                  'Monthly estimate',
                  _money(
                    pattern['monthlyEstimate'],
                    pattern['currency'] as String,
                  ),
                ),
                _metric(
                  'Next expected',
                  pattern['state'] == 'Possibly stopped'
                      ? 'Possibly stopped'
                      : '${pattern['nextDate']}',
                ),
                _metric(
                  'Amount range',
                  '${_money(pattern['min'], pattern['currency'] as String)} – ${_money(pattern['max'], pattern['currency'] as String)}',
                ),
                const SizedBox(height: 20),
                Text(
                  'Payment history · ${pattern['currency']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final row in _list(pattern['history']).reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(child: Text('${row['date']}')),
                        Text(
                          _money(row['amount'], pattern['currency'] as String),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          row['change'] == null
                              ? '—'
                              : _money(
                                  row['change'],
                                  pattern['currency'] as String,
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.dashPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.dashLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.dashMute, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
