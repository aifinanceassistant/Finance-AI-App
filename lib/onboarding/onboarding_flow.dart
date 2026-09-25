import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_scope.dart';
import '../dashboard/shell.dart';
import 'models.dart';
import 'onboarding_api.dart';
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
  String? _spaceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSpace());
  }

  Future<void> _loadSpace() async {
    final spaceId = await resolveOnboardingPortfolioId(AuthScope.read(context));
    if (!mounted || spaceId == null) return;
    setState(() => _spaceId = spaceId);
    await _refreshAccounts();
  }

  Future<void> _refreshAccounts() async {
    final spaceId = _spaceId;
    if (spaceId == null) return;
    final res = await loadOnboardingAccounts(AuthScope.read(context), spaceId);
    if (!mounted || res.accounts == null) return;
    setState(() => _state = _state.copyWith(accounts: res.accounts));
  }

  void _saveAnswers(Map<String, dynamic> answers) {
    unawaited(AuthScope.read(context).saveOnboardingAnswers(answers));
  }

  void _goTo(OnboardingPhase next) {
    setState(() {
      _phase = next;
      if (onboardingOrder.indexOf(next) > onboardingOrder.indexOf(_furthest)) {
        _furthest = next;
      }
    });
  }

  Future<String?> _finish() async {
    final err = await AuthScope.read(context).completeOnboarding();
    if (err != null) return err;
    if (!mounted) return null;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const DashboardShell()),
      (route) => false,
    );
    return null;
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
            _saveAnswers({'heardFrom': sources});
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
          spaceId: _spaceId,
          accounts: _state.accounts,
          onRefresh: _refreshAccounts,
          onContinue: () {
            _saveAnswers({'skippedAccounts': false});
            _goTo(OnboardingPhase.moves);
          },
          onSkip: () {
            setState(() => _state = _state.copyWith(skippedAccounts: true));
            _saveAnswers({'skippedAccounts': true});
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
            _saveAnswers({
              'plan': plan,
              'referral': referral,
              'skippedTrial': false,
            });
            _goTo(OnboardingPhase.review);
          },
          onSkip: () {
            setState(() {
              _state = _state.copyWith(clearPlan: true, skippedTrial: true);
            });
            _saveAnswers({'plan': null, 'skippedTrial': true});
            _goTo(OnboardingPhase.review);
          },
        ),
        OnboardingPhase.review => ReviewStep(
          spaceId: _spaceId,
          accounts: _state.accounts,
          trialStarted: _state.plan != null,
          onFinish: _finish,
        ),
      },
    );
  }
}
