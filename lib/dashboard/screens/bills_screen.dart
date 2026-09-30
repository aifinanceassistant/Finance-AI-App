import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../accounts_controller.dart';
import '../bills_controller.dart';
import '../dash_colors.dart';
import '../dash_sheets.dart';
import '../data.dart';
import '../filter_sort.dart';
import '../form_validation.dart';
import '../shimmer.dart';
import '../spaces_scope.dart';
import '../ui.dart';

const _filterFields = [
  FilterFieldDef(id: 'description', label: 'Description', type: FilterFieldType.text),
  FilterFieldDef(id: 'number', label: 'Number', type: FilterFieldType.text),
  FilterFieldDef(id: 'status', label: 'Status', type: FilterFieldType.select),
  FilterFieldDef(id: 'dueDate', label: 'Due', type: FilterFieldType.date),
  FilterFieldDef(
    id: 'amountRemaining',
    label: 'Remaining',
    type: FilterFieldType.number,
  ),
];

const _billStatuses = ['draft', 'open', 'partial', 'paid', 'void'];

Object? _billValue(BillRecord b, String field) {
  switch (field) {
    case 'description':
      return b.description;
    case 'number':
      return b.number;
    case 'status':
      return b.status;
    case 'dueDate':
      return b.dueDate ?? '';
    case 'amountRemaining':
      return b.amountRemaining;
    default:
      return '';
  }
}

String _statusLabel(String status) {
  if (status.isEmpty) return status;
  return '${status[0].toUpperCase()}${status.substring(1)}';
}

Color _statusColor(BuildContext context, String status) {
  switch (status) {
    case 'paid':
      return AppColors.success;
    case 'partial':
      return const Color(0xFFB45309);
    case 'void':
      return AppColors.danger;
    case 'draft':
      return context.dashSoftMute;
    default:
      return AppColors.brand;
  }
}

String _todayIso() => DateTime.now().toUtc().toIso8601String().substring(0, 10);

class BillsScreen extends StatefulWidget {
  const BillsScreen({
    super.key,
    required this.controller,
    this.accounts,
  });

  final BillsController controller;
  final AccountsController? accounts;

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  List<FilterRule> _filterRules = [];
  List<SortRule> _sortRules = [];
  String _search = '';

  BillsController get _ctrl => widget.controller;
  List<BillRecord> get _items => _ctrl.items;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onCtrl);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onCtrl);
    super.dispose();
  }

  void _onCtrl() {
    if (mounted) setState(() {});
  }

  List<String> _selectOptions(String field) {
    if (field != 'status') return [];
    return [...{..._items.map((b) => b.status), ..._billStatuses}].toList()
      ..sort();
  }

  List<BillRecord> get _filtered {
    final searched = applySearch(_items, _search, _filterFields, _billValue);
    final filtered = applyFilters(searched, _filterRules, _billValue);
    return applySort(filtered, _sortRules, _billValue);
  }

  List<DemoAccount> get _payableAccounts {
    final accounts = widget.accounts?.accounts ?? const <DemoAccount>[];
    return [
      for (final a in accounts)
        if (a.id != null && a.id!.isNotEmpty) a,
    ];
  }

  Future<void> _openEditor({BillRecord? existing}) async {
    final isEdit = existing != null;
    final numberCtrl = TextEditingController(text: existing?.number ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final amountCtrl = TextEditingController(
      text: existing != null
          ? existing.originalAmount.toStringAsFixed(2)
          : '',
    );
    final issueCtrl = TextEditingController(
      text: existing?.issueDate ?? _todayIso(),
    );
    final dueCtrl = TextEditingController(text: existing?.dueDate ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    var status = existing?.status ?? 'open';
    if (!_billStatuses.contains(status)) status = 'open';
    var currency = kSupportedCurrencies.contains(existing?.currency ?? '')
        ? existing!.currency
        : DisplayCurrency.code;
    var fieldErrors = <String, String?>{};

    await showDashSheet<void>(
      context: context,
      title: isEdit ? 'Edit bill' : 'New bill',
      description: isEdit ? 'Update this bill' : 'Track money you owe',
      builder: (ctx, setSheetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Description'),
            DashTextField(
              controller: descCtrl,
              hint: 'What is this bill for?',
              autofocus: true,
              errorText: fieldErrors['description'],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Number'),
            DashTextField(
              controller: numberCtrl,
              hint: 'Optional',
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Status'),
            DashDropdown<String>(
              value: status,
              items: _billStatuses,
              labelOf: _statusLabel,
              onChanged: (v) => setSheetState(() => status = v),
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Amount'),
            Row(
              children: [
                Expanded(
                  child: DashTextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
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
            const DashFieldLabel('Issue date'),
            DashTextField(
              controller: issueCtrl,
              hint: 'YYYY-MM-DD',
              errorText: fieldErrors['issueDate'],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Due date'),
            DashTextField(
              controller: dueCtrl,
              hint: 'YYYY-MM-DD (optional)',
              errorText: fieldErrors['dueDate'],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Notes'),
            DashTextField(
              controller: notesCtrl,
              hint: 'Optional',
            ),
            const SizedBox(height: 18),
            AccentButton(
              label: isEdit ? 'Save' : 'Add bill',
              onPressed: () async {
                final descErr = requiredText(descCtrl.text, 'Description');
                final amountErr = positiveAmount(amountCtrl.text, 'Amount');
                final issueErr = requiredIsoDate(issueCtrl.text, 'Issue date');
                final dueErr = optionalIsoDate(dueCtrl.text, 'Due date');
                final errors = <String, String?>{
                  if (descErr != null) 'description': descErr,
                  if (amountErr != null) 'amount': amountErr,
                  if (issueErr != null) 'issueDate': issueErr,
                  if (dueErr != null) 'dueDate': dueErr,
                };
                setSheetState(() => fieldErrors = errors);
                if (hasFieldErrors(errors)) {
                  toast(
                    context,
                    firstFieldError(errors) ?? 'Fix the highlighted fields',
                  );
                  return;
                }
                final amount = double.parse(amountCtrl.text.trim());
                final due = dueCtrl.text.trim();
                if (isEdit) {
                  final updated = await _ctrl.update(
                    existing.id,
                    description: descCtrl.text.trim(),
                    number: numberCtrl.text.trim(),
                    status: status,
                    issueDate: issueCtrl.text.trim(),
                    dueDate: due.isEmpty ? null : due,
                    clearDueDate: due.isEmpty,
                    originalAmount: amount,
                    currency: currency,
                    notes: notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim(),
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  toast(
                    context,
                    updated == null ? 'Could not update' : 'Bill saved',
                  );
                } else {
                  final created = await _ctrl.create(
                    description: descCtrl.text.trim(),
                    number: numberCtrl.text.trim(),
                    status: status,
                    issueDate: issueCtrl.text.trim(),
                    dueDate: due.isEmpty ? null : due,
                    originalAmount: amount,
                    currency: currency,
                    notes: notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim(),
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  toast(
                    context,
                    created == null ? 'Could not create' : 'Bill added',
                  );
                }
              },
            ),
            if (isEdit) ...[
              const SizedBox(height: 10),
              if (existing.canSettle)
                GhostButton(
                  label: 'Record payment',
                  onPressed: () {
                    Navigator.pop(ctx);
                    // ignore: discarded_futures
                    _openSettle(existing);
                  },
                ),
              const SizedBox(height: 10),
              GhostButton(
                label: 'Delete',
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _confirmDelete(existing);
                },
              ),
            ],
          ],
        );
      },
    );

    numberCtrl.dispose();
    descCtrl.dispose();
    amountCtrl.dispose();
    issueCtrl.dispose();
    dueCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _openSettle(BillRecord bill) async {
    final accounts = _payableAccounts;
    if (accounts.isEmpty) {
      toast(context, 'Add an account before recording a payment');
      return;
    }
    final amountCtrl = TextEditingController(
      text: bill.amountRemaining.toStringAsFixed(2),
    );
    final dateCtrl = TextEditingController(text: _todayIso());
    var accountId = bill.accountId;
    if (accountId == null ||
        !accounts.any((a) => a.id == accountId)) {
      accountId = accounts.first.id;
    }
    var fieldErrors = <String, String?>{};

    await showDashSheet<void>(
      context: context,
      title: 'Record payment',
      description: 'Pay remaining ${moneyNative(bill.amountRemaining, bill.currency)}',
      builder: (ctx, setSheetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Pay from'),
            DashDropdown<String>(
              value: accountId!,
              items: [for (final a in accounts) a.id!],
              labelOf: (id) {
                final a = accounts.firstWhere((x) => x.id == id);
                return a.displayName;
              },
              onChanged: (v) => setSheetState(() => accountId = v),
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Amount'),
            DashTextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              errorText: fieldErrors['amount'],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Date'),
            DashTextField(
              controller: dateCtrl,
              hint: 'YYYY-MM-DD',
              errorText: fieldErrors['date'],
            ),
            const SizedBox(height: 18),
            AccentButton(
              label: 'Record payment',
              onPressed: () async {
                final amountErr = positiveAmount(amountCtrl.text, 'Amount');
                final dateErr = requiredIsoDate(dateCtrl.text, 'Date');
                final errors = <String, String?>{
                  if (amountErr != null) 'amount': amountErr,
                  if (dateErr != null) 'date': dateErr,
                };
                setSheetState(() => fieldErrors = errors);
                if (hasFieldErrors(errors)) {
                  toast(
                    context,
                    firstFieldError(errors) ?? 'Fix the highlighted fields',
                  );
                  return;
                }
                final updated = await _ctrl.settle(
                  bill.id,
                  accountId: accountId!,
                  amount: double.parse(amountCtrl.text.trim()),
                  date: dateCtrl.text.trim(),
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                toast(
                  context,
                  updated == null ? 'Could not record payment' : 'Payment recorded',
                );
              },
            ),
          ],
        );
      },
    );

    amountCtrl.dispose();
    dateCtrl.dispose();
  }

  Future<void> _confirmDelete(BillRecord bill) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete bill?'),
        content: Text('Remove ${bill.title}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final removed = await _ctrl.remove(bill.id);
    if (!mounted) return;
    toast(context, removed ? 'Bill deleted' : 'Could not delete');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final remaining = filtered.fold<double>(
      0,
      (s, b) => s + b.amountRemaining,
    );
    final canWrite =
        SpacesScope.maybeOf(context)?.can('transactions', 'write') != false;
    final subtitle = filtered.length == _items.length
        ? '${filtered.length} bill${filtered.length == 1 ? '' : 's'}'
        : '${filtered.length} of ${_items.length} bills';

    return DashModalScaffold(
      body: dashPullToRefresh(
        onRefresh: () => _ctrl.loadForSpace(_ctrl.spaceId),
        backgroundColor: context.dashPanel,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            DashFeedChrome(
              title: 'Bills',
              subtitle: subtitle,
              onPrimary: () => _openEditor(),
              primaryTooltip: 'Add bill',
              primaryEnabled: canWrite,
              metaLine: 'Remaining ${money(remaining)}',
              filterBar: FilterSortBar(
                fields: _filterFields,
                rules: _filterRules,
                sorts: _sortRules,
                selectOptions: _selectOptions,
                defaultFilterField: 'status',
                defaultSortField: 'dueDate',
                search: _search,
                onSearchChanged: (v) => setState(() => _search = v),
                searchHint: 'Search bills…',
                onRulesChanged: (rules) => setState(() => _filterRules = rules),
                onSortsChanged: (sorts) => setState(() => _sortRules = sorts),
                iconButtons: true,
                expandSearch: true,
              ),
            ),
            if (_ctrl.loading)
              const DashLoadingBody(kpiCount: 0, listRows: 5)
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(0, 24, 0, 28),
                        child: Text(
                          _items.isEmpty
                              ? 'No bills yet. Add one to track money you owe.'
                              : 'No bills match these filters',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.dashMute,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (final b in filtered)
                            _BillRow(
                              bill: b,
                              onTap: () => _openEditor(existing: b),
                            ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill, required this.onTap});

  final BillRecord bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final due = bill.dueDate;
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            bill.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.dashInk,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(context, bill.status)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _statusLabel(bill.status),
                            style: TextStyle(
                              color: _statusColor(context, bill.status),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (bill.number.isNotEmpty) bill.number,
                        if (due != null && due.isNotEmpty) 'Due $due',
                      ].join(' · '),
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
              Text(
                moneyNative(bill.amountRemaining, bill.currency),
                style: TextStyle(
                  color: context.dashInk,
                  fontSize: 13,
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
