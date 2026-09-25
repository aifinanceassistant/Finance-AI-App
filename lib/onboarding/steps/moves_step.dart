import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../onboarding_layout.dart';
import '../onboarding_shell.dart';

class MovesStep extends StatefulWidget {
  const MovesStep({super.key, required this.onContinue, required this.onSkip});

  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  State<MovesStep> createState() => _MovesStepState();
}

class _MovesStepState extends State<MovesStep>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: 'Money moves',
      subtitle: 'FinanceAI sorts activity into spending, transfers, and earnings so budgets stay clear.',
      body: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(const ['Spending', 'Transfers', 'Earnings'][i]),
                    selected: _tabs.index == i,
                    onSelected: (_) => setState(() => _tabs.index = i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: _tabs,
          builder: (context, _) => _MovePanel(index: _tabs.index),
        ),
      ],
      actions: OnboardingActions(
        primaryLabel: 'Continue',
        onPrimary: widget.onContinue,
        secondaryLabel: 'Skip for now',
        onSecondary: widget.onSkip,
      ),
    );
  }
}

class _MovePanel extends StatelessWidget {
  const _MovePanel({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final content = switch (index) {
      0 => (
        title: 'Spending',
        body: 'Everyday purchases and bills. These count toward budgets and category totals.',
        rows: const [
          ('Whole Foods', 'Groceries', '-\$86.40'),
          ('Uber', 'Transportation', '-\$18.20'),
          ('Netflix', 'Subscriptions', '-\$15.49'),
        ],
      ),
      1 => (
        title: 'Transfers',
        body: 'Money you move between your own accounts. These stay out of spending budgets.',
        rows: const [
          ('Chase → Amex', 'Transfer', '-\$500.00'),
          ('Ally → Chase', 'Transfer', '+\$1,000.00'),
        ],
      ),
      _ => (
        title: 'Earnings',
        body: 'Paychecks and other income. These help set your monthly plan ceiling.',
        rows: const [
          ('Acme Corp Payroll', 'Income', '+\$4,200.00'),
          ('Dividend', 'Income', '+\$42.10'),
        ],
      ),
    };

    return Container(
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
            content.title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content.body,
            style: const TextStyle(
              color: AppColors.mute,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          for (final row in content.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.$1,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          row.$2,
                          style: const TextStyle(
                            color: AppColors.mute,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    row.$3,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
