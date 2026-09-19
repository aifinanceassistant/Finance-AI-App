import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'landing_shared.dart';

class LandingClassic extends StatefulWidget {
  const LandingClassic({
    super.key,
    required this.onStarted,
    required this.onLogin,
    required this.onDemo,
  });

  final VoidCallback onStarted;
  final VoidCallback onLogin;
  final VoidCallback onDemo;

  @override
  State<LandingClassic> createState() => _LandingClassicState();
}

class _LandingClassicState extends State<LandingClassic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _count;
  late final Animation<int> _net;
  late final Animation<int> _delta;

  @override
  void initState() {
    super.initState();
    _count = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    final curve = CurvedAnimation(parent: _count, curve: Curves.easeOutCubic);
    _net = IntTween(begin: 0, end: landingNetWorth).animate(curve);
    _delta = IntTween(begin: 0, end: landingMonthDelta).animate(curve);
    _count.forward();
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        const LandingAtmosphere(),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom * 0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LandingBrandRow(onDemo: widget.onDemo),
                const Spacer(flex: 2),
                const Text(
                  'Net worth',
                  style: TextStyle(
                    color: AppColors.mute,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedBuilder(
                  animation: _net,
                  builder: (_, _) => Text(
                    formatLandingMoney(_net.value),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 48,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: _delta,
                  builder: (_, _) => Text(
                    '+${formatLandingMoney(_delta.value)} this month',
                    style: const TextStyle(
                      color: Color(0xFF2F9D6A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'The money app that keeps your finances on track.',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 28,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Budgets, accounts, and AI coaching in one calm place.',
                  style: TextStyle(
                    color: AppColors.mute,
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(flex: 3),
                LandingActions(
                  onStarted: widget.onStarted,
                  onLogin: widget.onLogin,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
