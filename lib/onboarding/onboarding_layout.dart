import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared Minimal step frame (title + body + sticky actions).
class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    required this.body,
    this.actions,
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> body;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AppColors.mute,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ...body,
            ],
          ),
        ),
        if (actions != null) actions!,
      ],
    );
  }
}

/// Compact selectable option (chip / list) for Minimal onboarding.
class OnboardingChoiceTile extends StatelessWidget {
  const OnboardingChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.body,
  });

  final String label;
  final String? body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (body != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: selected ? const Color(0xFFE8F3FB) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? AppColors.brand : const Color(0xFFE0E6EE),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body!,
                          style: const TextStyle(
                            color: AppColors.mute,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? AppColors.brand : AppColors.mute,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFE8F3FB),
      checkmarkColor: AppColors.brand,
      labelStyle: TextStyle(
        color: selected ? AppColors.brand : AppColors.ink,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      side: BorderSide(
        color: selected ? AppColors.brand : const Color(0xFFE0E6EE),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      showCheckmark: true,
    );
  }
}
