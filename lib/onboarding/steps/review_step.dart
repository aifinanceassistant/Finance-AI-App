import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../theme/app_theme.dart';
import '../models.dart';
import '../onboarding_api.dart';
import '../onboarding_dialogs.dart';
import '../onboarding_layout.dart';
import '../onboarding_shell.dart';

enum _ReviewId { accounts, labels, plan }

class _Label {
  _Label({
    required this.name,
    this.serverId,
    this.budget = 0,
    this.savedBudget,
  });

  final String name;
  String? serverId;
  double budget;
  double? savedBudget;
}

const _extraLabels = [
  'Car',
  'Children',
  'Clothing',
  'Donations',
  'Education',
  'Entertainment',
  'Gym',
  'Healthcare',
  'Home',
  'Insurance',
  'Pets',
  'Travel',
];

/// Cash-flow checklist. Nothing is written until "Open dashboard"; saved rows
/// are flagged so a retry after a partial failure never duplicates them.
class ReviewStep extends StatefulWidget {
  const ReviewStep({
    super.key,
    required this.spaceId,
    required this.accounts,
    required this.trialStarted,
    required this.onFinish,
  });

  final String? spaceId;
  final List<LinkedAccount> accounts;
  final bool trialStarted;

  /// Marks onboarding complete; resolves to an error message on failure.
  final Future<String?> Function() onFinish;

  @override
  State<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<ReviewStep> {
  _ReviewId _focus = _ReviewId.accounts;
  bool _budgetingOn = true;
  final List<_Label> _labels = [];
  String? _labelsError;
  bool _saving = false;
  List<String> _errors = const [];

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  @override
  void didUpdateWidget(covariant ReviewStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId == null && widget.spaceId != null) _loadLabels();
  }

  Future<void> _loadLabels() async {
    final spaceId = widget.spaceId;
    if (spaceId == null) return;
    final res = await loadExpenseCategories(AuthScope.read(context), spaceId);
    if (!mounted) return;
    setState(() {
      _labelsError = res.error;
      final loaded = res.categories;
      if (loaded == null) return;
      _labels
        ..clear()
        ..addAll([
          for (final c in loaded)
            _Label(
              name: c.name,
              serverId: c.id,
              budget: c.monthlyBudget ?? 0,
              savedBudget: c.monthlyBudget,
            ),
        ]);
    });
  }

  Future<void> _addLabel() async {
    final result = await showOnboardingSheet<_Label>(
      context,
      title: 'New label',
      builder: (_) => const _LabelForm(),
    );
    if (result == null) return;
    final exists = _labels.any(
      (l) => l.name.toLowerCase() == result.name.toLowerCase(),
    );
    if (!exists) setState(() => _labels.add(result));
  }

  Future<void> _editBudget(_Label label) async {
    final result = await showOnboardingSheet<double>(
      context,
      title: 'Monthly limit · ${label.name}',
      builder: (_) => _BudgetForm(initial: label.budget),
    );
    if (result != null) setState(() => label.budget = result);
  }

  Future<List<String>> _saveAll() async {
    final spaceId = widget.spaceId;
    if (spaceId == null) {
      return ['Your workspace hasn’t loaded yet. Go back and try again.'];
    }
    final auth = AuthScope.read(context);
    final errors = <String>[];

    for (final l in _labels) {
      final wanted = _budgetingOn && l.budget > 0 ? l.budget : null;
      if (l.serverId == null) {
        final res = await createExpenseCategory(auth, spaceId, l.name, wanted);
        if (res.error == null) {
          l.serverId = res.id ?? 'saved';
          l.savedBudget = wanted;
        } else {
          errors.add('${l.name}: ${res.error}');
        }
        continue;
      }
      if (!_budgetingOn || wanted == l.savedBudget) continue;
      final err = await updateCategoryBudget(auth, l.serverId!, wanted);
      if (err == null) {
        l.savedBudget = wanted;
      } else {
        errors.add('${l.name} budget: $err');
      }
    }
    return errors;
  }

  Future<void> _openDashboard({bool skipSave = false}) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errors = const [];
    });
    final errors = skipSave ? <String>[] : await _saveAll();
    if (!mounted) return;
    if (errors.isNotEmpty) {
      setState(() {
        _saving = false;
        _errors = errors;
      });
      return;
    }
    final err = await widget.onFinish();
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _saving = false;
        _errors = [err];
      });
    }
  }

  Widget _row(String left, String right, {VoidCallback? onRemove}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(right, style: const TextStyle(color: AppColors.mute)),
          if (onRemove != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16),
            ),
        ],
      ),
    );
  }

  Widget _action(String label, VoidCallback? onPressed) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(padding: EdgeInsets.zero),
    child: Text(label),
  );

  List<Widget> _detailFor(_ReviewId id) {
    switch (id) {
      case _ReviewId.accounts:
        if (widget.accounts.isEmpty) {
          return const [
            Text(
              'Nothing linked yet. You can continue, but balances stay empty until you connect something.',
              style: TextStyle(color: AppColors.mute),
            ),
          ];
        }
        return [
          for (final a in widget.accounts)
            _row('${a.institution} · ${a.name}', money(a.balance)),
        ];
      case _ReviewId.labels:
        final names = _labels.map((l) => l.name.toLowerCase()).toSet();
        return [
          if (_labelsError != null)
            Text(
              'Couldn’t load labels ($_labelsError).',
              style: const TextStyle(color: Color(0xFFC44B4B)),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final l in _labels)
                InputChip(
                  label: Text(l.name),
                  onDeleted: l.serverId == null
                      ? () => setState(() => _labels.remove(l))
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in _extraLabels)
                if (!names.contains(n.toLowerCase()))
                  ActionChip(
                    label: Text('+ $n'),
                    onPressed: () =>
                        setState(() => _labels.add(_Label(name: n))),
                  ),
            ],
          ),
          _action('+ New label', _addLabel),
        ];
      case _ReviewId.plan:
        if (!_budgetingOn) {
          return [
            const Text(
              'Budgeting is off. Turn it on for category limits on the dashboard.',
              style: TextStyle(color: AppColors.mute),
            ),
            _action(
              'Turn on budgeting',
              () => setState(() => _budgetingOn = true),
            ),
          ];
        }
        return [
          for (final l in _labels)
            InkWell(
              onTap: () => _editBudget(l),
              child: _row(
                l.name,
                l.budget > 0 ? '${money(l.budget)}/mo' : 'Set limit',
              ),
            ),
          _action(
            'Turn off budgeting',
            () => setState(() => _budgetingOn = false),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetTotal = _budgetingOn
        ? _labels.fold<double>(0, (s, l) => s + l.budget)
        : 0.0;

    final items = [
      (
        id: _ReviewId.accounts,
        nav: 'Linked accounts',
        question: 'Is everything connected?',
        metric: '${widget.accounts.length}',
        hint: widget.accounts.length == 1
            ? 'account linked'
            : 'accounts linked',
      ),
      (
        id: _ReviewId.labels,
        nav: 'Spending labels',
        question: 'Do these categories fit you?',
        metric: '${_labels.length}',
        hint: _labels.length == 1 ? 'active label' : 'active labels',
      ),
      (
        id: _ReviewId.plan,
        nav: 'Monthly plan',
        question: 'Does this budget feel realistic?',
        metric: _budgetingOn ? money(budgetTotal) : 'Off',
        hint: _budgetingOn ? 'planned to spend' : 'budgeting paused',
      ),
    ];
    final focused = items.firstWhere((i) => i.id == _focus);

    final detail = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E6EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            focused.question,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            focused.metric,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          Text(focused.hint, style: const TextStyle(color: AppColors.mute)),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEEF1F5)),
          const SizedBox(height: 8),
          ..._detailFor(focused.id),
        ],
      ),
    );

    return OnboardingStepScaffold(
      eyebrow: 'LAST CHECK',
      title: 'Does this look right?',
      subtitle: 'Before we open your dashboard, confirm what you earn, what already leaves each month, and how you want the rest organized.',
      body: [
        if (widget.trialStarted) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1FAF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCDE9DA)),
            ),
            child: const Text(
              'Finish checkout in the browser to start your free trial. You can manage it from Settings → Billing.',
              style: TextStyle(
                color: Color(0xFF2F9D6A),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item.nav),
                    selected: item.id == _focus,
                    onSelected: (_) => setState(() => _focus = item.id),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        detail,
        if (_errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF4F4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF3D2D2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Some items didn’t save:',
                  style: TextStyle(
                    color: Color(0xFFC44B4B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final e in _errors)
                  Text(
                    '• $e',
                    style: const TextStyle(
                      color: Color(0xFFC44B4B),
                      fontSize: 13,
                    ),
                  ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => _openDashboard(skipSave: true),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFC44B4B),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('Skip these and open the dashboard'),
                ),
              ],
            ),
          ),
        ],
      ],
      actions: OnboardingActions(
        primaryLabel: _saving
            ? 'Saving…'
            : _errors.isNotEmpty
            ? 'Try again'
            : 'Open dashboard',
        onPrimary: _saving ? () {} : () => _openDashboard(),
      ),
    );
  }
}

class _LabelForm extends StatefulWidget {
  const _LabelForm();

  @override
  State<_LabelForm> createState() => _LabelFormState();
}

class _LabelFormState extends State<_LabelForm> {
  final _name = TextEditingController();
  final _budget = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: onboardingInputDecoration('Label name'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _budget,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: onboardingInputDecoration(
            'Monthly limit (optional)',
            prefix: '\$ ',
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.length < 2) return;
            final budget =
                double.tryParse(
                  _budget.text.replaceAll(RegExp(r'[^0-9.]'), ''),
                ) ??
                0;
            Navigator.of(context).pop(_Label(name: name, budget: budget));
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _BudgetForm extends StatefulWidget {
  const _BudgetForm({required this.initial});

  final double initial;

  @override
  State<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<_BudgetForm> {
  late final _value = TextEditingController(
    text: widget.initial > 0
        ? (widget.initial % 1 == 0
              ? widget.initial.toInt().toString()
              : widget.initial.toStringAsFixed(2))
        : '',
  );

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _value,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: onboardingInputDecoration('Monthly limit', prefix: '\$ '),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            double.tryParse(_value.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                0,
          ),
          style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
