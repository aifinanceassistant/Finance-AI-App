import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../accounts_controller.dart';
import '../accounts_scope.dart';
import '../dash_sheets.dart';
import '../data.dart';
import '../filter_sort.dart';
import '../shimmer.dart';
import '../ui.dart';

const _filterFields = [
  FilterFieldDef(id: 'bank', label: 'Institution', type: FilterFieldType.text),
  FilterFieldDef(id: 'type', label: 'Type', type: FilterFieldType.select),
  FilterFieldDef(id: 'status', label: 'Status', type: FilterFieldType.select),
  FilterFieldDef(id: 'balance', label: 'Balance', type: FilterFieldType.number),
  FilterFieldDef(id: 'synced', label: 'Last sync', type: FilterFieldType.date),
];

const _accountTypes = ['Checking', 'Savings', 'Credit', 'Cash'];
const _statusLabels = ['Succeeded', 'Pending', 'Failed'];

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

Object? _accountValue(DemoAccount a, String field) {
  switch (field) {
    case 'bank':
      return a.bank;
    case 'type':
      return a.type;
    case 'status':
      return _statusLabel(a.status);
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
    final bankCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final last4Ctrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    var type = _accountTypes.first;

    await showDashSheet<void>(
      context: context,
      title: 'Connect bank',
      description: 'Link an institution to sync balances and transactions',
      builder: (ctx, setSheetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Institution'),
            DashTextField(
              controller: bankCtrl,
              hint: 'Chase, Amex, Fidelity…',
              autofocus: true,
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
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Starting balance'),
            DashTextField(
              controller: balanceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
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
            label: 'Connect',
            onPressed: () async {
              final trimmed = bankCtrl.text.trim();
              if (trimmed.isEmpty) {
                toast(context, 'Enter a bank or broker name');
                return;
              }
              final digits = last4Ctrl.text.replaceAll(RegExp(r'\D'), '');
              final last4 = digits.length >= 4
                  ? digits.substring(digits.length - 4)
                  : (digits.isEmpty ? '0000' : digits.padLeft(4, '0'));
              final created = await _ctrl.create(
                institution: trimmed,
                name: nameCtrl.text.trim(),
                type: type,
                lastFour: last4,
                balance: double.tryParse(balanceCtrl.text) ?? 0,
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

    bankCtrl.dispose();
    nameCtrl.dispose();
    last4Ctrl.dispose();
    balanceCtrl.dispose();
  }

  Future<void> _openEditSheet(DemoAccount account) async {
    final bankCtrl = TextEditingController(text: account.bank);
    final nameCtrl = TextEditingController(
      text: (account.name ?? '').trim().isEmpty
          ? account.bank
          : account.name!.trim(),
    );
    final last4Ctrl = TextEditingController(text: account.digits);
    final balanceCtrl = TextEditingController(
      text: account.balance.abs().toStringAsFixed(2),
    );
    var type = _accountTypes.contains(account.type)
        ? account.type
        : _accountTypes.first;

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
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Balance'),
            DashTextField(
              controller: balanceCtrl,
              hint: '0.00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
            const SizedBox(height: 18),
            AccentButton(
              label: 'Save',
              onPressed: () async {
                final trimmed = bankCtrl.text.trim();
                if (trimmed.isEmpty) {
                  toast(context, 'Enter a bank or broker name');
                  return;
                }
                final digits = last4Ctrl.text.replaceAll(RegExp(r'\D'), '');
                final last4 = digits.length >= 4
                    ? digits.substring(digits.length - 4)
                    : (digits.isEmpty ? '0000' : digits.padLeft(4, '0'));
                final key = AccountsController.accountKey(account);
                final updated = await _ctrl.update(
                  key: key,
                  institution: trimmed,
                  name: nameCtrl.text.trim(),
                  type: type,
                  lastFour: last4,
                  balance: double.tryParse(balanceCtrl.text) ?? 0,
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
            AccentButton(label: 'Connect bank', onPressed: _openConnectSheet),
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
                  title: 'Institutions',
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
                                if (a.displayName != a.bank) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    a.bank,
                                    style: const TextStyle(
                                      color: AppColors.softMute,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      '${a.type} · ',
                                      style: const TextStyle(
                                        color: AppColors.mute,
                                        fontSize: 12,
                                      ),
                                    ),
                                    AccountNumber(account: a),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    StatusPill(status: a.status),
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
                                      onTap: () async {
                                        final key =
                                            AccountsController.accountKey(a);
                                        await _ctrl.reconnect(key);
                                        if (!mounted) return;
                                        toast(context, 'Reconnected');
                                      },
                                    ),
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
                            money(a.balance),
                            style: TextStyle(
                              color: a.balance < 0
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

class _AccountAction extends StatelessWidget {
  const _AccountAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.mute;
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
          color: Colors.transparent,
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
