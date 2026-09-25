import 'package:flutter/foundation.dart';

import '../auth/auth_controller.dart';
import 'data.dart';
import 'fx_prefetch.dart';

class TransactionsController extends ChangeNotifier {
  TransactionsController(this._auth);

  factory TransactionsController.fake() {
    final c = TransactionsController(AuthController.fake());
    c._txns = List<DemoTxn>.of(demoTransactions);
    c._spaceId = 'fake-personal';
    c._loading = false;
    return c;
  }

  final AuthController _auth;

  List<DemoTxn> _txns = [];
  String _spaceId = '';
  bool _loading = true;

  List<DemoTxn> get transactions => List.unmodifiable(_txns);
  bool get loading => _loading;
  String get spaceId => _spaceId;

  static String _displayDate(String iso) {
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
      case 'pending':
        return TxnStatus.pending;
      case 'failed':
        return TxnStatus.failed;
      default:
        return TxnStatus.succeeded;
    }
  }

  static String _dbStatus(TxnStatus status) {
    switch (status) {
      case TxnStatus.pending:
        return 'Pending';
      case TxnStatus.failed:
        return 'Failed';
      case TxnStatus.succeeded:
        return 'Succeeded';
    }
  }

  static MoneyMove _uiType(
    String? type,
    double amount,
    String category,
    String merchant,
  ) {
    if (type == 'income') return MoneyMove.income;
    return inferMoneyMove(amount, category, merchant);
  }

  static String _dbType(MoneyMove type) {
    return type == MoneyMove.income ? 'Income' : 'Expense';
  }

  static ApprovalStatus _uiApproval(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'pending':
        return ApprovalStatus.pending;
      case 'rejected':
        return ApprovalStatus.rejected;
      case 'approved':
        return ApprovalStatus.approved;
      default:
        // Legacy rows with no approvalStatus are treated as approved.
        return ApprovalStatus.approved;
    }
  }

  static String _dbApproval(ApprovalStatus status) {
    switch (status) {
      case ApprovalStatus.approved:
        return 'Approved';
      case ApprovalStatus.rejected:
        return 'Rejected';
      case ApprovalStatus.pending:
        return 'Pending';
    }
  }

  static DemoTxn fromJson(Map<String, dynamic> json) {
    final merchant = (json['merchant'] as String?)?.trim() ?? 'Transaction';
    final category = (json['category'] as String?)?.trim() ?? 'Uncategorized';
    final account = (json['account'] as String?)?.trim() ?? '—';
    final amount = (json['amount'] as num?)?.toDouble() ?? 0;
    final date = (json['date'] as String?) ?? '';
    final dateIso = date.length >= 10 ? date.substring(0, 10) : date;
    final originalAmount = (json['originalAmount'] as num?)?.toDouble();
    final originalCurrencyRaw =
        (json['originalCurrency'] as String?)?.trim().toUpperCase();
    return DemoTxn(
      id: json['id'] as String? ?? '',
      merchant: merchant,
      category: category,
      account: account,
      amount: amount,
      date: _displayDate(date),
      dateIso: dateIso.isEmpty ? null : dateIso,
      status: _uiStatus(json['status'] as String?),
      approvalStatus: _uiApproval(json['approvalStatus'] as String?),
      type: _uiType(json['type'] as String?, amount, category, merchant),
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
      _txns = [];
      _loading = false;
      notifyListeners();
      return;
    }

    if (_auth.isFake) {
      _txns = List<DemoTxn>.of(demoTransactions);
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
        '/api/transactions?portfolio_id=${Uri.encodeQueryComponent(spaceId)}',
      );
      final list = <DemoTxn>[];
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) list.add(fromJson(item));
        }
      }
      _txns = list;
      await prefetchFxRates(
        _auth,
        list.map((t) => t.originalCurrency),
      );
    } catch (e) {
      debugPrint('TransactionsController.load: $e');
      _txns = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<DemoTxn?> patch(String id, Map<String, dynamic> body) async {
    if (_auth.isFake) {
      final idx = _txns.indexWhere((t) => t.id == id);
      if (idx < 0) return null;
      final t = _txns[idx];
      final updated = t.copyWith(
        category: body['category'] as String? ?? t.category,
        status: body['status'] != null
            ? _uiStatus(body['status'] as String)
            : t.status,
        approvalStatus: body['approvalStatus'] != null
            ? _uiApproval(body['approvalStatus'] as String)
            : t.approvalStatus,
        type: body['type'] != null
            ? (body['type'] == 'Income' || body['type'] == 'income'
                ? MoneyMove.income
                : body['type'] == 'Transfer' || body['type'] == 'transfer'
                    ? MoneyMove.transfer
                    : MoneyMove.expense)
            : t.type,
      );
      _txns = [..._txns]..[idx] = updated;
      notifyListeners();
      return updated;
    }

    final decoded = await _auth.apiDecode(
      'PATCH',
      '/api/transactions/$id',
      body: body,
    );
    if (decoded is! Map<String, dynamic>) return null;
    final row = fromJson(decoded);
    _txns = [for (final t in _txns) if (t.id == id) row else t];
    notifyListeners();
    return row;
  }

  Future<void> markSettled(String id) async {
    await patch(id, {'status': _dbStatus(TxnStatus.succeeded)});
  }

  Future<void> setApproval(String id, ApprovalStatus status) async {
    await patch(id, {'approvalStatus': _dbApproval(status)});
  }

  Future<DemoTxn?> create({
    required String merchant,
    required double amount,
    required String accountId,
    required String category,
    required MoneyMove type,
    String? date,
    String? accountLabel,
    String? currency,
  }) async {
    final code = (currency ?? DisplayCurrency.code).toUpperCase();
    if (_auth.isFake) {
      final row = DemoTxn(
        id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
        merchant: merchant,
        category: category,
        account: accountLabel?.trim().isNotEmpty == true
            ? accountLabel!.trim()
            : accountId,
        amount: type == MoneyMove.income ? amount.abs() : -amount.abs(),
        date: 'Just now',
        status: TxnStatus.succeeded,
        approvalStatus: ApprovalStatus.pending,
        type: type,
        originalAmount: amount.abs(),
        originalCurrency: code,
      );
      _txns = [row, ..._txns];
      notifyListeners();
      return row;
    }

    final body = <String, dynamic>{
      'portfolioId': _spaceId,
      'merchant': merchant,
      'amount': amount.abs(),
      'originalAmount': amount.abs(),
      'currency': code,
      'accountId': accountId,
      'category': category,
      'type': _dbType(type),
      'status': 'Succeeded',
      if (date != null && date.isNotEmpty) 'date': date,
    };
    final decoded = await _auth.apiDecode(
      'POST',
      '/api/transactions',
      body: body,
    );
    if (decoded is! Map<String, dynamic>) return null;
    final row = fromJson(decoded);
    _txns = [row, ..._txns];
    notifyListeners();
    return row;
  }

  Future<void> settleAll() async {
    final open = _txns
        .where(
          (t) => t.status == TxnStatus.pending || t.status == TxnStatus.failed,
        )
        .toList();
    for (final t in open) {
      await markSettled(t.id);
    }
  }

  Future<void> updateDetail({
    required String id,
    required String category,
    required MoneyMove type,
    required bool reconciled,
  }) async {
    final body = <String, dynamic>{
      'category': category,
      'type': _dbType(type),
    };
    if (reconciled) body['status'] = _dbStatus(TxnStatus.succeeded);
    await patch(id, body);
  }

  Future<bool> remove(String id) async {
    if (_auth.isFake) {
      _txns = _txns.where((t) => t.id != id).toList();
      notifyListeners();
      return true;
    }
    final decoded = await _auth.apiDecode('DELETE', '/api/transactions/$id');
    if (decoded == null) return false;
    _txns = _txns.where((t) => t.id != id).toList();
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
      debugPrint('TransactionsController.processDue: $e');
    }
  }
}
