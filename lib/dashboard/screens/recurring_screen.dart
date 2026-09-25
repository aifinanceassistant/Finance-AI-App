import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../dash_colors.dart';
import '../dash_sheets.dart';
import '../data.dart';
import '../filter_sort.dart';
import '../form_validation.dart';
import '../recurring_controller.dart';
import '../recurring_scope.dart';
import '../shimmer.dart';
import '../spaces_scope.dart';
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
    final nextCtrl = TextEditingController();
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();
    var cadence = 'Monthly';
    var type = MoneyMove.expense;
    var currency = DisplayCurrency.code;
    var fieldErrors = <String, String?>{};
    void Function(VoidCallback)? setLocal;

    await showDashSheet<void>(
      context: context,
      title: 'Add recurring',
      description: 'Track a subscription or repeating transfer',
      builder: (ctx, setSheetState) {
        setLocal = setSheetState;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Name'),
            DashTextField(
              controller: nameCtrl,
              hint: 'Netflix',
              autofocus: true,
              errorText: fieldErrors['name'],
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
            const DashFieldLabel('Amount'),
            Row(
              children: [
                Expanded(
                  child: DashTextField(
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
                    errorText: fieldErrors['amount'],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: DashDropdown<String>(
                    value: currency,
                    items: kSupportedCurrencies,
                    labelOf: (c) => c,
                    onChanged: (v) => setSheetState(() => currency = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Cadence'),
            DashDropdown<String>(
              value: cadence,
              items: _cadences,
              labelOf: (v) => v,
              onChanged: (v) => setSheetState(() => cadence = v),
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
                        hint: 'YYYY-MM-DD',
                        errorText: fieldErrors['start'],
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
                        hint: 'YYYY-MM-DD',
                        errorText: fieldErrors['end'],
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
              hint: 'YYYY-MM-DD',
              errorText: fieldErrors['next'],
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
              final nameErr = requiredText(trimmed, 'Name');
              final parsed = double.tryParse(amountCtrl.text.trim());
              final amountErr = positiveAmount(parsed?.abs());
              final startErr = optionalIsoDate(startCtrl.text, 'Start date');
              final endErr = optionalIsoDate(endCtrl.text, 'End date');
              final nextErr = optionalIsoDate(nextCtrl.text, 'Next date');
              final errors = <String, String?>{
                if (nameErr != null) 'name': nameErr,
                if (amountErr != null) 'amount': amountErr,
                if (startErr != null) 'start': startErr,
                if (endErr != null) 'end': endErr,
                if (nextErr != null) 'next': nextErr,
              };
              setLocal?.call(() => fieldErrors = errors);
              if (hasFieldErrors(errors)) {
                toast(
                  context,
                  firstFieldError(errors) ?? 'Fix the highlighted fields',
                );
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
                amount: parsed ?? 0,
                cadence: cadence,
                next: next,
                start: startCtrl.text.trim().isEmpty
                    ? next
                    : startCtrl.text.trim(),
                end: endCtrl.text.trim(),
                type: type,
                currency: currency,
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
    final amountCtrl = TextEditingController(
      text: '${item.originalAmount ?? item.amount}',
    );
    final nextCtrl = TextEditingController(text: item.next);
    final startCtrl = TextEditingController(text: item.start);
    final endCtrl = TextEditingController(text: item.end);
    var cadence = item.cadence;
    var type = item.type;
    var currency = kSupportedCurrencies.contains(
          (item.originalCurrency ?? DisplayCurrency.code).toUpperCase(),
        )
        ? (item.originalCurrency ?? DisplayCurrency.code).toUpperCase()
        : DisplayCurrency.code;
    var fieldErrors = <String, String?>{};
    void Function(VoidCallback)? setLocal;

    String? isoOrUnchangedLegacy(String value, String legacy, String label) {
      final v = value.trim();
      if (v.isEmpty) return null;
      if (v == legacy.trim() && optionalIsoDate(v, label) != null) return null;
      return optionalIsoDate(v, label);
    }

    await showDashSheet<void>(
      context: context,
      title: 'Manage recurring',
      description: '${item.cadence} · ${item.account}',
      builder: (ctx, setSheetState) {
        setLocal = setSheetState;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Name'),
            DashTextField(
              controller: nameCtrl,
              autofocus: true,
              errorText: fieldErrors['name'],
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
            const DashFieldLabel('Amount'),
            Row(
              children: [
                Expanded(
                  child: DashTextField(
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
                    errorText: fieldErrors['amount'],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: DashDropdown<String>(
                    value: currency,
                    items: kSupportedCurrencies,
                    labelOf: (c) => c,
                    onChanged: (v) => setSheetState(() => currency = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Cadence'),
            DashDropdown<String>(
              value: cadence,
              items: _cadences,
              labelOf: (v) => v,
              onChanged: (v) => setSheetState(() => cadence = v),
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
                        hint: 'YYYY-MM-DD',
                        errorText: fieldErrors['start'],
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
                        hint: 'YYYY-MM-DD',
                        errorText: fieldErrors['end'],
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
              hint: 'YYYY-MM-DD',
              errorText: fieldErrors['next'],
            ),
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
              final nameErr = requiredText(trimmed, 'Name');
              final parsed = double.tryParse(amountCtrl.text.trim());
              final amountErr = positiveAmount(parsed?.abs());
              final startErr =
                  isoOrUnchangedLegacy(startCtrl.text, item.start, 'Start date');
              final endErr =
                  isoOrUnchangedLegacy(endCtrl.text, item.end, 'End date');
              final nextErr =
                  isoOrUnchangedLegacy(nextCtrl.text, item.next, 'Next date');
              final errors = <String, String?>{
                if (nameErr != null) 'name': nameErr,
                if (amountErr != null) 'amount': amountErr,
                if (startErr != null) 'start': startErr,
                if (endErr != null) 'end': endErr,
                if (nextErr != null) 'next': nextErr,
              };
              setLocal?.call(() => fieldErrors = errors);
              if (hasFieldErrors(errors)) {
                toast(
                  context,
                  firstFieldError(errors) ?? 'Fix the highlighted fields',
                );
                return;
              }
              final updated = await _ctrl.patch(item.id, {
                'name': trimmed,
                'amount': parsed ?? item.amount,
                'next': nextCtrl.text.trim().isEmpty
                    ? item.next
                    : nextCtrl.text.trim(),
                'start': startCtrl.text.trim().isEmpty
                    ? item.start
                    : startCtrl.text.trim(),
                'end': endCtrl.text.trim(),
                'cadence': cadence,
                'type': moneyMoveLabel(type),
                'currency': currency,
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
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nothing scheduled',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.dashSoftMute, fontSize: 13),
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
                  style: TextStyle(
                    color: context.dashSoftMute,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: context.dashLine),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < entry.value.length; i++)
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          border: i < entry.value.length - 1
                              ? Border(
                                  bottom: BorderSide(color: context.dashLine),
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
                                    style: TextStyle(
                                      color: context.dashInk,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${entry.value[i].cadence} · ${entry.value[i].account}',
                                    style: TextStyle(
                                      color: context.dashSoftMute,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ConvertedAmountText(
                              amount: (entry.value[i].originalAmount ??
                                      entry.value[i].amount)
                                  .abs(),
                              originalCurrency:
                                  entry.value[i].originalCurrency ?? 'USD',
                              signed: true,
                              isIncome: entry.value[i].amount > 0,
                              primaryStyle: TextStyle(
                                color: entry.value[i].amount > 0
                                    ? AppColors.success
                                    : context.dashInk,
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

  Map<String, List<DemoRecurring>> get _typeGroups {
    final map = <String, List<DemoRecurring>>{};
    for (final r in _upcoming) {
      final key = moneyMoveLabel(r.type);
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final groups = _typeGroups;
    final outflow = filtered
        .where((r) => r.amount < 0)
        .fold<double>(0, (s, r) => s + r.amount.abs());
    final inflow = filtered
        .where((r) => r.amount > 0)
        .fold<double>(0, (s, r) => s + r.amount);
    final canWrite =
        SpacesScope.maybeOf(context)?.can('recurring', 'write') != false;
    final subtitle = filtered.length == _recurring.length
        ? '${filtered.length} items'
        : '${filtered.length} of ${_recurring.length} items';

    return DashModalScaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          DashFeedChrome(
            title: 'Recurring',
            subtitle: subtitle,
            onSecondary: _detectMore,
            secondaryIcon: Icons.auto_awesome_outlined,
            secondaryTooltip: 'Detect more',
            extraActions: [
              IconButton(
                onPressed: _openCalendarSheet,
                tooltip: 'Calendar',
                icon: const Icon(Icons.calendar_month_outlined, size: 22),
                color: context.dashInk,
                visualDensity: VisualDensity.compact,
              ),
            ],
            onPrimary: _openAddRecurringSheet,
            primaryTooltip: 'Add recurring',
            primaryEnabled: canWrite,
            metaLine: 'Out ${money(outflow)} · In ${money(inflow)}',
            filterBar: FilterSortBar(
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
              iconButtons: true,
              expandSearch: true,
            ),
          ),
          if (_ctrl.loading)
            const DashLoadingBody(kpiCount: 1, listRows: 5)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(0, 24, 0, 28),
                      child: Text(
                        'No recurring series match these filters',
                        style: TextStyle(
                          color: context.dashMute,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final entry in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                color: context.dashMute,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          for (final item in entry.value)
                            _RecurringRow(
                              item: item,
                              onTap: () => _openManageSheet(item),
                            ),
                        ],
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _RecurringRow extends StatelessWidget {
  const _RecurringRow({required this.item, required this.onTap});

  final DemoRecurring item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.dashLine)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.dashInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.cadence} · ${item.category} · next ${item.next}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.dashMute,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ConvertedAmountText(
                amount: (item.originalAmount ?? item.amount).abs(),
                originalCurrency: item.originalCurrency ?? 'USD',
                signed: true,
                isIncome: item.amount > 0,
                primaryStyle: TextStyle(
                  color: item.amount > 0 ? AppColors.success : context.dashInk,
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
