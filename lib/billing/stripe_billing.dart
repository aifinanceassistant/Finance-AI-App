import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_controller.dart';

/// Starts Stripe Checkout via the web API and opens the returned URL.
///
/// [plan] is `solo` | `team` | `family` (web plan slugs).
Future<String?> startStripeCheckout(
  AuthController auth, {
  required String billing,
  String plan = 'solo',
}) async {
  final res = await startStripeCheckoutDetailed(
    auth,
    billing: billing,
    plan: plan,
  );
  return res.error;
}

/// Opens Stripe Checkout in the browser. [code] carries the server's error
/// code (e.g. `already_subscribed`, `invalid_promotion_code`).
Future<({String? error, String? code})> startStripeCheckoutDetailed(
  AuthController auth, {
  required String billing,
  String plan = 'solo',
  String? promotionCode,
}) async {
  if (auth.isFake) return (error: null, code: null);
  try {
    final res = await auth.apiRequest(
      'POST',
      '/api/billing/checkout',
      body: {
        'plan': plan,
        'billing': billing,
        'accounts': 1,
        'returnTo': 'app',
        if (promotionCode != null && promotionCode.isNotEmpty)
          'promotionCode': promotionCode,
      },
    );
    final data = res.data;
    if (!res.ok) {
      final code = data is Map ? data['code'] as String? : null;
      return (error: res.error ?? 'Checkout failed', code: code);
    }
    final url = data is Map ? data['url'] as String? : null;
    if (url == null || url.isEmpty) {
      return (error: 'No checkout URL', code: null);
    }
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) return (error: 'Could not open Stripe checkout', code: null);
    return (error: null, code: null);
  } catch (e) {
    debugPrint('startStripeCheckout: $e');
    return (error: 'Checkout failed', code: null);
  }
}

/// Looks up a referral / promotion code in Stripe via the web API.
Future<({bool valid, double? percentOff, int? amountOff, String? currency})>
checkPromotionCode(AuthController auth, String code) async {
  final res = await auth.apiRequest(
    'GET',
    '/api/billing/promo?code=${Uri.encodeQueryComponent(code)}',
  );
  final data = res.data;
  if (!res.ok || data is! Map) {
    return (valid: false, percentOff: null, amountOff: null, currency: null);
  }
  return (
    valid: data['valid'] == true,
    percentOff: (data['percentOff'] as num?)?.toDouble(),
    amountOff: (data['amountOff'] as num?)?.toInt(),
    currency: data['currency'] as String?,
  );
}

Future<String?> openStripeBillingPortal(AuthController auth) async {
  if (auth.isFake) return null;
  try {
    final decoded = await auth.apiDecode('POST', '/api/billing/portal');
    if (decoded is! Map<String, dynamic>) {
      return 'Could not open billing portal';
    }
    final url = decoded['url'] as String?;
    if (url == null || url.isEmpty) {
      return (decoded['error'] as String?) ?? 'No portal URL';
    }
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) return 'Could not open Stripe portal';
    return null;
  } catch (e) {
    debugPrint('openStripeBillingPortal: $e');
    return 'Could not open billing portal';
  }
}

Future<Map<String, dynamic>?> fetchBillingStatus(AuthController auth) async {
  if (auth.isFake) {
    return {
      'subscriptionActive': false,
      'planLabel': 'No subscription',
      'seatLimit': 1,
    };
  }
  try {
    final decoded = await auth.apiDecode('GET', '/api/settings/billing');
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (e) {
    debugPrint('fetchBillingStatus: $e');
  }
  return null;
}
