import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_env.dart';
import '../billing/entitlements.dart';
import '../dashboard/data.dart' show DisplayCurrency;

enum AuthDestination { landing, onboarding, dashboard, resetPassword }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.name,
    this.onboardingCompleted = false,
    this.onboardingKnown = true,
    this.currency = 'USD',
    this.role = 'user',
    this.subscriptionActive = false,
    this.entitlements,
  });

  final String id;
  final String email;
  final String? name;
  final bool onboardingCompleted;

  /// False while [onboardingCompleted] is only a default (profile not yet
  /// fetched and nothing cached) — routing waits instead of showing onboarding.
  final bool onboardingKnown;
  final String currency;
  final String role;
  final bool subscriptionActive;
  final Entitlements? entitlements;

  bool get isAppAdmin => isAppAdminRole(role);

  /// Admins are treated as subscribed for feature gates.
  bool get isEffectivelySubscribed =>
      isAppAdmin || subscriptionActive || (entitlements?.isSubscribed ?? false);

  AuthUser copyWith({
    String? id,
    String? email,
    String? name,
    bool? onboardingCompleted,
    bool? onboardingKnown,
    String? currency,
    String? role,
    bool? subscriptionActive,
    Entitlements? entitlements,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingKnown: onboardingKnown ?? this.onboardingKnown,
      currency: currency ?? this.currency,
      role: role ?? this.role,
      subscriptionActive: subscriptionActive ?? this.subscriptionActive,
      entitlements: entitlements ?? this.entitlements,
    );
  }
}

const _rememberKey = 'financeai_remember_me';
const _onboardedKeyPrefix = 'financeai_onboarded_';

/// App-wide auth. Use [AuthController.supabase] in production and
/// [AuthController.fake] in widget tests.
class AuthController extends ChangeNotifier {
  AuthController._({
    required this.isFake,
    AuthUser? initialUser,
    this.fakeSucceed = true,
  }) : _user = initialUser;

  factory AuthController.supabase() => AuthController._(isFake: false);

  /// Deterministic controller for widget tests (no network).
  factory AuthController.fake({
    AuthUser? user,
    bool succeed = true,
  }) =>
      AuthController._(isFake: true, initialUser: user, fakeSucceed: succeed);

  final bool isFake;
  final bool fakeSucceed;

  AuthUser? _user;
  bool _loading = true;
  bool _ready = false;
  bool _needsPasswordReset = false;
  bool _postAuthNavStarted = false;
  bool _closingAuthBrowser = false;
  StreamSubscription<AuthState>? _sub;
  /// Drops overlapping [_applyUser] results from token-refresh races.
  var _applyGeneration = 0;

  AuthUser? get user => _user;
  bool get loading => _loading;
  bool get ready => _ready;
  bool get isSignedIn => _user != null;
  bool get needsPasswordReset => _needsPasswordReset;

  /// Signed in but onboarding status not resolved yet — show a loader.
  bool get profilePending =>
      _user != null && !_user!.onboardingKnown && !_needsPasswordReset;

  /// Completes once [profilePending] is false (retries end within ~30s).
  Future<void> waitForProfile() {
    if (!profilePending) return Future.value();
    final done = Completer<void>();
    void check() {
      if (!profilePending && !done.isCompleted) {
        removeListener(check);
        done.complete();
      }
    }

    addListener(check);
    return done.future;
  }

  Future<bool?> _readOnboardedCache(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_onboardedKeyPrefix$userId');
  }

  Future<void> _writeOnboardedCache(String userId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_onboardedKeyPrefix$userId', value);
  }

  SupabaseClient? get _client {
    if (isFake || !AppEnv.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<bool> getRememberMe() async {
    if (isFake) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberKey) ?? true;
  }

  Future<void> setRememberMe(bool value) async {
    if (isFake) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, value);
  }

  Future<void> init() async {
    if (isFake) {
      _loading = false;
      _ready = true;
      notifyListeners();
      return;
    }

    if (!AppEnv.isSupabaseConfigured) {
      _loading = false;
      _ready = true;
      notifyListeners();
      return;
    }

    final client = _client!;
    final remember = await getRememberMe();
    final session = client.auth.currentSession;

    if (!remember && session != null) {
      // Session-only preference: drop persisted session on cold start.
      try {
        await client.auth.signOut();
      } catch (_) {}
      _user = null;
    } else if (session?.user != null) {
      await _applyUser(session!.user);
    } else {
      _user = null;
    }

    _sub = client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final u = data.session?.user;

      if (event == AuthChangeEvent.passwordRecovery) {
        _needsPasswordReset = true;
        unawaited(closeAuthBrowser());
        if (u != null) {
          await _applyUser(u);
        } else {
          notifyListeners();
        }
        return;
      }

      if (u == null) {
        _user = null;
        _needsPasswordReset = false;
        _postAuthNavStarted = false;
        notifyListeners();
        return;
      }

      // Dismiss OAuth sheet as soon as the session exists (before profile fetch).
      unawaited(closeAuthBrowser());
      await _applyUser(u);
    });

    _loading = false;
    _ready = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Dismisses SFSafariViewController / Custom Tabs after OAuth redirect.
  Future<void> closeAuthBrowser() async {
    if (_closingAuthBrowser) return;
    _closingAuthBrowser = true;
    try {
      if (await supportsCloseForLaunchMode(LaunchMode.inAppBrowserView)) {
        await closeInAppWebView();
      }
    } catch (_) {
      // No open in-app browser, or platform doesn't support close.
    } finally {
      _closingAuthBrowser = false;
    }
  }

  /// Returns true the first time post-auth navigation should run.
  bool beginPostAuthNavigation() {
    if (_postAuthNavStarted) return false;
    _postAuthNavStarted = true;
    return true;
  }

  Future<void> _applyUser(User sbUser) async {
    final email = sbUser.email;
    if (email == null || email.isEmpty) {
      _user = null;
      notifyListeners();
      return;
    }

    final gen = ++_applyGeneration;
    final previous =
        _user?.id == sbUser.id && _user!.onboardingKnown ? _user : null;
    final cached =
        previous == null ? await _readOnboardedCache(sbUser.id) : null;
    final meta = sbUser.userMetadata ?? {};
    // Seed from the in-memory user, else the on-device cache, so a failed
    // profile fetch (e.g. network still waking after resume) can't route a
    // finished user to onboarding.
    var mapped = AuthUser(
      id: sbUser.id,
      email: email,
      name: (meta['full_name'] as String?) ??
          (meta['name'] as String?) ??
          previous?.name,
      onboardingCompleted:
          previous?.onboardingCompleted ?? cached ?? false,
      onboardingKnown: previous != null || cached != null,
      currency: previous?.currency ?? 'USD',
      role: previous?.role ?? 'user',
      subscriptionActive: previous?.subscriptionActive ?? false,
      entitlements: previous?.entitlements,
    );
    mapped = await _mergeProfile(mapped);
    if (gen != _applyGeneration) return;
    _user = mapped;
    notifyListeners();
    if (!mapped.onboardingKnown) {
      unawaited(_retryProfile(gen));
    }
  }

  /// Backoff retries while onboarding status is unknown (loader is showing).
  Future<void> _retryProfile(int gen) async {
    for (final seconds in const [1, 2, 4, 8, 15]) {
      await Future<void>.delayed(Duration(seconds: seconds));
      final current = _user;
      if (gen != _applyGeneration || current == null) return;
      if (current.onboardingKnown) return;
      final merged = await _mergeProfile(current);
      if (gen != _applyGeneration) return;
      if (merged.onboardingKnown) {
        _user = merged;
        notifyListeners();
        return;
      }
    }
    // Give up waiting: fall back to the default rather than spin forever.
    if (gen != _applyGeneration || _user == null) return;
    _user = _user!.copyWith(onboardingKnown: true);
    notifyListeners();
  }

  Future<AuthUser> _mergeProfile(AuthUser base) async {
    try {
      final data = await _apiJson('GET', '/api/profile');
      // Keep prior session fields when the request fails / 401s mid-refresh.
      if (data == null) return base;
      final currency =
          ((data['currency'] as String?)?.trim().isNotEmpty ?? false)
              ? (data['currency'] as String).trim().toUpperCase()
              : base.currency;
      DisplayCurrency.setCode(currency);
      // ignore: discarded_futures
      _refreshDisplayFx(currency);

      final role = (data['role'] as String?)?.trim().isNotEmpty == true
          ? (data['role'] as String).trim()
          : base.role;
      final entitlements = data['entitlements'] != null
          ? Entitlements.fromJson(data['entitlements'])
          : base.entitlements;
      final admin = isAppAdminRole(role);
      final subscriptionActive = admin ||
          data['subscription_active'] == true ||
          (entitlements?.isSubscribed ?? false);

      // Once onboarding is known complete for this session, don't regress on
      // a transient profile payload that omits the timestamp.
      final onboardedFromApi = data['onboarding_completed_at'] != null;
      final onboardingCompleted =
          onboardedFromApi || base.onboardingCompleted;
      // ignore: discarded_futures
      _writeOnboardedCache(base.id, onboardingCompleted);

      return AuthUser(
        id: base.id,
        email: (data['email'] as String?) ?? base.email,
        name: (data['full_name'] as String?) ?? base.name,
        onboardingCompleted: onboardingCompleted,
        onboardingKnown: true,
        currency: currency,
        role: role,
        subscriptionActive: subscriptionActive,
        entitlements: admin && entitlements == null
            ? Entitlements.admin
            : entitlements,
      );
    } catch (_) {
      return base;
    }
  }

  Future<void> _refreshDisplayFx(String currency) async {
    final code = currency.trim().toUpperCase();
    if (code.isEmpty || code == 'USD') return;
    try {
      final data = await _apiJson(
        'GET',
        '/api/currency/rate?from=${Uri.encodeQueryComponent(code)}',
      );
      final rate = (data?['rate'] as num?)?.toDouble();
      if (rate == null || !rate.isFinite || rate <= 0) return;
      DisplayCurrency.setRateToUsd(code, rate);
      notifyListeners();
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _apiJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final decoded = await _apiDecode(method, path, body: body);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  }

  /// Public API helper for feature modules (spaces, accounts, …).
  Future<Object?> apiDecode(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _apiDecode(method, path, body: body);

  Future<Object?> _apiDecode(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final base = AppEnv.appUrl;
    if (base.isEmpty) return null;
    final token = _client?.auth.currentSession?.accessToken;
    if (token == null && !isFake) return null;

    if (isFake) return null;

    final uri = Uri.parse('$base$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    late http.Response res;
    if (method == 'GET') {
      res = await http.get(uri, headers: headers);
    } else if (method == 'POST') {
      res = await http.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
    } else if (method == 'PATCH') {
      res = await http.patch(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
    } else if (method == 'DELETE') {
      res = await http.delete(uri, headers: headers);
    } else {
      return null;
    }

    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    if (res.body.isEmpty || res.body == 'null') {
      return method == 'DELETE' ? true : null;
    }
    return jsonDecode(res.body);
  }

  Future<void> syncProfile() async {
    if (isFake) return;
    try {
      await _apiJson('POST', '/api/auth/sync-profile');
      if (_user != null) {
        _user = await _mergeProfile(_user!);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> completeOnboarding() async {
    if (isFake) {
      if (_user != null) {
        _user = _user!.copyWith(onboardingCompleted: true);
        notifyListeners();
      }
      return;
    }
    await _apiJson('PATCH', '/api/profile', body: {'onboarding_completed': true});
    if (_user != null) {
      _user = _user!.copyWith(onboardingCompleted: true, onboardingKnown: true);
      await _writeOnboardedCache(_user!.id, true);
      notifyListeners();
    }
  }

  AuthDestination destinationForSession() {
    if (_needsPasswordReset) return AuthDestination.resetPassword;
    if (_user == null) return AuthDestination.landing;
    if (!_user!.onboardingCompleted) return AuthDestination.onboarding;
    return AuthDestination.dashboard;
  }

  Future<String?> login(
    String email,
    String password, {
    bool remember = true,
  }) async {
    if (isFake) {
      if (!fakeSucceed) return 'Invalid credentials';
      _user = AuthUser(
        id: 'fake',
        email: email,
        name: 'Alex Rivera',
        onboardingCompleted: true,
      );
      notifyListeners();
      return null;
    }
    final client = _client;
    if (client == null) return 'Auth is not configured';
    try {
      await setRememberMe(remember);
      await client.auth.signInWithPassword(email: email, password: password);
      await syncProfile();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<({String? error, bool needsEmailConfirm})> register(
    String email,
    String password,
    String name,
  ) async {
    if (isFake) {
      if (!fakeSucceed) {
        return (error: 'Registration failed', needsEmailConfirm: false);
      }
      _user = AuthUser(
        id: 'fake',
        email: email,
        name: name,
        onboardingCompleted: false,
      );
      notifyListeners();
      return (error: null, needsEmailConfirm: false);
    }
    final client = _client;
    if (client == null) {
      return (error: 'Auth is not configured', needsEmailConfirm: false);
    }
    try {
      await setRememberMe(true);
      final res = await client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
        emailRedirectTo: AppEnv.mobileAuthRedirect,
      );
      if (res.user != null &&
          (res.user!.identities == null || res.user!.identities!.isEmpty)) {
        return (
          error:
              'This email is already registered. If you haven’t confirmed your email yet, check your inbox. Otherwise, try logging in.',
          needsEmailConfirm: false,
        );
      }
      if (res.session != null) {
        await syncProfile();
        return (error: null, needsEmailConfirm: false);
      }
      return (error: null, needsEmailConfirm: true);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') ||
          msg.contains('user already exists') ||
          msg.contains('already been registered')) {
        return (
          error:
              'This email is already registered. If you haven’t confirmed your email yet, check your inbox. Otherwise, try logging in.',
          needsEmailConfirm: false,
        );
      }
      return (error: e.message, needsEmailConfirm: false);
    } catch (e) {
      return (error: e.toString(), needsEmailConfirm: false);
    }
  }

  Future<String?> sendMagicLink(String email) async {
    if (isFake) return fakeSucceed ? null : 'Failed to send';
    final client = _client;
    if (client == null) return 'Auth is not configured';
    try {
      await setRememberMe(true);
      await client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: AppEnv.mobileAuthRedirect,
        shouldCreateUser: true,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    if (isFake) return fakeSucceed ? null : 'Failed to send';
    final client = _client;
    if (client == null) return 'Auth is not configured';
    try {
      await client.auth.resetPasswordForEmail(
        email,
        redirectTo: AppEnv.mobileAuthRedirect,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updatePassword(String password) async {
    if (isFake) {
      if (!fakeSucceed) return 'Failed to update password';
      _needsPasswordReset = false;
      notifyListeners();
      return null;
    }
    final client = _client;
    if (client == null) return 'Auth is not configured';
    if (password.length < 8) return 'Use at least 8 characters';
    try {
      await client.auth.updateUser(UserAttributes(password: password));
      _needsPasswordReset = false;
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signInWithOAuth(OAuthProvider provider) async {
    if (isFake) {
      if (!fakeSucceed) return 'OAuth failed';
      _user = const AuthUser(
        id: 'fake',
        email: 'oauth@example.com',
        name: 'Alex Rivera',
        onboardingCompleted: true,
      );
      notifyListeners();
      return null;
    }
    final client = _client;
    if (client == null) return 'Auth is not configured';
    try {
      await setRememberMe(true);
      await client.auth.signInWithOAuth(
        provider,
        redirectTo: AppEnv.mobileAuthRedirect,
        // SFSafariViewController (iOS) / Chrome Custom Tabs (Android).
        // Google on Android is forced external by supabase_flutter.
        authScreenLaunchMode: LaunchMode.inAppBrowserView,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    if (isFake) {
      _user = null;
      _needsPasswordReset = false;
      _postAuthNavStarted = false;
      notifyListeners();
      return;
    }
    try {
      await _client?.auth.signOut();
    } catch (_) {}
    _user = null;
    _needsPasswordReset = false;
    _postAuthNavStarted = false;
    notifyListeners();
  }
}
