import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import 'data.dart';
import 'fx_prefetch.dart';

class RecurringController extends ChangeNotifier {
  RecurringController(this._auth);

  factory RecurringController.fake() {
    final c = RecurringController(AuthController.fake());
    c._items = List<DemoRecurring>.of(demoRecurring);
    c._spaceId = 'fake-personal';
    c._loading = false;
    return c;
  }

  final AuthController _auth;

  List<DemoRecurring> _items = [];
  String _spaceId = '';
  bool _loading = true;

  List<DemoRecurring> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  String get spaceId => _spaceId;

  static String _displayDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final raw = iso.length >= 10 ? iso.substring(0, 10) : iso;
    final d = DateTime.tryParse(raw);
    if (d == null) return iso;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  static TxnStatus _uiStatus(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'paused':
      case 'pending':
        return TxnStatus.pending;
      case 'ended':
      case 'failed':
        return TxnStatus.failed;
      default:
        return TxnStatus.succeeded;
    }
  }

  static MoneyMove _uiType(String? type, double amount, String category, String name) {
    if (type == 'income') return MoneyMove.income;
    return inferMoneyMove(amount, category, name);
  }

  static String _dbType(MoneyMove type) =>
      type == MoneyMove.income ? 'Income' : 'Expense';

  static DemoRecurring fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim() ?? 'Recurring';
    final category = (json['category'] as String?)?.trim() ?? 'Other';
    final amount = (json['amount'] as num?)?.toDouble() ?? 0;
    final nextDate = json['nextDate'] as String? ?? '';
    final startDate = json['startDate'] as String?;
    final endDate = json['endDate'] as String?;
    final originalAmount = (json['originalAmount'] as num?)?.toDouble();
    final originalCurrencyRaw =
        (json['originalCurrency'] as String?)?.trim().toUpperCase();
    return DemoRecurring(
      id: json['id'] as String? ?? '',
      name: name,
      category: category,
      account: (json['account'] as String?)?.trim() ?? '—',
      amount: amount,
      cadence: (json['cadence'] as String?) ?? 'Monthly',
      next: _displayDate(nextDate),
      start: _displayDate(startDate ?? nextDate),
      end: endDate == null || endDate.isEmpty ? '' : _displayDate(endDate),
      status: _uiStatus(json['status'] as String?),
      type: _uiType(json['type'] as String?, amount, category, name),
      originalAmount: originalAmount,
      originalCurrency:
          originalCurrencyRaw != null && originalCurrencyRaw.isNotEmpty
              ? originalCurrencyRaw
              : null,
    );
  }

  Future<void> loadForSpace(String spaceId) async {
    _spaceId = spaceId;
    if (spaceId.isEmpty || spaceId == 'pending') {
      _items = [];
      _loading = false;
      notifyListeners();
      return;
    }

    if (_auth.isFake) {
      _items = List<DemoRecurring>.of(demoRecurring);
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();
    try {
      await _processDueIfNeeded(spaceId);
      final decoded = await _auth.apiDecode(
        'GET',
        '/api/recurring?portfolio_id=${Uri.encodeQueryComponent(spaceId)}',
      );
      final list = <DemoRecurring>[];
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) list.add(fromJson(item));
        }
      }
      _items = list;
      await prefetchFxRates(_auth, list.map((r) => r.originalCurrency));
    } catch (e) {
      debugPrint('RecurringController.load: $e');
      _items = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<DemoRecurring?> create({
    required String name,
    required String category,
    required String account,
    required double amount,
    required String cadence,
    required String next,
    required String start,
    required String end,
    required MoneyMove type,
    String? currency,
  }) async {
    if (_spaceId.isEmpty) return null;
    final code = (currency ?? DisplayCurrency.code).toUpperCase();

    if (_auth.isFake) {
      final row = DemoRecurring(
        id: 'fake-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        category: category,
        account: account,
        amount: amount,
        cadence: cadence,
        next: next,
        start: start,
        end: end,
        status: TxnStatus.pending,
        type: type,
        originalAmount: amount.abs(),
        originalCurrency: code,
      );
      _items = [..._items, row];
      notifyListeners();
      return row;
    }

    final decoded = await _auth.apiDecode(
      'POST',
      '/api/recurring',
      body: {
        'portfolioId': _spaceId,
        'name': name,
        'category': category,
        'account': account,
        'amount': amount,
        'cadence': cadence,
        'next': next,
        'start': start,
        'end': end,
        'type': _dbType(type),
        'status': 'Pending',
        'currency': code,
      },
    );
    if (decoded is! Map<String, dynamic>) return null;
    final row = fromJson(decoded);
    _items = [..._items, row];
    notifyListeners();
    return row;
  }

  Future<DemoRecurring?> patch(String id, Map<String, dynamic> body) async {
    if (_auth.isFake) {
      final idx = _items.indexWhere((r) => r.id == id);
      if (idx < 0) return null;
      final t = _items[idx];
      final currency = (body['currency'] as String?)?.toUpperCase();
      final updated = t.copyWith(
        name: body['name'] as String? ?? t.name,
        amount: (body['amount'] as num?)?.toDouble() ?? t.amount,
        cadence: body['cadence'] as String? ?? t.cadence,
        next: body['next'] as String? ?? t.next,
        start: body['start'] as String? ?? t.start,
        end: body['end'] as String? ?? t.end,
        status: body['status'] != null
            ? _uiStatus(body['status'] as String)
            : t.status,
        type: body['type'] != null
            ? (body['type'] == 'Income' || body['type'] == 'income'
                ? MoneyMove.income
                : body['type'] == 'Transfer'
                    ? MoneyMove.transfer
                    : MoneyMove.expense)
            : t.type,
        originalAmount: (body['amount'] as num?)?.toDouble().abs() ??
            t.originalAmount,
        originalCurrency: currency ?? t.originalCurrency,
      );
      _items = [..._items]..[idx] = updated;
      notifyListeners();
      return updated;
    }

    final decoded = await _auth.apiDecode(
      'PATCH',
      '/api/recurring/$id',
      body: body,
    );
    if (decoded is! Map<String, dynamic>) return null;
    final row = fromJson(decoded);
    _items = [for (final r in _items) if (r.id == id) row else r];
    notifyListeners();
    return row;
  }

  Future<void> skipNext(String id) async {
    await patch(id, {'advanceNext': true, 'skip': true});
  }

  Future<void> markPaid(String id) async {
    await patch(id, {'advanceNext': true, 'markPaid': true});
  }

  Future<bool> remove(String id) async {
    if (_auth.isFake) {
      _items = _items.where((r) => r.id != id).toList();
      notifyListeners();
      return true;
    }
    final decoded = await _auth.apiDecode('DELETE', '/api/recurring/$id');
    if (decoded == null) return false;
    _items = _items.where((r) => r.id != id).toList();
    notifyListeners();
    return true;
  }

  Future<void> _processDueIfNeeded(String spaceId) async {
    if (_auth.isFake || spaceId.isEmpty) return;
    final now = DateTime.now();
    final asOf =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      await _auth.apiDecode(
        'POST',
        '/api/recurring/process-due',
        body: {'portfolioId': spaceId, 'asOf': asOf},
      );
    } catch (e) {
      debugPrint('RecurringController.processDue: $e');
    }
  }
}
