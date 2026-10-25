import 'package:flutter/material.dart';

import 'dash_colors.dart';
import 'transactions_controller.dart';

enum RecurringLayout { ledger, cards, timeline }

extension on RecurringLayout {
  String get label => switch (this) {
    RecurringLayout.ledger => 'Ledger',
    RecurringLayout.cards => 'Cards',
    RecurringLayout.timeline => 'Timeline',
  };
}

RecurringLayout _savedLayout = RecurringLayout.ledger;

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
  const _RecurringAnalysisDialog({
    required this.controller,
    this.fullPage = false,
    this.initialLayout,
  });
  final TransactionsController controller;
  final bool fullPage;
  final RecurringLayout? initialLayout;
  @override
  State<_RecurringAnalysisDialog> createState() =>
      _RecurringAnalysisDialogState();
}

class _RecurringAnalysisDialogState extends State<_RecurringAnalysisDialog> {
  late Future<Map<String, dynamic>> _request = widget.controller
      .recurringAnalysis();
  late RecurringLayout _layout = widget.initialLayout ?? _savedLayout;
  String _search = '';
  String _filter = 'All';
  String _money(Object? value, String currency) =>
      '$currency ${((value as num?) ?? 0).toStringAsFixed(2)}';
  List<Map<String, dynamic>> _list(Object? value) =>
      value is List ? value.whereType<Map<String, dynamic>>().toList() : [];

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        if (!widget.fullPage)
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
                  tooltip: 'Full page',
                  icon: const Icon(Icons.open_in_full),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _RecurringAnalysisDialog(
                          controller: widget.controller,
                          fullPage: true,
                          initialLayout: _layout,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Variation',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SegmentedButton<RecurringLayout>(
                segments: [
                  for (final v in RecurringLayout.values)
                    ButtonSegment(value: v, label: Text(v.label)),
                ],
                selected: {_layout},
                onSelectionChanged: (value) => setState(() {
                  _layout = value.first;
                  _savedLayout = _layout;
                }),
              ),
            ],
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
                    '${all.length} recurring · ${data['transactionsAnalyzed']} transactions',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${data['historyStart'] ?? '—'} – ${data['historyEnd'] ?? '—'}',
                    style: TextStyle(fontSize: 12, color: context.dashMute),
                  ),
                  for (final t in _list(data['totals']))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '${t['currency']} / month\nExpenses ${_money(t['monthlyExpenses'], t['currency'] as String)} · Income ${_money(t['monthlyIncome'], t['currency'] as String)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search recurring transactions',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
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
                  const SizedBox(height: 12),
                  if (patterns.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        all.isEmpty
                            ? 'No recurring transactions found yet.'
                            : 'No matches.',
                      ),
                    )
                  else
                    switch (_layout) {
                      RecurringLayout.ledger => _ledger(patterns),
                      RecurringLayout.cards => _cards(patterns),
                      RecurringLayout.timeline => _timeline(patterns),
                    },
                ],
              );
            },
          ),
        ),
      ],
    );
    if (widget.fullPage) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recurring transactions')),
        body: SafeArea(child: content),
      );
    }
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: content,
    );
  }

  String _change(Map<String, dynamic> p) {
    final change = (p['priceChange'] as num).toDouble();
    return change == 0
        ? 'Unchanged'
        : '${change > 0 ? '+' : ''}${_money(change, p['currency'] as String)} (${p['priceChangePercent']}%)';
  }

  Color _changeColor(Map<String, dynamic> p) => (p['priceChange'] as num) > 0
      ? const Color(0xFFC24145)
      : const Color(0xFF0D9488);
  void _openPattern(Map<String, dynamic> p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .75,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${p['name']}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close details',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            _details(p),
          ],
        ),
      ),
    );
  }

  Widget _ledger(List<Map<String, dynamic>> patterns) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        columnSpacing: 22,
        columns: [
          for (final label in [
            'Description',
            'Frequency',
            'Transactions',
            'Latest',
            'Price change',
            'Next expected',
          ])
            DataColumn(label: Text(label)),
        ],
        rows: [
          for (final p in patterns)
            DataRow(
              onSelectChanged: (_) => _openPattern(p),
              cells: [
                DataCell(
                  Text(
                    '${p['name']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DataCell(Text('${p['cadence']}')),
                DataCell(Text('${p['count']}')),
                DataCell(
                  Text(_money(p['latestAmount'], p['currency'] as String)),
                ),
                DataCell(
                  Text(_change(p), style: TextStyle(color: _changeColor(p))),
                ),
                DataCell(
                  Text(
                    p['state'] == 'Possibly stopped'
                        ? 'Possibly stopped'
                        : '${p['nextDate']}',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cards(List<Map<String, dynamic>> patterns) {
    return Column(
      children: [
        for (final p in patterns)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _openPattern(p),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${p['name']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          '${p['cadence']}',
                          style: TextStyle(color: context.dashMute),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _money(p['latestAmount'], p['currency'] as String),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                      ),
                    ),
                    Text(
                      _change(p),
                      style: TextStyle(color: _changeColor(p), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 42,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _PriceTrend(
                          _list(p['history'])
                              .map((t) => (t['amount'] as num).toDouble())
                              .toList(),
                          _changeColor(p),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text('${p['count']} transactions'),
                        Text(
                          p['state'] == 'Possibly stopped'
                              ? 'Possibly stopped'
                              : 'Next ${p['nextDate']}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _timeline(List<Map<String, dynamic>> patterns) {
    final ordered = [...patterns]
      ..sort(
        (a, b) => (a['nextDate'] as String).compareTo(b['nextDate'] as String),
      );
    final dates = ordered.map((p) => p['nextDate'] as String).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final date in dates) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              date,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.dashMute,
              ),
            ),
          ),
          for (final p in ordered.where((p) => p['nextDate'] == date))
            Card(
              child: ListTile(
                onTap: () => _openPattern(p),
                leading: const Icon(Icons.event_repeat),
                title: Text('${p['name']}'),
                subtitle: Text(
                  '${p['cadence']} · ${p['count']} transactions${p['state'] == 'Possibly stopped' ? ' · Possibly stopped' : ''}',
                ),
                trailing: Text(
                  _money(p['latestAmount'], p['currency'] as String),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _details(Map<String, dynamic> p) {
    final currency = p['currency'] as String;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${p['category']} · ${p['account']} · ${p['cadence']}'),
        const SizedBox(height: 16),
        Text(
          'Total recorded: ${_money(p['total'], currency)}\nAverage: ${_money(p['average'], currency)}\nRange: ${_money(p['min'], currency)} – ${_money(p['max'], currency)}\nLatest change: ${_change(p)}\nEstimated next date: ${p['nextDate']}',
        ),
        const SizedBox(height: 16),
        const Text(
          'Payment history',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        for (final t in _list(p['history']).reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text('${t['date']}')),
                Text(_money(t['amount'], currency)),
                const SizedBox(width: 12),
                Text(t['change'] == null ? '—' : _money(t['change'], currency)),
              ],
            ),
          ),
      ],
    );
  }
}

class _PriceTrend extends CustomPainter {
  _PriceTrend(this.amounts, this.color);
  final List<double> amounts;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (amounts.isEmpty) {
      return;
    }
    final sorted = [...amounts]..sort();
    final low = sorted.first, high = sorted.last;
    final path = Path();
    for (var i = 0; i < amounts.length; i++) {
      final x = amounts.length == 1
          ? size.width / 2
          : i / (amounts.length - 1) * size.width;
      final y = high == low
          ? size.height / 2
          : size.height -
                4 -
                (amounts[i] - low) / (high - low) * (size.height - 8);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _PriceTrend oldDelegate) =>
      oldDelegate.amounts != amounts || oldDelegate.color != color;
}
