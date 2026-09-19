import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data.dart';
import '../filter_sort.dart';
import '../ui.dart';
import '../variant_style.dart';
import '../widgets/space_alien.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.style,
    required this.onViewTransactions,
    required this.onViewAccounts,
    required this.onViewCategories,
    required this.onViewGoals,
    required this.onConnectBank,
  });

  final DashVariantStyle style;
  final VoidCallback onViewTransactions;
  final VoidCallback onViewAccounts;
  final VoidCallback onViewCategories;
  final VoidCallback onViewGoals;
  final VoidCallback onConnectBank;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _period = '30D';
  List<FilterRule> _rules = [];
  List<SortRule> _sorts = [];
  String _search = '';
  bool _tipDismissed = false;

  static const _fields = [
    FilterFieldDef(
      id: 'merchant',
      label: 'Description',
      type: FilterFieldType.text,
    ),
    FilterFieldDef(
      id: 'category',
      label: 'Category',
      type: FilterFieldType.select,
    ),
    FilterFieldDef(
      id: 'amount',
      label: 'Amount',
      type: FilterFieldType.number,
    ),
    FilterFieldDef(
      id: 'status',
      label: 'Status',
      type: FilterFieldType.select,
    ),
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

  List<DemoTxn> get _periodTxns {
    final all = demoTransactions;
    if (_period == '7D') return all.take(3).toList();
    if (_period == '12M') return all;
    return all.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final goal = demoGoals.first;
    final progress = goal.saved / goal.target;
    final sym = DisplayCurrency.symbolFor(DisplayCurrency.code);
    final actionItems = <(String, VoidCallback)>[
      (
        'Move ${sym}200 to emergency fund',
        widget.onViewGoals,
      ),
      ('Review dining budget overrun', widget.onViewTransactions),
      ('Confirm Airbnb pending charge', widget.onViewTransactions),
    ];
    final stories = <(String, String, IconData, VoidCallback)>[
      (
        'Cash position',
        '${sym}12,480.22 across 5 accounts. Wise holds the largest share at ${sym}5,519.',
        Icons.account_balance_wallet_outlined,
        widget.onViewAccounts,
      ),
      (
        'Spend so far',
        '${sym}3,214 this month · 68% of budget with 12 days left.',
        Icons.shopping_bag_outlined,
        widget.onViewTransactions,
      ),
      if (!_tipDismissed)
        (
          'Tip',
          'Dining is ${sym}30 over. Cutting two restaurant nights gets you back on track.',
          Icons.lightbulb_outline_rounded,
          () {
            setState(() => _tipDismissed = true);
            widget.onViewCategories();
          },
        ),
    ];

    const homeMood = AlienMood.alert;
    final moodStyle = AlienMoodStyle.of(homeMood);
    final homeDigest =
        'Dining is ${sym}30 over · Airbnb still pending review';

    final searched =
        applySearch(_periodTxns, _search, _fields, _txnValue);
    final recent = applySort(
      applyFilters(searched, _rules, _txnValue),
      _sorts,
      _txnValue,
    );
    final categories = {..._periodTxns.map((t) => t.category)}.toList()
      ..sort();

    return ListView(
      key: const ValueKey('briefing'),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
      children: [
        DashPageHeader(
          title: 'Good Morning, Alex',
          subtitle: 'Thursday briefing · March 10',
          trailing: const SpaceAlienMascot(size: 40, mood: homeMood),
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
              defaultSortField: 'date',
            ),
            GhostButton(
              label: 'Connect bank',
              onPressed: widget.onConnectBank,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(
            children: [
              for (final p in const ['7D', '30D', '12M']) ...[
                ChoiceChip(
                  label: Text(p),
                  selected: _period == p,
                  onSelected: (_) => setState(() => _period = p),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Text(
            homeDigest,
            style: TextStyle(
              color: moodStyle.text,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DashPanel(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRIMARY GOAL',
                  style: TextStyle(
                    color: style.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  goal.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${moneyWhole(goal.saved)} of ${moneyWhole(goal.target)}',
                  style: const TextStyle(
                    color: AppColors.mute,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                ProgressTrack(
                  progress: progress.clamp(0.0, 1.0),
                  color: style.primary,
                  height: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).round()}% complete',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: DashPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cash left',
                        style: TextStyle(
                          color: AppColors.mute,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        money(1485.92),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DashPanel(
                  padding: const EdgeInsets.all(14),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Days left',
                        style: TextStyle(
                          color: AppColors.mute,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '12',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Today\'s digest',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        for (final s in stories)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(style.radius),
              child: InkWell(
                onTap: s.$4,
                borderRadius: BorderRadius.circular(style.radius),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(style.radius),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(s.$3, color: style.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.$1,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.$2,
                              style: const TextStyle(
                                color: AppColors.mute,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DashPanel(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next actions',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < actionItems.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == actionItems.length - 1 ? 0 : 10,
                    ),
                    child: InkWell(
                      onTap: actionItems[i].$2,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_box_outline_blank_rounded,
                            size: 20,
                            color: style.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              actionItems[i].$1,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
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
            child: Column(
              children: [
                DashPanelHeader(
                  title: 'Recent payments',
                  subtitle: '${recent.length} in $_period',
                  action: LinkAction(
                    label: 'View all',
                    onTap: widget.onViewTransactions,
                  ),
                ),
                if (recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
                    child: Text(
                      'No payments match these filters',
                      style: TextStyle(color: AppColors.mute, fontSize: 13),
                    ),
                  )
                else
                  for (final t in recent.take(6)) _TightTxnRow(txn: t),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TightTxnRow extends StatelessWidget {
  const _TightTxnRow({required this.txn});

  final DemoTxn txn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              txn.merchant,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConvertedAmountText(
            amount: (txn.originalAmount ?? txn.amount).abs(),
            originalCurrency: txn.originalCurrency ?? 'USD',
            signed: true,
            isIncome: txn.amount > 0,
            primaryStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: txn.amount > 0 ? AppColors.success : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
