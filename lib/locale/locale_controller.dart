import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight locale preference (en / fr). Not a full ARB i18n system.
class LocaleController extends ChangeNotifier {
  LocaleController();

  static const _prefsKey = 'financeai-app-language';

  Locale _locale = const Locale('en');
  bool _ready = false;

  Locale get locale => _locale;
  bool get ready => _ready;
  String get languageCode => _locale.languageCode;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      _locale = _normalize(code);
    } catch (_) {
      _locale = const Locale('en');
    }
    _ready = true;
    notifyListeners();
  }

  /// Apply a language from profile or settings without necessarily persisting
  /// (caller persists via API + [setLanguage] when user changes it).
  Future<void> applyCode(String? code, {bool persist = true}) async {
    final next = _normalize(code);
    if (next.languageCode == _locale.languageCode && _ready) return;
    _locale = next;
    _ready = true;
    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, next.languageCode);
      } catch (_) {
        /* ignore */
      }
    }
    notifyListeners();
  }

  Future<void> setLanguage(String code) => applyCode(code, persist: true);

  static Locale _normalize(String? code) {
    final c = (code ?? 'en').trim().toLowerCase();
    if (c.startsWith('fr')) return const Locale('fr');
    return const Locale('en');
  }
}

class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope != null, 'LocaleScope not found');
    return scope!.notifier!;
  }

  static LocaleController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LocaleScope>()?.notifier;
  }

  static LocaleController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<LocaleScope>();
    assert(scope != null, 'LocaleScope not found');
    return scope!.notifier!;
  }
}
