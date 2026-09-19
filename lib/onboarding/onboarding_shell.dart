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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phase.word,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${index + 1} of ${onboardingOrder.length} · ${phase.hint}',
                          style: const TextStyle(
                            color: AppColors.mute,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Steps',
                    onPressed: () => _openSteps(context, furthestIndex),
                    icon: const Icon(Icons.menu_rounded, color: AppColors.ink),
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
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE3E8EE),
                  color: AppColors.brand,
                ),
              ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: primaryEnabled ? onPrimary : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                primaryLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSecondary,
              child: Text(
                secondaryLabel!,
                style: const TextStyle(
                  color: AppColors.mute,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
