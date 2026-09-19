import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models.dart';
import '../onboarding_shell.dart';

enum _ReviewId { accounts, income, fixed, labels, plan }

class ReviewStep extends StatefulWidget {
  const ReviewStep({
    super.key,
    required this.accounts,
    required this.onContinue,
  });

  final List<LinkedAccount> accounts;
  final VoidCallback onContinue;

  @override
  State<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<ReviewStep> {
  _ReviewId _focus = _ReviewId.accounts;
  bool _budgetingOn = true;
  double _budgetTotal = 1505;
  double _fixedTotal = 2511.47;
  int _labelCount = 6;

  List<LinkedAccount> get _accounts =>
      widget.accounts.isNotEmpty ? widget.accounts : _mockAccounts;

  static final _mockAccounts = [
    const LinkedAccount(
      id: 'm1',
      name: 'Checking',
      institution: 'Chase',
      kind: AccountKind.depository,
      balance: 4820.44,
      last4: '4421',
      color: Color(0xFF117ACA),
    ),
    const LinkedAccount(
      id: 'm2',
      name: 'Brokerage',
      institution: 'Fidelity',
      kind: AccountKind.investment,
      balance: 48200,
      last4: '2290',
      color: Color(0xFF4C8C2B),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        id: _ReviewId.accounts,
        nav: 'Linked accounts',
        question: 'Is everything connected?',
        metric: '${_accounts.length}',
        hint: 'accounts linked',
        status: _accounts.isNotEmpty ? 'Looks connected' : 'Nothing linked yet',
      ),
      (
        id: _ReviewId.income,
        nav: 'Pay & income',
        question: 'What do you bring in?',
        metric: money(8400),
        hint: 'seen last month',
        status: 'Income detected',
      ),
      (
        id: _ReviewId.fixed,
        nav: 'Fixed costs',
        question: 'What leaves every month?',
        metric: money(_fixedTotal),
        hint: 'committed each month',
        status: '6 recurring',
      ),
      (
        id: _ReviewId.labels,
        nav: 'Spending labels',
        question: 'Do these categories fit you?',
        metric: '$_labelCount',
        hint: 'active labels',
        status: 'Ready to sort',
      ),
      (
        id: _ReviewId.plan,
        nav: 'Monthly plan',
        question: 'Does this budget feel realistic?',
        metric: _budgetingOn ? money(_budgetTotal) : 'Off',
        hint: _budgetingOn ? 'planned to spend' : 'budgeting paused',
        status: _budgetingOn ? 'Plan set' : 'Budgeting off',
      ),
    ];
    final focused = items.firstWhere((i) => i.id == _focus);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            children: [
              const Text(
                'LAST CHECK',
                style: TextStyle(
                  color: AppColors.brand,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Does this look right?',
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
                'Before we open your dashboard, confirm what you earn, what already leaves each month, and how you want the rest organized.',
                style: TextStyle(
                  color: AppColors.mute,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: item.id == _focus
                        ? const Color(0xFFE8F3FB)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => setState(() => _focus = item.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.nav,
                                    style: const TextStyle(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    item.status,
                                    style: TextStyle(
                                      color: item.status.contains('Needs') ||
                                              item.status.contains('Nothing')
                                          ? const Color(0xFFC47A2A)
                                          : const Color(0xFF2F9D6A),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              item.metric,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E6EE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      focused.question,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      focused.hint,
                      style: const TextStyle(color: AppColors.mute),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      focused.metric,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    if (focused.id == _ReviewId.plan) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () =>
                            setState(() => _budgetingOn = !_budgetingOn),
                        child: Text(
                          _budgetingOn ? 'Turn off budgeting' : 'Turn on budgeting',
                        ),
                      ),
                    ],
                    if (focused.id == _ReviewId.fixed) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => setState(() {
                          _fixedTotal += 15.49;
                        }),
                        child: const Text('+ Add a bill (demo)'),
                      ),
                    ],
                    if (focused.id == _ReviewId.labels) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => setState(() => _labelCount += 1),
                        child: const Text('+ Add label (demo)'),
                      ),
                    ],
                    if (focused.id == _ReviewId.plan && _budgetingOn) ...[
                      TextButton(
                        onPressed: () => setState(() => _budgetTotal += 50),
                        child: const Text('Bump plan +\$50 (demo)'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        OnboardingActions(
          primaryLabel: 'Open dashboard',
          onPrimary: widget.onContinue,
        ),
      ],
    );
  }
}
