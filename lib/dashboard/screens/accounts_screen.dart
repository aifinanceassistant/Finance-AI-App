import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
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

const _accountTypes = ['Checking', 'Savings', 'Credit', 'Cash'];
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
  const AccountsScreen({super.key});

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
              const Text(
                'Powered by Plaid’s institution catalog when configured.',
                style: TextStyle(fontSize: 11, color: Color(0xFF8898AA)),
              ),
              const SizedBox(height: 12),
              if (searching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Searching…',
                      style: TextStyle(color: Color(0xFF8898AA)),
                    ),
                  ),
                )
              else if (hits.isEmpty && searchCtrl.text.trim().isNotEmpty)
                Text(
                  'No match — use Other to enter a custom name.',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    fontSize: 13,
                  ),
                )
              else
                for (final hit in hits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE3E8EE)),
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
              color: const Color(0xFFF6F9FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE3E8EE)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INSTITUTION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Color(0xFF8898AA),
                        ),
                      ),
                      Text(
                        institution!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
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
              const Text(
                'How do you want to connect?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF697386),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFEEF6FC), Colors.white],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD7E6F4)),
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
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF697386),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE3E8EE)),
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
                    const Text(
                      'Type the account details yourself. Balances won’t auto-update from the bank.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF697386),
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
              labelOf: (v) => v,
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
              final balanceErr = nonNegativeAmount(balanceCtrl.text, 'Balance');
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
    final nativeBal = (account.originalBalance ?? account.balance).abs();
    final balanceCtrl = TextEditingController(
      text: nativeBal.toStringAsFixed(2),
    );
    var type = _accountTypes.contains(account.type)
        ? account.type
        : _accountTypes.first;
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
              labelOf: (t) => t,
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
                final balanceErr = nonNegativeAmount(balanceCtrl.text, 'Balance');
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final total = filtered.fold<double>(0, (s, a) => s + a.balance);
    final loading = _ctrl.loading;

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        DashPageHeader(
          title: 'Accounts',
          subtitle: 'Linked banks and cards',
          actions: [
            GhostButton(label: 'Refresh all', onPressed: _refreshAll),
            AccentButton(
              label: 'Connect bank',
              onPressed: SpacesScope.maybeOf(context)?.can('accounts', 'write') ==
                      false
                  ? null
                  : _openConnectSheet,
            ),
          ],
        ),
        if (loading)
          const DashLoadingBody(kpiCount: 1, listRows: 5)
        else ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: FilterSortBar(
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
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DashPanel(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total balance',
                  style: TextStyle(
                    color: AppColors.mute,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  money(total),
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Across ${filtered.length} of ${_accounts.length} linked accounts',
                  style: const TextStyle(
                    color: AppColors.softMute,
                    fontSize: 13,
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
                  title: 'Accounts',
                  subtitle: 'Open banking connections',
                ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
                    child: Text(
                      _accounts.isEmpty
                          ? 'No accounts linked yet'
                          : 'No accounts match these filters',
                      style: const TextStyle(
                        color: AppColors.mute,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  for (final a in filtered)
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.line)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.displayName,
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  a.bank,
                                  style: const TextStyle(
                                    color: AppColors.softMute,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      a.digits.isEmpty
                                          ? a.type
                                          : '${a.type} · ',
                                      style: const TextStyle(
                                        color: AppColors.mute,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      a.provider == 'plaid'
                                          ? (a.digits.isEmpty
                                              ? 'Plaid'
                                              : 'Plaid · ')
                                          : (a.digits.isEmpty
                                              ? 'Manual'
                                              : 'Manual · '),
                                      style: TextStyle(
                                        color: a.provider == 'plaid'
                                            ? const Color(0xFF2A7FC4)
                                            : AppColors.mute,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    AccountNumber(account: a),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _AccountConnectionPill(account: a),
                                    const SizedBox(width: 8),
                                    Text(
                                      a.synced,
                                      style: const TextStyle(
                                        color: AppColors.softMute,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (a.provider == 'plaid') ...[
                                      _AccountAction(
                                        icon: Icons.sync_rounded,
                                        label: 'Sync',
                                        onTap: () async {
                                          final key =
                                              AccountsController.accountKey(a);
                                          await _ctrl.syncOne(key);
                                          if (!mounted) return;
                                          toast(context, 'Synced');
                                        },
                                      ),
                                      _AccountAction(
                                        icon: Icons.link_rounded,
                                        label: 'Reconnect',
                                        emphasize: a.status == TxnStatus.failed,
                                        onTap: () async {
                                          final key =
                                              AccountsController.accountKey(a);
                                          try {
                                            final result =
                                                await _ctrl.reconnect(key);
                                            if (!mounted) return;
                                            if (result == null) return;
                                            toast(
                                              context,
                                              '${result.institutionName} reconnected',
                                            );
                                          } catch (e) {
                                            if (!mounted) return;
                                            toast(
                                              context,
                                              e.toString().replaceFirst(
                                                    'Exception: ',
                                                    '',
                                                  ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                    _AccountAction(
                                      icon: Icons.edit_outlined,
                                      label: 'Edit',
                                      onTap: () => _openEditSheet(a),
                                    ),
                                    _AccountAction(
                                      icon: Icons.delete_outline_rounded,
                                      label: 'Remove',
                                      danger: true,
                                      onTap: () async {
                                        final key =
                                            AccountsController.accountKey(a);
                                        final ok = await _ctrl.remove(key);
                                        if (!mounted) return;
                                        toast(
                                          context,
                                          ok
                                              ? 'Connection removed'
                                              : 'Could not remove',
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            moneyNative(
                              a.originalBalance ?? a.balance,
                              a.nativeCurrency,
                            ),
                            style: TextStyle(
                              color: (a.originalBalance ?? a.balance) < 0
                                  ? AppColors.danger
                                  : AppColors.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
        ],
      ],
    );
  }
}

class _AccountConnectionPill extends StatelessWidget {
  const _AccountConnectionPill({required this.account});

  final DemoAccount account;

  @override
  Widget build(BuildContext context) {
    final label = _accountStatusLabel(account);
    final (Color bg, Color fg) = switch (label) {
      'Linked' => (const Color(0xFFE6F9F1), AppColors.success),
      'Manual' => (const Color(0xFFF0F3F7), AppColors.mute),
      'Pending' => (const Color(0xFFFFF8E6), AppColors.warning),
      _ => (const Color(0xFFFDE8E8), AppColors.danger),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountAction extends StatelessWidget {
  const _AccountAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final color = danger || emphasize ? AppColors.danger : AppColors.mute;
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 250),
      preferBelow: false,
      verticalOffset: 18,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Material(
          color: emphasize ? const Color(0xFFFEF2F2) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: emphasize
                ? const BorderSide(color: Color(0xFFFECACA))
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: () {
              Tooltip.dismissAllToolTips();
              onTap();
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(icon, size: 18, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
