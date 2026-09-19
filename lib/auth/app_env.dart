import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads root `.env.example` (committed) then root `.env` (gitignored overrides).
class AppEnv {
  AppEnv._();

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env.example');
    } catch (e) {
      debugPrint('AppEnv: could not load .env.example ($e)');
    }
    try {
      await dotenv.load(
        fileName: '.env',
        mergeWith: Map<String, String>.from(dotenv.env),
        isOptional: true,
      );
    } catch (_) {}
  }

  static String _get(String key) => dotenv.maybeGet(key)?.trim() ?? '';

  static String get appUrl =>
      _get('NEXT_PUBLIC_APP_URL').replaceAll(RegExp(r'/$'), '');
  static String get supabaseUrl => _get('NEXT_PUBLIC_SUPABASE_URL');
  static String get supabasePublishableKey =>
      _get('NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY');
  static String get mobileAuthRedirect {
    final v = _get('NEXT_PUBLIC_MOBILE_AUTH_REDIRECT');
    return v.isEmpty ? 'financeai://auth-callback' : v;
  }

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      !supabaseUrl.contains('your-project') &&
      supabasePublishableKey.isNotEmpty &&
      supabasePublishableKey != 'sb_publishable_xxx';
}
