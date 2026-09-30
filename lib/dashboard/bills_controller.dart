import 'package:flutter/foundation.dart';

import '../auth/auth_controller.dart';
import 'fx_prefetch.dart';

class BillRecord {
  const BillRecord({
    required this.id,
    required this.number,
    required this.description,
    required this.status,
    required this.issueDate,
    this.dueDate,
    required this.currency,
    required this.originalAmount,
    required this.amount,
    required this.amountPaid,
    required this.amountRemaining,
    this.contactId,
    this.accountId,
    this.categoryId,
    this.notes,
  });

  final String id;
  final String number;
  final String description;
  final String status;
  final String issueDate;
  final String? dueDate;
  final String currency;
  final double originalAmount;
  final double amount;
  final double amountPaid;
  final double amountRemaining;
  final String? contactId;
  final String? accountId;
  final String? categoryId;
  final String? notes;

  String get title {
    final d = description.trim();
    if (d.isNotEmpty) return d;
    final n = number.trim();
    if (n.isNotEmpty) return n;
    return 'Bill';
  }

  bool get canSettle =>
      status == 'open' || status == 'partial';

  static BillRecord fromJson(Map<String, dynamic> json) {
    final currencyRaw = (json['currency'] as String?)?.trim().toUpperCase();
    return BillRecord(
      id: json['id'] as String? ?? '',
      number: (json['number'] as String?)?.trim() ?? '',
      description: (json['description'] as String?)?.trim() ?? '',
      status: ((json['status'] as String?) ?? 'open').trim().toLowerCase(),
      issueDate: _ymd(json['issueDate']),
      dueDate: _ymdNullable(json['dueDate']),
      currency:
          currencyRaw != null && currencyRaw.isNotEmpty ? currencyRaw : 'USD',
      originalAmount: (json['originalAmount'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0,
      amountRemaining: (json['amountRemaining'] as num?)?.toDouble() ?? 0,
      contactId: json['contactId'] as String?,
      accountId: json['accountId'] as String?,
      categoryId: json['categoryId'] as String?,
      notes: (json['notes'] as String?)?.trim(),
    );
  }

  static String _ymd(dynamic raw) {
    if (raw is! String || raw.isEmpty) {
      return DateTime.now().toUtc().toIso8601String().substring(0, 10);
    }
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  static String? _ymdNullable(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }
}

class BillsController extends ChangeNotifier {
  BillsController(this._auth);

  factory BillsController.fake() {
    final c = BillsController(AuthController.fake());
    c._items = List<BillRecord>.of(_demoBills);
    c._spaceId = 'fake-personal';
    c._loading = false;
    return c;
  }

  final AuthController _auth;

  List<BillRecord> _items = [];
  String _spaceId = '';
  bool _loading = true;

  List<BillRecord> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  String get spaceId => _spaceId;

  Future<void> loadForSpace(String spaceId) async {
    _spaceId = spaceId;
    if (spaceId.isEmpty || spaceId == 'pending') {
      _items = [];
      _loading = false;
      notifyListeners();
      return;
    }

    if (_auth.isFake) {
      _items = List<BillRecord>.of(_demoBills);
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();
    try {
      final decoded = await _auth.apiDecode(
        'GET',
        '/api/bills?portfolio_id=${Uri.encodeQueryComponent(spaceId)}',
      );
      final list = <BillRecord>[];
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) list.add(BillRecord.fromJson(item));
        }
      }
      _items = list;
      await prefetchFxRates(_auth, list.map((b) => b.currency));
    } catch (e) {
      debugPrint('BillsController.load: $e');
      _items = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<BillRecord?> create({
    required String description,
    String number = '',
    String status = 'open',
    required String issueDate,
    String? dueDate,
    required double originalAmount,
    required String currency,
    String? accountId,
    String? categoryId,
    String? contactId,
    String? notes,
  }) async {
    if (_spaceId.isEmpty) return null;
    final code = currency.toUpperCase();

    if (_auth.isFake) {
      final row = BillRecord(
        id: 'fake-bill-${DateTime.now().millisecondsSinceEpoch}',
        number: number,
        description: description,
        status: status,
        issueDate: issueDate,
        dueDate: dueDate,
        currency: code,
        originalAmount: originalAmount.abs(),
        amount: originalAmount.abs(),
        amountPaid: 0,
        amountRemaining: originalAmount.abs(),
        accountId: accountId,
        categoryId: categoryId,
        contactId: contactId,
        notes: notes,
      );
      _items = [..._items, row];
      notifyListeners();
      return row;
    }

    final decoded = await _auth.apiDecode(
      'POST',
      '/api/bills',
      body: {
        'portfolioId': _spaceId,
        'number': number,
        'description': description,
        'status': status,
        'issueDate': issueDate,
        if (dueDate != null && dueDate.isNotEmpty) 'dueDate': dueDate,
        'originalAmount': originalAmount.abs(),
        'currency': code,
        if (accountId != null) 'accountId': accountId,
        if (categoryId != null) 'categoryId': categoryId,
        if (contactId != null) 'contactId': contactId,
        if (notes != null) 'notes': notes,
      },
    );
    if (decoded is! Map<String, dynamic>) return null;
    final row = BillRecord.fromJson(decoded);
    _items = [..._items, row];
    notifyListeners();
    return row;
  }

  Future<BillRecord?> update(
    String id, {
    String? description,
    String? number,
    String? status,
    String? issueDate,
    String? dueDate,
    bool clearDueDate = false,
    double? originalAmount,
    String? currency,
    String? accountId,
    String? categoryId,
    String? contactId,
    String? notes,
  }) async {
    if (_auth.isFake) {
      final idx = _items.indexWhere((b) => b.id == id);
      if (idx < 0) return null;
      final t = _items[idx];
      final amt = originalAmount?.abs() ?? t.originalAmount;
      final paid = t.amountPaid;
      final updated = BillRecord(
        id: t.id,
        number: number ?? t.number,
        description: description ?? t.description,
        status: status ?? t.status,
        issueDate: issueDate ?? t.issueDate,
        dueDate: clearDueDate ? null : (dueDate ?? t.dueDate),
        currency: (currency ?? t.currency).toUpperCase(),
        originalAmount: amt,
        amount: amt,
        amountPaid: paid,
        amountRemaining: (amt - paid).clamp(0, double.infinity),
        accountId: accountId ?? t.accountId,
        categoryId: categoryId ?? t.categoryId,
        contactId: contactId ?? t.contactId,
        notes: notes ?? t.notes,
      );
      _items = [..._items]..[idx] = updated;
      notifyListeners();
      return updated;
    }

    final body = <String, dynamic>{};
    if (description != null) body['description'] = description;
    if (number != null) body['number'] = number;
    if (status != null) body['status'] = status;
    if (issueDate != null) body['issueDate'] = issueDate;
    if (clearDueDate) {
      body['dueDate'] = null;
    } else if (dueDate != null) {
      body['dueDate'] = dueDate;
    }
    if (originalAmount != null) body['originalAmount'] = originalAmount.abs();
    if (currency != null) body['currency'] = currency.toUpperCase();
    if (accountId != null) body['accountId'] = accountId;
    if (categoryId != null) body['categoryId'] = categoryId;
    if (contactId != null) body['contactId'] = contactId;
    if (notes != null) body['notes'] = notes;

    final decoded = await _auth.apiDecode(
      'PATCH',
      '/api/bills/$id',
      body: body,
    );
    if (decoded is! Map<String, dynamic>) return null;
    final row = BillRecord.fromJson(decoded);
    _items = [for (final b in _items) if (b.id == id) row else b];
    notifyListeners();
    return row;
  }

  Future<bool> remove(String id) async {
    if (_auth.isFake) {
      _items = _items.where((b) => b.id != id).toList();
      notifyListeners();
      return true;
    }
    final decoded = await _auth.apiDecode('DELETE', '/api/bills/$id');
    if (decoded == null) return false;
    _items = _items.where((b) => b.id != id).toList();
    notifyListeners();
    return true;
  }

  Future<BillRecord?> settle(
    String id, {
    required String accountId,
    double? amount,
    String? date,
    String? description,
    String? categoryId,
  }) async {
    if (_auth.isFake) {
      final idx = _items.indexWhere((b) => b.id == id);
      if (idx < 0) return null;
      final t = _items[idx];
      final pay = (amount ?? t.amountRemaining).abs();
      final paid = t.amountPaid + pay;
      final remaining = (t.amount - paid).clamp(0.0, double.infinity);
      final status = remaining <= 0.001
          ? 'paid'
          : paid > 0
              ? 'partial'
              : t.status;
      final updated = BillRecord(
        id: t.id,
        number: t.number,
        description: t.description,
        status: status,
        issueDate: t.issueDate,
        dueDate: t.dueDate,
        currency: t.currency,
        originalAmount: t.originalAmount,
        amount: t.amount,
        amountPaid: paid,
        amountRemaining: remaining,
        contactId: t.contactId,
        accountId: accountId,
        categoryId: categoryId ?? t.categoryId,
        notes: t.notes,
      );
      _items = [..._items]..[idx] = updated;
      notifyListeners();
      return updated;
    }

    final decoded = await _auth.apiDecode(
      'POST',
      '/api/bills/$id/settle',
      body: {
        'accountId': accountId,
        if (amount != null) 'amount': amount,
        if (date != null && date.isNotEmpty) 'date': date,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (categoryId != null) 'categoryId': categoryId,
      },
    );
    if (decoded is! Map<String, dynamic>) return null;
    // Settle may return { bill, transaction } or the bill itself.
    final billJson = decoded['bill'] is Map<String, dynamic>
        ? decoded['bill'] as Map<String, dynamic>
        : decoded;
    final row = BillRecord.fromJson(billJson);
    _items = [for (final b in _items) if (b.id == id) row else b];
    notifyListeners();
    return row;
  }
}

const _demoBills = [
  BillRecord(
    id: 'demo-bill-1',
    number: 'BILL-1001',
    description: 'Office internet',
    status: 'open',
    issueDate: '2026-09-01',
    dueDate: '2026-09-30',
    currency: 'USD',
    originalAmount: 89.99,
    amount: 89.99,
    amountPaid: 0,
    amountRemaining: 89.99,
  ),
  BillRecord(
    id: 'demo-bill-2',
    number: 'BILL-1002',
    description: 'Cloud hosting',
    status: 'partial',
    issueDate: '2026-08-15',
    dueDate: '2026-09-15',
    currency: 'USD',
    originalAmount: 240,
    amount: 240,
    amountPaid: 100,
    amountRemaining: 140,
  ),
];
