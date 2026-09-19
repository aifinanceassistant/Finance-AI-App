import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models.dart';
import '../onboarding_shell.dart';

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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip adding accounts?'),
        content: const Text(
          'You can connect banks and cards later. Spending and balances stay empty until you do.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            children: [
              const Text(
                'Where does your money live?',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Connect banks, cards, and investments. FinanceAI uses read-only access.',
                style: TextStyle(
                  color: AppColors.mute,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Suggested',
                style: TextStyle(
                  color: AppColors.mute,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              for (final item in suggestedInstitutions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE0E6EE)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: item.color,
                        child: Text(
                          item.name.characters.first,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        item.kind.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: widget.accounts.any((a) => a.institution == item.name)
                          ? const Icon(Icons.check_circle, color: Color(0xFF2F9D6A))
                          : TextButton(
                              onPressed: () => _link(item),
                              child: const Text('Link'),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                for (final account in widget.accounts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFFE0E6EE)),
                      ),
                      child: ListTile(
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
          ),
        ),
        OnboardingActions(
          primaryLabel: widget.accounts.isEmpty
              ? 'Continue without accounts'
              : 'Continue',
          onPrimary: widget.accounts.isEmpty ? _confirmSkip : widget.onContinue,
          secondaryLabel: widget.accounts.isEmpty ? null : 'Skip for now',
          onSecondary: widget.accounts.isEmpty ? null : _confirmSkip,
        ),
      ],
    );
  }
}
