import 'package:flutter/material.dart';

import 'accounts_controller.dart';
import 'accounts_scope.dart';
import 'categories_controller.dart';
import 'categories_scope.dart';
import 'dash_colors.dart';
import 'data.dart';
import 'goals_controller.dart';
import 'goals_scope.dart';
import 'investments_controller.dart';
import 'investments_scope.dart';
import 'recurring_controller.dart';
import 'recurring_scope.dart';
import 'shell.dart';
import 'spaces.dart';
import 'spaces_scope.dart';
import 'transactions_controller.dart';
import 'transactions_scope.dart';

/// Destination for static page / jump hits beyond primary [DashTab]s.
enum CommandPage {
  home,
  transactions,
  categories,
  accounts,
  more,
  settings,
  reports,
  goals,
  investments,
  recurring,
  team,
}

/// Opens a full-screen command search modal.
///
/// Mobile uses the search icon in shell chrome (⌘K is a web desktop pattern).
Future<void> showCommandSearch(
  BuildContext context, {
  required ValueChanged<DashTab> onSelectTab,
  ValueChanged<CommandPage>? onOpenPage,
  ValueChanged<String>? onSelectSpace,
}) {
  // Use getInherited* (not dependOn*) — this runs from a tap handler, not build.
  final spaces = context.getInheritedWidgetOfExactType<SpacesScope>()?.notifier ??
      SpacesController.fake();
  final transactions =
      context.getInheritedWidgetOfExactType<TransactionsScope>()?.notifier ??
          TransactionsController.fake();
  final accounts =
      context.getInheritedWidgetOfExactType<AccountsScope>()?.notifier ??
          AccountsController.fake();
  final categories =
      context.getInheritedWidgetOfExactType<CategoriesScope>()?.notifier ??
          CategoriesController.fake();
  final goals =
      context.getInheritedWidgetOfExactType<GoalsScope>()?.notifier ??
          GoalsController.fake();
  final investments =
      context.getInheritedWidgetOfExactType<InvestmentsScope>()?.notifier ??
          InvestmentsController.fake();
  final recurring =
      context.getInheritedWidgetOfExactType<RecurringScope>()?.notifier ??
          RecurringController.fake();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.dashPanel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return SpacesScope(
        controller: spaces,
        child: TransactionsScope(
          controller: transactions,
          child: AccountsScope(
            controller: accounts,
            child: CategoriesScope(
              controller: categories,
              child: GoalsScope(
                controller: goals,
                child: InvestmentsScope(
                  controller: investments,
                  child: RecurringScope(
                    controller: recurring,
                    child: _CommandSearchSheet(
                      onSelectTab: onSelectTab,
                      onOpenPage: onOpenPage,
                      onSelectSpace: onSelectSpace,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _CommandHit {
  const _CommandHit({
    required this.id,
    required this.title,
    required this.group,
    required this.icon,
    this.subtitle,
    this.tab,
    this.page,
    this.spaceId,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String group;
  final IconData icon;
  final DashTab? tab;
  final CommandPage? page;
  final String? spaceId;

  bool matches(String q) {
    if (q.isEmpty) return true;
    final hay = '${title.toLowerCase()} ${(subtitle ?? '').toLowerCase()}';
    return hay.contains(q);
  }
}

class _CommandSearchSheet extends StatefulWidget {
  const _CommandSearchSheet({
    required this.onSelectTab,
    this.onOpenPage,
    this.onSelectSpace,
  });

  final ValueChanged<DashTab> onSelectTab;
  final ValueChanged<CommandPage>? onOpenPage;
  final ValueChanged<String>? onSelectSpace;

  @override
  State<_CommandSearchSheet> createState() => _CommandSearchSheetState();
}

class _CommandSearchSheetState extends State<_CommandSearchSheet> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<_CommandHit> _catalog(BuildContext context) {
    final spaces = SpacesScope.maybeOf(context);
    final txns = TransactionsScope.of(context).transactions;
    final accounts = AccountsScope.of(context).accounts;
    final categories = CategoriesScope.of(context).categories;
    final goals = GoalsScope.of(context).goals;
    final holdings = InvestmentsScope.of(context).holdings;
    final recurring = RecurringScope.of(context).items;

    final hits = <_CommandHit>[
      const _CommandHit(
        id: 'action-txn',
        title: 'Go to transactions',
        group: 'Quick actions',
        icon: Icons.arrow_forward_rounded,
        tab: DashTab.transactions,
        page: CommandPage.transactions,
      ),
      for (final p in _pages)
        _CommandHit(
          id: 'page-${p.name}',
          title: p.label,
          subtitle: 'Jump to ${p.label}',
          group: 'Pages',
          icon: p.icon,
          tab: p.tab,
          page: p.page,
        ),
    ];

    for (final s in spaces?.spaces ?? const <Space>[]) {
      hits.add(
        _CommandHit(
          id: 'space-${s.id}',
          title: s.name,
          subtitle: s.id == spaces?.spaceId ? 'Current space' : 'Switch space',
          group: 'Spaces',
          icon: Icons.public_outlined,
          spaceId: s.id,
        ),
      );
    }

    for (final t in txns) {
      hits.add(
        _CommandHit(
          id: 'txn-${t.id}',
          title: t.merchant,
          subtitle: '${t.account} · ${_statusLabel(t.status)}',
          group: 'Transactions',
          icon: Icons.receipt_long_outlined,
          tab: DashTab.transactions,
          page: CommandPage.transactions,
        ),
      );
    }

    for (final a in accounts) {
      hits.add(
        _CommandHit(
          id: 'acc-${a.id ?? a.bank}-${a.number}',
          title: '${a.displayName} · ${a.type}',
          subtitle: a.number,
          group: 'Accounts',
          icon: Icons.account_balance_outlined,
          tab: DashTab.accounts,
          page: CommandPage.accounts,
        ),
      );
    }

    for (final c in categories) {
      hits.add(
        _CommandHit(
          id: 'cat-${c.id}',
          title: c.name,
          subtitle: '${c.txns} transactions · ${c.group}',
          group: 'Categories',
          icon: Icons.label_outline_rounded,
          tab: DashTab.categories,
          page: CommandPage.categories,
        ),
      );
    }

    for (final g in goals) {
      hits.add(
        _CommandHit(
          id: 'goal-${g.id ?? g.name}',
          title: g.name,
          subtitle: g.note.isEmpty ? 'Due ${g.due}' : g.note,
          group: 'Goals',
          icon: Icons.flag_outlined,
          page: CommandPage.goals,
        ),
      );
    }

    for (final h in holdings) {
      hits.add(
        _CommandHit(
          id: 'hold-${h.id ?? h.ticker}',
          title: '${h.name} (${h.ticker})',
          subtitle: h.type,
          group: 'Investments',
          icon: Icons.trending_up_rounded,
          page: CommandPage.investments,
        ),
      );
    }

    for (final r in recurring) {
      hits.add(
        _CommandHit(
          id: 'rec-${r.id}',
          title: r.name,
          subtitle: 'Next ${r.next} · ${r.category}',
          group: 'Recurring',
          icon: Icons.autorenew_rounded,
          page: CommandPage.recurring,
        ),
      );
    }

    return hits;
  }

  void _run(_CommandHit hit) {
    Navigator.pop(context);
    if (hit.spaceId != null) {
      widget.onSelectSpace?.call(hit.spaceId!);
      return;
    }
    if (hit.page != null && widget.onOpenPage != null) {
      widget.onOpenPage!(hit.page!);
      return;
    }
    if (hit.tab != null) {
      widget.onSelectTab(hit.tab!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final filtered = _catalog(context).where((h) => h.matches(q)).toList();
    final groups = <String, List<_CommandHit>>{};
    for (final h in filtered) {
      (groups[h.group] ??= []).add(h);
    }
    final height = MediaQuery.sizeOf(context).height * 0.92;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.dashLine,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: context.dashMute, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _query,
                    focusNode: _focus,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      color: context.dashInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search pages, money…',
                      hintStyle: TextStyle(color: context.dashSoftMute),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: context.dashMute),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.dashLine),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      q.isEmpty ? 'Nothing to search yet' : 'No matches for “$q”',
                      style: TextStyle(
                        color: context.dashSoftMute,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                    children: [
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                          child: Text(
                            entry.key.toUpperCase(),
                            style: TextStyle(
                              color: context.dashMute,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.06 * 11,
                            ),
                          ),
                        ),
                        for (final hit in entry.value)
                          ListTile(
                            dense: true,
                            leading: Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: context.isDark
                                    ? context.dashLine
                                    : const Color(0xFFF6F9FC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: context.dashLine),
                              ),
                              child: Icon(
                                hit.icon,
                                size: 16,
                                color: context.dashMute,
                              ),
                            ),
                            title: Text(
                              hit.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.dashInk,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: hit.subtitle == null
                                ? null
                                : Text(
                                    hit.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.dashSoftMute,
                                      fontSize: 12,
                                    ),
                                  ),
                            onTap: () => _run(hit),
                          ),
                      ],
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: context.dashSoftMute,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(TxnStatus s) => switch (s) {
      TxnStatus.succeeded => 'Succeeded',
      TxnStatus.pending => 'Pending',
      TxnStatus.failed => 'Failed',
    };

class _PageDef {
  const _PageDef({
    required this.name,
    required this.label,
    required this.icon,
    required this.page,
    this.tab,
  });

  final String name;
  final String label;
  final IconData icon;
  final CommandPage page;
  final DashTab? tab;
}

const _pages = <_PageDef>[
  _PageDef(
    name: 'home',
    label: 'Home',
    icon: Icons.home_outlined,
    page: CommandPage.home,
    tab: DashTab.home,
  ),
  _PageDef(
    name: 'transactions',
    label: 'Transactions',
    icon: Icons.receipt_long_outlined,
    page: CommandPage.transactions,
    tab: DashTab.transactions,
  ),
  _PageDef(
    name: 'categories',
    label: 'Categories',
    icon: Icons.label_outline_rounded,
    page: CommandPage.categories,
    tab: DashTab.categories,
  ),
  _PageDef(
    name: 'accounts',
    label: 'Accounts',
    icon: Icons.account_balance_outlined,
    page: CommandPage.accounts,
    tab: DashTab.accounts,
  ),
  _PageDef(
    name: 'more',
    label: 'More',
    icon: Icons.grid_view_outlined,
    page: CommandPage.more,
    tab: DashTab.more,
  ),
  _PageDef(
    name: 'settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    page: CommandPage.settings,
  ),
  _PageDef(
    name: 'reports',
    label: 'Reports',
    icon: Icons.insights_outlined,
    page: CommandPage.reports,
  ),
  _PageDef(
    name: 'goals',
    label: 'Goals',
    icon: Icons.flag_outlined,
    page: CommandPage.goals,
  ),
  _PageDef(
    name: 'investments',
    label: 'Investments',
    icon: Icons.trending_up_rounded,
    page: CommandPage.investments,
  ),
  _PageDef(
    name: 'recurring',
    label: 'Recurring',
    icon: Icons.autorenew_rounded,
    page: CommandPage.recurring,
  ),
  _PageDef(
    name: 'team',
    label: 'Team',
    icon: Icons.group_outlined,
    page: CommandPage.team,
  ),
];
