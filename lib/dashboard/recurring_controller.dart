import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import 'data.dart';
import 'fx_prefetch.dart';

class RecurringFixItem {
  const RecurringFixItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    required this.suggestedName,
    required this.suggestedMagnitude,
    required this.suggestedCurrency,
    required this.suggestedCadence,
    required this.suggestedNextDate,
    required this.suggestedStartDate,
    required this.suggestedType,
    this.suggestedAccountId,
    this.suggestedCategoryId,
    this.recurringId,
  });

  final String id;
  final String kind;
  final String title;
  final String detail;
  final String suggestedName;
  final double suggestedMagnitude;
  final String suggestedCurrency;
  final String suggestedCadence;
  final String suggestedNextDate;
  final String suggestedStartDate;
  final String suggestedType;
  final String? suggestedAccountId;
  final String? suggestedCategoryId;
  final String? recurringId;

  factory RecurringFixItem.fromJson(Map<String, dynamic> json) {
    final suggested = json['suggested'] is Map<String, dynamic>
        ? json['suggested'] as Map<String, dynamic>
        : <String, dynamic>{};
    return RecurringFixItem(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? 'add',
      title: json['title'] as String? ?? 'Suggestion',
      detail: json['detail'] as String? ?? '',
      suggestedName: suggested['name'] as String? ?? '',
      suggestedMagnitude:
          (suggested['magnitude'] as num?)?.toDouble() ?? 0,
      suggestedCurrency:
          (suggested['currency'] as String?)?.trim().toUpperCase() ?? 'USD',
      suggestedCadence: suggested['cadence'] as String? ?? 'Monthly',
      suggestedNextDate: suggested['nextDate'] as String? ?? '',
      suggestedStartDate: suggested['startDate'] as String? ?? '',
      suggestedType: suggested['type'] as String? ?? 'expense',
      suggestedAccountId: suggested['accountId'] as String?,
      suggestedCategoryId: suggested['categoryId'] as String?,
      recurringId: json['recurringId'] as String?,
    );
  }
}

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
  List<RecurringFixItem> _fixes = [];
  String _spaceId = '';
  bool _loading = true;
  bool _fixesLoading = false;

  List<DemoRecurring> get items => List.unmodifiable(_items);
  List<RecurringFixItem> get fixes => List.unmodifiable(_fixes);
  bool get loading => _loading;
  bool get fixesLoading => _fixesLoading;
  String get spaceId => _spaceId;

  static String _advanceIso(String iso, String cadence) {
    final raw = iso.length >= 10 ? iso.substring(0, 10) : iso;
    final d = DateTime.tryParse(raw);
    if (d == null) return DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final key = cadence.trim().toLowerCase();
    late final DateTime next;
    if (key == 'weekly') {
      next = d.add(const Duration(days: 7));
    } else if (key == 'biweekly' || key == 'bi-weekly') {
      next = d.add(const Duration(days: 14));
    } else if (key == 'quarterly') {
      next = DateTime.utc(d.year, d.month + 3, d.day);
    } else if (key == 'yearly' || key == 'annual') {
      next = DateTime.utc(d.year + 1, d.month, d.day);
    } else {
      next = DateTime.utc(d.year, d.month + 1, d.day);
    }
    return next.toIso8601String().substring(0, 10);
  }

  /// Roll a stored next_date forward until on/after today (display-only).
  /// Returns null when the series has no remaining occurrence.
  static String? _upcomingIso(
    String nextDate,
    String cadence, {
    String? endDate,
    int? remainingOccurrences,
  }) {
    if (remainingOccurrences != null && remainingOccurrences <= 0) return null;
    final now = DateTime.now().toUtc();
    final asOf =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final endYmd = (endDate != null && endDate.length >= 10)
        ? endDate.substring(0, 10)
        : '';
    var cur = nextDate.length >= 10 ? nextDate.substring(0, 10) : nextDate;
    if (cur.isEmpty) cur = asOf;
    if (endYmd.isNotEmpty && cur.compareTo(endYmd) > 0) return null;
    if (cur.compareTo(asOf) >= 0) return cur;
    for (var i = 0; i < 240; i++) {
      cur = _advanceIso(cur, cadence);
      if (endYmd.isNotEmpty && cur.compareTo(endYmd) > 0) return null;
      if (cur.compareTo(asOf) >= 0) return cur;
    }
    if (endYmd.isNotEmpty && cur.compareTo(endYmd) > 0) return null;
    return cur;
  }

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
    final year = d.year != now.year ? ', ${d.year}' : '';
    return '${months[d.month - 1]} ${d.day}$year';
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
    final cadence = (json['cadence'] as String?) ?? 'Monthly';
    final remaining = (json['remainingOccurrences'] as num?)?.toInt();
    final status = _uiStatus(json['status'] as String?);
    final nextIso = status == TxnStatus.failed
        ? null
        : _upcomingIso(
            nextDate,
            cadence,
            endDate: endDate,
            remainingOccurrences: remaining,
          );
    return DemoRecurring(
      id: json['id'] as String? ?? '',
      name: name,
      category: category,
      account: (json['account'] as String?)?.trim() ?? '—',
      amount: amount,
      cadence: cadence,
      next: nextIso == null ? '—' : _displayDate(nextIso),
      start: _displayDate(startDate ?? nextDate),
      end: endDate == null || endDate.isEmpty ? '' : _displayDate(endDate),
      status: status,
      type: _uiType(json['type'] as String?, amount, category, name),
      originalAmount: originalAmount,
      originalCurrency:
          originalCurrencyRaw != null && originalCurrencyRaw.isNotEmpty
              ? originalCurrencyRaw
              : null,
      autoApply: json['autoApply'] == true,
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
      await loadFixes();
    } catch (e) {
      debugPrint('RecurringController.load: $e');
      _items = [];
      _fixes = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadFixes() async {
    if (_auth.isFake || _spaceId.isEmpty || _spaceId == 'pending') {
      _fixes = [];
      _fixesLoading = false;
      notifyListeners();
      return;
    }
    _fixesLoading = true;
    notifyListeners();
    try {
      final decoded = await _auth.apiDecode(
        'GET',
        '/api/recurring/fixes?portfolio_id=${Uri.encodeQueryComponent(_spaceId)}',
      );
      final list = <RecurringFixItem>[];
      if (decoded is Map<String, dynamic> && decoded['fixes'] is List) {
        for (final item in decoded['fixes'] as List) {
          if (item is Map<String, dynamic>) {
            list.add(RecurringFixItem.fromJson(item));
          }
        }
      }
      _fixes = list;
    } catch (e) {
      debugPrint('RecurringController.loadFixes: $e');
      _fixes = [];
    }
    _fixesLoading = false;
    notifyListeners();
  }

  Future<bool> acceptFix(String fixId) async {
    if (_spaceId.isEmpty) return false;
    if (_auth.isFake) {
      _fixes = _fixes.where((f) => f.id != fixId).toList();
      notifyListeners();
      return true;
    }
    final decoded = await _auth.apiDecode(
      'POST',
      '/api/recurring/fixes',
      body: {
        'portfolioId': _spaceId,
        'fixId': fixId,
      },
    );
    if (decoded is! Map<String, dynamic>) return false;
    final recurring = decoded['recurring'];
    if (recurring is Map<String, dynamic>) {
      final row = fromJson(recurring);
      final idx = _items.indexWhere((r) => r.id == row.id);
      if (idx >= 0) {
        _items = [..._items]..[idx] = row;
      } else {
        _items = [..._items, row];
      }
      await prefetchFxRates(_auth, [row.originalCurrency]);
    }
    _fixes = _fixes.where((f) => f.id != fixId).toList();
    notifyListeners();
    return true;
  }

  Future<bool> dismissFix(String fixId) async {
    _fixes = _fixes.where((f) => f.id != fixId).toList();
    notifyListeners();
    return true;
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
    bool autoApply = false,
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
        autoApply: autoApply,
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
        'autoApply': autoApply,
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
        autoApply: body['autoApply'] as bool? ?? t.autoApply,
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
