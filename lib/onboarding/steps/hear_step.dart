import 'package:flutter/material.dart';

import '../models.dart';
import '../onboarding_layout.dart';
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
    return OnboardingStepScaffold(
      title: 'How did you hear about us?',
      subtitle: 'Select all that apply. We want to hear from you directly.',
      body: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final source in hearSources)
              OnboardingChoiceTile(
                label: source.label,
                selected: _selected.contains(source.id),
                onTap: () => _toggle(source.id),
              ),
          ],
        ),
      ],
      actions: OnboardingActions(
        primaryLabel: 'Next',
        primaryEnabled: _selected.isNotEmpty,
        onPrimary: () => widget.onContinue(_selected.toList()),
      ),
    );
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }
}
