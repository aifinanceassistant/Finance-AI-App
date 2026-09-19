import '../auth/auth_controller.dart';
import 'data.dart';

/// Fetches FX rates for unique non-USD currency codes and caches them.
Future<void> prefetchFxRates(
  AuthController auth,
  Iterable<String?> codes,
) async {
  if (auth.isFake) return;
  final unique = <String>{};
  for (final raw in codes) {
    final code = (raw ?? '').trim().toUpperCase();
    if (code.isNotEmpty && code != 'USD') unique.add(code);
  }
  for (final code in unique) {
    try {
      final data = await auth.apiDecode(
        'GET',
        '/api/currency/rate?from=${Uri.encodeQueryComponent(code)}',
      );
      if (data is! Map<String, dynamic>) continue;
      final rate = (data['rate'] as num?)?.toDouble();
      if (rate == null || !rate.isFinite || rate <= 0) continue;
      DisplayCurrency.setRateToUsd(code, rate);
    } catch (_) {}
  }
}
