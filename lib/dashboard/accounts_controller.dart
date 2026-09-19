import 'package:flutter/foundation.dart';

import '../auth/auth_controller.dart';
import 'data.dart';
import 'fx_prefetch.dart';

class AccountsController extends ChangeNotifier {
  AccountsController(this._auth);

  factory AccountsController.fake() {
    final c = AccountsController(AuthController.fake());
    c._accounts = List<DemoAccount>.of(demoAccounts);
    c._spaceId = 'fake-personal';
    c._loading = false;
    c._publish();
    return c;
  }

  final AuthController _auth;

  List<DemoAccount> _accounts = [];
  String _spaceId = '';
  bool _loading = false;

  List<DemoAccount> get accounts => List.unmodifiable(_accounts);
  bool get loading => _loading;
  String get spaceId => _spaceId;

  static String accountKey(DemoAccount a) => a.id ?? '${a.bank}-${a.number}';

  void _publish({bool? loading}) {
    if (loading != null) _loading = loading;
    accountsStore.value = List<DemoAccount>.of(_accounts);
    notifyListeners();
  }

  static String _syncLabel(String? iso) {
    if (iso == null || iso.isEmpty) return 'Never';
    final t = DateTime.tryParse(iso);
    if (t == null) return 'Never';
    final mins = DateTime.now().difference(t).inMinutes;
    if (mins < 1) return 'Just now';
    if (mins < 60) return '$mins min ago';
    final hrs = (mins / 60).round();
    if (hrs < 48) return '$hrs hr${hrs == 1 ? '' : 's'} ago';
    final days = (hrs / 24).round();
    return '$days day${days == 1 ? '' : 's'} ago';
  }

  static DemoAccount fromJson(Map<String, dynamic> json) {
    final institution = (json['institution'] as String?)?.trim() ?? '';
    final name = (json['name'] as String?)?.trim() ?? institution;
    final lastFour = (json['lastFour'] as String?) ?? '';
    final digits = lastFour.replaceAll(RegExp(r'\D'), '');
    final suffix = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : (digits.isEmpty ? '—' : digits);
    final type = (json['type'] as String?) ?? 'Checking';
    final balance = (json['balance'] as num?)?.toDouble() ?? 0;
    final originalBalance = (json['originalBalance'] as num?)?.toDouble();
    final originalCurrencyRaw =
        (json['originalCurrency'] as String?)?.trim().toUpperCase();
    final defaultCurrencyRaw =
        (json['defaultCurrency'] as String?)?.trim().toUpperCase();
    final connected = json['connected'] == true;
    final signedUsd = type == 'Credit' ? -balance.abs() : balance;
    final signedOriginal = originalBalance == null
        ? null
        : (type == 'Credit' ? -originalBalance.abs() : originalBalance);
    return DemoAccount(
      id: json['id'] as String?,
      bank: institution.isEmpty ? name : institution,
      name: name,
      type: type,
      number: '····$suffix',
      lastFour: suffix == '—' ? null : suffix,
      balance: signedUsd,
      originalBalance: signedOriginal,
      originalCurrency:
          originalCurrencyRaw != null && originalCurrencyRaw.isNotEmpty
              ? originalCurrencyRaw
              : null,
      defaultCurrency:
          defaultCurrencyRaw != null && defaultCurrencyRaw.isNotEmpty
              ? defaultCurrencyRaw
              : null,
      status: connected ? TxnStatus.succeeded : TxnStatus.failed,
      synced: _syncLabel(json['lastSyncedAt'] as String?),
    );
  }

  Future<void> loadForSpace(String spaceId) async {
    _spaceId = spaceId;
    if (spaceId.isEmpty || spaceId == 'pending') {
      _accounts = [];
      _publish(loading: false);
      return;
    }

    if (_auth.isFake) {
      _accounts = List<DemoAccount>.of(demoAccounts);
      _publish(loading: false);
      return;
    }

    _publish(loading: true);
    try {
      final decoded = await _auth.apiDecode(
        'GET',
        '/api/accounts?portfolio_id=${Uri.encodeQueryComponent(spaceId)}',
      );
      final list = <DemoAccount>[];
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) list.add(fromJson(item));
        }
      }
      _accounts = list;
      await prefetchFxRates(
        _auth,
        list.expand((a) => [a.originalCurrency, a.defaultCurrency]),
      );
    } catch (e) {
      debugPrint('AccountsController.load: $e');
      _accounts = [];
    }
    _publish(loading: false);
  }

  Future<DemoAccount?> create({
    required String institution,
    String? name,
    required String type,
    required String lastFour,
    required double balance,
    String? defaultCurrency,
  }) async {
    if (_spaceId.isEmpty) return null;
    final nickname = (name ?? '').trim().isEmpty ? institution : name!.trim();
    final code = (defaultCurrency ?? DisplayCurrency.code).toUpperCase();

    if (_auth.isFake) {
      final account = DemoAccount(
        id: 'fake-${DateTime.now().millisecondsSinceEpoch}',
        bank: institution,
        name: nickname,
        type: type,
        number: '····$lastFour',
        lastFour: lastFour,
        balance: type == 'Credit' ? -balance.abs() : balance,
        originalBalance: type == 'Credit' ? -balance.abs() : balance,
        originalCurrency: code,
        defaultCurrency: code,
        status: TxnStatus.succeeded,
        synced: 'Just now',
      );
      _accounts = [..._accounts, account];
      _publish();
      return account;
    }

    final decoded = await _auth.apiDecode(
      'POST',
      '/api/accounts',
      body: {
        'portfolioId': _spaceId,
        'name': nickname,
        'institution': institution,
        'type': type,
        'balance': balance.abs(),
        'lastFour': lastFour,
        'connected': true,
        'defaultCurrency': code,
      },
    );
    if (decoded is! Map<String, dynamic>) return null;
    final account = fromJson(decoded);
    _accounts = [..._accounts, account];
    _publish();
    return account;
  }

  DemoAccount? _findByKey(String key) {
    for (final a in _accounts) {
      if (accountKey(a) == key) return a;
    }
    return null;
  }

  Future<bool> remove(String key) async {
    final target = _findByKey(key);
    if (target == null) return false;

    if (_auth.isFake || target.id == null) {
      _accounts = _accounts.where((a) => accountKey(a) != key).toList();
      _publish();
      return true;
    }

    final decoded = await _auth.apiDecode('DELETE', '/api/accounts/${target.id}');
    if (decoded == null) return false;
    _accounts = _accounts.where((a) => accountKey(a) != key).toList();
    _publish();
    return true;
  }

  Future<void> syncAll() async {
    if (_auth.isFake) {
      _accounts = [
        for (final a in _accounts)
          a.copyWith(
            synced: 'Just now',
            status: a.status == TxnStatus.failed
                ? TxnStatus.pending
                : TxnStatus.succeeded,
          ),
      ];
      _publish();
      return;
    }

    final next = <DemoAccount>[];
    for (final a in _accounts) {
      if (a.id == null) {
        next.add(a.copyWith(synced: 'Just now'));
        continue;
      }
      final decoded = await _auth.apiDecode(
        'PATCH',
        '/api/accounts/${a.id}',
        body: {'touchSync': true},
      );
      if (decoded is Map<String, dynamic>) {
        next.add(fromJson(decoded));
      } else {
        next.add(a);
      }
    }
    _accounts = next;
    _publish();
  }

  Future<void> reconnect(String key) async {
    final target = _findByKey(key);
    if (target == null) return;

    if (_auth.isFake || target.id == null) {
      _accounts = [
        for (final a in _accounts)
          if (accountKey(a) == key)
            a.copyWith(status: TxnStatus.succeeded, synced: 'Just now')
          else
            a,
      ];
      _publish();
      return;
    }

    final decoded = await _auth.apiDecode(
      'PATCH',
      '/api/accounts/${target.id}',
      body: {'connected': true, 'touchSync': true},
    );
    if (decoded is Map<String, dynamic>) {
      final updated = fromJson(decoded);
      _accounts = [
        for (final a in _accounts)
          if (accountKey(a) == key) updated else a,
      ];
      _publish();
    }
  }

  Future<void> syncOne(String key) async {
    final target = _findByKey(key);
    if (target == null) return;

    if (_auth.isFake || target.id == null) {
      _accounts = [
        for (final a in _accounts)
          if (accountKey(a) == key)
            a.copyWith(
              synced: 'Just now',
              status: a.status == TxnStatus.failed
                  ? TxnStatus.pending
                  : TxnStatus.succeeded,
            )
          else
            a,
      ];
      _publish();
      return;
    }

    final decoded = await _auth.apiDecode(
      'PATCH',
      '/api/accounts/${target.id}',
      body: {'touchSync': true},
    );
    if (decoded is Map<String, dynamic>) {
      final updated = fromJson(decoded);
      _accounts = [
        for (final a in _accounts)
          if (accountKey(a) == key) updated else a,
      ];
      _publish();
    }
  }

  Future<DemoAccount?> update({
    required String key,
    required String institution,
    String? name,
    required String type,
    required String lastFour,
    required double balance,
    String? defaultCurrency,
  }) async {
    final target = _findByKey(key);
    if (target == null) return null;
    final nickname = (name ?? '').trim().isEmpty ? institution : name!.trim();
    final code = (defaultCurrency ?? target.nativeCurrency).toUpperCase();

    if (_auth.isFake || target.id == null) {
      final updated = target.copyWith(
        bank: institution,
        name: nickname,
        type: type,
        number: '····$lastFour',
        lastFour: lastFour,
        balance: type == 'Credit' ? -balance.abs() : balance.abs(),
        originalBalance: type == 'Credit' ? -balance.abs() : balance.abs(),
        originalCurrency: code,
        defaultCurrency: code,
      );
      _accounts = [
        for (final a in _accounts)
          if (accountKey(a) == key) updated else a,
      ];
      _publish();
      return updated;
    }

    final decoded = await _auth.apiDecode(
      'PATCH',
      '/api/accounts/${target.id}',
      body: {
        'name': nickname,
        'institution': institution,
        'type': type,
        'lastFour': lastFour,
        'balance': balance.abs(),
        'defaultCurrency': code,
      },
    );
    if (decoded is! Map<String, dynamic>) return null;
    final updated = fromJson(decoded);
    _accounts = [
      for (final a in _accounts)
        if (accountKey(a) == key) updated else a,
    ];
    _publish();
    return updated;
  }
}
