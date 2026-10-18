import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    this.monthlyBudget,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String type; // expense | income
  final double spent;
  final int txns;
  final String group;
  final Color color;
  final String emoji;
  final double? monthlyBudget;
  final int sortOrder;

  CategoryRecord copyWith({
    String? id,
    String? name,
    String? type,
    double? spent,
    int? txns,
    String? group,
    Color? color,
    String? emoji,
    double? monthlyBudget,
    int? sortOrder,
    bool clearMonthlyBudget = false,
  }) {
    return CategoryRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      spent: spent ?? this.spent,
      txns: txns ?? this.txns,
      group: group ?? this.group,
      color: color ?? this.color,
      emoji: emoji ?? this.emoji,
      monthlyBudget:
          clearMonthlyBudget ? null : (monthlyBudget ?? this.monthlyBudget),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// Client-side auto-categorize rule (matches web localStorage CategoryRule).
class CategoryRule {
  const CategoryRule({
    required this.id,
    required this.match,
    required this.categoryName,
  });

  final String id;
  final String match;
  final String categoryName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'match': match,
        'categoryName': categoryName,
      };

  factory CategoryRule.fromJson(Map<String, dynamic> json) {
    return CategoryRule(
      id: json['id'] as String? ?? '',
      match: (json['match'] as String?) ?? '',
      categoryName: (json['categoryName'] as String?) ?? '',
    );
  }
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
          monthlyBudget: s.$2 * 1.1,
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
  List<CategoryRule> _rules = [];
  Map<String, double> _localBudgets = {};
  String _spaceId = '';
  bool _loading = true;

  List<CategoryRecord> get categories => List.unmodifiable(_categories);
  List<CategoryRule> get rules => List.unmodifiable(_rules);
  bool get loading => _loading;
  String get spaceId => _spaceId;

  static const _fakeSeed = <(String, double, int)>[
    ('Housing', 1450, 1),
    ('Groceries', 420, 9),
    ('Dining', 310, 10),
    ('Transport', 210, 7),
    ('Subscriptions', 89, 6),
  ];

  String get _metaKey => 'financeai-category-meta:$_spaceId';

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
      monthlyBudget: (json['monthlyBudget'] as num?)?.toDouble(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? index,
    );
  }

  Future<void> _loadLocalMeta() async {
    if (_spaceId.isEmpty || _spaceId == 'pending') {
      _rules = [];
      _localBudgets = {};
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_metaKey);
      if (raw == null || raw.isEmpty) {
        _rules = [];
        _localBudgets = {};
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _rules = [];
        _localBudgets = {};
        return;
      }
      final rulesRaw = decoded['rules'];
      final budgetsRaw = decoded['monthlyBudgets'];
      _rules = [];
      if (rulesRaw is List) {
        for (final item in rulesRaw) {
          if (item is Map<String, dynamic>) {
            _rules.add(CategoryRule.fromJson(item));
          } else if (item is Map) {
            _rules.add(CategoryRule.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
      _localBudgets = {};
      if (budgetsRaw is Map) {
        budgetsRaw.forEach((k, v) {
          final n = v is num ? v.toDouble() : double.tryParse('$v');
          if (n != null) _localBudgets['$k'] = n;
        });
      }
    } catch (e) {
      debugPrint('CategoriesController._loadLocalMeta: $e');
      _rules = [];
      _localBudgets = {};
    }
  }

  Future<void> _saveLocalMeta() async {
    if (_spaceId.isEmpty || _spaceId == 'pending' || _auth.isFake) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _metaKey,
        jsonEncode({
          'rules': _rules.map((r) => r.toJson()).toList(),
          'monthlyBudgets': _localBudgets,
        }),
      );
    } catch (e) {
      debugPrint('CategoriesController._saveLocalMeta: $e');
    }
  }

  CategoryRecord _withLocalBudget(CategoryRecord c) {
    final local = _localBudgets[c.id] ?? _localBudgets[c.name];
    if (local == null) return c;
    return c.copyWith(monthlyBudget: local);
  }

  Future<void> loadForSpace(String spaceId) async {
    _spaceId = spaceId;
    if (spaceId.isEmpty || spaceId == 'pending') {
      _categories = [];
      _rules = [];
      _localBudgets = {};
      _loading = false;
      notifyListeners();
      return;
    }

    if (_auth.isFake) {
      _categories = CategoriesController.fake()._categories;
      _rules = const [
        CategoryRule(id: 'r1', match: 'uber', categoryName: 'Transport'),
        CategoryRule(id: 'r2', match: 'netflix', categoryName: 'Subscriptions'),
      ];
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();
    try {
      await _loadLocalMeta();
      final decoded = await _auth.apiDecode(
        'GET',
        '/api/categories?portfolio_id=${Uri.encodeQueryComponent(spaceId)}',
      );
      final list = <CategoryRecord>[];
      if (decoded is List) {
        for (var i = 0; i < decoded.length; i++) {
          final item = decoded[i];
          if (item is Map<String, dynamic>) {
            list.add(_withLocalBudget(fromJson(item, i)));
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
    double? monthlyBudget,
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
        monthlyBudget: monthlyBudget,
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
        if (monthlyBudget != null) 'monthlyBudget': monthlyBudget,
      },
    );
    if (decoded is! Map<String, dynamic>) return null;
    var row = fromJson(decoded, _categories.length);
    if (monthlyBudget != null) {
      _localBudgets[row.id] = monthlyBudget;
      await _saveLocalMeta();
      row = row.copyWith(monthlyBudget: monthlyBudget);
    }
    _categories = [..._categories, row];
    notifyListeners();
    return row;
  }

  Future<bool> rename(String id, String name) async {
    if (_auth.isFake) {
      _categories = [
        for (final c in _categories)
          if (c.id == id) c.copyWith(name: name) else c,
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
          c.copyWith(name: updated.name, type: updated.type)
        else
          c,
    ];
    notifyListeners();
    return true;
  }

  Future<bool> setMonthlyBudget(String id, double? budget) async {
    final idx = _categories.indexWhere((c) => c.id == id);
    if (idx < 0) return false;
    final cur = _categories[idx];

    if (_auth.isFake) {
      _categories = [..._categories]
        ..[idx] = cur.copyWith(
          monthlyBudget: budget,
          clearMonthlyBudget: budget == null,
        );
      notifyListeners();
      return true;
    }

    // Persist to API when available; also keep local meta like web.
    try {
      await _auth.apiDecode(
        'PATCH',
        '/api/categories/$id',
        body: {'monthlyBudget': budget},
      );
    } catch (e) {
      debugPrint('CategoriesController.setMonthlyBudget api: $e');
    }
    if (budget == null) {
      _localBudgets.remove(id);
      _localBudgets.remove(cur.name);
    } else {
      _localBudgets[id] = budget;
    }
    await _saveLocalMeta();
    _categories = [..._categories]
      ..[idx] = cur.copyWith(
        monthlyBudget: budget,
        clearMonthlyBudget: budget == null,
      );
    notifyListeners();
    return true;
  }

  Future<bool> addRule({
    required String match,
    required String categoryName,
  }) async {
    final trimmed = match.trim();
    if (trimmed.isEmpty || categoryName.trim().isEmpty) return false;
    final rule = CategoryRule(
      id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
      match: trimmed,
      categoryName: categoryName.trim(),
    );
    _rules = [..._rules, rule];
    await _saveLocalMeta();
    notifyListeners();
    return true;
  }

  Future<bool> removeRule(String id) async {
    _rules = _rules.where((r) => r.id != id).toList();
    await _saveLocalMeta();
    notifyListeners();
    return true;
  }

  /// Delete [sourceId] and remap local rules/budgets to [targetName] (web merge).
  Future<bool> mergeInto({
    required String sourceId,
    required String targetId,
  }) async {
    final source = _categories.cast<CategoryRecord?>().firstWhere(
          (c) => c?.id == sourceId,
          orElse: () => null,
        );
    final target = _categories.cast<CategoryRecord?>().firstWhere(
          (c) => c?.id == targetId,
          orElse: () => null,
        );
    if (source == null || target == null || sourceId == targetId) return false;

    final ok = await remove(sourceId);
    if (!ok) return false;

    _rules = [
      for (final r in _rules)
        if (r.categoryName == source.name)
          CategoryRule(
            id: r.id,
            match: r.match,
            categoryName: target.name,
          )
        else
          r,
    ];
    final budget = _localBudgets.remove(sourceId) ??
        _localBudgets.remove(source.name);
    if (budget != null) {
      _localBudgets[targetId] =
          (_localBudgets[targetId] ?? target.monthlyBudget ?? 0) + budget;
    }
    await _saveLocalMeta();
    notifyListeners();
    return true;
  }

  Future<bool> remove(String id) async {
    if (_auth.isFake) {
      final gone = _categories.where((c) => c.id == id).toList();
      _categories = _categories.where((c) => c.id != id).toList();
      for (final c in gone) {
        _localBudgets.remove(c.id);
        _localBudgets.remove(c.name);
        _rules = _rules.where((r) => r.categoryName != c.name).toList();
      }
      notifyListeners();
      return true;
    }
    final decoded = await _auth.apiDecode('DELETE', '/api/categories/$id');
    if (decoded == null) return false;
    final gone = _categories.where((c) => c.id == id).toList();
    _categories = _categories.where((c) => c.id != id).toList();
    for (final c in gone) {
      _localBudgets.remove(c.id);
      _localBudgets.remove(c.name);
      _rules = _rules.where((r) => r.categoryName != c.name).toList();
    }
    await _saveLocalMeta();
    notifyListeners();
    return true;
  }
}
