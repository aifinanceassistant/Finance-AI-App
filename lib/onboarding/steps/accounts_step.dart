import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../providers/plaid_link_flow.dart';
import '../../theme/app_theme.dart';
import '../models.dart';
import '../onboarding_dialogs.dart';
import '../onboarding_layout.dart';
import '../onboarding_shell.dart';
import '../persist_accounts.dart';

class AccountsStep extends StatefulWidget {
  const AccountsStep({
    super.key,
    required this.accounts,
    required this.onAccountsChange,
    required this.onContinue,
    required this.onSkip,
  });

  final List<LinkedAccount> accounts;
  final ValueChanged<List<LinkedAccount>> onAccountsChange;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  State<AccountsStep> createState() => _AccountsStepState();
}

class _AccountsStepState extends State<AccountsStep> {
  bool _plaidBusy = false;

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _link(({String name, AccountKind kind, double balance, Color color, String last4}) item) {
    if (widget.accounts.any((a) => a.institution == item.name)) return;
    final account = LinkedAccount(
      id: '${item.name}-${DateTime.now().millisecondsSinceEpoch}',
      name: switch (item.kind) {
        AccountKind.credit => 'Credit card',
        AccountKind.investment => 'Brokerage',
        AccountKind.depository => 'Checking',
        AccountKind.loan => 'Loan',
        AccountKind.other => 'Account',
      },
      institution: item.name,
      kind: item.kind,
      balance: item.balance,
      last4: item.last4,
      color: item.color,
    );
    widget.onAccountsChange([...widget.accounts, account]);
  }

  void _remove(String id) {
    widget.onAccountsChange(
      widget.accounts.where((a) => a.id != id).toList(),
    );
  }

  Future<void> _confirmSkip() async {
    final ok = await showOnboardingConfirm(
      context,
      title: 'Skip adding accounts?',
      body:
          'You can connect banks and cards later. Spending and balances stay empty until you do.',
      confirmLabel: 'Skip for now',
    );
    if (ok == true) widget.onSkip();
  }

  Future<void> _linkWithPlaid() async {
    final auth = AuthScope.read(context);
    if (auth.isFake || !auth.isSignedIn) {
      _snack('Sign in to link a bank with Plaid');
      return;
    }
    setState(() => _plaidBusy = true);
    try {
      final portfolioId = await resolveOnboardingPortfolioId(auth);
      if (!mounted) return;
      if (portfolioId == null || portfolioId.isEmpty) {
        _snack('No space yet — accounts will save when you finish onboarding');
        return;
      }
      final result = await PlaidLinkFlow(auth).connect(portfolioId: portfolioId);
      if (!mounted) return;
      if (result == null) return;
      _snack(
        'Linked ${result.institutionName}'
        '${result.created + result.updated > 0 ? ' · ${result.created + result.updated} account${result.created + result.updated == 1 ? '' : 's'}' : ''}',
      );
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _plaidBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final canPlaid = !auth.isFake && auth.isSignedIn;

    return OnboardingStepScaffold(
      title: 'Where does your money live?',
      subtitle:
          'Connect banks, cards, and investments. FinanceAI uses read-only access.',
      body: [
        if (canPlaid) ...[
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _plaidBusy ? null : _linkWithPlaid,
              icon: _plaidBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.account_balance_rounded, size: 18),
              label: Text(
                _plaidBusy ? 'Opening Plaid…' : 'Link with Plaid',
                style: const TextStyle(fontWeight: FontWeight.w700),
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
          const SizedBox(height: 14),
        ],
        const Text(
          'Suggested',
          style: TextStyle(
            color: AppColors.mute,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in suggestedInstitutions)
              ActionChip(
                avatar: CircleAvatar(
                  backgroundColor: item.color,
                  radius: 10,
                  child: Text(
                    item.name.characters.first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                label: Text(item.name),
                onPressed: widget.accounts.any((a) => a.institution == item.name)
                    ? null
                    : () => _link(item),
              ),
          ],
        ),
        if (widget.accounts.isNotEmpty) ...[
          const SizedBox(height: 12),
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
                      IconButton(
                        onPressed: () => _remove(account.id),
                        icon: const Icon(Icons.close, size: 18),
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
