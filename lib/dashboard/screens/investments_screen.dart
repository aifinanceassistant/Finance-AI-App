import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../dash_colors.dart';
import '../dash_sheets.dart';
import '../data.dart';
import '../filter_sort.dart';
import '../form_validation.dart';
import '../investments_controller.dart';
import '../investments_scope.dart';
import '../shimmer.dart';
import '../spaces_scope.dart';
import '../ui.dart';

const _filterFields = [
  FilterFieldDef(id: 'name', label: 'Holding', type: FilterFieldType.text),
  FilterFieldDef(id: 'ticker', label: 'Ticker', type: FilterFieldType.text),
  FilterFieldDef(id: 'type', label: 'Type', type: FilterFieldType.select),
  FilterFieldDef(id: 'value', label: 'Value', type: FilterFieldType.number),
  FilterFieldDef(
    id: 'change',
    label: 'Day change',
    type: FilterFieldType.number,
  ),
  FilterFieldDef(id: 'cost', label: 'Cost basis', type: FilterFieldType.number),
];

const _holdingTypes = ['ETF', 'Stock', 'Fund', 'Crypto', 'Bond', 'Cash'];

Object? _holdingValue(DemoHolding h, String field) {
  switch (field) {
    case 'name':
      return h.name;
    case 'ticker':
      return h.ticker;
    case 'type':
      return h.type;
    case 'value':
      return h.value;
    case 'change':
      return h.change;
    case 'cost':
      return h.cost;
    default:
      return '';
  }
}

class _AllocationRow {
  const _AllocationRow({
    required this.label,
    required this.amount,
    required this.pct,
  });

  final String label;
  final double amount;
  final int pct;
}

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  List<FilterRule> _filterRules = [];
  List<SortRule> _sortRules = [];
  String _search = '';

  InvestmentsController get _ctrl => InvestmentsScope.of(context);
  List<DemoHolding> get _holdings => _ctrl.holdings;

  List<String> _selectOptions(String field) {
    if (field == 'type') {
      return [...{..._holdings.map((h) => h.type), ..._holdingTypes}].toList()
        ..sort();
    }
    return [];
  }

  List<DemoHolding> get _filtered {
    final searched =
        applySearch(_holdings, _search, _filterFields, _holdingValue);
    final filtered = applyFilters(searched, _filterRules, _holdingValue);
    return applySort(filtered, _sortRules, _holdingValue);
  }

  List<_AllocationRow> get _allocation {
    final map = <String, double>{};
    for (final h in _holdings) {
      map[h.type] = (map[h.type] ?? 0) + h.value;
    }
    final sum = map.values.fold<double>(0, (s, v) => s + v);
    final total = sum == 0 ? 1.0 : sum;
    return map.entries
        .map(
          (e) => _AllocationRow(
            label: e.key,
            amount: e.value,
            pct: ((e.value / total) * 100).round(),
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  void _syncBrokers() {
    toast(context, 'Broker price sync isn’t available yet');
  }

  Future<void> _openAddHoldingSheet() async {
    final nameCtrl = TextEditingController();
    final tickerCtrl = TextEditingController();
    final valueCtrl = TextEditingController(text: '1000');
    final costCtrl = TextEditingController(text: '1000');
    var type = _holdingTypes.first;
    var currency = DisplayCurrency.code;
    var fieldErrors = <String, String?>{};
    void Function(VoidCallback)? setLocal;

    await showDashSheet<void>(
      context: context,
      title: 'Add holding',
      description: 'Track a position in this space',
      builder: (ctx, setSheetState) {
        setLocal = setSheetState;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Name'),
            DashTextField(
              controller: nameCtrl,
              hint: 'Vanguard Total Stock',
              autofocus: true,
              errorText: fieldErrors['name'],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Ticker'),
                      DashTextField(
                        controller: tickerCtrl,
                        hint: 'VTI',
                        errorText: fieldErrors['ticker'],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Type'),
                      DashDropdown<String>(
                        value: type,
                        items: _holdingTypes,
                        labelOf: (v) => v,
                        onChanged: (v) => setSheetState(() => type = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Currency'),
            DashDropdown<String>(
              value: currency,
              items: kSupportedCurrencies,
              labelOf: (c) => c,
              onChanged: (v) => setSheetState(() => currency = v),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Value'),
                      DashTextField(
                        controller: valueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]'),
                          ),
                        ],
                        errorText: fieldErrors['value'],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Cost basis'),
                      DashTextField(
                        controller: costCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]'),
                          ),
                        ],
                        errorText: fieldErrors['cost'],
                      ),
                    ],
                  ),
                ),
              ],
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
              final trimmedName = nameCtrl.text.trim();
              final trimmedTicker = tickerCtrl.text.trim().toUpperCase();
              final nameErr = requiredText(trimmedName, 'Name');
              final tickerErr = requiredText(trimmedTicker, 'Ticker');
              final valueErr = nonNegativeAmount(valueCtrl.text, 'Value');
              final costErr = nonNegativeAmount(costCtrl.text, 'Cost');
              final errors = <String, String?>{
                if (nameErr != null) 'name': nameErr,
                if (tickerErr != null) 'ticker': tickerErr,
                if (valueErr != null) 'value': valueErr,
                if (costErr != null) 'cost': costErr,
              };
              setLocal?.call(() => fieldErrors = errors);
              if (hasFieldErrors(errors)) {
                toast(
                  context,
                  firstFieldError(errors) ?? 'Fix the highlighted fields',
                );
                return;
              }
              if (_holdings.any((h) => h.ticker == trimmedTicker)) {
                toast(context, 'That symbol is already in the portfolio');
                return;
              }
              final v = double.tryParse(valueCtrl.text) ?? 0;
              final c = double.tryParse(costCtrl.text) ?? v;
              final created = await _ctrl.create(
                name: trimmedName,
                ticker: trimmedTicker,
                type: type,
                value: v,
                cost: c,
                currency: currency,
              );
              if (!mounted) return;
              if (created == null) {
                toast(context, 'Could not add holding');
                return;
              }
              Navigator.pop(context);
              toast(context, 'Holding added · $trimmedTicker');
            },
          ),
        ),
      ],
    );

    nameCtrl.dispose();
    tickerCtrl.dispose();
    valueCtrl.dispose();
    costCtrl.dispose();
  }

  Future<void> _openEditHoldingSheet(DemoHolding holding) async {
    final id = holding.id?.trim() ?? '';
    if (id.isEmpty) {
      toast(context, 'Could not edit this holding');
      return;
    }
    final nameCtrl = TextEditingController(text: holding.name);
    final tickerCtrl = TextEditingController(text: holding.ticker);
    final valueCtrl = TextEditingController(
      text: (holding.originalPrice ?? holding.value).toStringAsFixed(2),
    );
    final costCtrl = TextEditingController(
      text: holding.cost.toStringAsFixed(2),
    );
    var type = _holdingTypes.contains(holding.type)
        ? holding.type
        : _holdingTypes.first;
    var currency = kSupportedCurrencies.contains(
          (holding.currency ?? DisplayCurrency.code).toUpperCase(),
        )
        ? (holding.currency ?? DisplayCurrency.code).toUpperCase()
        : DisplayCurrency.code;
    var fieldErrors = <String, String?>{};
    void Function(VoidCallback)? setLocal;

    await showDashSheet<void>(
      context: context,
      title: 'Edit holding',
      description: '${holding.ticker} · ${holding.type}',
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Ticker'),
                      DashTextField(
                        controller: tickerCtrl,
                        errorText: fieldErrors['ticker'],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Type'),
                      DashDropdown<String>(
                        value: type,
                        items: [
                          if (!_holdingTypes.contains(type)) type,
                          ..._holdingTypes,
                        ],
                        labelOf: (v) => v,
                        onChanged: (v) => setSheetState(() => type = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Currency'),
            DashDropdown<String>(
              value: currency,
              items: kSupportedCurrencies,
              labelOf: (c) => c,
              onChanged: (v) => setSheetState(() => currency = v),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Value'),
                      DashTextField(
                        controller: valueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]'),
                          ),
                        ],
                        errorText: fieldErrors['value'],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Cost basis'),
                      DashTextField(
                        controller: costCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]'),
                          ),
                        ],
                        errorText: fieldErrors['cost'],
                      ),
                    ],
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
            final ok = await _ctrl.remove(id);
            if (!mounted) return;
            Navigator.pop(context);
            toast(context, ok ? 'Holding removed' : 'Could not remove');
          },
          child: const Text(
            'Delete',
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
              final trimmedName = nameCtrl.text.trim();
              final trimmedTicker = tickerCtrl.text.trim().toUpperCase();
              final nameErr = requiredText(trimmedName, 'Name');
              final tickerErr = requiredText(trimmedTicker, 'Ticker');
              final valueErr = nonNegativeAmount(valueCtrl.text, 'Value');
              final costErr = nonNegativeAmount(costCtrl.text, 'Cost');
              final errors = <String, String?>{
                if (nameErr != null) 'name': nameErr,
                if (tickerErr != null) 'ticker': tickerErr,
                if (valueErr != null) 'value': valueErr,
                if (costErr != null) 'cost': costErr,
              };
              setLocal?.call(() => fieldErrors = errors);
              if (hasFieldErrors(errors)) {
                toast(
                  context,
                  firstFieldError(errors) ?? 'Fix the highlighted fields',
                );
                return;
              }
              if (_holdings.any(
                (h) => h.id != id && h.ticker == trimmedTicker,
              )) {
                toast(context, 'That symbol is already in the portfolio');
                return;
              }
              final v = double.tryParse(valueCtrl.text) ?? holding.value;
              final c = double.tryParse(costCtrl.text) ?? holding.cost;
              final updated = await _ctrl.update(
                id,
                name: trimmedName,
                ticker: trimmedTicker,
                type: type,
                value: v,
                cost: c,
                currency: currency,
              );
              if (!mounted) return;
              if (updated == null) {
                toast(context, 'Could not update holding');
                return;
              }
              Navigator.pop(context);
              toast(context, 'Holding updated · $trimmedTicker');
            },
          ),
        ),
      ],
    );

    nameCtrl.dispose();
    tickerCtrl.dispose();
    valueCtrl.dispose();
    costCtrl.dispose();
  }

  Future<void> _openAllocationSheet() async {
    final allocation = _allocation;

    await showDashSheet<void>(
      context: context,
      title: 'Allocation',
      description: 'Breakdown by holding type',
      builder: (ctx, setSheetState) {
        if (allocation.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No holdings yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.dashSoftMute, fontSize: 13),
            ),
          );
        }
        return Column(
          children: [
            for (final row in allocation)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.label,
                            style: TextStyle(
                              color: context.dashInk,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${money(row.amount)} · ${row.pct}%',
                          style: TextStyle(
                            color: context.dashMute,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ProgressTrack(
                      progress: row.pct / 100,
                      color: AppColors.accent,
                      height: 6,
                    ),
                  ],
                ),
              ),
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
    final total = filtered.fold<double>(0, (s, h) => s + h.value);
    final cost = filtered.fold<double>(0, (s, h) => s + h.cost);
    final gain = total - cost;
    final canWrite =
        SpacesScope.maybeOf(context)?.can('investments', 'write') != false;
    final subtitle = filtered.length == _holdings.length
        ? '${filtered.length} holdings'
        : '${filtered.length} of ${_holdings.length} holdings';
    final gainLabel = '${gain >= 0 ? '+' : ''}${money(gain)}';

    return DashModalScaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          DashFeedChrome(
            title: 'Investments',
            subtitle: subtitle,
            onSecondary: _syncBrokers,
            secondaryIcon: Icons.sync_rounded,
            secondaryTooltip: 'Sync brokers',
            extraActions: [
              IconButton(
                onPressed: _openAllocationSheet,
                tooltip: 'Allocation',
                icon: const Icon(Icons.pie_chart_outline_rounded, size: 22),
                color: context.dashInk,
                visualDensity: VisualDensity.compact,
              ),
            ],
            onPrimary: _openAddHoldingSheet,
            primaryTooltip: 'Add holding',
            primaryEnabled: canWrite,
            metaLine: 'Value ${money(total)} · Gain $gainLabel',
            filterBar: FilterSortBar(
              fields: _filterFields,
              rules: _filterRules,
              sorts: _sortRules,
              selectOptions: _selectOptions,
              defaultFilterField: 'type',
              defaultSortField: 'value',
              search: _search,
              onSearchChanged: (v) => setState(() => _search = v),
              searchHint: 'Search holdings…',
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
                        'No holdings match these filters',
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
                        for (final h in filtered)
                          _HoldingRow(
                            holding: h,
                            onTap: () => _openEditHoldingSheet(h),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _HoldingRow extends StatelessWidget {
  const _HoldingRow({required this.holding, required this.onTap});

  final DemoHolding holding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final up = holding.change > 0;
    final down = holding.change < 0;
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
                      holding.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.dashInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${holding.ticker} · ${holding.type}',
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ConvertedAmountText(
                    amount: (holding.originalPrice ?? holding.value).abs(),
                    originalCurrency: holding.currency ?? 'USD',
                    primaryStyle: TextStyle(
                      color: context.dashInk,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${up ? '+' : ''}${holding.change.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: up
                          ? const Color(0xFF0D9488)
                          : down
                              ? const Color(0xFFC53030)
                              : context.dashMute,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
