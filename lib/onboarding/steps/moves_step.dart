import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../onboarding_shell.dart';

class MovesStep extends StatefulWidget {
  const MovesStep({
    super.key,
    required this.onContinue,
    required this.onSkip,
  });

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
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            children: [
              const Text(
                'Money moves',
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
                'FinanceAI sorts activity into spending, transfers, and earnings so budgets stay clear.',
                style: TextStyle(
                  color: AppColors.mute,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F3F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabs,
                  labelColor: AppColors.ink,
                  unselectedLabelColor: AppColors.mute,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: const [
                    Tab(text: 'Spending'),
                    Tab(text: 'Transfers'),
                    Tab(text: 'Earnings'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: _tabs,
                builder: (context, _) => _MovePanel(index: _tabs.index),
              ),
            ],
          ),
        ),
        OnboardingActions(
          primaryLabel: 'Continue',
          onPrimary: widget.onContinue,
          secondaryLabel: 'Skip for now',
          onSecondary: widget.onSkip,
        ),
      ],
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
          body:
              'Everyday purchases and bills. These count toward budgets and category totals.',
          rows: const [
            ('Whole Foods', 'Groceries', '-\$86.40'),
            ('Uber', 'Transportation', '-\$18.20'),
            ('Netflix', 'Subscriptions', '-\$15.49'),
          ],
        ),
      1 => (
          title: 'Transfers',
          body:
              'Money you move between your own accounts. These stay out of spending budgets.',
          rows: const [
            ('Chase → Amex', 'Transfer', '-\$500.00'),
            ('Ally → Chase', 'Transfer', '+\$1,000.00'),
          ],
        ),
      _ => (
          title: 'Earnings',
          body:
              'Paychecks and other income. These help set your monthly plan ceiling.',
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
