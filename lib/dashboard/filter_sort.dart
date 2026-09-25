import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'dash_colors.dart';
import 'ui.dart';

enum FilterFieldType { text, number, select, date }

class FilterFieldDef {
  const FilterFieldDef({
    required this.id,
    required this.label,
    required this.type,
  });

  final String id;
  final String label;
  final FilterFieldType type;
}

class FilterRule {
  FilterRule({
    required this.id,
    required this.field,
    required this.operator,
    required this.value,
    this.junction = 'and',
  });

  final String id;
  String field;
  String operator;
  String value;
  String junction;
}

class SortRule {
  SortRule({
    required this.id,
    required this.field,
    this.direction = 'desc',
  });

  final String id;
  String field;
  String direction;
}

String newRuleId() =>
    'r-${DateTime.now().microsecondsSinceEpoch}-${UniqueKey().hashCode}';

const _textOps = [
  ('contains', 'contains'),
  ('is', 'is'),
  ('is_not', 'is not'),
];

const _numberOps = [
  ('eq', '='),
  ('gt', '>'),
  ('lt', '<'),
  ('gte', '≥'),
  ('lte', '≤'),
];

const _selectOps = [
  ('is', 'is'),
  ('is_not', 'is not'),
];

List<(String, String)> opsFor(FilterFieldType type) {
  switch (type) {
    case FilterFieldType.number:
      return _numberOps;
    case FilterFieldType.select:
      return _selectOps;
    case FilterFieldType.text:
    case FilterFieldType.date:
      return _textOps;
  }
}

FilterFieldDef fieldMeta(List<FilterFieldDef> fields, String id) {
  return fields.firstWhere((f) => f.id == id, orElse: () => fields.first);
}

bool matchRule<T>(
  T item,
  FilterRule rule,
  Object? Function(T item, String field) getValue,
) {
  final raw = getValue(item, rule.field);
  final text = '$raw';
  final needle = rule.value.trim();
  final lower = text.toLowerCase();
  final nLower = needle.toLowerCase();
  switch (rule.operator) {
    case 'contains':
      return lower.contains(nLower);
    case 'is':
      return lower == nLower;
    case 'is_not':
      return lower != nLower;
    case 'eq':
      return num.tryParse(text) == num.tryParse(needle);
    case 'gt':
      return (num.tryParse(text) ?? 0) > (num.tryParse(needle) ?? 0);
    case 'lt':
      return (num.tryParse(text) ?? 0) < (num.tryParse(needle) ?? 0);
    case 'gte':
      return (num.tryParse(text) ?? 0) >= (num.tryParse(needle) ?? 0);
    case 'lte':
      return (num.tryParse(text) ?? 0) <= (num.tryParse(needle) ?? 0);
    default:
      return true;
  }
}

List<T> applyFilters<T>(
  List<T> items,
  List<FilterRule> rules,
  Object? Function(T item, String field) getValue,
) {
  if (rules.isEmpty) return items;
  return items.where((item) {
    var ok = matchRule(item, rules.first, getValue);
    for (var i = 1; i < rules.length; i++) {
      final rule = rules[i];
      final hit = matchRule(item, rule, getValue);
      ok = rule.junction == 'or' ? (ok || hit) : (ok && hit);
    }
    return ok;
  }).toList();
}

/// Case-insensitive match across all filterable field values.
List<T> applySearch<T>(
  List<T> items,
  String query,
  List<FilterFieldDef> fields,
  Object? Function(T item, String field) getValue,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return items;
  return items.where((item) {
    return fields.any((f) {
      final raw = getValue(item, f.id);
      return '$raw'.toLowerCase().contains(q);
    });
  }).toList();
}

List<T> applySort<T>(
  List<T> items,
  List<SortRule> sorts,
  Object? Function(T item, String field) getValue,
) {
  if (sorts.isEmpty) return items;
  final copy = [...items];
  copy.sort((a, b) {
    for (final sort in sorts) {
      final av = getValue(a, sort.field);
      final bv = getValue(b, sort.field);
      int cmp;
      if (av is num && bv is num) {
        cmp = av.compareTo(bv);
      } else {
        cmp = '$av'.compareTo('$bv');
      }
      if (cmp != 0) return sort.direction == 'asc' ? cmp : -cmp;
    }
    return 0;
  });
  return copy;
}

class FilterSortBar extends StatelessWidget {
  const FilterSortBar({
    super.key,
    required this.fields,
    required this.rules,
    required this.sorts,
    required this.onRulesChanged,
    required this.onSortsChanged,
    this.selectOptions,
    this.defaultFilterField,
    this.defaultSortField,
    this.search = '',
    this.onSearchChanged,
    this.searchHint = 'Search…',
    this.showStats,
    this.onShowStatsChanged,
    this.iconButtons = false,
    this.expandSearch = false,
  });

  final List<FilterFieldDef> fields;
  final List<FilterRule> rules;
  final List<SortRule> sorts;
  final ValueChanged<List<FilterRule>> onRulesChanged;
  final ValueChanged<List<SortRule>> onSortsChanged;
  final List<String> Function(String field)? selectOptions;
  final String? defaultFilterField;
  final String? defaultSortField;
  final String search;
  final ValueChanged<String>? onSearchChanged;
  final String searchHint;
  final bool? showStats;
  final ValueChanged<bool>? onShowStatsChanged;
  /// Web-style filter/sort icons with count badges (instead of GhostButtons).
  final bool iconButtons;
  /// Stretch the search field across remaining width (Row + Expanded).
  final bool expandSearch;

  @override
  Widget build(BuildContext context) {
    final statsVisible = showStats;
    final onStats = onShowStatsChanged;
    final actions = <Widget>[
      if (iconButtons) ...[
        _FilterSortIconButton(
          tooltip: rules.isEmpty ? 'Filter' : 'Filter · ${rules.length}',
          icon: Icons.filter_list_rounded,
          active: rules.isNotEmpty,
          badge: rules.isEmpty ? null : rules.length,
          onPressed: () => _openFilters(context),
        ),
        _FilterSortIconButton(
          tooltip: sorts.isEmpty ? 'Sort' : 'Sort · ${sorts.length}',
          icon: Icons.swap_vert_rounded,
          active: sorts.isNotEmpty,
          badge: sorts.isEmpty ? null : sorts.length,
          onPressed: () => _openSorts(context),
        ),
      ] else ...[
        GhostButton(
          label: rules.isEmpty ? 'Filter' : 'Filter · ${rules.length}',
          onPressed: () => _openFilters(context),
          foregroundColor: rules.isNotEmpty ? AppColors.brandDark : null,
        ),
        GhostButton(
          label: sorts.isEmpty ? 'Sort' : 'Sort · ${sorts.length}',
          onPressed: () => _openSorts(context),
          foregroundColor: sorts.isNotEmpty ? AppColors.brandDark : null,
        ),
      ],
      if (statsVisible != null && onStats != null)
        IconButton(
          onPressed: () => onStats(!statsVisible),
          tooltip: statsVisible ? 'Hide stats' : 'Show stats',
          icon: Icon(
            Icons.speed_outlined,
            size: 18,
            color: statsVisible ? AppColors.brandDark : context.dashMute,
          ),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        ),
    ];

    if (expandSearch && onSearchChanged != null) {
      return Row(
        children: [
          Expanded(
            child: _TableSearchField(
              value: search,
              hint: searchHint,
              onChanged: onSearchChanged!,
            ),
          ),
          const SizedBox(width: 4),
          ...actions,
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (onSearchChanged != null)
          SizedBox(
            width: MediaQuery.sizeOf(context).width < 360 ? 140 : 180,
            child: _TableSearchField(
              value: search,
              hint: searchHint,
              onChanged: onSearchChanged!,
            ),
          ),
        ...actions,
      ],
    );
  }

  Future<void> _openFilters(BuildContext context) async {
    var draft = rules
        .map(
          (r) => FilterRule(
            id: r.id,
            field: r.field,
            operator: r.operator,
            value: r.value,
            junction: r.junction,
          ),
        )
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dashPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Filters',
                              style: TextStyle(
                                color: context.dashInk,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (draft.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setLocal(() => draft = []);
                                onRulesChanged([]);
                              },
                              child: const Text('Clear'),
                            ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (var i = 0; i < draft.length; i++)
                              _FilterRuleRow(
                                index: i,
                                rule: draft[i],
                                fields: fields,
                                selectOptions: selectOptions,
                                onChanged: () {
                                  setLocal(() {});
                                  onRulesChanged([...draft]);
                                },
                                onRemove: () {
                                  setLocal(() => draft.removeAt(i));
                                  onRulesChanged([...draft]);
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GhostButton(
                        label: 'Add filter',
                        onPressed: () {
                          final field = defaultFilterField ?? fields.first.id;
                          final meta = fieldMeta(fields, field);
                          final opts = selectOptions?.call(field) ?? const <String>[];
                          setLocal(() {
                            draft.add(
                              FilterRule(
                                id: newRuleId(),
                                field: field,
                                operator: opsFor(meta.type).first.$1,
                                value: opts.isEmpty ? '' : opts.first,
                              ),
                            );
                          });
                          onRulesChanged([...draft]);
                        },
                      ),
                      const SizedBox(height: 8),
                      AccentButton(
                        label: 'Done',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openSorts(BuildContext context) async {
    var draft = sorts
        .map(
          (s) => SortRule(id: s.id, field: s.field, direction: s.direction),
        )
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dashPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sort',
                            style: TextStyle(
                              color: context.dashInk,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (draft.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setLocal(() => draft = []);
                              onSortsChanged([]);
                            },
                            child: const Text('Clear'),
                          ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    for (var i = 0; i < draft.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 44,
                              child: Text(
                                i == 0 ? 'By' : 'Then',
                                style: TextStyle(
                                  color: context.dashMute,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: draft[i].field,
                                items: [
                                  for (final f in fields)
                                    DropdownMenuItem(
                                      value: f.id,
                                      child: Text(f.label),
                                    ),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setLocal(() => draft[i].field = v);
                                  onSortsChanged([...draft]);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: draft[i].direction,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'asc',
                                    child: Text('Ascending'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'desc',
                                    child: Text('Descending'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setLocal(() => draft[i].direction = v);
                                  onSortsChanged([...draft]);
                                },
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setLocal(() => draft.removeAt(i));
                                onSortsChanged([...draft]);
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                          ],
                        ),
                      ),
                    GhostButton(
                      label: 'Add sort',
                      onPressed: () {
                        setLocal(() {
                          draft.add(
                            SortRule(
                              id: newRuleId(),
                              field: defaultSortField ?? fields.first.id,
                            ),
                          );
                        });
                        onSortsChanged([...draft]);
                      },
                    ),
                    const SizedBox(height: 8),
                    AccentButton(
                      label: 'Done',
                      onPressed: () => Navigator.pop(ctx),
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
}

class _FilterSortIconButton extends StatelessWidget {
  const _FilterSortIconButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onPressed,
    this.badge,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              size: 18,
              color: active ? AppColors.brandDark : context.dashMute,
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          ),
          if (badge != null && badge! > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableSearchField extends StatefulWidget {
  const _TableSearchField({
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_TableSearchField> createState() => _TableSearchFieldState();
}

class _TableSearchFieldState extends State<_TableSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_TableSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _controller.text.trim().isNotEmpty;
    return TextField(
      controller: _controller,
      onChanged: (v) {
        setState(() {});
        widget.onChanged(v);
      },
      style: TextStyle(
        color: context.dashInk,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        isDense: true,
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.dashLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: active
                ? (context.isDark
                    ? AppColors.brand.withValues(alpha: 0.45)
                    : const Color(0xFFCFE4F6))
                : context.dashLine,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3B9AE0)),
        ),
        filled: true,
        fillColor: active
            ? context.dashElevated
            : context.dashPanel,
      ),
    );
  }
}

class _FilterRuleRow extends StatelessWidget {
  const _FilterRuleRow({
    required this.index,
    required this.rule,
    required this.fields,
    required this.onChanged,
    required this.onRemove,
    this.selectOptions,
  });

  final int index;
  final FilterRule rule;
  final List<FilterFieldDef> fields;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final List<String> Function(String field)? selectOptions;

  @override
  Widget build(BuildContext context) {
    final meta = fieldMeta(fields, rule.field);
    final ops = opsFor(meta.type);
    final opts = selectOptions?.call(rule.field) ?? const <String>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                child: index == 0
                    ? Text(
                        'Where',
                        style: TextStyle(
                          color: context.dashMute,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : DropdownButton<String>(
                        value: rule.junction,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'and', child: Text('And')),
                          DropdownMenuItem(value: 'or', child: Text('Or')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          rule.junction = v;
                          onChanged();
                        },
                      ),
              ),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: rule.field,
                  items: [
                    for (final f in fields)
                      DropdownMenuItem(value: f.id, child: Text(f.label)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    rule.field = v;
                    final nextMeta = fieldMeta(fields, v);
                    rule.operator = opsFor(nextMeta.type).first.$1;
                    final nextOpts = selectOptions?.call(v) ?? const <String>[];
                    rule.value = nextOpts.isEmpty ? '' : nextOpts.first;
                    onChanged();
                  },
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: ops.any((o) => o.$1 == rule.operator)
                      ? rule.operator
                      : ops.first.$1,
                  items: [
                    for (final o in ops)
                      DropdownMenuItem(value: o.$1, child: Text(o.$2)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    rule.operator = v;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: meta.type == FilterFieldType.select && opts.isNotEmpty
                    ? DropdownButtonFormField<String>(
                        value: opts.contains(rule.value)
                            ? rule.value
                            : opts.first,
                        items: [
                          for (final o in opts)
                            DropdownMenuItem(value: o, child: Text(o)),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          rule.value = v;
                          onChanged();
                        },
                      )
                    : TextFormField(
                        initialValue: rule.value,
                        onChanged: (v) {
                          rule.value = v;
                          onChanged();
                        },
                        keyboardType: meta.type == FilterFieldType.number
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                              )
                            : TextInputType.text,
                        inputFormatters: meta.type == FilterFieldType.number
                            ? [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.\-]'),
                                ),
                              ]
                            : null,
                        decoration: const InputDecoration(
                          hintText: 'Value',
                          isDense: true,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
