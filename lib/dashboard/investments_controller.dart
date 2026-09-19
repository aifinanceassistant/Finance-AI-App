import 'package:flutter/foundation.dart';

import '../auth/auth_controller.dart';
import 'data.dart';

class InvestmentsController extends ChangeNotifier {
  InvestmentsController(this._auth);

  factory InvestmentsController.fake() {
    final c = InvestmentsController(AuthController.fake());
    c._holdings = List<DemoHolding>.of(demoHoldings);
    c._spaceId = 'fake-personal';
    c._loading = false;
    return c;
  }

  final AuthController _auth;

  List<DemoHolding> _holdings = [];
  String _spaceId = '';
  bool _loading = false;

  List<DemoHolding> get holdings => List.unmodifiable(_holdings);
  bool get loading => _loading;
  String get spaceId => _spaceId;

  static DemoHolding fromJson(Map<String, dynamic> json) {
    return DemoHolding(
      id: json['id'] as String?,
      name: (json['name'] as String?)?.trim() ?? 'Holding',
      ticker: ((json['ticker'] as String?) ?? (json['symbol'] as String?) ?? '')
          .trim()
          .toUpperCase(),
      type: (json['type'] as String?)?.trim() ?? 'Stock',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      change: (json['change'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<void> loadForSpace(String spaceId) async {
    _spaceId = spaceId;
    if (spaceId.isEmpty || spaceId == 'pending') {
      _holdings = [];
      _loading = false;
      notifyListeners();
      return;
    }

    if (_auth.isFake) {
      _holdings = List<DemoHolding>.of(demoHoldings);
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();
    try {
      final decoded = await _auth.apiDecode(
        'GET',
        '/api/investments?portfolio_id=${Uri.encodeQueryComponent(spaceId)}',
      );
      final list = <DemoHolding>[];
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) list.add(fromJson(item));
        }
      }
      _holdings = list;
    } catch (e) {
      debugPrint('InvestmentsController.load: $e');
      _holdings = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<DemoHolding?> create({
    required String name,
    required String ticker,
    required String type,
    required double value,
    required double cost,
  }) async {
    if (_spaceId.isEmpty) return null;

    if (_auth.isFake) {
      final row = DemoHolding(
        id: 'fake-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        ticker: ticker,
        type: type,
        value: value,
        cost: cost,
        change: 0,
      );
      _holdings = [..._holdings, row];
      notifyListeners();
      return row;
    }

    final decoded = await _auth.apiDecode(
      'POST',
      '/api/investments',
      body: {
        'portfolioId': _spaceId,
        'name': name,
        'ticker': ticker,
        'type': type,
        'value': value,
        'cost': cost,
      },
    );
    if (decoded is! Map<String, dynamic>) return null;
    final row = fromJson(decoded);
    _holdings = [..._holdings, row];
    notifyListeners();
    return row;
  }

  Future<DemoHolding?> update(
    String id, {
    String? name,
    String? ticker,
    String? type,
    double? value,
    double? cost,
  }) async {
    if (_auth.isFake) {
      final idx = _holdings.indexWhere((h) => h.id == id);
      if (idx < 0) return null;
      final t = _holdings[idx];
      final updated = t.copyWith(
        name: name ?? t.name,
        ticker: ticker ?? t.ticker,
        type: type ?? t.type,
        value: value ?? t.value,
        cost: cost ?? t.cost,
      );
      _holdings = [..._holdings]..[idx] = updated;
      notifyListeners();
      return updated;
    }

    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (ticker != null) body['ticker'] = ticker;
    if (type != null) body['type'] = type;
    if (value != null) body['value'] = value;
    if (cost != null) body['cost'] = cost;

    final decoded = await _auth.apiDecode(
      'PATCH',
      '/api/investments/$id',
      body: body,
    );
    if (decoded is! Map<String, dynamic>) return null;
    final row = fromJson(decoded);
    _holdings = [for (final h in _holdings) if (h.id == id) row else h];
    notifyListeners();
    return row;
  }

  Future<bool> remove(String id) async {
    if (_auth.isFake) {
      _holdings = _holdings.where((h) => h.id != id).toList();
      notifyListeners();
      return true;
    }
    final decoded = await _auth.apiDecode('DELETE', '/api/investments/$id');
    if (decoded == null) return false;
    _holdings = _holdings.where((h) => h.id != id).toList();
    notifyListeners();
    return true;
  }
}
