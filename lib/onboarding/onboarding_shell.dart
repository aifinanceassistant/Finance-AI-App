import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'models.dart';

class OnboardingShell extends StatelessWidget {
  const OnboardingShell({
    super.key,
    required this.phase,
    required this.furthest,
    required this.onPhaseChange,
    required this.child,
  });

  final OnboardingPhase phase;
  final OnboardingPhase furthest;
  final ValueChanged<OnboardingPhase> onPhaseChange;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final index = onboardingOrder.indexOf(phase);
    final furthestIndex = onboardingOrder.indexOf(furthest);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _MinimalChrome(
              index: index,
              onOpenSteps: () => _openSteps(context, furthestIndex),
            ),
            Expanded(child: child),
            SizedBox(height: bottom > 0 ? 0 : 4),
          ],
        ),
      ),
    );
  }

  void _openSteps(BuildContext context, int furthestIndex) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < onboardingOrder.length; i++)
                  ListTile(
                    enabled: i <= furthestIndex,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: i == onboardingOrder.indexOf(phase)
                          ? AppColors.brand
                          : i < onboardingOrder.indexOf(phase)
                          ? const Color(0xFFD9EEFB)
                          : const Color(0xFFF0F3F7),
                      foregroundColor: i == onboardingOrder.indexOf(phase)
                          ? Colors.white
                          : AppColors.ink,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(
                      onboardingOrder[i].word,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: i <= furthestIndex
                            ? AppColors.ink
                            : AppColors.mute,
                      ),
                    ),
                    subtitle: Text(onboardingOrder[i].hint),
                    trailing: i > furthestIndex
                        ? const Icon(Icons.lock_outline, size: 16)
                        : null,
                    onTap: i <= furthestIndex
                        ? () {
                            Navigator.pop(context);
                            onPhaseChange(onboardingOrder[i]);
                          }
                        : null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MinimalChrome extends StatelessWidget {
  const _MinimalChrome({required this.index, required this.onOpenSteps});

  final int index;
  final VoidCallback onOpenSteps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'F',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < onboardingOrder.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= index
                              ? AppColors.brand
                              : const Color(0xFFD0D5DD),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onOpenSteps,
                icon: const Icon(Icons.menu_rounded, size: 22),
                color: AppColors.ink,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (index + 1) / onboardingOrder.length,
              minHeight: 3,
              backgroundColor: const Color(0xFFE8ECF1),
              color: AppColors.brand,
            ),
          ),
        ),
      ],
    );
  }
}

class OnboardingActions extends StatelessWidget {
  const OnboardingActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryEnabled = true,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool primaryEnabled;

  @override
  Widget build(BuildContext context) {
    final primary = SizedBox(
      height: 44,
      child: FilledButton(
        onPressed: primaryEnabled ? onPrimary : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          primaryLabel,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );

    final secondary = secondaryLabel != null && onSecondary != null
        ? TextButton(
            onPressed: onSecondary,
            child: Text(
              secondaryLabel!,
              style: const TextStyle(
                color: AppColors.mute,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : null;

    if (secondary != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Row(
          children: [
            Expanded(child: secondary),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: primary),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: primary,
    );
  }
}
