import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../dash_colors.dart';
import '../data.dart';
import '../filter_sort.dart';
import '../shimmer.dart';
import '../transactions_scope.dart';
import '../ui.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.m3;
  List<FilterRule> _rules = [];
  List<SortRule> _sorts = [];
  String _search = '';

  static const _fields = [
    FilterFieldDef(id: 'merchant', label: 'Description', type: FilterFieldType.text),
    FilterFieldDef(id: 'category', label: 'Category', type: FilterFieldType.select),
    FilterFieldDef(id: 'amount', label: 'Amount', type: FilterFieldType.number),
    FilterFieldDef(id: 'status', label: 'Status', type: FilterFieldType.select),
  ];

  Object? _txnValue(DemoTxn t, String field) {
    switch (field) {
      case 'merchant':
        return t.merchant;
      case 'type':
        return moneyMoveLabel(t.type);
      case 'category':
        return t.category;
      case 'amount':
        return t.amount;
      case 'status':
        return t.status.name;
      default:
        return t.date;
    }
  }

  void _cyclePeriod() {
    setState(() {
      _period = switch (_period) {
        ReportPeriod.month => ReportPeriod.m3,
        ReportPeriod.m3 => ReportPeriod.ytd,
        ReportPeriod.ytd => ReportPeriod.m12,
        ReportPeriod.m12 => ReportPeriod.month,
      };
    });
  }

  Future<void> _copyCsv({
    required List<CashflowBucket> buckets,
    required List<DemoCategory> cats,
    required double income,
    required double spend,
    required double saved,
    required String rate,
  }) async {
    final buf = StringBuffer()
      ..writeln('FinanceAI Report')
      ..writeln('Period,${_period.label}')
      ..writeln('Income,${income.toStringAsFixed(2)}')
      ..writeln('Spend,${spend.toStringAsFixed(2)}')
      ..writeln('Saved,${saved.toStringAsFixed(2)}')
      ..writeln('Savings rate,%$rate')
      ..writeln()
      ..writeln('Month,Income,Spend,Net');
    for (final b in buckets) {
      buf.writeln(
        '${b.label},${b.inflow.toStringAsFixed(2)},${b.outflow.toStringAsFixed(2)},${b.net.toStringAsFixed(2)}',
      );
    }
    buf
      ..writeln()
      ..writeln('Category,Amount,Pct');
    for (final c in cats) {
      buf.writeln(
        '${c.name},${c.amount.toStringAsFixed(2)},${c.pct.toStringAsFixed(1)}',
      );
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      toast(context, 'CSV summary copied · no PDF export yet');
    }
  }

  List<_InsightLine> _buildInsights({
    required List<DemoCategory> cats,
    required double income,
    required double spend,
    required double saved,
    required String rate,
  }) {
    final lines = <_InsightLine>[];
    if (cats.isEmpty && income == 0 && spend == 0) {
      lines.add(
        const _InsightLine(
          before: 'No transactions in this period yet — add a few to see trends.',
        ),
      );
      return lines;
    }
    if (cats.isNotEmpty) {
      final top = cats.first;
      lines.add(
        _InsightLine(
          before: '${top.name} leads spend at ',
          emphasis: moneyWhole(top.amount),
          after: ' (${top.pct.round()}% of categorized expenses).',
        ),
      );
    }
    if (income > 0) {
      lines.add(
        _InsightLine(
          before: 'Savings rate is ',
          emphasis: '$rate%',
          after:
              ' on ${moneyWhole(income)} in · ${moneyWhole(spend)} out (${moneyWhole(saved)} net).',
        ),
      );
    } else if (spend > 0) {
      lines.add(
        _InsightLine(
          before: 'Spent ',
          emphasis: moneyWhole(spend),
          after: ' with no recorded income in this window.',
        ),
      );
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final loading = TransactionsScope.of(context).loading;
    final txns = TransactionsScope.of(context).transactions;
    final searched = applySearch(txns, _search, _fields, _txnValue);
    final filtered = applySort(
      applyFilters(searched, _rules, _txnValue),
      _sorts,
      _txnValue,
    );

    final periodTxns = txnsInReportPeriod(filtered, _period);
    final buckets = buildCashflowBuckets(
      periodTxns,
      months: _period.monthCount(),
    );
    final incomeSeries = [for (final b in buckets) b.inflow];
    final spendSeries = [for (final b in buckets) b.outflow];
    final months = [for (final b in buckets) b.label];

    final income = incomeSeries.fold<double>(0, (s, v) => s + v);
    final spend = spendSeries.fold<double>(0, (s, v) => s + v);
    final saved = income - spend;
    final rate =
        income == 0 ? '0.0' : ((saved / income) * 100).toStringAsFixed(1);
    final cats = categorySpendBreakdown(periodTxns);

    final categories = {
      ...filtered.map((t) => t.category),
    }.toList()
      ..sort();

    final insights = _buildInsights(
      cats: cats,
      income: income,
      spend: spend,
      saved: saved,
      rate: rate,
    );

    return DashModalScaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          DashFeedChrome(
            title: 'Reports',
            subtitle: 'Cash flow · ${_period.label}',
            onSecondary: _cyclePeriod,
            secondaryIcon: Icons.date_range_outlined,
            secondaryTooltip: _period.label,
            onPrimary: () => _copyCsv(
              buckets: buckets,
              cats: cats,
              income: income,
              spend: spend,
              saved: saved,
              rate: rate,
            ),
            primaryIcon: Icons.download_outlined,
            primaryTooltip: 'Copy CSV summary',
            metaLine:
                'Income ${moneyWhole(income)} · Spend ${moneyWhole(spend)} · Saved ${moneyWhole(saved)}',
            filterBar: FilterSortBar(
              fields: _fields,
              rules: _rules,
              sorts: _sorts,
              search: _search,
              onSearchChanged: (v) => setState(() => _search = v),
              searchHint: 'Search…',
              onRulesChanged: (r) => setState(() => _rules = r),
              onSortsChanged: (s) => setState(() => _sorts = s),
              selectOptions: (field) {
                if (field == 'status') {
                  return TxnStatus.values.map((e) => e.name).toList();
                }
                if (field == 'category') return categories;
                return const [];
              },
              defaultFilterField: 'category',
              defaultSortField: 'amount',
              iconButtons: true,
              expandSearch: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: _PeriodChips(
              value: _period,
              onChanged: (p) => setState(() => _period = p),
            ),
          ),
          if (loading)
            const DashLoadingBody(kpiCount: 1, listRows: 5)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
                    child: Text(
                      'Income vs spend · ${_period.label}',
                      style: TextStyle(
                        color: context.dashMute,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        _Legend(color: Color(0xFFC7C3FF), label: 'Income'),
                        SizedBox(width: 14),
                        _Legend(color: AppColors.accent, label: 'Spend'),
                      ],
                    ),
                  ),
                  if (periodTxns.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Text(
                        'No transactions in ${_period.label.toLowerCase()}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.dashMute,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    IncomeSpendBars(
                      months: months,
                      income: incomeSeries,
                      spend: spendSeries,
                    ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
                    child: Text(
                      'Spend by category',
                      style: TextStyle(
                        color: context.dashMute,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (cats.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No expense categories yet',
                        style: TextStyle(
                          color: context.dashMute,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    for (final c in cats)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: context.dashLine),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.name,
                                    style: TextStyle(
                                      color: context.dashInk,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${moneyWhole(c.amount)} · ${spend == 0 ? 0 : ((c.amount / spend) * 100).round()}%',
                                  style: TextStyle(
                                    color: context.dashMute,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ProgressTrack(
                              progress: spend == 0 ? 0 : c.amount / spend,
                              color: c.color,
                              height: 4,
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
                    child: Text(
                      'Insights',
                      style: TextStyle(
                        color: context.dashMute,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final line in insights)
                    _Insight(line: line),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InsightLine {
  const _InsightLine({
    required this.before,
    this.emphasis,
    this.after,
  });

  final String before;
  final String? emphasis;
  final String? after;
}

class _PeriodChips extends StatelessWidget {
  const _PeriodChips({required this.value, required this.onChanged});

  final ReportPeriod value;
  final ValueChanged<ReportPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.dashPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.dashLine),
      ),
      child: Row(
        children: [
          for (final p in ReportPeriod.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: value == p
                        ? context.dashElevated
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    p.shortLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          value == p ? FontWeight.w700 : FontWeight.w500,
                      color: value == p ? context.dashInk : context.dashMute,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: context.dashMute,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Insight extends StatelessWidget {
  const _Insight({required this.line});

  final _InsightLine line;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.dashLine)),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            color: context.dashInk,
            fontSize: 14,
            height: 1.4,
          ),
          children: [
            TextSpan(text: line.before),
            if (line.emphasis != null)
              TextSpan(
                text: line.emphasis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            if (line.after != null) TextSpan(text: line.after),
          ],
        ),
      ),
    );
  }
}
