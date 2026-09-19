import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_controller.dart';

class Space {
  const Space({
    required this.id,
    required this.name,
    required this.type,
  });

  final String id;
  final String name;
  final String type; // Personal | Business

  String get initial =>
      name.trim().isEmpty ? 'S' : name.trim()[0].toUpperCase();

  factory Space.fromJson(Map<String, dynamic> json) {
    return Space(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Space',
      type: json['type'] as String? ?? 'Personal',
    );
  }
}

class SpacesController extends ChangeNotifier {
  SpacesController(this._auth);

  factory SpacesController.fake() {
    final c = SpacesController(AuthController.fake());
    c._spaces = const [
      Space(id: 'fake-personal', name: 'Personal', type: 'Personal'),
    ];
    c._spaceId = c._spaces.first.id;
    c._loading = false;
    c._ready = true;
    return c;
  }

  final AuthController _auth;

  List<Space> _spaces = [];
  String _spaceId = '';
  bool _loading = true;
  bool _ready = false;

  static const _prefsKey = 'financeai-space-id';

  List<Space> get spaces => List.unmodifiable(_spaces);
  String get spaceId => _spaceId;
  Space get space {
    for (final s in _spaces) {
      if (s.id == _spaceId) return s;
    }
    if (_spaces.isNotEmpty) return _spaces.first;
    return const Space(id: 'pending', name: 'Space', type: 'Personal');
  }
  bool get loading => _loading;
  bool get ready => _ready;

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    if (_auth.isFake) {
      _spaces = const [
        Space(id: 'fake-personal', name: 'Personal', type: 'Personal'),
      ];
      _spaceId = _spaces.first.id;
      _loading = false;
      _ready = true;
      notifyListeners();
      return;
    }

    try {
      final decoded = await _auth.apiDecode('GET', '/api/portfolios');
      final list = <Space>[];
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            list.add(Space.fromJson(item));
          }
        }
      }
      _spaces = list;

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      _spaceId = list.any((s) => s.id == stored)
          ? stored!
          : (list.isNotEmpty ? list.first.id : '');
    } catch (e) {
      debugPrint('SpacesController.load: $e');
      _spaces = const [];
      _spaceId = '';
    }

    _loading = false;
    _ready = true;
    notifyListeners();
  }

  Future<void> select(String id) async {
    if (!_spaces.any((s) => s.id == id)) return;
    _spaceId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, id);
  }

  Future<Space?> create({
    required String name,
    String type = 'Personal',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    if (_auth.isFake) {
      final space = Space(
        id: 'fake-${DateTime.now().millisecondsSinceEpoch}',
        name: trimmed,
        type: type,
      );
      _spaces = [..._spaces, space];
      await select(space.id);
      return space;
    }

    final decoded = await _auth.apiDecode(
      'POST',
      '/api/portfolios',
      body: {'name': trimmed, 'type': type},
    );
    if (decoded is! Map<String, dynamic>) return null;
    final space = Space.fromJson(decoded);
    _spaces = [..._spaces, space];
    await select(space.id);
    return space;
  }

  Future<bool> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    if (_auth.isFake) {
      _spaces = [
        for (final s in _spaces)
          if (s.id == id) Space(id: s.id, name: trimmed, type: s.type) else s,
      ];
      notifyListeners();
      return true;
    }

    final decoded = await _auth.apiDecode(
      'PATCH',
      '/api/portfolios/$id',
      body: {'name': trimmed},
    );
    if (decoded is! Map<String, dynamic>) return false;
    final updated = Space.fromJson(decoded);
    _spaces = [for (final s in _spaces) if (s.id == id) updated else s];
    notifyListeners();
    return true;
  }

  Future<bool> remove(String id) async {
    if (_spaces.length <= 1) return false;

    if (_auth.isFake) {
      _spaces = _spaces.where((s) => s.id != id).toList();
      if (_spaceId == id) await select(_spaces.first.id);
      notifyListeners();
      return true;
    }

    final decoded = await _auth.apiDecode('DELETE', '/api/portfolios/$id');
    if (decoded == null) return false;
    _spaces = _spaces.where((s) => s.id != id).toList();
    if (_spaceId == id && _spaces.isNotEmpty) {
      await select(_spaces.first.id);
    } else {
      notifyListeners();
    }
    return true;
  }
}
