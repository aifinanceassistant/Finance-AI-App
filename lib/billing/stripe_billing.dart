import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_controller.dart';

/// Starts Stripe Checkout (Solo) via the web API and opens the returned URL.
Future<String?> startStripeCheckout(
  AuthController auth, {
  required String billing,
}) async {
  if (auth.isFake) return null;
  try {
    final decoded = await auth.apiDecode(
      'POST',
      '/api/billing/checkout',
      body: {
        'plan': 'solo',
        'billing': billing,
        'accounts': 1,
      },
    );
    if (decoded is! Map<String, dynamic>) {
      return 'Checkout failed';
    }
    final url = decoded['url'] as String?;
    if (url == null || url.isEmpty) {
      return (decoded['error'] as String?) ?? 'No checkout URL';
    }
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) return 'Could not open Stripe checkout';
    return null;
  } catch (e) {
    debugPrint('startStripeCheckout: $e');
    return 'Checkout failed';
  }
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
