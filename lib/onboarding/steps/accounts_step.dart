import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../providers/plaid_link_flow.dart';
import '../../theme/app_theme.dart';
import '../models.dart';
import '../onboarding_api.dart';
import '../onboarding_dialogs.dart';
import '../onboarding_layout.dart';
import '../onboarding_shell.dart';

/// Accounts are written to the server as soon as they're linked or added, so
/// the list always reflects what the dashboard will show.
class AccountsStep extends StatefulWidget {
  const AccountsStep({
    super.key,
    required this.spaceId,
    required this.accounts,
    required this.onRefresh,
    required this.onContinue,
    required this.onSkip,
  });

  final String? spaceId;
  final List<LinkedAccount> accounts;
  final Future<void> Function() onRefresh;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  State<AccountsStep> createState() => _AccountsStepState();
}

class _AccountsStepState extends State<AccountsStep> {
  bool _plaidBusy = false;
  String? _removingId;

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _remove(String id) async {
    setState(() => _removingId = id);
    final err = await deleteOnboardingAccount(AuthScope.read(context), id);
    if (!mounted) return;
    if (err != null) {
      setState(() => _removingId = null);
      _snack(err);
      return;
    }
    await widget.onRefresh();
    if (mounted) setState(() => _removingId = null);
  }

  Future<void> _confirmSkip() async {
    final ok = await showOnboardingConfirm(
      context,
      title: 'Skip adding accounts?',
      body: 'You can connect banks and cards later. Spending and balances stay empty until you do.',
      confirmLabel: 'Skip for now',
    );
    if (ok == true) widget.onSkip();
  }

  Future<void> _linkWithPlaid() async {
    final auth = AuthScope.read(context);
    final spaceId = widget.spaceId;
    if (auth.isFake || !auth.isSignedIn || spaceId == null) {
      _snack('Your workspace is still loading — try again in a moment');
      return;
    }
    setState(() => _plaidBusy = true);
    try {
      final result = await PlaidLinkFlow(auth).connect(portfolioId: spaceId);
      if (!mounted || result == null) return;
      await widget.onRefresh();
      if (!mounted) return;
      final n = result.created + result.updated;
      _snack(
        'Linked ${result.institutionName}'
        '${n > 0 ? ' · $n account${n == 1 ? '' : 's'}' : ''}',
      );
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _plaidBusy = false);
    }
  }

  Future<void> _addManual() async {
    final spaceId = widget.spaceId;
    if (spaceId == null) {
      _snack('Your workspace is still loading — try again in a moment');
      return;
    }
    final added = await showOnboardingSheet<bool>(
      context,
      title: 'Add an account manually',
      subtitle: 'For cash, wallets, or banks Plaid doesn’t support. Update the balance any time.',
      builder: (_) => _ManualAccountForm(spaceId: spaceId),
    );
    if (added == true) await widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final canPlaid = !auth.isFake && auth.isSignedIn;
    final ready = widget.spaceId != null;

    return OnboardingStepScaffold(
      title: 'Where does your money live?',
      subtitle: 'Connect banks, cards, and investments. FinanceAI uses read-only access.',
      body: [
        if (canPlaid) ...[
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: _plaidBusy || !ready ? null : _linkWithPlaid,
              icon: _plaidBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.account_balance_rounded, size: 18),
              label: Text(
                _plaidBusy ? 'Opening Plaid…' : 'Connect a bank or card',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: ready ? _addManual : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Add manually',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brand,
              side: const BorderSide(color: AppColors.brand),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        if (widget.accounts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Linked (${widget.accounts.length})',
            style: const TextStyle(
              color: AppColors.mute,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          for (final account in widget.accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE0E6EE)),
                ),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: account.color,
                    child: Text(
                      account.institution.characters.first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    account.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${account.institution}${account.last4 != null ? ' ····${account.last4}' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        money(account.balance),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (_removingId == account.id)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        IconButton(
                          onPressed: _removingId == null
                              ? () => _remove(account.id)
                              : null,
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Remove',
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
      actions: OnboardingActions(
        primaryLabel: widget.accounts.isEmpty
            ? 'Continue without accounts'
            : 'Continue',
        onPrimary: widget.accounts.isEmpty ? _confirmSkip : widget.onContinue,
        secondaryLabel: widget.accounts.isEmpty ? null : 'Skip for now',
        onSecondary: widget.accounts.isEmpty ? null : _confirmSkip,
      ),
    );
  }
}

class _ManualAccountForm extends StatefulWidget {
  const _ManualAccountForm({required this.spaceId});

  final String spaceId;

  @override
  State<_ManualAccountForm> createState() => _ManualAccountFormState();
}

class _ManualAccountFormState extends State<_ManualAccountForm> {
  final _name = TextEditingController();
  final _institution = TextEditingController();
  final _balance = TextEditingController();
  String _type = manualAccountTypes.first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _institution.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the account a name');
      return;
    }
    final balance =
        double.tryParse(_balance.text.replaceAll(RegExp(r'[^0-9.\-]'), '')) ??
        0;
    setState(() {
      _saving = true;
      _error = null;
    });
    final institution = _institution.text.trim();
    final err = await createManualAccount(
      AuthScope.read(context),
      widget.spaceId,
      name: name,
      institution: institution.isEmpty
          ? (_type == 'Cash' ? 'Cash' : 'Manual')
          : institution,
      type: _type,
      balance: balance,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _saving = false;
        _error = err;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in manualAccountTypes)
              ChoiceChip(
                label: Text(t),
                selected: _type == t,
                onSelected: (_) => setState(() => _type = t),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: onboardingInputDecoration('Account name'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _institution,
          textCapitalization: TextCapitalization.words,
          decoration: onboardingInputDecoration('Institution (optional)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _balance,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: onboardingInputDecoration(
            _type == 'Credit' ? 'Amount owed' : 'Current balance',
            prefix: '\$ ',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(
              color: Color(0xFFC44B4B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 46,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _saving ? 'Saving…' : 'Add account',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
