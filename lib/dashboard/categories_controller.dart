import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../theme/app_theme.dart';

class CategoryRecord {
  const CategoryRecord({
    required this.id,
    required this.name,
    required this.type,
    required this.spent,
    required this.txns,
    required this.group,
    required this.color,
    required this.emoji,
  });

  final String id;
  final String name;
  final String type; // expense | income
  final double spent;
  final int txns;
  final String group;
  final Color color;
  final String emoji;
}

const _fallbackColors = [
  AppColors.brand,
  AppColors.accent,
  Color(0xFF22C55E),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFFA855F7),
  Color(0xFF14B8A6),
  Color(0xFFF472B6),
];

({String group, Color color, String emoji}) _metaFor(
  String name,
  String type,
  int index,
) {
  final key = name.trim().toLowerCase();
  const map = <String, ({String group, int color, String emoji})>{
    'beauty': (group: 'Lifestyle', color: 0xFFF472B6, emoji: '💄'),
    'car': (group: 'Essentials', color: 0xFF3B9AE0, emoji: '🚗'),
    'children': (group: 'Family', color: 0xFFF59E0B, emoji: '🚸'),
    'clothing': (group: 'Lifestyle', color: 0xFF6366F1, emoji: '👕'),
    'dining': (group: 'Lifestyle', color: 0xFFF59E0B, emoji: '🍔'),
    'entertainment': (group: 'Lifestyle', color: 0xFFA855F7, emoji: '🎟️'),
    'food': (group: 'Essentials', color: 0xFF22C55E, emoji: '🥑'),
    'grocery': (group: 'Essentials', color: 0xFF22C55E, emoji: '🥑'),
    'groceries': (group: 'Essentials', color: 0xFF22C55E, emoji: '🥑'),
    'healthcare': (group: 'Wellness', color: 0xFFEF4444, emoji: '💊'),
    'housing': (group: 'Essentials', color: 0xFF0EA5E9, emoji: '🏠'),
    'home': (group: 'Essentials', color: 0xFF0EA5E9, emoji: '🏠'),
    'insurance': (group: 'Finance', color: 0xFF8B5CF6, emoji: '☂️'),
    'rent': (group: 'Essentials', color: 0xFFE11D48, emoji: '🔑'),
    'restaurants': (group: 'Lifestyle', color: 0xFFF59E0B, emoji: '🍔'),
    'shopping': (group: 'Lifestyle', color: 0xFF7C3AED, emoji: '🛍️'),
    'shops': (group: 'Lifestyle', color: 0xFF7C3AED, emoji: '🛍️'),
    'subscriptions': (group: 'Lifestyle', color: 0xFFA855F7, emoji: '🎟️'),
    'transportation': (group: 'Essentials', color: 0xFF06B6D4, emoji: '🚌'),
    'utilities': (group: 'Essentials', color: 0xFF6366F1, emoji: '🔌'),
    'salary': (group: 'Income', color: 0xFF22C55E, emoji: '💰'),
    'freelance': (group: 'Income', color: 0xFF3B82F6, emoji: '💻'),
    'other': (group: 'Other', color: 0xFF8898AA, emoji: '🏷️'),
  };
  final hit = map[key];
  if (hit != null) {
    return (group: hit.group, color: Color(hit.color), emoji: hit.emoji);
  }
  if (type == 'income') {
    return (group: 'Income', color: const Color(0xFF22C55E), emoji: '💰');
  }
  return (
    group: 'Other',
    color: _fallbackColors[index % _fallbackColors.length],
    emoji: '🏷️',
  );
}

class CategoriesController extends ChangeNotifier {
  CategoriesController(this._auth);

  factory CategoriesController.fake() {
    final c = CategoriesController(AuthController.fake());
    final list = <CategoryRecord>[];
    for (var i = 0; i < _fakeSeed.length; i++) {
      final s = _fakeSeed[i];
      final meta = _metaFor(s.$1, 'expense', i);
      list.add(
        CategoryRecord(
          id: 'fake-$i',
          name: s.$1,
          type: 'expense',
          spent: s.$2,
          txns: s.$3,
          group: meta.group,
          color: meta.color,
          emoji: meta.emoji,
        ),
      );
    }
    c._categories = list;
    c._spaceId = 'fake-personal';
    c._loading = false;
    return c;
  }

  final AuthController _auth;

  List<CategoryRecord> _categories = [];
  String _spaceId = '';
  bool _loading = true;

  List<CategoryRecord> get categories => List.unmodifiable(_categories);
  bool get loading => _loading;
  String get spaceId => _spaceId;

  static const _fakeSeed = <(String, double, int)>[
    ('Housing', 1450, 1),
    ('Groceries', 420, 9),
    ('Dining', 310, 10),
    ('Transport', 210, 7),
    ('Subscriptions', 89, 6),
  ];

  static CategoryRecord fromJson(Map<String, dynamic> json, int index) {
    final name = (json['name'] as String?)?.trim() ?? 'Category';
    final type = (json['type'] as String?) ?? 'expense';
    final meta = _metaFor(name, type, index);
    return CategoryRecord(
      id: json['id'] as String? ?? '',
      name: name,
      type: type,
      spent: (json['spent'] as num?)?.toDouble() ?? 0,
      txns: (json['txns'] as num?)?.toInt() ?? 0,
      group: meta.group,
      color: meta.color,
      emoji: meta.emoji,
    );
  }

  Future<void> loadForSpace(String spaceId) async {
    _spaceId = spaceId;
    if (spaceId.isEmpty || spaceId == 'pending') {
      _categories = [];
      _loading = false;
      notifyListeners();
      return;
    }

    if (_auth.isFake) {
      _categories = CategoriesController.fake()._categories;
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();
    try {
      final decoded = await _auth.apiDecode(
        'GET',
        '/api/categories?portfolio_id=${Uri.encodeQueryComponent(spaceId)}',
      );
      final list = <CategoryRecord>[];
      if (decoded is List) {
        for (var i = 0; i < decoded.length; i++) {
          final item = decoded[i];
          if (item is Map<String, dynamic>) {
            list.add(fromJson(item, i));
          }
        }
      }
      _categories = list;
    } catch (e) {
      debugPrint('CategoriesController.load: $e');
      _categories = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<CategoryRecord?> create({
    required String name,
    required String type,
  }) async {
    if (_spaceId.isEmpty) return null;

    if (_auth.isFake) {
      final meta = _metaFor(name, type, _categories.length);
      final row = CategoryRecord(
        id: 'fake-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        type: type,
        spent: 0,
        txns: 0,
        group: meta.group,
        color: meta.color,
        emoji: meta.emoji,
      );
      _categories = [..._categories, row];
      notifyListeners();
      return row;
    }

    final decoded = await _auth.apiDecode(
      'POST',
      '/api/categories',
      body: {
        'portfolioId': _spaceId,
        'name': name,
        'type': type,
      },
    );
    if (decoded is! Map<String, dynamic>) return null;
    final row = fromJson(decoded, _categories.length);
    _categories = [..._categories, row];
    notifyListeners();
    return row;
  }

  Future<bool> rename(String id, String name) async {
    if (_auth.isFake) {
      _categories = [
        for (final c in _categories)
          if (c.id == id)
            CategoryRecord(
              id: c.id,
              name: name,
              type: c.type,
              spent: c.spent,
              txns: c.txns,
              group: c.group,
              color: c.color,
              emoji: c.emoji,
            )
          else
            c,
      ];
      notifyListeners();
      return true;
    }

    final decoded = await _auth.apiDecode(
      'PATCH',
      '/api/categories/$id',
      body: {'name': name},
    );
    if (decoded is! Map<String, dynamic>) return false;
    final updated = fromJson(decoded, 0);
    _categories = [
      for (final c in _categories)
        if (c.id == id)
          CategoryRecord(
            id: updated.id,
            name: updated.name,
            type: updated.type,
            spent: c.spent,
            txns: c.txns,
            group: c.group,
            color: c.color,
            emoji: c.emoji,
          )
        else
          c,
    ];
    notifyListeners();
    return true;
  }

  Future<bool> remove(String id) async {
    if (_auth.isFake) {
      _categories = _categories.where((c) => c.id != id).toList();
      notifyListeners();
      return true;
    }
    final decoded = await _auth.apiDecode('DELETE', '/api/categories/$id');
    if (decoded == null) return false;
    _categories = _categories.where((c) => c.id != id).toList();
    notifyListeners();
    return true;
  }
}
