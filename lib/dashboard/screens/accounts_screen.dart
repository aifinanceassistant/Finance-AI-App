import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../dash_colors.dart';
import '../accounts_controller.dart';
import '../accounts_scope.dart';
import '../dash_sheets.dart';
import '../data.dart';
import '../filter_sort.dart';
import '../form_validation.dart';
import '../shimmer.dart';
import '../spaces_scope.dart';
import '../ui.dart';

const _filterFields = [
  FilterFieldDef(id: 'bank', label: 'Institution', type: FilterFieldType.text),
  FilterFieldDef(id: 'type', label: 'Type', type: FilterFieldType.select),
  FilterFieldDef(id: 'provider', label: 'Provider', type: FilterFieldType.select),
  FilterFieldDef(id: 'status', label: 'Status', type: FilterFieldType.select),
  FilterFieldDef(id: 'balance', label: 'Balance', type: FilterFieldType.number),
  FilterFieldDef(id: 'synced', label: 'Last sync', type: FilterFieldType.date),
];

const _accountTypes = [
  'Checking',
  'Savings',
  'Credit',
  'Cash',
  'IOU',
  'Investment',
];
const _statusLabels = ['Linked', 'Manual', 'Needs reconnect', 'Pending'];

String _accountStatusLabel(DemoAccount a) {
  if (a.provider != 'plaid') return 'Manual';
  switch (a.status) {
    case TxnStatus.failed:
      return 'Needs reconnect';
    case TxnStatus.pending:
      return 'Pending';
    case TxnStatus.succeeded:
      return 'Linked';
  }
}

Object? _accountValue(DemoAccount a, String field) {
  switch (field) {
    case 'bank':
      return a.bank;
    case 'type':
      return a.type;
    case 'provider':
      return a.provider == 'plaid' ? 'Plaid' : 'Manual';
    case 'status':
      return _accountStatusLabel(a);
    case 'balance':
      return a.balance;
    case 'synced':
      return a.synced;
    default:
      return '';
  }
}

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key, this.onRefresh});

  final Future<void> Function()? onRefresh;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<FilterRule> _filterRules = [];
  List<SortRule> _sortRules = [];
  String _search = '';

  AccountsController get _ctrl => AccountsScope.of(context);

  List<DemoAccount> get _accounts => _ctrl.accounts;

  List<String> _selectOptions(String field) {
    if (field == 'status') return _statusLabels;
    if (field == 'provider') return const ['Plaid', 'Manual'];
    if (field == 'type') {
      return [...{..._accounts.map((a) => a.type), ..._accountTypes}].toList()
        ..sort();
    }
    return [];
  }

  List<DemoAccount> get _filtered {
    final searched =
        applySearch(_accounts, _search, _filterFields, _accountValue);
    final filtered = applyFilters(searched, _filterRules, _accountValue);
    return applySort(filtered, _sortRules, _accountValue);
  }

  List<({String institution, List<DemoAccount> accounts, String totalLabel})>
      _institutionGroups(List<DemoAccount> filtered) {
    final order = <String>[];
    final map = <String, List<DemoAccount>>{};
    for (final a in filtered) {
      final institution = a.bank.trim().isEmpty ? 'Other' : a.bank.trim();
      if (!map.containsKey(institution)) {
        order.add(institution);
        map[institution] = [];
      }
      map[institution]!.add(a);
    }
    return [
      for (final institution in order)
        (
          institution: institution,
          accounts: map[institution]!,
          totalLabel: _groupTotalLabel(map[institution]!),
        ),
    ];
  }

  String _groupTotalLabel(List<DemoAccount> accounts) {
    final currencies = {
      for (final a in accounts) a.nativeCurrency,
    };
    if (currencies.length == 1) {
      final code = currencies.first;
      final total = accounts.fold<double>(
        0,
        (s, a) => s + (a.originalBalance ?? a.balance),
      );
      return moneyNative(total, code);
    }
    final totalUsd = accounts.fold<double>(0, (s, a) => s + a.balance);
    return money(totalUsd);
  }

  Future<void> _refreshAll() async {
    await _ctrl.syncAll();
    if (!mounted) return;
    toast(
      context,
      'Accounts refreshed · ${_accounts.length} connections synced',
    );
  }

  Future<void> _openConnectSheet() async {
    final searchCtrl = TextEditingController();
    final otherCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final last4Ctrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    String? institution;
    var method = 'choose'; // choose | plaid | manual
    var otherOpen = false;
    var searching = false;
    var hits = <({String id, String name, List<String> countries})>[];
    var type = _accountTypes.first;
    var currency = DisplayCurrency.code;
    var fieldErrors = <String, String?>{};
    void Function(VoidCallback)? setLocal;
    Timer? debounce;

    Future<void> runSearch(String q, void Function(void Function()) setSheetState) async {
      setSheetState(() => searching = true);
      final next = await _ctrl.searchInstitutions(q);
      if (!mounted) return;
      setSheetState(() {
        hits = next;
        searching = false;
      });
    }

    // Seed suggestions
    hits = await _ctrl.searchInstitutions('');

    await showDashSheet<void>(
      context: context,
      title: 'Connect bank',
      description:
          'Search for your bank, then connect with a provider or enter details manually.',
      builder: (ctx, setSheetState) {
        setLocal = setSheetState;
        if (institution == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DashFieldLabel('Search institutions'),
              DashTextField(
                controller: searchCtrl,
                hint: 'Search banks in the US, Canada, UK, EU…',
              ),
              ListenableBuilder(
                listenable: searchCtrl,
                builder: (_, _) {
                  debounce?.cancel();
                  debounce = Timer(const Duration(milliseconds: 300), () {
                    runSearch(searchCtrl.text, setSheetState);
                  });
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Powered by Plaid’s institution catalog when configured.',
                style: TextStyle(fontSize: 11, color: context.dashSoftMute),
              ),
              const SizedBox(height: 12),
              if (searching)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Searching…',
                      style: TextStyle(color: context.dashSoftMute),
                    ),
                  ),
                )
              else if (hits.isEmpty && searchCtrl.text.trim().isNotEmpty)
                Text(
                  'No match — use Other to enter a custom name.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.dashInk,
                    fontSize: 13,
                  ),
                )
              else
                for (final hit in hits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: context.dashPanel,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: context.dashLine),
                      ),
                      child: ListTile(
                        title: Text(
                          hit.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: hit.countries.isEmpty
                            ? null
                            : Text(
                                hit.countries.join(' · '),
                                style: const TextStyle(fontSize: 11),
                              ),
                        trailing: const Text(
                          'Select',
                          style: TextStyle(
                            color: Color(0xFF3B9AE0),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () => setSheetState(() {
                          institution = hit.name;
                          method = 'choose';
                          otherOpen = false;
                        }),
                      ),
                    ),
                  ),
              const SizedBox(height: 8),
              if (!otherOpen)
                OutlinedButton(
                  onPressed: () => setSheetState(() {
                    otherOpen = true;
                    otherCtrl.text = searchCtrl.text.trim();
                  }),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Other — specify institution name'),
                  ),
                )
              else ...[
                const DashFieldLabel('Institution name'),
                DashTextField(
                  controller: otherCtrl,
                  hint: 'e.g. Local credit union',
                ),
                const SizedBox(height: 8),
                AccentButton(
                  label: 'Use this name',
                  onPressed: () {
                    final name = otherCtrl.text.trim();
                    if (name.isEmpty) return;
                    setSheetState(() {
                      institution = name;
                      method = 'choose';
                      otherOpen = false;
                    });
                  },
                ),
              ],
            ],
          );
        }

        Widget selectedChip() {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.dashSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.dashLine),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INSTITUTION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: context.dashSoftMute,
                        ),
                      ),
                      Text(
                        institution!,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.dashInk,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setSheetState(() {
                    institution = null;
                    method = 'choose';
                  }),
                  child: const Text('Change'),
                ),
              ],
            ),
          );
        }

        if (method == 'choose') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              selectedChip(),
              const SizedBox(height: 16),
              Text(
                'How do you want to connect?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.dashMute,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: context.isDark
                        ? [context.dashElevated, context.dashPanel]
                        : const [Color(0xFFEEF6FC), Colors.white],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.isDark
                        ? context.dashLine
                        : const Color(0xFFD7E6F4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Plaid',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B9AE0),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'RECOMMENDED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Securely link $institution. Import accounts and sync balances.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.dashMute,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AccentButton(
                      label: 'Continue with Plaid',
                      onPressed: () => setSheetState(() => method = 'plaid'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.dashPanel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.dashLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter manually',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Type the account details yourself. Balances won’t auto-update from the bank.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.dashMute,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GhostButton(
                      label: 'Enter details',
                      onPressed: () => setSheetState(() => method = 'manual'),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        if (method == 'plaid') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              selectedChip(),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setSheetState(() => method = 'choose'),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('← All connection options'),
                ),
              ),
              const SizedBox(height: 8),
              AccentButton(
                label: 'Link $institution',
                onPressed: () async {
                  try {
                    final result = await _ctrl.linkWithPlaid();
                    if (!mounted) return;
                    if (result == null) return;
                    Navigator.pop(context);
                    toast(
                      context,
                      '${result.institutionName} linked · ${result.count} account${result.count == 1 ? '' : 's'}',
                    );
                  } catch (e) {
                    if (!mounted) return;
                    toast(
                      context,
                      e.toString().replaceFirst('Exception: ', ''),
                    );
                  }
                },
              ),
            ],
          );
        }

        // manual
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            selectedChip(),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setSheetState(() => method = 'choose'),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text('← All connection options'),
              ),
            ),
            const SizedBox(height: 8),
            const DashFieldLabel('Account name'),
            DashTextField(
              controller: nameCtrl,
              hint: 'e.g. Everyday checking',
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Account type'),
            DashDropdown<String>(
              value: type,
              items: _accountTypes,
              labelOf: (v) => v == 'IOU' ? 'IOU (shared expenses)' : v,
              onChanged: (v) => setSheetState(() => type = v),
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Last 4 digits'),
            DashTextField(
              controller: last4Ctrl,
              hint: '4242',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              errorText: fieldErrors['lastFour'],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Starting balance'),
            Row(
              children: [
                Expanded(
                  child: DashTextField(
                    controller: balanceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                    ],
                    errorText: fieldErrors['balance'],
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
        // Add account only meaningful on manual; builder can't easily gate actions,
        // so keep a primary that creates when institution + manual fields ready.
        Expanded(
          child: AccentButton(
            label: 'Add account',
            onPressed: () async {
              final trimmed = (institution ?? '').trim();
              final institutionErr = requiredText(trimmed, 'Institution');
              final lastFourErr = optionalLastFour(last4Ctrl.text);
              final balanceErr = accountBalanceAmount(balanceCtrl.text, type);
              final errors = <String, String?>{
                if (institutionErr != null) 'institution': institutionErr,
                if (lastFourErr != null) 'lastFour': lastFourErr,
                if (balanceErr != null) 'balance': balanceErr,
              };
              setLocal?.call(() => fieldErrors = errors);
              if (hasFieldErrors(errors)) {
                toast(
                  context,
                  firstFieldError(errors) ?? 'Fix the highlighted fields',
                );
                return;
              }
              if (method != 'manual') {
                toast(context, 'Choose Enter manually to add details');
                return;
              }
              final digits = last4Ctrl.text.replaceAll(RegExp(r'\D'), '');
              final last4 = digits; // empty OK; else exactly 4 (validated)
              final created = await _ctrl.create(
                institution: trimmed,
                name: nameCtrl.text.trim(),
                type: type,
                lastFour: last4,
                balance: double.tryParse(balanceCtrl.text) ?? 0,
                defaultCurrency: currency,
              );
              if (!mounted) return;
              if (created == null) {
                toast(context, 'Could not connect account');
                return;
              }
              Navigator.pop(context);
              toast(context, '${created.displayName} is linked and syncing');
            },
          ),
        ),
      ],
    );

    searchCtrl.dispose();
    otherCtrl.dispose();
    nameCtrl.dispose();
    last4Ctrl.dispose();
    balanceCtrl.dispose();
    debounce?.cancel();
  }

  Future<void> _openEditSheet(DemoAccount account) async {
    final bankCtrl = TextEditingController(text: account.bank);
    final nameCtrl = TextEditingController(
      text: (account.name ?? '').trim().isEmpty
          ? account.bank
          : account.name!.trim(),
    );
    final last4Ctrl = TextEditingController(text: account.digits);
    var type = _accountTypes.contains(account.type)
        ? account.type
        : _accountTypes.first;
    final nativeBal = account.originalBalance ?? account.balance;
    final balanceCtrl = TextEditingController(
      text: type == 'Credit'
          ? nativeBal.abs().toStringAsFixed(2)
          : nativeBal.toStringAsFixed(2),
    );
    var currency = kSupportedCurrencies.contains(account.nativeCurrency)
        ? account.nativeCurrency
        : DisplayCurrency.code;
    var fieldErrors = <String, String?>{};

    await showDashSheet<void>(
      context: context,
      title: 'Edit account',
      description: 'Update this institution’s details',
      builder: (ctx, setSheetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Institution'),
            DashTextField(
              controller: bankCtrl,
              hint: 'Chase, Amex, Fidelity…',
              autofocus: true,
              errorText: fieldErrors['institution'],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Account name'),
            DashTextField(
              controller: nameCtrl,
              hint: 'e.g. Everyday checking',
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Account type'),
            DashDropdown<String>(
              value: type,
              items: _accountTypes,
              labelOf: (t) => t == 'IOU' ? 'IOU (shared expenses)' : t,
              onChanged: (v) => setSheetState(() => type = v),
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Last 4 digits'),
            DashTextField(
              controller: last4Ctrl,
              hint: '4242',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              errorText: fieldErrors['lastFour'],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Balance'),
            Row(
              children: [
                Expanded(
                  child: DashTextField(
                    controller: balanceCtrl,
                    hint: '0.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    errorText: fieldErrors['balance'],
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
            const SizedBox(height: 18),
            AccentButton(
              label: 'Save',
              onPressed: () async {
                final trimmed = bankCtrl.text.trim();
                final institutionErr = requiredText(trimmed, 'Institution');
                final lastFourErr = optionalLastFour(last4Ctrl.text);
                final balanceErr = accountBalanceAmount(balanceCtrl.text, type);
                final errors = <String, String?>{
                  if (institutionErr != null) 'institution': institutionErr,
                  if (lastFourErr != null) 'lastFour': lastFourErr,
                  if (balanceErr != null) 'balance': balanceErr,
                };
                setSheetState(() => fieldErrors = errors);
                if (hasFieldErrors(errors)) {
                  toast(
                    context,
                    firstFieldError(errors) ?? 'Fix the highlighted fields',
                  );
                  return;
                }
                final digits = last4Ctrl.text.replaceAll(RegExp(r'\D'), '');
                final last4 = digits;
                final key = AccountsController.accountKey(account);
                final updated = await _ctrl.update(
                  key: key,
                  institution: trimmed,
                  name: nameCtrl.text.trim(),
                  type: type,
                  lastFour: last4,
                  balance: double.tryParse(balanceCtrl.text) ?? 0,
                  defaultCurrency: currency,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                toast(
                  context,
                  updated == null
                      ? 'Could not update'
                      : '${updated.displayName} saved',
                );
              },
            ),
          ],
        );
      },
    );

    bankCtrl.dispose();
    nameCtrl.dispose();
    last4Ctrl.dispose();
    balanceCtrl.dispose();
  }

  Future<void> _accountRowActions(DemoAccount a) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.dashPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
              if (a.provider == 'plaid') ...[
                ListTile(
                  leading: const Icon(Icons.sync_rounded),
                  title: const Text('Sync'),
                  onTap: () => Navigator.pop(ctx, 'sync'),
                ),
                ListTile(
                  leading: Icon(
                    Icons.link_rounded,
                    color: a.status == TxnStatus.failed
                        ? AppColors.danger
                        : null,
                  ),
                  title: Text(
                    'Reconnect',
                    style: TextStyle(
                      color: a.status == TxnStatus.failed
                          ? AppColors.danger
                          : null,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, 'reconnect'),
                ),
              ],
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: Text('Remove', style: TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    final key = AccountsController.accountKey(a);
    if (action == 'edit') {
      await _openEditSheet(a);
      return;
    }
    if (action == 'sync') {
      await _ctrl.syncOne(key);
      if (!mounted) return;
      toast(context, 'Synced');
      return;
    }
    if (action == 'reconnect') {
      try {
        final result = await _ctrl.reconnect(key);
        if (!mounted) return;
        if (result == null) return;
        toast(context, '${result.institutionName} reconnected');
      } catch (e) {
        if (!mounted) return;
        toast(context, e.toString().replaceFirst('Exception: ', ''));
      }
      return;
    }
    if (action == 'remove') {
      final ok = await _ctrl.remove(key);
      if (!mounted) return;
      toast(context, ok ? 'Connection removed' : 'Could not remove');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final total = filtered.fold<double>(0, (s, a) => s + a.balance);
    final loading = _ctrl.loading;
    final canWrite =
        SpacesScope.maybeOf(context)?.can('accounts', 'write') != false;
    final subtitle = filtered.length == _accounts.length
        ? '${filtered.length} linked'
        : '${filtered.length} of ${_accounts.length} linked';

    return dashPullToRefresh(
      onRefresh: widget.onRefresh ?? _refreshAll,
      backgroundColor: context.dashPanel,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        DashFeedChrome(
          title: 'Accounts',
          subtitle: subtitle,
          onSecondary: _refreshAll,
          secondaryIcon: Icons.sync_rounded,
          secondaryTooltip: 'Refresh all',
          onPrimary: _openConnectSheet,
          primaryTooltip: 'Connect bank',
          primaryEnabled: canWrite,
          metaLine: 'Total ${money(total)}',
          filterBar: FilterSortBar(
            fields: _filterFields,
            rules: _filterRules,
            sorts: _sortRules,
            selectOptions: _selectOptions,
            defaultFilterField: 'type',
            defaultSortField: 'bank',
            search: _search,
            onSearchChanged: (v) => setState(() => _search = v),
            searchHint: 'Search accounts…',
            onRulesChanged: (rules) => setState(() => _filterRules = rules),
            onSortsChanged: (sorts) => setState(() => _sortRules = sorts),
            iconButtons: true,
            expandSearch: true,
          ),
        ),
        if (loading)
          const DashLoadingBody(kpiCount: 1, listRows: 5)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(0, 24, 0, 28),
                    child: Text(
                      _accounts.isEmpty
                          ? 'No accounts linked yet'
                          : 'No accounts match these filters',
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
                      for (final group in _institutionGroups(filtered)) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  group.institution,
                                  style: TextStyle(
                                    color: context.dashMute,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${group.accounts.length} · ${group.totalLabel}',
                                style: TextStyle(
                                  color: context.dashSoftMute,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final a in group.accounts) _buildAccountRow(a),
                      ],
                    ],
                  ),
          ),
      ],
    ),
    );
  }

  Widget _buildAccountRow(DemoAccount a) {
    final bal = a.originalBalance ?? a.balance;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openEditSheet(a),
        onLongPress: () => _accountRowActions(a),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.dashLine),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  a.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.dashInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                moneyNative(bal, a.nativeCurrency),
                style: TextStyle(
                  color: bal < 0 ? AppColors.danger : context.dashInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
