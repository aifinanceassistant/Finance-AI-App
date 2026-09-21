import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../categories_controller.dart';
import '../categories_scope.dart';
import '../data.dart';
import '../filter_sort.dart';
import '../form_validation.dart';
import '../shimmer.dart';
import '../spaces_scope.dart';
import '../ui.dart';

const _categoryFilterFields = [
  FilterFieldDef(id: 'name', label: 'Name', type: FilterFieldType.text),
  FilterFieldDef(id: 'group', label: 'Group', type: FilterFieldType.select),
  FilterFieldDef(id: 'spent', label: 'Spent', type: FilterFieldType.number),
  FilterFieldDef(
    id: 'txns',
    label: 'Transactions',
    type: FilterFieldType.number,
  ),
];

Object? _categoryValue(_CategoryItem c, String field) {
  switch (field) {
    case 'name':
      return c.name;
    case 'group':
      return c.group;
    case 'spent':
      return c.spent;
    case 'txns':
      return c.txns;
    default:
      return '';
  }
}

class _CategoryItem {
  _CategoryItem({
    required this.id,
    required this.name,
    required this.group,
    required this.color,
    required this.spent,
    required this.txns,
    this.emoji = '🏷️',
    this.hidden = false,
    double? defaultBudget,
    Map<String, double>? monthlyBudgets,
  })  : defaultBudget = defaultBudget ?? (spent > 0 ? (spent * 1.08).roundToDouble() : 0),
        monthlyBudgets = monthlyBudgets ?? {};

  final String id;
  String name;
  String group;
  Color color;
  double spent;
  int txns;
  String emoji;
  bool hidden;
  double defaultBudget;
  Map<String, double> monthlyBudgets;

  double budgetFor(String monthKey) =>
      monthlyBudgets.containsKey(monthKey)
          ? monthlyBudgets[monthKey]!
          : defaultBudget;

  _CategoryItem copy() => _CategoryItem(
        id: id,
        name: name,
        group: group,
        color: color,
        spent: spent,
        txns: txns,
        emoji: emoji,
        hidden: hidden,
        defaultBudget: defaultBudget,
        monthlyBudgets: Map<String, double>.from(monthlyBudgets),
      );
}

enum _RuleMatch {
  merchantContains,
  merchantEquals,
  merchantStarts,
  memoContains,
  amountOver,
  amountUnder,
  autoLabel,
}

enum _RuleApplyTo { uncategorized, neu, all }

class _CategoryRule {
  _CategoryRule({
    required this.id,
    required this.match,
    required this.value,
    required this.categoryId,
    required this.priority,
    this.applyTo = _RuleApplyTo.neu,
  });

  final String id;
  _RuleMatch match;
  String value;
  String categoryId;
  int priority;
  bool enabled = true;
  _RuleApplyTo applyTo;
}

String _matchLabel(_RuleMatch m) => switch (m) {
      _RuleMatch.merchantContains => 'Merchant contains',
      _RuleMatch.merchantEquals => 'Merchant equals',
      _RuleMatch.merchantStarts => 'Merchant starts with',
      _RuleMatch.memoContains => 'Memo contains',
      _RuleMatch.amountOver => 'Amount over',
      _RuleMatch.amountUnder => 'Amount under',
      _RuleMatch.autoLabel => 'Auto-label (AI)',
    };

bool _matchNeedsValue(_RuleMatch m) => m != _RuleMatch.autoLabel;

String _ruleHeadline(_CategoryRule r) {
  if (r.match == _RuleMatch.autoLabel) return 'Auto-label with AI';
  final label = _matchLabel(r.match);
  if (r.match == _RuleMatch.amountOver || r.match == _RuleMatch.amountUnder) {
    return '$label ${DisplayCurrency.symbolFor(DisplayCurrency.code)}${r.value}';
  }
  return '$label “${r.value}”';
}

String _applyLabel(_RuleApplyTo a) => switch (a) {
      _RuleApplyTo.uncategorized => 'Uncategorized only',
      _RuleApplyTo.neu => 'New transactions',
      _RuleApplyTo.all => 'All matching',
    };

const _palette = [
  Color(0xFF3B9AE0),
  Color(0xFF635BFF),
  Color(0xFF0D9488),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF7C3AED),
];

const _defaultGroups = [
  'Essentials',
  'Lifestyle',
  'Wellness',
  'Family',
  'Finance',
  'Income',
  'Ops',
  'Other',
];

final _defaults = [
  _CategoryItem(id: 'beauty', name: 'Beauty', group: 'Lifestyle', color: Color(0xFFF472B6), spent: 48, txns: 3, emoji: '💄'),
  _CategoryItem(id: 'car', name: 'Car', group: 'Essentials', color: Color(0xFF3B9AE0), spent: 186, txns: 5, emoji: '🚗'),
  _CategoryItem(id: 'children', name: 'Children', group: 'Family', color: Color(0xFFF59E0B), spent: 37.49, txns: 2, emoji: '🚸'),
  _CategoryItem(id: 'clothing', name: 'Clothing', group: 'Lifestyle', color: Color(0xFF6366F1), spent: 92, txns: 4, emoji: '👕'),
  _CategoryItem(id: 'dance', name: 'Dance', group: 'Lifestyle', color: Color(0xFFEC4899), spent: 53, txns: 2, emoji: '💃'),
  _CategoryItem(id: 'donations', name: 'Donations', group: 'Lifestyle', color: Color(0xFF14B8A6), spent: 40, txns: 1, emoji: '🤝'),
  _CategoryItem(id: 'education', name: 'Education', group: 'Lifestyle', color: Color(0xFF3B82F6), spent: 71.8, txns: 2, emoji: '📘'),
  _CategoryItem(id: 'entertainment', name: 'Entertainment', group: 'Lifestyle', color: Color(0xFFA855F7), spent: 94.96, txns: 6, emoji: '🎟️'),
  _CategoryItem(id: 'groceries', name: 'Groceries', group: 'Essentials', color: Color(0xFF22C55E), spent: 347.29, txns: 9, emoji: '🥑'),
  _CategoryItem(id: 'gym', name: 'Gym', group: 'Wellness', color: Color(0xFF64748B), spent: 79, txns: 1, emoji: '👟'),
  _CategoryItem(id: 'healthcare', name: 'Healthcare', group: 'Wellness', color: Color(0xFFEF4444), spent: 62, txns: 3, emoji: '💊'),
  _CategoryItem(id: 'home', name: 'Home', group: 'Essentials', color: Color(0xFF0EA5E9), spent: 124, txns: 2, emoji: '🏠'),
  _CategoryItem(id: 'insurance', name: 'Insurance', group: 'Finance', color: Color(0xFF8B5CF6), spent: 210, txns: 1, emoji: '☂️'),
  _CategoryItem(id: 'loans', name: 'Loans', group: 'Finance', color: Color(0xFFCA8A04), spent: 85, txns: 1, emoji: '💰'),
  _CategoryItem(id: 'personal-care', name: 'Personal Care', group: 'Wellness', color: Color(0xFF78716C), spent: 36, txns: 2, emoji: '✂️'),
  _CategoryItem(id: 'pets', name: 'Pets', group: 'Family', color: Color(0xFFF97316), spent: 54, txns: 2, emoji: '🐶'),
  _CategoryItem(id: 'recreation', name: 'Recreation', group: 'Lifestyle', color: Color(0xFFEAB308), spent: 75, txns: 3, emoji: '🎫'),
  _CategoryItem(id: 'rent', name: 'Rent', group: 'Essentials', color: Color(0xFFE11D48), spent: 1450, txns: 1, emoji: '🔑'),
  _CategoryItem(id: 'restaurants', name: 'Restaurants', group: 'Lifestyle', color: Color(0xFFF59E0B), spent: 252.2, txns: 10, emoji: '🍔'),
  _CategoryItem(id: 'senior-care', name: 'Senior Care', group: 'Family', color: Color(0xFFA78BFA), spent: 63.5, txns: 2, emoji: '👵'),
  _CategoryItem(id: 'shops', name: 'Shops', group: 'Lifestyle', color: Color(0xFF7C3AED), spent: 145, txns: 5, emoji: '🛍️'),
  _CategoryItem(id: 'sports', name: 'Sports', group: 'Wellness', color: Color(0xFF10B981), spent: 60, txns: 2, emoji: '🚴'),
  _CategoryItem(id: 'transportation', name: 'Transportation', group: 'Essentials', color: Color(0xFF06B6D4), spent: 192.6, txns: 7, emoji: '🚌'),
  _CategoryItem(id: 'travel-vacation', name: 'Travel & Vacation', group: 'Lifestyle', color: Color(0xFF38BDF8), spent: 218, txns: 1, emoji: '🏖️'),
  _CategoryItem(id: 'utilities', name: 'Utilities', group: 'Essentials', color: Color(0xFF6366F1), spent: 168, txns: 4, emoji: '🔌'),
  _CategoryItem(id: 'yoga-pilates', name: 'Yoga & Pilates', group: 'Wellness', color: Color(0xFF14B8A6), spent: 50, txns: 2, emoji: '🧘'),
];

List<_CategoryRule> _seedRules(List<_CategoryItem> cats) {
  const seeds = <({String name, _RuleMatch match, String value})>[
    (name: 'Rent', match: _RuleMatch.merchantContains, value: 'Landlord'),
    (name: 'Rent', match: _RuleMatch.merchantContains, value: 'HOA'),
    (name: 'Home', match: _RuleMatch.merchantContains, value: 'Home Depot'),
    (name: 'Groceries', match: _RuleMatch.merchantContains, value: 'Whole Foods'),
    (name: 'Restaurants', match: _RuleMatch.merchantStarts, value: 'Starbucks'),
    (name: 'Entertainment', match: _RuleMatch.merchantEquals, value: 'Netflix'),
    (name: 'Entertainment', match: _RuleMatch.autoLabel, value: ''),
    (name: 'Transportation', match: _RuleMatch.merchantContains, value: 'Uber'),
    (name: 'Shops', match: _RuleMatch.merchantContains, value: 'Amazon'),
    (name: 'Healthcare', match: _RuleMatch.merchantContains, value: 'CVS'),
    (name: 'Travel & Vacation', match: _RuleMatch.merchantContains, value: 'Airbnb'),
    (name: 'Utilities', match: _RuleMatch.amountOver, value: '80'),
    (name: 'Car', match: _RuleMatch.memoContains, value: 'fuel'),
  ];
  final byName = {for (final c in cats) c.name: c.id};
  final rules = <_CategoryRule>[];
  for (var i = 0; i < seeds.length; i++) {
    final seed = seeds[i];
    final categoryId = byName[seed.name];
    if (categoryId == null) continue;
    rules.add(
      _CategoryRule(
        id: '$categoryId-r$i',
        match: seed.match,
        value: seed.value,
        categoryId: categoryId,
        priority: i + 1,
        applyTo: seed.match == _RuleMatch.autoLabel
            ? _RuleApplyTo.uncategorized
            : _RuleApplyTo.neu,
      ),
    );
  }
  return rules;
}

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, this.onOpenCategory});

  final ValueChanged<String>? onOpenCategory;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late List<_CategoryItem> _categories;
  late List<_CategoryRule> _rules;
  late List<String> _groups;
  final _query = TextEditingController();
  String _groupFilter = 'all';
  List<FilterRule> _filterRules = [];
  List<SortRule> _sortRules = [];
  bool _gridView = true;
  bool _spendMixOpen = false;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  CategoriesController? _ctrl;
  var _syncedSpaceId = '';

  String get _monthKey =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  String get _monthLabel {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[_month.month - 1]} ${_month.year}';
  }

  @override
  void initState() {
    super.initState();
    _categories = [];
    _rules = [];
    _groups = [..._defaultGroups];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = CategoriesScope.of(context);
    if (!identical(_ctrl, ctrl)) {
      _ctrl?.removeListener(_onCtrlChanged);
      _ctrl = ctrl;
      _ctrl!.addListener(_onCtrlChanged);
    }
    _syncFromController();
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onCtrlChanged);
    _query.dispose();
    super.dispose();
  }

  void _onCtrlChanged() {
    if (!mounted) return;
    _syncFromController();
  }

  void _syncFromController() {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    // Keep local edits (archive/budget/group) when same space & same ids when possible
    final records = ctrl.categories;
    final byId = {for (final c in _categories) c.id: c};
    final next = <_CategoryItem>[
      for (final r in records)
        byId[r.id]?.copy() ??
            _CategoryItem(
              id: r.id,
              name: r.name,
              group: r.group,
              color: r.color,
              spent: r.spent,
              txns: r.txns,
              emoji: r.emoji,
            ),
    ];
    // If space changed, drop local overlays
    if (ctrl.spaceId != _syncedSpaceId) {
      _syncedSpaceId = ctrl.spaceId;
      for (var i = 0; i < next.length; i++) {
        final r = records[i];
        next[i] = _CategoryItem(
          id: r.id,
          name: r.name,
          group: r.group,
          color: r.color,
          spent: r.spent,
          txns: r.txns,
          emoji: r.emoji,
        );
      }
    } else {
      // Refresh spent/txns/name from API while keeping local group/color/emoji/hidden/budgets
      for (var i = 0; i < next.length; i++) {
        final r = records[i];
        final local = byId[r.id];
        if (local == null) continue;
        next[i] = _CategoryItem(
          id: r.id,
          name: r.name,
          group: local.group,
          color: local.color,
          spent: r.spent,
          txns: r.txns,
          emoji: local.emoji,
          hidden: local.hidden,
          defaultBudget: local.defaultBudget,
          monthlyBudgets: Map<String, double>.from(local.monthlyBudgets),
        );
      }
    }
    setState(() {
      _categories = next;
      _rules = _seedRules(next);
      _groups = {
        ..._defaultGroups,
        ..._categories.map((c) => c.group),
      }.toList()
        ..sort();
    });
  }

  List<String> get _allGroups => {
        ..._groups,
        ..._categories.map((c) => c.group),
      }.toList()
        ..sort();

  Future<void> _openGroupsManager() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final groups = {
              ..._groups,
              ..._categories.map((c) => c.group),
            }.toList()
              ..sort();
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Groups',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Create or rename sections for your categories.',
                      style: TextStyle(color: AppColors.mute, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: groups.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: AppColors.line),
                        itemBuilder: (_, i) {
                          final g = groups[i];
                          final count =
                              _categories.where((c) => c.group == g).length;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              g,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            subtitle: Text(
                              '$count categor${count == 1 ? 'y' : 'ies'}',
                              style: const TextStyle(
                                color: AppColors.mute,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    final next = await _promptGroupName(
                                      ctx,
                                      initial: g,
                                    );
                                    if (next == null) return;
                                    if (!_renameGroup(g, next)) return;
                                    setModal(() {});
                                    setState(() {});
                                  },
                                  child: const Text('Edit'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _deleteGroup(g);
                                    setModal(() {});
                                    setState(() {});
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFC53030),
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Done'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () async {
                            final next = await _promptGroupName(ctx);
                            if (next == null) return;
                            if (!_createGroup(next)) return;
                            setModal(() {});
                            setState(() {});
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brand,
                          ),
                          child: const Text('New group'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _promptGroupName(
    BuildContext context, {
    String? initial,
  }) async {
    final ctrl = TextEditingController(text: initial ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial == null ? 'New group' : 'Edit group'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
            child: Text(initial == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
    final value = ctrl.text.trim();
    ctrl.dispose();
    if (saved != true || value.isEmpty) return null;
    return value;
  }

  bool _createGroup(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    if (_allGroups.any((g) => g.toLowerCase() == trimmed.toLowerCase())) {
      toast(context, 'Group already exists');
      return false;
    }
    setState(() {
      _groups = [..._groups, trimmed]..sort();
    });
    toast(context, 'Group created');
    return true;
  }

  bool _renameGroup(String from, String to) {
    final trimmed = to.trim();
    if (trimmed.isEmpty || trimmed == from) return false;
    if (_allGroups.any(
      (g) => g.toLowerCase() == trimmed.toLowerCase() && g != from,
    )) {
      toast(context, 'Group already exists');
      return false;
    }
    setState(() {
      _groups = [
        for (final g in _groups) g == from ? trimmed : g,
      ];
      if (!_groups.contains(trimmed)) _groups.add(trimmed);
      _groups = {..._groups}.toList()..sort();
      for (final c in _categories) {
        if (c.group == from) c.group = trimmed;
      }
      if (_groupFilter == from) _groupFilter = trimmed;
    });
    toast(context, 'Group updated');
    return true;
  }

  void _deleteGroup(String name) {
    final fallback = name == 'Other' ? 'Essentials' : 'Other';
    final target = _allGroups.contains(fallback)
        ? fallback
        : _allGroups.firstWhere((g) => g != name, orElse: () => 'Other');
    setState(() {
      _groups = _groups.where((g) => g != name).toList();
      if (!_groups.contains(target)) _groups.add(target);
      _groups.sort();
      for (final c in _categories) {
        if (c.group == name) c.group = target;
      }
      if (_groupFilter == name) _groupFilter = 'all';
    });
    toast(context, 'Moved categories to $target');
  }

  List<String> _selectOptions(String field) {
    if (field == 'group') return [..._allGroups];
    return [];
  }

  List<_CategoryItem> _applyFilterSort(List<_CategoryItem> base) {
    final searched = applySearch(
      base,
      _query.text,
      _categoryFilterFields,
      _categoryValue,
    );
    final filtered = applyFilters(searched, _filterRules, _categoryValue);
    return applySort(filtered, _sortRules, _categoryValue);
  }

  List<_CategoryItem> get _activeVisible {
    final base = _categories.where((c) {
      if (c.hidden) return false;
      if (_groupFilter != 'all' && c.group != _groupFilter) return false;
      return true;
    }).toList();
    return _applyFilterSort(base);
  }

  List<_CategoryItem> get _archivedVisible {
    final base = _categories.where((c) {
      if (!c.hidden) return false;
      if (_groupFilter != 'all' && c.group != _groupFilter) return false;
      return true;
    }).toList();
    return _applyFilterSort(base);
  }

  double get _totalSpend => _categories
      .where((c) => !c.hidden && c.group != 'Income')
      .fold<double>(0, (s, c) => s + c.spent);

  int get _activeCount => _categories.where((c) => !c.hidden).length;
  int get _archivedCount => _categories.where((c) => c.hidden).length;

  Future<void> _importDefaults() async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final names = _categories.map((c) => c.name.toLowerCase()).toSet();
    var added = 0;
    for (final d in _defaults) {
      if (names.contains(d.name.toLowerCase())) continue;
      final type = d.group == 'Income' ? 'income' : 'expense';
      final created = await ctrl.create(name: d.name, type: type);
      if (created != null) added++;
      names.add(d.name.toLowerCase());
    }
    if (!mounted) return;
    toast(
      context,
      added > 0
          ? 'Added $added default categor${added == 1 ? 'y' : 'ies'}'
          : 'Defaults already imported',
    );
  }

  Future<void> _openEditor({_CategoryItem? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    var group = existing?.group ?? _groups.first;
    var color = existing?.color ?? _palette.first;
    var emoji = existing?.emoji ?? '🏷️';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existing == null ? 'New category' : 'Edit category',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Name',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.mute,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () async {
                            final picked = await _pickEmoji(ctx, emoji);
                            if (picked != null) {
                              setModal(() => emoji = picked);
                            }
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Pets',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: group,
                    decoration: const InputDecoration(
                      labelText: 'Group',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final g in _allGroups)
                        DropdownMenuItem(value: g, child: Text(g)),
                    ],
                    onChanged: (v) => setModal(() => group = v ?? group),
                  ),
                  TextButton(
                    onPressed: () async {
                      final next = await _promptGroupName(ctx);
                      if (next == null) return;
                      if (!_createGroup(next)) return;
                      setModal(() => group = next);
                    },
                    child: const Text('New group'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Color',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.mute,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final c in _palette)
                        GestureDetector(
                          onTap: () => setModal(() => color = c),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == c
                                    ? AppColors.ink
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GhostButton(
                          label: 'Cancel',
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AccentButton(
                          label: existing == null ? 'Create' : 'Save',
                          onPressed: () {
                            if (nameCtrl.text.trim().isEmpty) {
                              toast(ctx, requiredText(nameCtrl.text, 'Name')!);
                              return;
                            }
                            Navigator.pop(ctx, true);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (saved != true || !mounted) return;
    final name = nameCtrl.text.trim();
    final clash = _categories.any(
      (c) =>
          c.id != existing?.id && c.name.toLowerCase() == name.toLowerCase(),
    );
    if (clash) {
      toast(context, 'Name already used');
      return;
    }
    final ctrl = _ctrl;
    if (existing == null) {
      final type = group == 'Income' ? 'income' : 'expense';
      final created = await ctrl?.create(name: name, type: type);
      if (!mounted) return;
      if (created == null) {
        toast(context, 'Could not create category');
        return;
      }
      setState(() {
        for (final item in _categories) {
          if (item.id == created.id) {
            item
              ..group = group
              ..color = color
              ..emoji = emoji;
            break;
          }
        }
      });
      toast(context, 'Category created');
    } else {
      final ok = await ctrl?.rename(existing.id, name) ?? false;
      if (!mounted) return;
      if (!ok) {
        toast(context, 'Could not update category');
        return;
      }
      setState(() {
        existing
          ..name = name
          ..group = group
          ..color = color
          ..emoji = emoji;
      });
      toast(context, 'Category updated');
    }
  }

  Future<String?> _pickEmoji(BuildContext parentCtx, String current) async {
    const options = [
      '🏷️', '💰', '💵', '💳', '🏦', '🔑', '🏠', '🔌', '🚗', '🚌', '⛽', '🛒',
      '🥑', '🍔', '☕', '🛍️', '👕', '💄', '🐶', '💊', '☂️', '📘', '🎟️', '🏖️',
      '🧘', '👟', '🚴', '✂️', '🎫', '🤝', '💃', '🚸', '👵', '💼', '📈', '🧾',
      '😀', '😍', '🔥', '⭐️', '🎯', '✈️', '🎁', '📱', '💡', '❤️', '🎉', '✅',
    ];
    return showModalBottomSheet<String>(
      context: parentCtx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose emoji',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: options.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemBuilder: (_, i) {
                    final e = options[i];
                    final selected = e == current;
                    return Material(
                      color: selected
                          ? AppColors.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.pop(ctx, e),
                        child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _merge(_CategoryItem source) async {
    final targets =
        _categories.where((c) => c.id != source.id && !c.hidden).toList();
    if (targets.isEmpty) {
      toast(context, 'Need another category to merge into');
      return;
    }
    var targetId = targets.first.id;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Merge ${source.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: targetId,
                    decoration: const InputDecoration(
                      labelText: 'Merge into',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final t in targets)
                        DropdownMenuItem(
                          value: t.id,
                          child: Text('${t.name} (${t.group})'),
                        ),
                    ],
                    onChanged: (v) => setModal(() => targetId = v ?? targetId),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GhostButton(
                          label: 'Cancel',
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AccentButton(
                          label: 'Merge',
                          onPressed: () => Navigator.pop(ctx, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;
    final target = _categories.firstWhere((c) => c.id == targetId);
    setState(() {
      target.spent += source.spent;
      target.txns += source.txns;
      _categories.removeWhere((c) => c.id == source.id);
      for (final r in _rules) {
        if (r.categoryId == source.id) r.categoryId = target.id;
      }
    });
    toast(context, '${source.name} merged into ${target.name}');
  }

  Future<void> _openRules() async {
    var match = _RuleMatch.merchantContains;
    final valueCtrl = TextEditingController();
    var categoryId =
        _categories.where((c) => !c.hidden).firstOrNull?.id ?? '';
    var applyTo = _RuleApplyTo.neu;
    var priority = (_rules.isEmpty
            ? 1
            : _rules.map((r) => r.priority).reduce((a, b) => a > b ? a : b) + 1)
        .toString();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
            final visibleCats = _categories.where((c) => !c.hidden).toList();
            final sorted = [..._rules]
              ..sort((a, b) => a.priority.compareTo(b.priority));
            final needsValue = _matchNeedsValue(match);
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
              child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * 0.82,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category rules',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Match merchants, memos, amounts, or enable AI auto-label.',
                      style: TextStyle(color: AppColors.mute, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<_RuleMatch>(
                      initialValue: match,
                      decoration: const InputDecoration(
                        labelText: 'When',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final m in _RuleMatch.values)
                          DropdownMenuItem(
                            value: m,
                            child: Text(_matchLabel(m)),
                          ),
                      ],
                      onChanged: (v) => setModal(() {
                        match = v ?? match;
                        if (match == _RuleMatch.autoLabel) {
                          valueCtrl.clear();
                          applyTo = _RuleApplyTo.uncategorized;
                        }
                      }),
                    ),
                    if (needsValue) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: valueCtrl,
                        decoration: InputDecoration(
                          labelText: match == _RuleMatch.amountOver ||
                                  match == _RuleMatch.amountUnder
                              ? 'Amount'
                              : 'Match value',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: const Text(
                          'AI suggests a label from merchant + memo when nothing else matches.',
                          style: TextStyle(
                            color: AppColors.mute,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: visibleCats.any((c) => c.id == categoryId)
                          ? categoryId
                          : visibleCats.firstOrNull?.id,
                      decoration: const InputDecoration(
                        labelText: 'Assign to',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final c in visibleCats)
                          DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.emoji} ${c.name}'),
                          ),
                      ],
                      onChanged: (v) =>
                          setModal(() => categoryId = v ?? categoryId),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<_RuleApplyTo>(
                            initialValue: applyTo,
                            decoration: const InputDecoration(
                              labelText: 'Apply to',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final a in _RuleApplyTo.values)
                                DropdownMenuItem(
                                  value: a,
                                  child: Text(_applyLabel(a)),
                                ),
                            ],
                            onChanged: match == _RuleMatch.autoLabel
                                ? null
                                : (v) =>
                                    setModal(() => applyTo = v ?? applyTo),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 88,
                          child: TextFormField(
                            initialValue: priority,
                            decoration: const InputDecoration(
                              labelText: 'Priority',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => priority = v,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AccentButton(
                      label: 'Add rule',
                      onPressed: () {
                        if (categoryId.isEmpty) return;
                        if (needsValue && valueCtrl.text.trim().isEmpty) return;
                        final p = int.tryParse(priority) ?? _rules.length + 1;
                        setState(() {
                          _rules.insert(
                            0,
                            _CategoryRule(
                              id: 'r-${DateTime.now().millisecondsSinceEpoch}',
                              match: match,
                              value: needsValue ? valueCtrl.text.trim() : '',
                              categoryId: categoryId,
                              priority: p,
                              applyTo: match == _RuleMatch.autoLabel
                                  ? _RuleApplyTo.uncategorized
                                  : applyTo,
                            ),
                          );
                        });
                        setModal(() {
                          valueCtrl.clear();
                          priority = '${p + 1}';
                          if (match == _RuleMatch.autoLabel) {
                            match = _RuleMatch.merchantContains;
                          }
                        });
                        toast(context, 'Rule added');
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: sorted.isEmpty
                          ? const Center(
                              child: Text(
                                'No rules yet',
                                style: TextStyle(color: AppColors.mute),
                              ),
                            )
                          : ListView.separated(
                              itemCount: sorted.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final r = sorted[i];
                                final cat = _categories
                                    .where((c) => c.id == r.categoryId)
                                    .firstOrNull;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    _ruleHeadline(r),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: r.enabled
                                          ? AppColors.ink
                                          : AppColors.mute,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '→ ${cat?.name ?? 'Unknown'} · ${_applyLabel(r.applyTo)} · P${r.priority}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Switch.adaptive(
                                        value: r.enabled,
                                        onChanged: (v) {
                                          setState(() => r.enabled = v);
                                          setModal(() {});
                                        },
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() => _rules.remove(r));
                                          setModal(() {});
                                        },
                                        child: const Text(
                                          'Remove',
                                          style: TextStyle(
                                            color: Color(0xFFCC4444),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _rowActions(_CategoryItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.hidden)
                ListTile(
                  title: const Text('Restore'),
                  onTap: () => Navigator.pop(ctx, 'hide'),
                )
              else ...[
                ListTile(
                  title: const Text('Edit'),
                  onTap: () => Navigator.pop(ctx, 'edit'),
                ),
                ListTile(
                  title: const Text('Set budget'),
                  onTap: () => Navigator.pop(ctx, 'budget'),
                ),
                ListTile(
                  title: const Text('Merge into…'),
                  onTap: () => Navigator.pop(ctx, 'merge'),
                ),
                ListTile(
                  title: const Text('Archive'),
                  onTap: () => Navigator.pop(ctx, 'hide'),
                ),
              ],
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _openEditor(existing: item);
      return;
    }
    if (action == 'budget') {
      await _openBudget(item);
      return;
    }
    if (action == 'merge') {
      await _merge(item);
      return;
    }
    if (action == 'hide') {
      setState(() => item.hidden = !item.hidden);
      toast(context, item.hidden ? 'Category archived' : 'Category restored');
    }
  }

  Future<void> _openBudget(_CategoryItem item) async {
    final commonCtrl = TextEditingController(
      text: item.defaultBudget > 0 ? item.defaultBudget.toStringAsFixed(0) : '',
    );
    final hasOverride = item.monthlyBudgets.containsKey(_monthKey);
    final monthCtrl = TextEditingController(
      text: hasOverride
          ? item.monthlyBudgets[_monthKey]!.toStringAsFixed(0)
          : '',
    );
    var useOverride = hasOverride;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budget · ${item.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commonCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'General budget (every month)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: useOverride,
                    onChanged: (v) =>
                        setModal(() => useOverride = v ?? false),
                    title: Text('Override for $_monthLabel'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (useOverride)
                    TextField(
                      controller: monthCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '$_monthLabel budget',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: GhostButton(
                          label: 'Cancel',
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AccentButton(
                          label: 'Save',
                          onPressed: () => Navigator.pop(ctx, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (saved != true || !mounted) return;
    setState(() {
      item.defaultBudget = double.tryParse(commonCtrl.text) ?? 0;
      if (useOverride) {
        item.monthlyBudgets[_monthKey] = double.tryParse(monthCtrl.text) ?? 0;
      } else {
        item.monthlyBudgets.remove(_monthKey);
      }
    });
    toast(context, 'Budget saved for ${item.name}');
  }

  @override
  Widget build(BuildContext context) {
    final activeVisible = _activeVisible;
    final archivedVisible = _archivedVisible;
    final spendRows = _categories
        .where((c) => !c.hidden && c.group != 'Income')
        .toList()
      ..sort((a, b) => b.spent.compareTo(a.spent));
    final total = _totalSpend;
    final names = {for (final c in _categories) c.name.toLowerCase()};
    final needsImport =
        _defaults.any((d) => !names.contains(d.name.toLowerCase()));
    final grouped = <String, List<_CategoryItem>>{};
    for (final c in activeVisible) {
      grouped.putIfAbsent(c.group, () => []).add(c);
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: const Text(
          'Categories',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          DashPageHeader(
            title: 'Categories',
            subtitle: 'Labels, monthly budgets, and flexible rules',
            actions: [
              GhostButton(
                label: _monthLabel.split(' ').first,
                onPressed: () async {
                  final next = await showDatePicker(
                    context: context,
                    initialDate: _month,
                    firstDate: DateTime(2025, 1),
                    lastDate: DateTime(2027, 12),
                    helpText: 'Pick a month',
                  );
                  if (next != null) {
                    setState(() => _month = DateTime(next.year, next.month, 1));
                  }
                },
              ),
              GhostButton(label: 'Groups', onPressed: _openGroupsManager),
              GhostButton(label: 'Rules', onPressed: _openRules),
              AccentButton(
                label: 'New category',
                onPressed: SpacesScope.maybeOf(context)
                            ?.can('categories', 'write') ==
                        false
                    ? null
                    : () => _openEditor(),
              ),
            ],
          ),
          if (_ctrl?.loading == true)
            const DashLoadingBody(kpiCount: 4, listRows: 6)
          else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    _monthLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month + 1),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: FilterSortBar(
              fields: _categoryFilterFields,
              rules: _filterRules,
              sorts: _sortRules,
              selectOptions: _selectOptions,
              defaultFilterField: 'group',
              defaultSortField: 'name',
              search: _query.text,
              onSearchChanged: (v) {
                _query.text = v;
                setState(() {});
              },
              searchHint: 'Search categories…',
              onRulesChanged: (rules) => setState(() => _filterRules = rules),
              onSortsChanged: (sorts) => setState(() => _sortRules = sorts),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: DashKpi(
                    label: 'Active',
                    value: _archivedCount > 0
                        ? '$_activeCount · $_archivedCount archived'
                        : '$_activeCount',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DashKpi(
                    label: 'Budget',
                    value: moneyWhole(
                      _categories
                          .where((c) => !c.hidden && c.group != 'Income')
                          .fold<double>(
                            0,
                            (s, c) => s + c.budgetFor(_monthKey),
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DashKpi(
                    label: 'Spent',
                    value: moneyWhole(_totalSpend),
                  ),
                ),
              ],
            ),
          ),
          if (spendRows.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DashPanel(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () =>
                            setState(() => _spendMixOpen = !_spendMixOpen),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Spend mix',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        AnimatedRotation(
                                          turns: _spendMixOpen ? 0.5 : 0,
                                          duration:
                                              const Duration(milliseconds: 180),
                                          child: const Icon(
                                            Icons.expand_more_rounded,
                                            size: 18,
                                            color: AppColors.mute,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Share of tagged spend · $_monthLabel',
                                      style: const TextStyle(
                                        color: AppColors.mute,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                moneyWhole(total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            height: 10,
                            child: Row(
                              children: [
                                for (final c in spendRows)
                                  if (total > 0 && c.spent / total >= 0.004)
                                    Expanded(
                                      flex: (c.spent / total * 1000)
                                          .round()
                                          .clamp(1, 1000),
                                      child: Tooltip(
                                        message:
                                            '${c.name} · ${((c.spent / total) * 100).round()}%',
                                        child: ColoredBox(color: c.color),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_spendMixOpen) ...[
                        const SizedBox(height: 12),
                        for (final c in spendRows)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                            child: Row(
                              children: [
                                Text(c.emoji,
                                    style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  total > 0
                                      ? '${((c.spent / total) * 100).round()}%'
                                      : '0%',
                                  style: const TextStyle(
                                    color: AppColors.mute,
                                    fontSize: 12,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DashPanel(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _groupFilter,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: 'all',
                                    child: Text('All groups'),
                                  ),
                                  for (final g in _allGroups)
                                    DropdownMenuItem(
                                      value: g,
                                      child: Text(g),
                                    ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _groupFilter = v ?? 'all'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.line),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _ViewToggle(
                                    icon: Icons.grid_view_rounded,
                                    selected: _gridView,
                                    onTap: () =>
                                        setState(() => _gridView = true),
                                  ),
                                  _ViewToggle(
                                    icon: Icons.view_list_rounded,
                                    selected: !_gridView,
                                    onTap: () =>
                                        setState(() => _gridView = false),
                                  ),
                                ],
                              ),
                            ),
                            if (needsImport) ...[
                              const SizedBox(width: 8),
                              LinkAction(
                                label: 'Import',
                                onTap: _importDefaults,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (activeVisible.isEmpty && archivedVisible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Column(
                        children: [
                          Text(
                            _categories.isEmpty
                                ? 'No categories yet'
                                : 'No categories match',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_categories.isEmpty)
                            needsImport
                                ? AccentButton(
                                    label: 'Import defaults',
                                    onPressed: SpacesScope.maybeOf(context)
                                                ?.can('categories', 'write') ==
                                            false
                                        ? null
                                        : _importDefaults,
                                  )
                                : GhostButton(
                                    label: 'New category',
                                    onPressed: SpacesScope.maybeOf(context)
                                                ?.can('categories', 'write') ==
                                            false
                                        ? null
                                        : () => _openEditor(),
                                  )
                          else
                            GhostButton(
                              label: 'Clear filters',
                              onPressed: () => setState(() {
                                _query.clear();
                                _groupFilter = 'all';
                                _filterRules = [];
                                _sortRules = [];
                              }),
                            ),
                        ],
                      ),
                    )
                  else ...[
                    for (final entry in grouped.entries) ...[
                      Container(
                        width: double.infinity,
                        color: AppColors.surface,
                        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: AppColors.mute,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final next = await _promptGroupName(
                                  context,
                                  initial: entry.key,
                                );
                                if (next == null) return;
                                _renameGroup(entry.key, next);
                              },
                              child: const Text('Edit'),
                            ),
                          ],
                        ),
                      ),
                      if (_gridView)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cols = constraints.maxWidth > 520 ? 3 : 2;
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: entry.value.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 1.15,
                                ),
                                itemBuilder: (_, i) {
                                  final item = entry.value[i];
                                  return _CategoryTile(
                                    item: item,
                                    monthKey: _monthKey,
                                    ruleCount: _rules
                                        .where((r) => r.categoryId == item.id)
                                        .length,
                                    share: total > 0 && item.group != 'Income'
                                        ? (item.spent / total * 100).round()
                                        : null,
                                    showDivider: false,
                                    grid: true,
                                    onOpen: () => widget.onOpenCategory?.call(item.name),
                                    onEdit: () => _rowActions(item),
                                  );
                                },
                              );
                            },
                          ),
                        )
                      else
                        for (var i = 0; i < entry.value.length; i++)
                          _CategoryTile(
                            item: entry.value[i],
                            monthKey: _monthKey,
                            ruleCount: _rules
                                .where((r) => r.categoryId == entry.value[i].id)
                                .length,
                            share: total > 0 && entry.value[i].group != 'Income'
                                ? (entry.value[i].spent / total * 100).round()
                                : null,
                            showDivider: i < entry.value.length - 1,
                            grid: false,
                            onOpen: () => widget.onOpenCategory
                                ?.call(entry.value[i].name),
                            onEdit: () => _rowActions(entry.value[i]),
                          ),
                    ],
                    if (archivedVisible.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        color: AppColors.surface,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: const Text(
                          'ARCHIVED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.mute,
                          ),
                        ),
                      ),
                      if (_gridView)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cols = constraints.maxWidth > 520 ? 3 : 2;
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: archivedVisible.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 1.15,
                                ),
                                itemBuilder: (_, i) {
                                  final item = archivedVisible[i];
                                  return _CategoryTile(
                                    item: item,
                                    monthKey: _monthKey,
                                    ruleCount: _rules
                                        .where((r) => r.categoryId == item.id)
                                        .length,
                                    share: total > 0 && item.group != 'Income'
                                        ? (item.spent / total * 100).round()
                                        : null,
                                    showDivider: false,
                                    grid: true,
                                    onOpen: () => widget.onOpenCategory?.call(item.name),
                                    onEdit: () => _rowActions(item),
                                  );
                                },
                              );
                            },
                          ),
                        )
                      else
                        for (var i = 0; i < archivedVisible.length; i++)
                          _CategoryTile(
                            item: archivedVisible[i],
                            monthKey: _monthKey,
                            ruleCount: _rules
                                .where(
                                  (r) =>
                                      r.categoryId == archivedVisible[i].id,
                                )
                                .length,
                            share: total > 0 &&
                                    archivedVisible[i].group != 'Income'
                                ? (archivedVisible[i].spent / total * 100)
                                    .round()
                                : null,
                            showDivider: i < archivedVisible.length - 1,
                            grid: false,
                            onOpen: () => widget.onOpenCategory?.call(archivedVisible[i].name),
                            onEdit: () => _rowActions(archivedVisible[i]),
                          ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 16,
            color: selected ? Colors.white : AppColors.mute,
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.item,
    required this.monthKey,
    required this.ruleCount,
    required this.share,
    required this.showDivider,
    required this.onEdit,
    this.onOpen,
    this.grid = false,
  });

  final _CategoryItem item;
  final String monthKey;
  final int ruleCount;
  final int? share;
  final bool showDivider;
  final bool grid;
  final VoidCallback onEdit;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final budget = item.budgetFor(monthKey);
    final meta = [
      '${item.txns} txns',
      if (ruleCount > 0) '$ruleCount rules',
      if (share != null) '$share%',
    ].join(' · ');
    final over = budget > 0 && item.spent > budget;
    final pct = budget > 0
        ? ((item.spent / budget) * 100).round().clamp(0, 100)
        : 0;

    final progress = budget > 0
        ? Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 4,
                backgroundColor: AppColors.surface,
                color: over ? const Color(0xFFC53030) : item.color,
              ),
            ),
          )
        : const SizedBox.shrink();

    if (grid) {
      return Opacity(
        opacity: item.hidden ? 0.6 : 1,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onEdit,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.more_horiz_rounded, size: 18),
                        color: AppColors.mute,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.mute,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    budget > 0
                        ? '${moneyWhole(item.spent)} / ${moneyWhole(budget)}'
                        : moneyWhole(item.spent),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  progress,
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: item.hidden ? 0.6 : 1,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onOpen,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              border: showDivider
                  ? const Border(bottom: BorderSide(color: AppColors.line))
                  : null,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(item.emoji, style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (item.hidden) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Archived',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.mute,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              '${item.txns} transactions',
                              if (ruleCount > 0) '$ruleCount rules',
                              if (share != null) '$share% of spend',
                            ].join(' · '),
                            style: const TextStyle(
                              color: AppColors.mute,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          budget > 0
                              ? '${moneyWhole(item.spent)} / ${moneyWhole(budget)}'
                              : moneyWhole(item.spent),
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          budget <= 0
                              ? 'No budget'
                              : item.monthlyBudgets.containsKey(monthKey)
                                  ? 'Month override'
                                  : 'General budget',
                          style: const TextStyle(
                            color: AppColors.mute,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.more_horiz_rounded, size: 20),
                      color: AppColors.mute,
                    ),
                  ],
                ),
                progress,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
