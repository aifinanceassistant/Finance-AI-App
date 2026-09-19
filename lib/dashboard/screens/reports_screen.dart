import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../data.dart';
import '../filter_sort.dart';
import '../ui.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _period = 6;
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

  @override
  Widget build(BuildContext context) {
    final searched =
        applySearch(demoTransactions, _search, _fields, _txnValue);
    final filtered = applySort(
      applyFilters(searched, _rules, _txnValue),
      _sorts,
      _txnValue,
    );
    final incomeNow = filtered
        .where((t) => t.amount > 0)
        .fold<double>(0, (s, t) => s + t.amount);
    final spendNow = filtered
        .where((t) => t.amount < 0)
        .fold<double>(0, (s, t) => s + t.amount.abs());
    final baseIncome = incomeNow == 0 ? reportIncome.last : incomeNow;
    final baseSpend = spendNow == 0 ? reportSpend.last : spendNow;
    final scale = const [0.88, 0.9, 0.93, 0.91, 0.96, 0.94, 0.92, 0.95, 1.02, 0.98, 1.04, 1.0];
    final monthsAll = const [
      'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar',
    ];
    final months = monthsAll.sublist(monthsAll.length - _period);
    final incomeSeries = scale
        .sublist(scale.length - _period)
        .map((f) => (baseIncome * f).roundToDouble())
        .toList();
    final spendSeries = scale
        .sublist(scale.length - _period)
        .map((f) => (baseSpend * f).roundToDouble())
        .toList();
    final income = incomeSeries.last;
    final spend = spendSeries.last;
    final saved = income - spend;
    final rate = income == 0 ? '0.0' : ((saved / income) * 100).toStringAsFixed(1);
    final cats = [...reportCategories]..sort((a, b) {
        // keep visual order unless sorted via txn filters affecting KPIs only
        return 0;
      });

    final categories = {
      ...demoTransactions.map((t) => t.category),
    }.toList()
      ..sort();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: const Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          DashPageHeader(
            title: 'Reports',
            subtitle: 'Cash flow and category breakdown',
            actions: [
              FilterSortBar(
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
              ),
              GhostButton(
                label: 'Last $_period months',
                onPressed: () => setState(() {
                  _period = _period == 3 ? 6 : (_period == 6 ? 12 : 3);
                }),
              ),
              AccentButton(
                label: 'Copy summary',
                onPressed: () async {
                  final summary = StringBuffer()
                    ..writeln('FinanceAI Report')
                    ..writeln('Period: last $_period months')
                    ..writeln('Income: ${moneyWhole(income)}')
                    ..writeln('Spend: ${moneyWhole(spend)}')
                    ..writeln('Saved: ${moneyWhole(saved)}')
                    ..writeln('Savings rate: $rate%');
                  await Clipboard.setData(ClipboardData(text: summary.toString()));
                  if (context.mounted) {
                    toast(context, 'Summary copied · paste into Notes or email');
                  }
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DashKpi(label: 'Income', value: moneyWhole(income)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DashKpi(label: 'Spend', value: moneyWhole(spend)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DashKpi(label: 'Saved', value: moneyWhole(saved)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DashKpi(label: 'Savings rate', value: '$rate%'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DashPanel(
              child: Column(
                children: [
                  DashPanelHeader(
                    title: 'Income vs spend',
                    subtitle: 'Last $_period months',
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        _Legend(color: Color(0xFFC7C3FF), label: 'Income'),
                        SizedBox(width: 14),
                        _Legend(color: AppColors.accent, label: 'Spend'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: IncomeSpendBars(
                      months: months,
                      income: incomeSeries,
                      spend: spendSeries,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DashPanel(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spend by category',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'This month',
                    style: TextStyle(color: AppColors.mute, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  for (final c in cats) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${moneyWhole(c.amount)} · ${((c.amount / spend) * 100).round()}%',
                          style: const TextStyle(
                            color: AppColors.mute,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ProgressTrack(
                      progress: c.amount / spend,
                      color: c.color,
                      height: 6,
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DashPanel(
              child: Column(
                children: [
                  const DashPanelHeader(
                    title: 'Insights',
                    subtitle: 'Generated from your linked activity',
                  ),
                  _Insight(
                    spans: [
                      const TextSpan(text: 'Dining is '),
                      TextSpan(
                        text:
                            '${DisplayCurrency.symbolFor(DisplayCurrency.code)}30 over',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(
                        text: ' budget this month, mostly weekends.',
                      ),
                    ],
                  ),
                  _Insight(
                    spans: [
                      const TextSpan(text: 'Subscriptions are steady at '),
                      TextSpan(
                        text: moneyWhole(89),
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text:
                            ', under your ${moneyWhole(120)} cap.',
                      ),
                    ],
                  ),
                  _Insight(
                    spans: [
                      const TextSpan(
                        text:
                            "You're on track to hit the emergency fund goal by ",
                      ),
                      TextSpan(
                        text: 'November',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: ' at the current pace.'),
                    ],
                  ),
                ],
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
          style: const TextStyle(
            color: AppColors.mute,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Insight extends StatelessWidget {
  const _Insight({required this.spans});

  final List<InlineSpan> spans;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            color: Color(0xFF3C4257),
            fontSize: 14,
            height: 1.4,
          ),
          children: spans,
        ),
      ),
    );
  }
}
