import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Root dotenv files (no leading `.` — Flutter omits hidden assets in release):
/// - `env` → debug (`flutter run`)
/// - `env.staging` → profile
/// - `env.production` → release
///
/// Override with `--dart-define=APP_ENV=local|staging|production`.
class AppEnv {
  AppEnv._();

  static Future<void> load() async {
    final override = _envFileForMode();
    // Load example as defaults, then override with the mode file.
    // flutter_dotenv keeps the *first* value for duplicate keys, so the
    // override file must be listed in [overrideWithFiles] (not mergeWith).
    try {
      await dotenv.load(fileName: 'env.example', overrideWithFiles: [override]);
      // ignore: avoid_print
      print('AppEnv: loaded $override');
    } catch (e) {
      // ignore: avoid_print
      print('AppEnv: could not load $override ($e)');
      try {
        await dotenv.load(fileName: override);
      } catch (e2) {
        // ignore: avoid_print
        print('AppEnv: fallback load failed ($e2)');
      }
    }

    if (!isSupabaseConfigured) {
      // ignore: avoid_print
      print('AppEnv: Supabase not configured. Edit $override and rebuild.');
    }
  }

  static String get activeFile => _envFileForMode();

  static String _envFileForMode() {
    const fromDefine = String.fromEnvironment('APP_ENV', defaultValue: '');
    switch (fromDefine.trim().toLowerCase()) {
      case 'local':
      case 'dev':
      case 'development':
        return 'env';
      case 'staging':
        return 'env.staging';
      case 'production':
      case 'prod':
        return 'env.production';
    }

    if (kReleaseMode) return 'env.production';
    if (kProfileMode) return 'env.staging';
    return 'env';
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
