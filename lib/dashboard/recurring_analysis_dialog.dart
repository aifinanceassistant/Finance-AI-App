import 'package:flutter/material.dart';

import 'dash_colors.dart';
import 'transactions_controller.dart';

Future<void> showRecurringAnalysis(
  BuildContext context,
  TransactionsController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.dashPanel,
    builder: (_) => _RecurringAnalysisDialog(controller: controller),
  );
}

class _RecurringAnalysisDialog extends StatefulWidget {
  const _RecurringAnalysisDialog({required this.controller});
  final TransactionsController controller;
  @override
  State<_RecurringAnalysisDialog> createState() =>
      _RecurringAnalysisDialogState();
}

class _RecurringAnalysisDialogState extends State<_RecurringAnalysisDialog> {
  late Future<Map<String, dynamic>> _request = widget.controller
      .recurringAnalysis();
  String _search = '';
  String _filter = 'All';
  String _money(Object? value, String currency) =>
      '$currency ${((value as num?) ?? 0).toStringAsFixed(2)}';
  List<Map<String, dynamic>> _list(Object? value) =>
      value is List ? value.whereType<Map<String, dynamic>>().toList() : [];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recurring transactions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Detected from recorded transactions. Dates and totals are estimates; nothing is posted automatically.',
            ),
          ),
          Expanded(
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
                            final request = widget.controller
                                .recurringAnalysis();
                            setState(() {
                              _request = request;
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
                final patterns = all.where((p) {
                  final text = '${p['name']} ${p['category']} ${p['account']}'
                      .toLowerCase();
                  return text.contains(_search.toLowerCase()) &&
                      switch (_filter) {
                        'Expenses' => p['type'] == 'expense',
                        'Income' => p['type'] == 'income',
                        'Price changed' => p['priceChange'] != 0,
                        'Possibly stopped' => p['state'] == 'Possibly stopped',
                        _ => true,
                      };
                }).toList();
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      '${data['transactionsAnalyzed']} completed transactions · ${all.length} patterns',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${data['historyStart'] ?? 'No history'} – ${data['historyEnd'] ?? '—'} · As of ${data['asOf'] ?? 'today'}',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Uses all available history for this space, independent of table filters. Currencies are kept separate.',
                    ),
                    for (final total in _list(data['totals']))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '${total['currency']} monthly estimate\nExpenses ${_money(total['monthlyExpenses'], total['currency'] as String)} · Income ${_money(total['monthlyIncome'], total['currency'] as String)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search recurring transactions',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _filter,
                      isExpanded: true,
                      items: [
                        for (final f in [
                          'All',
                          'Expenses',
                          'Income',
                          'Price changed',
                          'Possibly stopped',
                        ])
                          DropdownMenuItem(value: f, child: Text(f)),
                      ],
                      onChanged: (v) => setState(() => _filter = v ?? 'All'),
                    ),
                    if (patterns.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          all.isEmpty
                              ? 'No recurring patterns yet. At least three completed transactions on a consistent weekly, fortnightly, monthly, quarterly or yearly schedule are needed.'
                              : 'No matching patterns.',
                        ),
                      ),
                    for (final p in patterns)
                      _pattern(p, data['asOf'] as String? ?? ''),
                    const SizedBox(height: 16),
                    const Text(
                      'Detection uses description, contact, account, currency and timing. Transfers, pending, failed, rejected and future entries are excluded. Missing payments do not prove cancellation.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _pattern(Map<String, dynamic> p, String asOf) {
    final currency = p['currency'] as String;
    final change = (p['priceChange'] as num).toDouble();
    return Card(
      child: ExpansionTile(
        title: Text(
          '${p['name']}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${p['cadence']} · ${p['count']} transactions\n${_money(p['latestAmount'], currency)} · ${p['state']}',
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${p['type']} · ${p['category']} · ${p['account']}\n${p['confidence']}% pattern confidence\nFirst ${p['firstDate']} · Last ${p['lastDate']}\n${(p['nextDate'] as String).compareTo(asOf) < 0 ? 'Expected date (unobserved)' : 'Estimated next date'}: ${p['nextDate']}',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Total recorded: ${_money(p['total'], currency)}\nAverage: ${_money(p['average'], currency)}\nRange: ${_money(p['min'], currency)} – ${_money(p['max'], currency)}\nLatest change: ${change > 0 ? '+' : ''}${_money(change, currency)} (${p['priceChangePercent']}%)',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Changes compare recorded amounts in the original currency. Variable bills can change without a subscription price change.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final t in _list(p['history']).reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(child: Text('${t['date']}')),
                  Text(_money(t['amount'], currency)),
                  const SizedBox(width: 12),
                  Text(
                    t['change'] == null ? '—' : _money(t['change'], currency),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
