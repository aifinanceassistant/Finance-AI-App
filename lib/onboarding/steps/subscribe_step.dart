import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../billing/stripe_billing.dart';
import '../../theme/app_theme.dart';
import '../onboarding_shell.dart';

const _validCodes = {'FRIEND', 'WELCOME', 'FINANCEAI', 'PLUS2026'};

class SubscribeStep extends StatefulWidget {
  const SubscribeStep({
    super.key,
    required this.onContinue,
    required this.onSkip,
  });

  final void Function(String plan, String referral) onContinue;
  final VoidCallback onSkip;

  @override
  State<SubscribeStep> createState() => _SubscribeStepState();
}

class _SubscribeStepState extends State<SubscribeStep> {
  String _plan = 'plus-yearly';
  final _referral = TextEditingController();
  String? _referralMessage;
  bool _accepted = false;
  bool _busy = false;

  @override
  void dispose() {
    _referral.dispose();
    super.dispose();
  }

  void _applyReferral() {
    final code = _referral.text.trim().toUpperCase();
    setState(() {
      if (_validCodes.contains(code)) {
        _accepted = true;
        _referralMessage = 'Referral code accepted';
      } else {
        _accepted = false;
        _referralMessage = 'Code not recognized';
      }
    });
  }

  Future<void> _startTrial() async {
    setState(() => _busy = true);
    final auth = AuthScope.read(context);
    await auth.completeOnboarding();
    final err = await startStripeCheckout(
      auth,
      billing: _plan == 'plus-yearly' ? 'yearly' : 'monthly',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    widget.onContinue(
      _plan,
      _accepted ? _referral.text.trim().toUpperCase() : '',
    );
  }

  Future<void> _confirmSkip() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip the free trial?'),
        content: const Text(
          "You'll have a day to add a payment method if you want Plus features later.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sounds good'),
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
                'Start your free trial',
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
                'See what FinanceAI can do for a month before you subscribe.',
                style: TextStyle(
                  color: AppColors.mute,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _PlanCard(
                selected: _plan == 'plus-yearly',
                title: 'Plus yearly',
                price: _accepted ? '\$39.92/yr' : '\$49.90/yr',
                badge: 'Best value',
                onTap: () => setState(() => _plan = 'plus-yearly'),
              ),
              const SizedBox(height: 10),
              _PlanCard(
                selected: _plan == 'plus-monthly',
                title: 'Plus monthly',
                price: _accepted ? '\$3.99/mo' : '\$4.99/mo',
                onTap: () => setState(() => _plan = 'plus-monthly'),
              ),
              const SizedBox(height: 18),
              const Text(
                'Referral code',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _referral,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Optional',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0E6EE)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _applyReferral,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ink,
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
              if (_referralMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _referralMessage!,
                  style: TextStyle(
                    color: _accepted
                        ? const Color(0xFF2F9D6A)
                        : const Color(0xFFC47A2A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E6EE)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TimelineRow(title: 'Today', body: 'Full Plus access starts.'),
                    _TimelineRow(
                      title: 'In 7 days',
                      body: 'We remind you before the trial ends.',
                    ),
                    _TimelineRow(
                      title: 'After a month',
                      body: 'Billing begins unless you cancel.',
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        OnboardingActions(
          primaryLabel: _busy ? 'Redirecting…' : 'Start your free trial',
          onPrimary: _busy ? () {} : _startTrial,
          secondaryLabel: 'Skip for now',
          onSecondary: _busy ? () {} : _confirmSkip,
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.selected,
    required this.title,
    required this.price,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final String title;
  final String price;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE8F3FB) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppColors.brand : const Color(0xFFE0E6EE),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      style: const TextStyle(
                        color: AppColors.mute,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? AppColors.brand : AppColors.mute,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.title,
    required this.body,
    this.isLast = false,
  });

  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 34,
                  color: const Color(0xFFCFE4F6),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.mute,
                    fontSize: 13,
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
