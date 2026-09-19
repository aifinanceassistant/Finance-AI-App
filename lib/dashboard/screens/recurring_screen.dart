import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../dash_sheets.dart';
import '../data.dart';
import '../filter_sort.dart';
import '../recurring_controller.dart';
import '../recurring_scope.dart';
import '../shimmer.dart';
import '../ui.dart';

const _filterFields = [
  FilterFieldDef(id: 'name', label: 'Name', type: FilterFieldType.text),
  FilterFieldDef(id: 'type', label: 'Type', type: FilterFieldType.select),
  FilterFieldDef(
    id: 'category',
    label: 'Category',
    type: FilterFieldType.select,
  ),
  FilterFieldDef(
    id: 'account',
    label: 'Account',
    type: FilterFieldType.select,
  ),
  FilterFieldDef(id: 'amount', label: 'Amount', type: FilterFieldType.number),
  FilterFieldDef(
    id: 'cadence',
    label: 'Cadence',
    type: FilterFieldType.select,
  ),
  FilterFieldDef(id: 'next', label: 'Next', type: FilterFieldType.date),
  FilterFieldDef(id: 'start', label: 'Start', type: FilterFieldType.date),
  FilterFieldDef(id: 'end', label: 'End', type: FilterFieldType.date),
  FilterFieldDef(id: 'status', label: 'Status', type: FilterFieldType.select),
];

const _statusLabels = ['Succeeded', 'Pending', 'Failed'];
const _cadences = ['Weekly', 'Biweekly', 'Monthly', 'Quarterly', 'Yearly'];

final _detectedSamples = [
  DemoRecurring(
    id: 'rec_detect_1',
    name: 'iCloud+',
    category: 'Software',
    amount: -2.99,
    cadence: 'Monthly',
    next: 'Apr 18',
    start: 'Apr 18, 2023',
    account: 'Amex',
    status: TxnStatus.pending,
  ),
  DemoRecurring(
    id: 'rec_detect_2',
    name: 'Spotify Duo',
    category: 'Entertainment',
    amount: -14.99,
    cadence: 'Monthly',
    next: 'Apr 22',
    start: 'Sep 22, 2022',
    account: 'Chase',
    status: TxnStatus.succeeded,
  ),
];

String _statusLabel(TxnStatus status) {
  switch (status) {
    case TxnStatus.succeeded:
      return 'Succeeded';
    case TxnStatus.pending:
      return 'Pending';
    case TxnStatus.failed:
      return 'Failed';
  }
}

Object? _recurringValue(DemoRecurring r, String field) {
  switch (field) {
    case 'name':
      return r.name;
    case 'type':
      return moneyMoveLabel(r.type);
    case 'category':
      return r.category;
    case 'account':
      return r.account;
    case 'amount':
      return r.amount;
    case 'cadence':
      return r.cadence;
    case 'next':
      return r.next;
    case 'start':
      return r.start;
    case 'end':
      return r.endLabel;
    case 'status':
      return _statusLabel(r.status);
    default:
      return '';
  }
}

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  List<FilterRule> _filterRules = [];
  List<SortRule> _sortRules = [];
  String _search = '';

  RecurringController get _ctrl => RecurringScope.of(context);
  List<DemoRecurring> get _recurring => _ctrl.items;

  List<String> _selectOptions(String field) {
    if (field == 'status') return _statusLabels;
    if (field == 'type') return kMoneyMoveLabels;
    if (field == 'category') {
      return [...{..._recurring.map((r) => r.category)}].toList()..sort();
    }
    if (field == 'account') {
      return [...{..._recurring.map((r) => r.account)}].toList()..sort();
    }
    if (field == 'cadence') {
      return [...{..._recurring.map((r) => r.cadence), ..._cadences}].toList()
        ..sort();
    }
    return [];
  }

  List<DemoRecurring> get _filtered {
    final searched =
        applySearch(_recurring, _search, _filterFields, _recurringValue);
    final filtered = applyFilters(searched, _filterRules, _recurringValue);
    return applySort(filtered, _sortRules, _recurringValue);
  }

  List<DemoRecurring> get _upcoming {
    final list = [..._filtered]
      ..sort((a, b) => a.next.compareTo(b.next));
    return list;
  }

  Map<String, List<DemoRecurring>> get _calendarGroups {
    final map = <String, List<DemoRecurring>>{};
    for (final r in _recurring) {
      map.putIfAbsent(r.next, () => []).add(r);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Map.fromEntries(entries);
  }

  Future<void> _detectMore() async {
    final existing = _recurring.map((r) => r.name.toLowerCase()).toSet();
    final samples = _detectedSamples
        .where((s) => !existing.contains(s.name.toLowerCase()))
        .toList();
    if (samples.isEmpty) {
      toast(context, 'Nothing new · no additional recurring charges detected');
      return;
    }
    final added = <DemoRecurring>[];
    for (final s in samples) {
      final row = await _ctrl.create(
        name: s.name,
        category: s.category,
        account: s.account,
        amount: s.amount,
        cadence: s.cadence,
        next: s.next,
        start: s.start,
        end: s.end,
        type: s.type,
      );
      if (row != null) added.add(row);
    }
    if (!mounted) return;
    toast(
      context,
      added.isEmpty
          ? 'Could not add detected recurring'
          : 'Detected recurring · ${added.map((a) => a.name).join(', ')}',
    );
  }

  Future<void> _openAddRecurringSheet() async {
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'Subscriptions');
    final accountCtrl = TextEditingController(text: 'Checking');
    final amountCtrl = TextEditingController(text: '-12.99');
    final nextCtrl = TextEditingController(text: 'Apr 30');
    final startCtrl = TextEditingController(text: 'Apr 30, 2026');
    final endCtrl = TextEditingController();
    var cadence = 'Monthly';
    var type = MoneyMove.expense;

    await showDashSheet<void>(
      context: context,
      title: 'Add recurring',
      description: 'Track a subscription or repeating transfer',
      builder: (ctx, setSheetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Name'),
            DashTextField(
              controller: nameCtrl,
              hint: 'Netflix',
              autofocus: true,
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Type'),
            DashDropdown<MoneyMove>(
              value: type,
              items: MoneyMove.values,
              labelOf: moneyMoveLabel,
              onChanged: (v) => setSheetState(() => type = v),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Amount'),
                      DashTextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.\-]'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Cadence'),
                      DashDropdown<String>(
                        value: cadence,
                        items: _cadences,
                        labelOf: (v) => v,
                        onChanged: (v) => setSheetState(() => cadence = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Category'),
                      DashTextField(controller: categoryCtrl),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Account'),
                      DashTextField(controller: accountCtrl),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Start date'),
                      DashTextField(
                        controller: startCtrl,
                        hint: 'Apr 30, 2026',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('End date'),
                      DashTextField(
                        controller: endCtrl,
                        hint: 'Blank if ongoing',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Next date'),
            DashTextField(
              controller: nextCtrl,
              hint: 'Apr 30',
            ),
          ],
        );
      },
      actions: [
        Expanded(
          child: GhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Expanded(
          child: AccentButton(
            label: 'Add',
            onPressed: () async {
              final trimmed = nameCtrl.text.trim();
              if (trimmed.isEmpty) {
                toast(context, 'Enter a merchant or payment name');
                return;
              }
              final next = nextCtrl.text.trim().isEmpty
                  ? 'TBD'
                  : nextCtrl.text.trim();
              final created = await _ctrl.create(
                name: trimmed,
                category: categoryCtrl.text.trim().isEmpty
                    ? 'Other'
                    : categoryCtrl.text.trim(),
                account: accountCtrl.text.trim().isEmpty
                    ? 'Checking'
                    : accountCtrl.text.trim(),
                amount: double.tryParse(amountCtrl.text) ?? 0,
                cadence: cadence,
                next: next,
                start: startCtrl.text.trim().isEmpty
                    ? next
                    : startCtrl.text.trim(),
                end: endCtrl.text.trim(),
                type: type,
              );
              if (!mounted) return;
              if (created == null) {
                toast(context, 'Could not add recurring');
                return;
              }
              Navigator.pop(context);
              toast(context, 'Recurring added · $trimmed');
            },
          ),
        ),
      ],
    );

    nameCtrl.dispose();
    categoryCtrl.dispose();
    accountCtrl.dispose();
    amountCtrl.dispose();
    nextCtrl.dispose();
    startCtrl.dispose();
    endCtrl.dispose();
  }

  Future<void> _openManageSheet(DemoRecurring item) async {
    final nameCtrl = TextEditingController(text: item.name);
    final amountCtrl = TextEditingController(text: '${item.amount}');
    final nextCtrl = TextEditingController(text: item.next);
    final startCtrl = TextEditingController(text: item.start);
    final endCtrl = TextEditingController(text: item.end);
    var cadence = item.cadence;
    var type = item.type;

    await showDashSheet<void>(
      context: context,
      title: 'Manage recurring',
      description: '${item.cadence} · ${item.account}',
      builder: (ctx, setSheetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Name'),
            DashTextField(controller: nameCtrl, autofocus: true),
            const SizedBox(height: 14),
            const DashFieldLabel('Type'),
            DashDropdown<MoneyMove>(
              value: type,
              items: MoneyMove.values,
              labelOf: moneyMoveLabel,
              onChanged: (v) => setSheetState(() => type = v),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Amount'),
                      DashTextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.\-]'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Cadence'),
                      DashDropdown<String>(
                        value: cadence,
                        items: _cadences,
                        labelOf: (v) => v,
                        onChanged: (v) => setSheetState(() => cadence = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Start date'),
                      DashTextField(controller: startCtrl),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('End date'),
                      DashTextField(
                        controller: endCtrl,
                        hint: 'Blank if ongoing',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Next date'),
            DashTextField(controller: nextCtrl),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'Skip next',
                    onPressed: () async {
                      await _ctrl.skipNext(item.id);
                      if (!mounted) return;
                      Navigator.pop(context);
                      toast(context, 'Skipped next · next charge date advanced');
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GhostButton(
                    label: 'Mark paid',
                    onPressed: () async {
                      await _ctrl.markPaid(item.id);
                      if (!mounted) return;
                      Navigator.pop(context);
                      toast(context, 'Marked paid · next date advanced');
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
      actions: [
        TextButton(
          onPressed: () async {
            final ok = await _ctrl.remove(item.id);
            if (!mounted) return;
            Navigator.pop(context);
            toast(context, ok ? 'Recurring removed' : 'Could not remove');
          },
          child: const Text(
            'Remove',
            style: TextStyle(
              color: Color(0xFFC53030),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: GhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Expanded(
          child: AccentButton(
            label: 'Save',
            onPressed: () async {
              final trimmed = nameCtrl.text.trim();
              if (trimmed.isEmpty) {
                toast(context, 'Enter a merchant or payment name');
                return;
              }
              final updated = await _ctrl.patch(item.id, {
                'name': trimmed,
                'amount': double.tryParse(amountCtrl.text) ?? item.amount,
                'next': nextCtrl.text.trim().isEmpty
                    ? item.next
                    : nextCtrl.text.trim(),
                'start': startCtrl.text.trim().isEmpty
                    ? item.start
                    : startCtrl.text.trim(),
                'end': endCtrl.text.trim(),
                'cadence': cadence,
                'type': moneyMoveLabel(type),
              });
              if (!mounted) return;
              if (updated == null) {
                toast(context, 'Could not update recurring');
                return;
              }
              Navigator.pop(context);
              toast(context, 'Recurring updated · $trimmed');
            },
          ),
        ),
      ],
    );

    nameCtrl.dispose();
    amountCtrl.dispose();
    nextCtrl.dispose();
    startCtrl.dispose();
    endCtrl.dispose();
  }

  Future<void> _openCalendarSheet() async {
    final groups = _calendarGroups;

    await showDashSheet<void>(
      context: context,
      title: 'Recurring calendar',
      description: 'Upcoming charges and deposits by date',
      builder: (ctx, setSheetState) {
        if (groups.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nothing scheduled',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.softMute, fontSize: 13),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Text(
                  entry.key.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.softMute,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < entry.value.length; i++)
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          border: i < entry.value.length - 1
                              ? const Border(
                                  bottom: BorderSide(color: AppColors.line),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.value[i].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.ink,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${entry.value[i].cadence} · ${entry.value[i].account}',
                                    style: const TextStyle(
                                      color: AppColors.softMute,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              money(entry.value[i].amount, signed: true),
                              style: TextStyle(
                                color: entry.value[i].amount > 0
                                    ? AppColors.success
                                    : AppColors.ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
      actions: [
        Expanded(
          child: AccentButton(
            label: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final upcoming = _upcoming;
    final outflow = filtered
        .where((r) => r.amount < 0)
        .fold<double>(0, (s, r) => s + r.amount);
    final inflow = filtered
        .where((r) => r.amount > 0)
        .fold<double>(0, (s, r) => s + r.amount);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: const Text(
          'Recurring',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          DashPageHeader(
            title: 'Recurring',
            subtitle: 'Subscriptions, bills, and expected income',
            actions: [
              GhostButton(label: 'Detect more', onPressed: _detectMore),
              AccentButton(
                label: 'Add recurring',
                onPressed: _openAddRecurringSheet,
              ),
            ],
          ),
          if (_ctrl.loading)
            const DashLoadingBody(kpiCount: 3, listRows: 5)
          else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: FilterSortBar(
              fields: _filterFields,
              rules: _filterRules,
              sorts: _sortRules,
              selectOptions: _selectOptions,
              defaultFilterField: 'category',
              defaultSortField: 'next',
              search: _search,
              onSearchChanged: (v) => setState(() => _search = v),
              searchHint: 'Search recurring…',
              onRulesChanged: (rules) => setState(() => _filterRules = rules),
              onSortsChanged: (sorts) => setState(() => _sortRules = sorts),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: DashKpi(
                    label: 'Active series',
                    value: '${filtered.length}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DashKpi(
                    label: 'Monthly out',
                    value: money(outflow),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DashKpi(
              label: 'Monthly in',
              value: money(inflow),
              valueColor: AppColors.success,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DashPanel(
              child: Column(
                children: [
                  DashPanelHeader(
                    title: 'Upcoming transactions',
                    subtitle: 'Next charge or deposit for each series',
                    action: LinkAction(
                      label: 'Calendar',
                      onTap: _openCalendarSheet,
                    ),
                  ),
                  if (upcoming.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 28),
                      child: Text(
                        'No upcoming transactions match these filters',
                        style: TextStyle(
                          color: AppColors.mute,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < upcoming.length; i++)
                      _UpcomingTile(
                        item: upcoming[i],
                        showDivider: i < upcoming.length - 1,
                        onTap: () => _openManageSheet(upcoming[i]),
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
                    title: 'Recurring series',
                    subtitle:
                        '${filtered.length} of ${_recurring.length} shown · start & end dates',
                  ),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 28),
                      child: Text(
                        'No recurring series match these filters',
                        style: TextStyle(
                          color: AppColors.mute,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < filtered.length; i++)
                      _SeriesTile(
                        item: filtered[i],
                        showDivider: i < filtered.length - 1,
                        onTap: () => _openManageSheet(filtered[i]),
                      ),
                ],
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({
    required this.item,
    required this.showDivider,
    required this.onTap,
  });

  final DemoRecurring item;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(bottom: BorderSide(color: AppColors.line))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.cadence} · ${item.category}',
                      style: const TextStyle(
                        color: AppColors.mute,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TypePill(type: item.type),
                        Text(
                          'Due ${item.next}',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        StatusPill(status: item.status),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                money(item.amount, signed: true),
                style: TextStyle(
                  color: item.amount > 0 ? AppColors.success : AppColors.ink,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeriesTile extends StatelessWidget {
  const _SeriesTile({
    required this.item,
    required this.showDivider,
    required this.onTap,
  });

  final DemoRecurring item;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(bottom: BorderSide(color: AppColors.line))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.category} · ${item.cadence}',
                      style: const TextStyle(
                        color: AppColors.mute,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.start} → ${item.endLabel} · next ${item.next}',
                      style: const TextStyle(
                        color: AppColors.softMute,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        TypePill(type: item.type),
                        StatusPill(status: item.status),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                money(item.amount, signed: true),
                style: TextStyle(
                  color: item.amount > 0 ? AppColors.success : AppColors.ink,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
