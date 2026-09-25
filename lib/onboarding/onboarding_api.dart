import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../dashboard/data.dart' show DisplayCurrency;
import '../dashboard/form_validation.dart';
import 'models.dart';

/// The user's own space (their Personal space on a fresh signup).
Future<String?> resolveOnboardingPortfolioId(AuthController auth) async {
  if (auth.isFake) return 'fake-personal';
  final res = await auth.apiRequest('GET', '/api/portfolios');
  final list = res.data;
  if (!res.ok || list is! List || list.isEmpty) return null;
  Map? owned;
  for (final p in list) {
    if (p is Map && p['access'] is Map && p['access']['isOwner'] == true) {
      owned = p;
      break;
    }
  }
  final pick = owned ?? (list.first is Map ? list.first as Map : null);
  return pick?['id'] as String?;
}

const _palette = [
  Color(0xFF117ACA),
  Color(0xFF016FD0),
  Color(0xFF4C8C2B),
  Color(0xFF7700FF),
  Color(0xFFC41230),
  Color(0xFFD03027),
  Color(0xFF3B9AE0),
  Color(0xFFE0B84A),
];

Color _colorFor(String institution) {
  var h = 0;
  for (final c in institution.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _palette[h % _palette.length];
}

AccountKind _kindFromType(String type) => switch (type) {
  'Credit' => AccountKind.credit,
  'Investment' => AccountKind.investment,
  'Loan' => AccountKind.loan,
  'Checking' || 'Savings' || 'Cash' => AccountKind.depository,
  _ => AccountKind.other,
};

LinkedAccount _accountFromJson(Map json) {
  final institution = (json['institution'] as String?) ?? '';
  final lastFour = (json['lastFour'] as String?) ?? '';
  return LinkedAccount(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? 'Account',
    institution: institution.isEmpty ? 'Manual' : institution,
    kind: _kindFromType((json['type'] as String?) ?? ''),
    balance:
        ((json['originalBalance'] ?? json['balance']) as num?)?.toDouble() ?? 0,
    last4: lastFour.isEmpty ? null : lastFour,
    color: _colorFor(institution),
  );
}

Future<({List<LinkedAccount>? accounts, String? error})> loadOnboardingAccounts(
  AuthController auth,
  String spaceId,
) async {
  if (auth.isFake) return (accounts: const <LinkedAccount>[], error: null);
  final res = await auth.apiRequest(
    'GET',
    '/api/accounts?portfolio_id=${Uri.encodeQueryComponent(spaceId)}',
  );
  final data = res.data;
  if (!res.ok || data is! List) {
    return (accounts: null, error: res.error ?? 'Could not load accounts');
  }
  return (
    accounts: [
      for (final a in data)
        if (a is Map && a['id'] is String) _accountFromJson(a),
    ],
    error: null,
  );
}

const manualAccountTypes = [
  'Checking',
  'Savings',
  'Credit',
  'Cash',
  'Investment',
];

/// Creates a manual (unconnected) account; returns an error message on failure.
Future<String?> createManualAccount(
  AuthController auth,
  String spaceId, {
  required String name,
  required String institution,
  required String type,
  required double balance,
}) async {
  if (auth.isFake) return null;
  final res = await auth.apiRequest(
    'POST',
    '/api/accounts',
    body: {
      'portfolioId': spaceId,
      'name': name,
      'institution': institution,
      'type': type,
      'balance': apiAccountBalance(type, balance),
      'lastFour': '',
      'connected': false,
      'defaultCurrency': DisplayCurrency.code.toUpperCase(),
    },
  );
  return res.ok ? null : res.error;
}

Future<String?> deleteOnboardingAccount(AuthController auth, String id) async {
  if (auth.isFake) return null;
  final res = await auth.apiRequest(
    'DELETE',
    '/api/accounts/${Uri.encodeComponent(id)}',
  );
  return res.ok ? null : res.error;
}

typedef OnboardingCategory = ({String id, String name, double? monthlyBudget});

Future<({List<OnboardingCategory>? categories, String? error})>
loadExpenseCategories(AuthController auth, String spaceId) async {
  if (auth.isFake) {
    return (categories: const <OnboardingCategory>[], error: null);
  }
  final res = await auth.apiRequest(
    'GET',
    '/api/categories?portfolio_id=${Uri.encodeQueryComponent(spaceId)}&type=expense',
  );
  final data = res.data;
  if (!res.ok || data is! List) {
    return (categories: null, error: res.error ?? 'Could not load labels');
  }
  return (
    categories: [
      for (final c in data)
        if (c is Map && c['id'] is String)
          (
            id: c['id'] as String,
            name: (c['name'] as String?) ?? '',
            monthlyBudget: (c['monthlyBudget'] as num?)?.toDouble(),
          ),
    ],
    error: null,
  );
}

Future<({String? id, String? error})> createExpenseCategory(
  AuthController auth,
  String spaceId,
  String name,
  double? monthlyBudget,
) async {
  if (auth.isFake) return (id: 'fake-$name', error: null);
  final res = await auth.apiRequest(
    'POST',
    '/api/categories',
    body: {
      'portfolioId': spaceId,
      'name': name,
      'type': 'expense',
      'monthlyBudget': monthlyBudget,
    },
  );
  final data = res.data;
  if (!res.ok) return (id: null, error: res.error);
  return (id: data is Map ? data['id'] as String? : null, error: null);
}

Future<String?> updateCategoryBudget(
  AuthController auth,
  String id,
  double? monthlyBudget,
) async {
  if (auth.isFake) return null;
  final res = await auth.apiRequest(
    'PATCH',
    '/api/categories/${Uri.encodeComponent(id)}',
    body: {'monthlyBudget': monthlyBudget},
  );
  return res.ok ? null : res.error;
}

/// Monthly recurring income or expense tracked against [accountId].
Future<String?> createMonthlyRecurring(
  AuthController auth,
  String spaceId, {
  required String name,
  required double amount,
  required bool income,
  required String category,
  required DateTime nextDate,
  String? accountId,
}) async {
  if (auth.isFake) return null;
  final ymd =
      '${nextDate.year.toString().padLeft(4, '0')}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}';
  final res = await auth.apiRequest(
    'POST',
    '/api/recurring',
    body: {
      'portfolioId': spaceId,
      'name': name,
      'amount': amount,
      'type': income ? 'Income' : 'Expense',
      'category': category,
      'cadence': 'Monthly',
      'status': 'Active',
      'nextDate': ymd,
      'accountId': ?accountId,
    },
  );
  return res.ok ? null : res.error;
}
