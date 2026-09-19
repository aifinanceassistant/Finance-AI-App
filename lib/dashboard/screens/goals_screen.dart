import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../dash_sheets.dart';
import '../data.dart';
import '../filter_sort.dart';
import '../goals_controller.dart';
import '../goals_scope.dart';
import '../shimmer.dart';
import '../ui.dart';

const _filterFields = [
  FilterFieldDef(id: 'name', label: 'Name', type: FilterFieldType.text),
  FilterFieldDef(id: 'note', label: 'Note', type: FilterFieldType.text),
  FilterFieldDef(id: 'saved', label: 'Saved', type: FilterFieldType.number),
  FilterFieldDef(id: 'target', label: 'Target', type: FilterFieldType.number),
  FilterFieldDef(id: 'due', label: 'Due', type: FilterFieldType.date),
];

const _goalColors = [
  AppColors.accent,
  AppColors.brand,
  Color(0xFF00D4AA),
  Color(0xFFFFC043),
  Color(0xFFFF6B6B),
];

Object? _goalValue(DemoGoal g, String field) {
  switch (field) {
    case 'name':
      return g.name;
    case 'note':
      return g.note;
    case 'saved':
      return g.saved;
    case 'target':
      return g.target;
    case 'due':
      return g.due;
    default:
      return '';
  }
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    super.key,
    this.openContributeOnStart = false,
    this.contributeGoalName,
  });

  final bool openContributeOnStart;
  final String? contributeGoalName;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<FilterRule> _filterRules = [];
  List<SortRule> _sortRules = [];
  String _search = '';
  bool _sweepEnabled = true;
  bool _roundupEnabled = true;

  GoalsController get _ctrl => GoalsScope.of(context);
  List<DemoGoal> get _goals => _ctrl.goals;

  @override
  void initState() {
    super.initState();
    if (widget.openContributeOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openContributeSheet(goalName: widget.contributeGoalName);
      });
    }
  }

  List<DemoGoal> get _filtered {
    final searched = applySearch(_goals, _search, _filterFields, _goalValue);
    final filtered = applyFilters(searched, _filterRules, _goalValue);
    return applySort(filtered, _sortRules, _goalValue);
  }

  DemoGoal? get _primary => _goals.isEmpty ? null : _goals.first;
  DemoGoal? get _secondary =>
      _goals.length > 1 ? _goals[1] : null;

  Future<void> _openNewGoalSheet() async {
    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final targetCtrl = TextEditingController(text: '1000');
    final dueCtrl = TextEditingController(text: 'Dec 2026');
    var color = _goalColors.first;

    await showDashSheet<void>(
      context: context,
      title: 'New goal',
      description: 'Track a savings target in this space',
      builder: (ctx, setSheetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Name'),
            DashTextField(
              controller: nameCtrl,
              hint: 'Emergency fund',
              autofocus: true,
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Note'),
            DashTextField(
              controller: noteCtrl,
              hint: 'What this is for',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Target'),
                      DashTextField(
                        controller: targetCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashFieldLabel('Due'),
                      DashTextField(
                        controller: dueCtrl,
                        hint: 'Dec 2026',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Color'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _goalColors)
                  GestureDetector(
                    onTap: () => setSheetState(() => color = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: color == c
                            ? Border.all(color: AppColors.brand, width: 2)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
      actions: [
        Expanded(
          child: GhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Expanded(
          child: AccentButton(
            label: 'Create',
            onPressed: () async {
              final trimmed = nameCtrl.text.trim();
              if (trimmed.isEmpty) {
                toast(context, 'Give your goal a short name');
                return;
              }
              if (_goals.any(
                (g) => g.name.toLowerCase() == trimmed.toLowerCase(),
              )) {
                toast(context, 'Pick a unique goal name');
                return;
              }
              final created = await _ctrl.create(
                name: trimmed,
                note: noteCtrl.text.trim().isEmpty
                    ? 'Custom goal'
                    : noteCtrl.text.trim(),
                target: double.tryParse(targetCtrl.text) ?? 0,
                due: dueCtrl.text.trim().isEmpty
                    ? 'TBD'
                    : dueCtrl.text.trim(),
                color: color,
              );
              if (!mounted) return;
              if (created == null) {
                toast(context, 'Could not create goal');
                return;
              }
              Navigator.pop(context);
              toast(context, 'Goal created · $trimmed');
            },
          ),
        ),
      ],
    );

    nameCtrl.dispose();
    noteCtrl.dispose();
    targetCtrl.dispose();
    dueCtrl.dispose();
  }

  Future<void> _openContributeSheet({String? goalName}) async {
    final amountCtrl = TextEditingController(text: '50');
    var selected = goalName ?? _primary?.name ?? '';

    await showDashSheet<void>(
      context: context,
      title: 'Add money',
      description: 'Contribute to ${goalName ?? _primary?.name ?? 'a goal'}',
      builder: (ctx, setSheetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (goalName == null && _goals.isNotEmpty) ...[
              const DashFieldLabel('Goal'),
              DashDropdown<String>(
                value: selected.isEmpty ? _goals.first.name : selected,
                items: _goals.map((g) => g.name).toList(),
                labelOf: (v) => v,
                onChanged: (v) => setSheetState(() => selected = v),
              ),
              const SizedBox(height: 14),
            ],
            const DashFieldLabel('Amount'),
            DashTextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
          ],
        );
      },
      actions: [
        Expanded(
          child: GhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Expanded(
          child: AccentButton(
            label: 'Add',
            onPressed: () async {
              final value = double.tryParse(amountCtrl.text);
              if (value == null || value <= 0) {
                toast(context, 'Contribution must be greater than zero');
                return;
              }
              final targetName = goalName ?? selected;
              if (targetName.isEmpty) return;
              final goal = _goals.where((g) => g.name == targetName).firstOrNull;
              final id = goal?.id;
              if (id == null || id.isEmpty) {
                toast(context, 'Could not contribute');
                return;
              }
              final updated = await _ctrl.contribute(id, value);
              if (!mounted) return;
              if (updated == null) {
                toast(context, 'Could not contribute');
                return;
              }
              Navigator.pop(context);
              toast(
                context,
                'Contribution added · \$${value.toStringAsFixed(0)} → $targetName',
              );
            },
          ),
        ),
      ],
    );

    amountCtrl.dispose();
  }

  Future<void> _openRulesSheet() async {
    var sweep = _sweepEnabled;
    var roundup = _roundupEnabled;

    await showDashSheet<void>(
      context: context,
      title: 'Edit auto-save rules',
      description: 'Choose how leftover cash moves into goals',
      builder: (ctx, setSheetState) {
        return Column(
          children: [
            _RuleCheckbox(
              title: 'Weekly sweep',
              subtitle:
                  'Move leftover checking into ${_primary?.name ?? 'primary goal'}',
              value: sweep,
              onChanged: (v) => setSheetState(() => sweep = v),
            ),
            const SizedBox(height: 10),
            _RuleCheckbox(
              title: 'Round-ups',
              subtitle:
                  'Send spare change to ${_secondary?.name ?? 'a secondary goal'}',
              value: roundup,
              onChanged: (v) => setSheetState(() => roundup = v),
            ),
          ],
        );
      },
      actions: [
        Expanded(
          child: GhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Expanded(
          child: AccentButton(
            label: 'Save',
            onPressed: () {
              setState(() {
                _sweepEnabled = sweep;
                _roundupEnabled = roundup;
              });
              Navigator.pop(context);
              toast(
                context,
                'Auto-save rules updated · '
                '${sweep ? 'Sweep on' : 'Sweep off'} · '
                '${roundup ? 'Round-ups on' : 'Round-ups off'}',
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalTarget = filtered.fold<double>(0, (s, g) => s + g.target);
    final totalSaved = filtered.fold<double>(0, (s, g) => s + g.saved);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: const Text(
          'Goals',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          DashPageHeader(
            title: 'Goals',
            subtitle: 'Save toward what matters',
            actions: [
              GhostButton(
                label: 'Contribute',
                onPressed: () => _openContributeSheet(),
              ),
              AccentButton(
                label: 'New goal',
                onPressed: _openNewGoalSheet,
              ),
            ],
          ),
          if (_ctrl.loading)
            const DashLoadingBody(kpiCount: 2, listRows: 4)
          else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: FilterSortBar(
              fields: _filterFields,
              rules: _filterRules,
              sorts: _sortRules,
              defaultFilterField: 'name',
              defaultSortField: 'due',
              search: _search,
              onSearchChanged: (v) => setState(() => _search = v),
              searchHint: 'Search goals…',
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
                    label: 'Saved toward goals',
                    value: moneyWhole(totalSaved),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DashKpi(
                    label: 'Total targets',
                    value: moneyWhole(totalTarget),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: DashPanel(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 28),
                child: Text(
                  'No goals match these filters',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.mute,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            for (final g in filtered)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _GoalCard(
                  goal: g,
                  onAddMoney: () => _openContributeSheet(goalName: g.name),
                ),
              ),
          if (_goals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DashPanel(
                child: Column(
                  children: [
                    DashPanelHeader(
                      title: 'Auto-save rules',
                      subtitle: 'Move leftover budget into goals',
                      action: LinkAction(
                        label: 'Edit rules',
                        onTap: _openRulesSheet,
                      ),
                    ),
                    _RuleRow(
                      label:
                          'End of month surplus → ${_primary?.name ?? 'Emergency fund'}',
                      on: _sweepEnabled,
                    ),
                    if (_secondary != null)
                      _RuleRow(
                        label:
                            '\$50 / paycheck → ${_secondary!.name}',
                        on: _roundupEnabled,
                      ),
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

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onAddMoney});

  final DemoGoal goal;
  final VoidCallback onAddMoney;

  @override
  Widget build(BuildContext context) {
    final pct = goal.target > 0
        ? ((goal.saved / goal.target) * 100).round()
        : 0;

    return DashPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      goal.note,
                      style: const TextStyle(
                        color: AppColors.mute,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  goal.due,
                  style: const TextStyle(
                    color: AppColors.mute,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              text: moneyWhole(goal.saved),
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(
                  text: ' / ${moneyWhole(goal.target)}',
                  style: const TextStyle(
                    color: AppColors.softMute,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ProgressTrack(progress: pct / 100, color: goal.color),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$pct% complete',
                style: const TextStyle(
                  color: AppColors.mute,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              LinkAction(label: 'Add money', onTap: onAddMoney),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.on});

  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            on ? 'On' : 'Off',
            style: TextStyle(
              color: on ? AppColors.success : AppColors.mute,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleCheckbox extends StatelessWidget {
  const _RuleCheckbox({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppColors.brand,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.mute,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
