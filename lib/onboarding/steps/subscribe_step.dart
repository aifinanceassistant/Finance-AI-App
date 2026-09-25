import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../billing/stripe_billing.dart';
import '../../theme/app_theme.dart';
import '../onboarding_dialogs.dart';
import '../onboarding_layout.dart';
import '../onboarding_shell.dart';

/// Mirrors `TRIAL_DAYS` in the web app's `lib/billing/plans.ts`.
const _trialDays = 14;

typedef _Promo = ({
  String code,
  bool valid,
  double? percentOff,
  int? amountOff,
  String? currency,
});

const _reviews = [
  (
    title: 'Simply the best',
    body: 'This is by far the best budgeting app I have ever used, and I’ve tried a lot of them.',
  ),
  (
    title: 'Finally clear',
    body: 'Net worth, budgets, and transfers all make sense now. I check it every morning.',
  ),
  (
    title: 'Worth every cent',
    body: 'The AI categorization alone saved me hours. Setup was painless.',
  ),
];

/// Plus trial step — yearly / monthly, aligned with web subscribe.
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
  /// `yearly` | `monthly`
  String _billing = 'yearly';
  final _referral = TextEditingController();
  bool _busy = false;
  String? _checkoutError;
  int _review = 0;
  Timer? _reviewTimer;
  Timer? _promoTimer;
  _Promo? _promo;
  String _lastReferral = '';

  @override
  void initState() {
    super.initState();
    _referral.addListener(_onReferralChanged);
    _reviewTimer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (!mounted) return;
      setState(() => _review = (_review + 1) % _reviews.length);
    });
  }

  @override
  void dispose() {
    _reviewTimer?.cancel();
    _promoTimer?.cancel();
    _referral.dispose();
    super.dispose();
  }

  String get _referralNormalized =>
      _referral.text.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  void _onReferralChanged() {
    final code = _referralNormalized;
    if (code == _lastReferral) return;
    _lastReferral = code;
    _promoTimer?.cancel();
    setState(() {});
    if (code.length < 3) return;
    _promoTimer = Timer(const Duration(milliseconds: 450), () async {
      final res = await checkPromotionCode(AuthScope.read(context), code);
      if (!mounted) return;
      setState(() {
        _promo = (
          code: code,
          valid: res.valid,
          percentOff: res.percentOff,
          amountOff: res.amountOff,
          currency: res.currency,
        );
      });
    });
  }

  _Promo? get _promoForCode =>
      _promo?.code == _referralNormalized ? _promo : null;

  bool get _promoChecking =>
      _referralNormalized.length >= 3 && _promoForCode == null;

  bool get _referralAccepted => _promoForCode?.valid ?? false;

  bool get _referralInvalid =>
      _referralNormalized.length >= 3 &&
      _promoForCode != null &&
      !_promoForCode!.valid;

  String get _discountLabel {
    final p = _promoForCode;
    if (p == null || !p.valid) return '';
    if (p.percentOff != null) {
      final pct = p.percentOff!;
      return '${pct % 1 == 0 ? pct.toInt() : pct}% off';
    }
    if (p.amountOff != null) return '${_money(p.amountOff! / 100)} off';
    return 'Discount';
  }

  double _discounted(double base) {
    final p = _promoForCode;
    if (p == null || !p.valid) return base;
    if (p.percentOff != null) {
      return (base * (1 - p.percentOff! / 100) * 100).round() / 100;
    }
    final usd = p.currency == null || p.currency!.toLowerCase() == 'usd';
    if (p.amountOff != null && usd) {
      final v = ((base - p.amountOff! / 100) * 100).round() / 100;
      return v < 0 ? 0 : v;
    }
    return base;
  }

  double get _basePrice => _billing == 'yearly' ? 49.9 : 4.99;

  double get _chargedPrice => _discounted(_basePrice);

  String _money(num n) {
    final fixed = n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2);
    return '\$$fixed';
  }

  String get _planId => _billing == 'yearly' ? 'plus-yearly' : 'plus-monthly';

  Future<void> _startTrial() async {
    if (_promoChecking) return;
    if (_referralNormalized.isNotEmpty && !_referralAccepted) {
      setState(
        () => _checkoutError =
            'Remove the referral code or enter a valid one to continue.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _checkoutError = null;
    });
    final auth = AuthScope.read(context);
    final referral = _referralAccepted ? _referralNormalized : '';
    final res = await startStripeCheckoutDetailed(
      auth,
      billing: _billing,
      plan: 'team',
      promotionCode: referral,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.code == 'already_subscribed' || res.code == 'admin_exempt') {
      widget.onContinue(_planId, referral);
      return;
    }
    if (res.error != null) {
      setState(() => _checkoutError = res.error);
      return;
    }
    widget.onContinue(_planId, referral);
  }

  Future<void> _confirmSkip() async {
    final ok = await showOnboardingConfirm(
      context,
      title: 'Skip for now',
      body: 'You can start your free trial any time from Settings → Billing. Some features stay locked until you subscribe.',
      confirmLabel: 'Sounds good',
    );
    if (ok) widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    final yearlyCharged = _discounted(49.9);
    final yearlyDetail =
        'Only ${_money((yearlyCharged / 12 * 100).round() / 100)}/mo';
    final monthlyDetail = _referralAccepted ? _discountLabel : 'Billed monthly';
    final period = _billing == 'yearly' ? 'year' : 'month';

    return OnboardingStepScaffold(
      title: 'Start your free trial',
      subtitle: 'See what FinanceAI can do for you, before you subscribe.',
      body: [
        Text(
          '21,000 5-star reviews',
          style: TextStyle(
            color: AppColors.brand.withValues(alpha: 0.95),
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: _ReviewCard(
            key: ValueKey(_review),
            title: _reviews[_review].title,
            body: _reviews[_review].body,
          ),
        ),
        const SizedBox(height: 18),
        const _SectionLabel('Plan'),
        const SizedBox(height: 8),
        _PlanRow(
          selected: _billing == 'yearly',
          priceLine: _priceLineFor(yearly: true),
          badge: _referralAccepted
              ? 'Best value · $_discountLabel referral discount'
              : 'Best value',
          detail: yearlyDetail,
          onTap: () => setState(() => _billing = 'yearly'),
        ),
        const SizedBox(height: 8),
        _PlanRow(
          selected: _billing == 'monthly',
          priceLine: _priceLineFor(yearly: false),
          badge: _referralAccepted ? '$_discountLabel referral discount' : null,
          detail: monthlyDetail,
          onTap: () => setState(() => _billing = 'monthly'),
        ),
        const SizedBox(height: 16),
        const _SectionLabel('Referral code'),
        const SizedBox(height: 8),
        TextField(
          controller: _referral,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            hintText: 'Enter code (optional)',
            filled: true,
            fillColor: Colors.white,
            suffixIcon: _referralAccepted
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF2F9D6A),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _referralAccepted
                    ? const Color(0xFF7EC9A0)
                    : _referralInvalid
                    ? const Color(0xFFE8B4B4)
                    : const Color(0xFFE0E6EE),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _referralAccepted
                    ? const Color(0xFF7EC9A0)
                    : _referralInvalid
                    ? const Color(0xFFE8B4B4)
                    : const Color(0xFFE0E6EE),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _referralAccepted
                    ? const Color(0xFF2F9D6A)
                    : _referralInvalid
                    ? const Color(0xFFC44B4B)
                    : AppColors.brand,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        if (_promoChecking) ...[
          const SizedBox(height: 6),
          const Text(
            'Checking code…',
            style: TextStyle(
              color: AppColors.mute,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else if (_referralAccepted) ...[
          const SizedBox(height: 6),
          Text(
            'Referral code accepted · $_discountLabel applied',
            style: TextStyle(
              color: Color(0xFF2F9D6A),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ] else if (_referralInvalid) ...[
          const SizedBox(height: 6),
          const Text(
            'That referral code isn’t valid',
            style: TextStyle(
              color: Color(0xFFC44B4B),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 16),
        const _SectionLabel('How your trial works'),
        const SizedBox(height: 10),
        const _TimelineRow(
          title: 'Today, your free trial begins.',
          body: 'FinanceAI analyzes connected accounts to categorize spending and track net worth.',
        ),
        const _TimelineRow(
          title: 'Get a reminder before your trial ends.',
          body: 'We email you before billing starts — no surprises.',
        ),
        const _TimelineRow(
          title: 'After $_trialDays days, your trial ends.',
          body: 'Your Plus subscription begins then. Cancel anytime.',
          isLast: true,
        ),
        const SizedBox(height: 14),
        Text(
          'You’ll enter payment details securely on Stripe. Your trial starts after checkout. '
          'After the free trial, this renews at ${_money(_chargedPrice)}/$period'
          '${_referralAccepted ? ' with your referral discount' : ''}. Cancel anytime.',
          style: const TextStyle(
            color: AppColors.mute,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        if (_checkoutError != null) ...[
          const SizedBox(height: 8),
          Text(
            _checkoutError!,
            style: const TextStyle(
              color: Color(0xFFC44B4B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
      actions: OnboardingActions(
        primaryLabel: _busy
            ? 'Redirecting…'
            : _promoChecking
            ? 'Checking code…'
            : 'Start your free trial',
        onPrimary: _busy || _promoChecking ? () {} : _startTrial,
        secondaryLabel: 'Skip for now',
        onSecondary: _busy ? () {} : _confirmSkip,
      ),
    );
  }

  String _priceLineFor({required bool yearly}) {
    final base = yearly ? 49.9 : 4.99;
    final period = yearly ? 'year' : 'month';
    final charged = _discounted(base);
    if (_referralAccepted && charged != base) {
      return '${_money(base)}/$period → ${_money(charged)}/$period + $_trialDays-day free trial';
    }
    return '${_money(charged)}/$period + $_trialDays-day free trial';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF9AA1AD),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (_) => const Icon(
                Icons.star_rounded,
                size: 16,
                color: Color(0xFFE0B84A),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '“$body”',
            style: const TextStyle(
              color: AppColors.mute,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.selected,
    required this.priceLine,
    required this.detail,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final String priceLine;
  final String? badge;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF5F9FD) : Colors.white,
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
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      priceLine,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        badge!,
                        style: TextStyle(
                          color: AppColors.brand.withValues(alpha: 0.95),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      badge?.contains('off') == true || detail.contains('off')
                      ? const Color(0xFFE8F6EF)
                      : const Color(0xFFE8F3FB),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  detail,
                  style: TextStyle(
                    color: detail.contains('off')
                        ? const Color(0xFF2F9D6A)
                        : const Color(0xFF2A7FC4),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.brand : const Color(0xFFF0F3F7),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
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
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 28,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: const Color(0xFFCFE4F6),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.mute,
                    fontSize: 12,
                    height: 1.35,
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
