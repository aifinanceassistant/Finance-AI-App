import 'package:flutter/material.dart';

enum OnboardingPhase {
  hear,
  security,
  accounts,
  moves,
  subscribe,
  review,
}

extension OnboardingPhaseX on OnboardingPhase {
  String get word => switch (this) {
    OnboardingPhase.hear => 'Start',
    OnboardingPhase.security => 'Protect',
    OnboardingPhase.accounts => 'Connect',
    OnboardingPhase.moves => 'Understand',
    OnboardingPhase.subscribe => 'Subscribe',
    OnboardingPhase.review => 'Review',
  };

  String get hint => switch (this) {
    OnboardingPhase.hear => 'How you found FinanceAI',
    OnboardingPhase.security => 'Authenticator & login security',
    OnboardingPhase.accounts => 'Banks, cards, and balances',
    OnboardingPhase.moves => 'Spending, transfers, and earnings',
    OnboardingPhase.subscribe => 'Free trial & Plus plan',
    OnboardingPhase.review => 'Confirm income, bills, and your plan',
  };
}

const onboardingOrder = OnboardingPhase.values;

class LinkedAccount {
  const LinkedAccount({
    required this.id,
    required this.name,
    required this.institution,
    required this.kind,
    required this.balance,
    this.last4,
    this.color = const Color(0xFF3B9AE0),
  });

  final String id;
  final String name;
  final String institution;
  final AccountKind kind;
  final double balance;
  final String? last4;
  final Color color;
}

enum AccountKind { depository, investment, credit, loan, other }

class OnboardingState {
  const OnboardingState({
    this.heardFrom = const [],
    this.twoFactor = false,
    this.accounts = const [],
    this.skippedAccounts = false,
    this.plan,
    this.referral = '',
    this.skippedTrial = false,
  });

  final List<String> heardFrom;
  final bool twoFactor;
  final List<LinkedAccount> accounts;
  final bool skippedAccounts;
  final String? plan;
  final String referral;
  final bool skippedTrial;

  OnboardingState copyWith({
    List<String>? heardFrom,
    bool? twoFactor,
    List<LinkedAccount>? accounts,
    bool? skippedAccounts,
    String? plan,
    bool clearPlan = false,
    String? referral,
    bool? skippedTrial,
  }) {
    return OnboardingState(
      heardFrom: heardFrom ?? this.heardFrom,
      twoFactor: twoFactor ?? this.twoFactor,
      accounts: accounts ?? this.accounts,
      skippedAccounts: skippedAccounts ?? this.skippedAccounts,
      plan: clearPlan ? null : (plan ?? this.plan),
      referral: referral ?? this.referral,
      skippedTrial: skippedTrial ?? this.skippedTrial,
    );
  }
}

const hearSources = <({String id, String label})>[
  (id: 'app-store', label: 'App Store'),
  (id: 'search', label: 'Google or Bing'),
  (id: 'article', label: 'Article or Blog'),
  (id: 'social', label: 'Instagram or Facebook'),
  (id: 'ai', label: 'ChatGPT, Claude, Gemini, etc.'),
  (id: 'friend', label: 'Friend or Family'),
  (id: 'reddit', label: 'Reddit'),
  (id: 'ad', label: 'Billboard or Subway Ad'),
  (id: 'podcast', label: 'Podcast or Radio'),
  (id: 'youtube', label: 'YouTube'),
  (id: 'other', label: 'Other'),
];

const suggestedInstitutions =
    <({String name, AccountKind kind, double balance, Color color, String last4})>[
      (
        name: 'Chase',
        kind: AccountKind.depository,
        balance: 4820.44,
        color: Color(0xFF117ACA),
        last4: '4421',
      ),
      (
        name: 'Amex',
        kind: AccountKind.credit,
        balance: 1240.18,
        color: Color(0xFF016FD0),
        last4: '1005',
      ),
      (
        name: 'Fidelity',
        kind: AccountKind.investment,
        balance: 48200,
        color: Color(0xFF4C8C2B),
        last4: '2290',
      ),
      (
        name: 'Ally',
        kind: AccountKind.depository,
        balance: 12650,
        color: Color(0xFF7700FF),
        last4: '8810',
      ),
      (
        name: 'Vanguard',
        kind: AccountKind.investment,
        balance: 31840,
        color: Color(0xFFC41230),
        last4: '7742',
      ),
      (
        name: 'Capital One',
        kind: AccountKind.credit,
        balance: 860.5,
        color: Color(0xFFD03027),
        last4: '3312',
      ),
    ];

String money(num n) {
  final fixed = n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer('\$');
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  if (parts.length > 1) buffer.write('.${parts[1]}');
  return buffer.toString();
}
