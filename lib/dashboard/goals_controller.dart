import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../theme/app_theme.dart';
import 'data.dart';

class GoalsController extends ChangeNotifier {
  GoalsController(this._auth);

  factory GoalsController.fake() {
    final c = GoalsController(AuthController.fake());
    c._goals = List<DemoGoal>.of(demoGoals);
    c._spaceId = 'fake-personal';
    c._loading = false;
    return c;
  }

  final AuthController _auth;

  List<DemoGoal> _goals = [];
  String _spaceId = '';
  bool _loading = false;

  List<DemoGoal> get goals => List.unmodifiable(_goals);
  bool get loading => _loading;
  String get spaceId => _spaceId;

  static Color colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.accent;
    var h = hex.replaceFirst('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return AppColors.accent;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return AppColors.accent;
    return Color(v);
  }

  static String colorToHex(Color c) {
    final argb = c.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  static DemoGoal fromJson(Map<String, dynamic> json) {
    return DemoGoal(
      id: json['id'] as String?,
      name: (json['name'] as String?)?.trim() ?? 'Goal',
      target: (json['target'] as num?)?.toDouble() ?? 0,
      saved: (json['saved'] as num?)?.toDouble() ?? 0,
      due: (json['due'] as String?)?.trim() ?? '',
      color: colorFromHex(json['color'] as String?),
      note: (json['note'] as String?)?.trim() ?? '',
    );
  }

  Future<void> loadForSpace(String spaceId) async {
    _spaceId = spaceId;
    if (spaceId.isEmpty || spaceId == 'pending') {
      _goals = [];
      _loading = false;
      notifyListeners();
      return;
    }

    if (_auth.isFake) {
      _goals = List<DemoGoal>.of(demoGoals);
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();
    try {
      final decoded = await _auth.apiDecode(
        'GET',
        '/api/goals?portfolio_id=${Uri.encodeQueryComponent(spaceId)}',
      );
      final list = <DemoGoal>[];
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) list.add(fromJson(item));
        }
      }
      _goals = list;
    } catch (e) {
      debugPrint('GoalsController.load: $e');
      _goals = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<DemoGoal?> create({
    required String name,
    required String note,
    required double target,
    required String due,
    required Color color,
  }) async {
    if (_spaceId.isEmpty) return null;

    if (_auth.isFake) {
      final row = DemoGoal(
        id: 'fake-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        note: note,
        target: target,
        saved: 0,
        due: due,
        color: color,
      );
      _goals = [..._goals, row];
      notifyListeners();
      return row;
    }

    final decoded = await _auth.apiDecode(
      'POST',
      '/api/goals',
      body: {
        'portfolioId': _spaceId,
        'name': name,
        'note': note,
        'target': target,
        'saved': 0,
        'due': due,
        'color': colorToHex(color),
      },
    );
    if (decoded is! Map<String, dynamic>) return null;
    final row = fromJson(decoded);
    _goals = [..._goals, row];
    notifyListeners();
    return row;
  }

  Future<DemoGoal?> contribute(String id, double amount) async {
    if (_auth.isFake) {
      final idx = _goals.indexWhere((g) => g.id == id);
      if (idx < 0) return null;
      final t = _goals[idx];
      final updated = t.copyWith(
        saved: (t.saved + amount).clamp(0, t.target),
      );
      _goals = [..._goals]..[idx] = updated;
      notifyListeners();
      return updated;
    }

    final decoded = await _auth.apiDecode(
      'PATCH',
      '/api/goals/$id',
      body: {'contribute': amount},
    );
    if (decoded is! Map<String, dynamic>) return null;
    final row = fromJson(decoded);
    _goals = [for (final g in _goals) if (g.id == id) row else g];
    notifyListeners();
    return row;
  }

  Future<DemoGoal?> update(
    String id, {
    String? name,
    String? note,
    double? target,
    double? saved,
    String? due,
    Color? color,
  }) async {
    if (_auth.isFake) {
      final idx = _goals.indexWhere((g) => g.id == id);
      if (idx < 0) return null;
      final t = _goals[idx];
      final nextTarget = target ?? t.target;
      final updated = t.copyWith(
        name: name ?? t.name,
        note: note ?? t.note,
        target: nextTarget,
        saved: saved ?? t.saved.clamp(0, nextTarget),
        due: due ?? t.due,
        color: color ?? t.color,
      );
      _goals = [..._goals]..[idx] = updated;
      notifyListeners();
      return updated;
    }

    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (note != null) body['note'] = note;
    if (target != null) body['target'] = target;
    if (saved != null) body['saved'] = saved;
    if (due != null) body['due'] = due;
    if (color != null) body['color'] = colorToHex(color);

    final decoded = await _auth.apiDecode(
      'PATCH',
      '/api/goals/$id',
      body: body,
    );
    if (decoded is! Map<String, dynamic>) return null;
    final row = fromJson(decoded);
    _goals = [for (final g in _goals) if (g.id == id) row else g];
    notifyListeners();
    return row;
  }

  Future<bool> remove(String id) async {
    if (_auth.isFake) {
      _goals = _goals.where((g) => g.id != id).toList();
      notifyListeners();
      return true;
    }
    final decoded = await _auth.apiDecode('DELETE', '/api/goals/$id');
    if (decoded == null) return false;
    _goals = _goals.where((g) => g.id != id).toList();
    notifyListeners();
    return true;
  }
}
