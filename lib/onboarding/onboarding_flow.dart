import 'package:flutter/material.dart';

import '../auth/auth_scope.dart';
import '../dashboard/shell.dart';
import 'models.dart';
import 'onboarding_shell.dart';
import 'steps/accounts_step.dart';
import 'steps/hear_step.dart';
import 'steps/moves_step.dart';
import 'steps/review_step.dart';
import 'steps/security_step.dart';
import 'steps/subscribe_step.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  OnboardingPhase _phase = OnboardingPhase.hear;
  OnboardingPhase _furthest = OnboardingPhase.hear;
  OnboardingState _state = const OnboardingState();

  void _goTo(OnboardingPhase next) {
    setState(() {
      _phase = next;
      if (onboardingOrder.indexOf(next) >
          onboardingOrder.indexOf(_furthest)) {
        _furthest = next;
      }
    });
  }

  void _finish() async {
    await AuthScope.read(context).completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const DashboardShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      phase: _phase,
      furthest: _furthest,
      onPhaseChange: (phase) => setState(() => _phase = phase),
      child: switch (_phase) {
        OnboardingPhase.hear => HearStep(
            onContinue: (sources) {
              setState(() {
                _state = _state.copyWith(heardFrom: sources);
              });
              _goTo(OnboardingPhase.security);
            },
          ),
        OnboardingPhase.security => SecurityStep(
            onContinue: () {
              setState(() => _state = _state.copyWith(twoFactor: true));
              _goTo(OnboardingPhase.accounts);
            },
            onSkip: () {
              setState(() => _state = _state.copyWith(twoFactor: false));
              _goTo(OnboardingPhase.accounts);
            },
          ),
        OnboardingPhase.accounts => AccountsStep(
            accounts: _state.accounts,
            onAccountsChange: (accounts) {
              setState(() => _state = _state.copyWith(accounts: accounts));
            },
            onContinue: () => _goTo(OnboardingPhase.moves),
            onSkip: () {
              setState(
                () => _state = _state.copyWith(skippedAccounts: true),
              );
              _goTo(OnboardingPhase.moves);
            },
          ),
        OnboardingPhase.moves => MovesStep(
            onContinue: () => _goTo(OnboardingPhase.subscribe),
            onSkip: () => _goTo(OnboardingPhase.subscribe),
          ),
        OnboardingPhase.subscribe => SubscribeStep(
            onContinue: (plan, referral) {
              setState(() {
                _state = _state.copyWith(
                  plan: plan,
                  referral: referral,
                  skippedTrial: false,
                );
              });
              _goTo(OnboardingPhase.review);
            },
            onSkip: () {
              setState(() {
                _state = _state.copyWith(
                  clearPlan: true,
                  skippedTrial: true,
                );
              });
              _goTo(OnboardingPhase.review);
            },
          ),
        OnboardingPhase.review => ReviewStep(
            accounts: _state.accounts,
            onContinue: _finish,
          ),
      },
    );
  }
}
