import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class LandingBrandRow extends StatelessWidget {
  const LandingBrandRow({super.key, required this.onDemo, this.centered = false});

  final VoidCallback onDemo;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final brand = Row(
      mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/icon/app_icon.png',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 8),
        const Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'finance',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                TextSpan(
                  text: 'ai',
                  style: TextStyle(
                    color: AppColors.brand,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (centered) {
      return Column(
        children: [
          brand,
          const SizedBox(height: 10),
          TextButton(
            onPressed: onDemo,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandDark,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Demo mode'),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: brand),
        TextButton(
          onPressed: onDemo,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brandDark,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Demo'),
        ),
      ],
    );
  }
}

class LandingActions extends StatelessWidget {
  const LandingActions({
    super.key,
    required this.onStarted,
    required this.onLogin,
    this.stacked = true,
    this.inkPrimary = true,
  });

  final VoidCallback onStarted;
  final VoidCallback onLogin;
  final bool stacked;
  final bool inkPrimary;

  @override
  Widget build(BuildContext context) {
    final primary = FilledButton(
      onPressed: onStarted,
      style: FilledButton.styleFrom(
        backgroundColor: inkPrimary ? AppColors.ink : AppColors.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: const Text(
        'Get started',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
    final secondary = SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onLogin,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.ink, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text(
          'Log in',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );

    if (!stacked) {
      return Row(
        children: [
          Expanded(child: primary),
          const SizedBox(width: 10),
          Expanded(child: secondary),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        primary,
        const SizedBox(height: 12),
        secondary,
      ],
    );
  }
}

class LandingAtmosphere extends StatelessWidget {
  const LandingAtmosphere({super.key, this.tint});

  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/landing_atmosphere.png',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(color: Colors.white),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.55, -0.15),
              radius: 1.15,
              colors: [
                tint ?? const Color(0xB3CFE8FB),
                const Color(0x99E7F4FC),
                const Color(0xFFFFFFFF),
              ],
              stops: const [0.0, 0.42, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

String formatLandingMoney(int value) {
  final digits = value.toString();
  final buffer = StringBuffer('\$');
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

const landingNetWorth = 1284200;
const landingMonthDelta = 18420;
