import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../dash_sheets.dart';
import '../data.dart';
import '../filter_sort.dart';
import '../investments_controller.dart';
import '../investments_scope.dart';
import '../shimmer.dart';
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
    toast(context, 'Brokers synced · prices updated');
  }

  Future<void> _openAddHoldingSheet() async {
    final nameCtrl = TextEditingController();
    final tickerCtrl = TextEditingController();
    final valueCtrl = TextEditingController(text: '1000');
    final costCtrl = TextEditingController(text: '1000');
    var type = _holdingTypes.first;

    await showDashSheet<void>(
      context: context,
      title: 'Add holding',
      description: 'Track a position in this space',
      builder: (ctx, setSheetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Name'),
            DashTextField(
              controller: nameCtrl,
              hint: 'Vanguard Total Stock',
              autofocus: true,
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
              if (trimmedName.isEmpty || trimmedTicker.isEmpty) {
                toast(context, 'Name and ticker are required');
                return;
              }
              if (_holdings.any((h) => h.ticker == trimmedTicker)) {
                toast(context, 'That symbol is already in the portfolio');
                return;
              }
              final v = math.max(0.0, double.tryParse(valueCtrl.text) ?? 0);
              final c = math.max(0.0, double.tryParse(costCtrl.text) ?? v);
              final created = await _ctrl.create(
                name: trimmedName,
                ticker: trimmedTicker,
                type: type,
                value: v,
                cost: c,
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

  Future<void> _openAllocationSheet() async {
    final allocation = _allocation;

    await showDashSheet<void>(
      context: context,
      title: 'Allocation',
      description: 'Breakdown by holding type',
      builder: (ctx, setSheetState) {
        if (allocation.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No holdings yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.softMute, fontSize: 13),
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
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${money(row.amount)} · ${row.pct}%',
                          style: const TextStyle(
                            color: AppColors.mute,
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
    final gainPct = cost == 0 ? 0.0 : (gain / cost) * 100;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: const Text(
          'Investments',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          DashPageHeader(
            title: 'Investments',
            subtitle: 'Brokerage and crypto holdings',
            actions: [
              GhostButton(label: 'Sync brokers', onPressed: _syncBrokers),
              AccentButton(
                label: 'Add holding',
                onPressed: _openAddHoldingSheet,
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
              defaultFilterField: 'type',
              defaultSortField: 'value',
              search: _search,
              onSearchChanged: (v) => setState(() => _search = v),
              searchHint: 'Search holdings…',
              onRulesChanged: (rules) => setState(() => _filterRules = rules),
              onSortsChanged: (sorts) => setState(() => _sortRules = sorts),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: DashKpi(label: 'Portfolio value', value: money(total)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DashKpi(
                    label: 'Total gain',
                    value: '${gain >= 0 ? '+' : ''}${money(gain)}',
                    valueColor: gain >= 0 ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DashKpi(
              label: 'Return',
              value:
                  '${gainPct >= 0 ? '+' : ''}${gainPct.toStringAsFixed(1)}%',
              valueColor: gainPct >= 0 ? AppColors.success : AppColors.danger,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DashPanel(
              child: Column(
                children: [
                  DashPanelHeader(
                    title: 'Holdings',
                    subtitle: '${filtered.length} of ${_holdings.length} positions',
                    action: LinkAction(
                      label: 'Allocation',
                      onTap: _openAllocationSheet,
                    ),
                  ),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 28),
                      child: Text(
                        'No holdings match these filters',
                        style: TextStyle(
                          color: AppColors.mute,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < filtered.length; i++)
                      _HoldingTile(
                        holding: filtered[i],
                        showDivider: i < filtered.length - 1,
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

class _HoldingTile extends StatelessWidget {
  const _HoldingTile({required this.holding, required this.showDivider});

  final DemoHolding holding;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final up = holding.change > 0;
    final down = holding.change < 0;
    return Container(
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
                  holding.name,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${holding.ticker} · ${holding.type}',
                  style: const TextStyle(
                    color: AppColors.mute,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(holding.value),
                style: const TextStyle(
                  color: AppColors.ink,
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
                          : AppColors.mute,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
