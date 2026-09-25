import 'package:flutter/foundation.dart';

import '../auth/auth_controller.dart';
import '../dashboard/data.dart' show DisplayCurrency;
import '../dashboard/form_validation.dart';
import 'models.dart';

/// Resolves the first portfolio/space id for account creates.
Future<String?> resolveOnboardingPortfolioId(AuthController auth) async {
  if (auth.isFake) return 'fake-personal';
  try {
    final decoded = await auth.apiDecode('GET', '/api/portfolios');
    if (decoded is! List || decoded.isEmpty) return null;
    final first = decoded.first;
    if (first is Map<String, dynamic>) {
      return first['id'] as String?;
    }
    if (first is Map) {
      return first['id'] as String?;
    }
  } catch (e) {
    debugPrint('resolveOnboardingPortfolioId: $e');
  }
  return null;
}

String onboardingAccountType(AccountKind kind) => switch (kind) {
      AccountKind.credit => 'Credit',
      AccountKind.investment => 'Investment',
      AccountKind.loan => 'Cash',
      AccountKind.depository => 'Checking',
      AccountKind.other => 'Checking',
    };

/// POSTs each linked account (same body as AccountsController.create).
Future<void> persistOnboardingAccounts(
  AuthController auth,
  List<LinkedAccount> accounts, {
  String? portfolioId,
}) async {
  if (auth.isFake || accounts.isEmpty) return;
  final spaceId = portfolioId ?? await resolveOnboardingPortfolioId(auth);
  if (spaceId == null || spaceId.isEmpty) {
    debugPrint('persistOnboardingAccounts: no portfolio');
    return;
  }
  final currency = DisplayCurrency.code.toUpperCase();
  for (final a in accounts) {
    final type = onboardingAccountType(a.kind);
    final lastFour = (a.last4 ?? '').replaceAll(RegExp(r'\D'), '');
    try {
      await auth.apiDecode(
        'POST',
        '/api/accounts',
        body: {
          'portfolioId': spaceId,
          'name': a.name,
          'institution': a.institution,
          'type': type,
          'balance': apiAccountBalance(type, a.balance),
          'lastFour': lastFour,
          'connected': true,
          'defaultCurrency': currency,
        },
      );
    } catch (e) {
      debugPrint('persistOnboardingAccounts ${a.institution}: $e');
    }
  }
}
