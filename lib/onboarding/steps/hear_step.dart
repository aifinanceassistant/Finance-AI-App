import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models.dart';
import '../onboarding_shell.dart';

class HearStep extends StatefulWidget {
  const HearStep({super.key, required this.onContinue});

  final ValueChanged<List<String>> onContinue;

  @override
  State<HearStep> createState() => _HearStepState();
}

class _HearStepState extends State<HearStep> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            children: [
              const Text(
                'How did you hear about us?',
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
                'Select all that apply. We want to hear from you directly.',
                style: TextStyle(
                  color: AppColors.mute,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final source in hearSources)
                    SizedBox(
                      width: (MediaQuery.sizeOf(context).width - 50) / 2,
                      child: _SourceCard(
                        label: source.label,
                        selected: _selected.contains(source.id),
                        onTap: () {
                          setState(() {
                            if (_selected.contains(source.id)) {
                              _selected.remove(source.id);
                            } else {
                              _selected.add(source.id);
                            }
                          });
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        OnboardingActions(
          primaryLabel: 'Next',
          primaryEnabled: _selected.isNotEmpty,
          onPrimary: () => widget.onContinue(_selected.toList()),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
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
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: selected ? AppColors.brand : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selected ? AppColors.brand : const Color(0xFFD0D5DD),
                  ),
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
