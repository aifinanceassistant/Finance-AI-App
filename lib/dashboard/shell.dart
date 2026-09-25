import 'package:flutter/material.dart';

import '../auth/auth_navigation.dart';
import '../auth/auth_scope.dart';
import '../theme/app_theme.dart';
import '../variations/models.dart';
import 'accounts_controller.dart';
import 'accounts_scope.dart';
import 'agent_chat.dart';
import 'agent_mode.dart';
import 'bottom_nav.dart';
import 'categories_controller.dart';
import 'categories_scope.dart';
import 'command_search.dart';
import 'dash_colors.dart';
import 'goals_controller.dart';
import 'goals_scope.dart';
import 'investments_controller.dart';
import 'investments_scope.dart';
import 'notifications_center.dart';
import 'recurring_controller.dart';
import 'recurring_scope.dart';
import 'screens/accounts_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/home_screen.dart';
import 'screens/investments_screen.dart';
import 'screens/more_screen.dart';
import 'screens/recurring_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/users_permissions_screen.dart';
import 'space_switcher_bar.dart';
import 'spaces.dart';
import 'spaces_scope.dart';
import 'transactions_controller.dart';
import 'transactions_scope.dart';
import 'ui.dart';
import 'variant_style.dart';
import 'dash_sheets.dart';
import 'form_validation.dart';

enum DashTab { home, transactions, categories, accounts, more }

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, this.initialTab = DashTab.home});

  final DashTab initialTab;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell>
    with WidgetsBindingObserver {
  late DashTab _tab = widget.initialTab;
  late final PageController _pages = PageController(initialPage: _tab.index);
  String? _txnCategoryFilter;
  var _openReconcile = false;
  var _agentMode = false;
  var _agentModeHydrated = false;
  SpacesController? _spaces;
  AccountsController? _accounts;
  TransactionsController? _transactions;
  CategoriesController? _categories;
  RecurringController? _recurring;
  InvestmentsController? _investments;
  GoalsController? _goals;
  var _ownedSpaces = false;
  var _ownedAccounts = false;
  var _ownedTransactions = false;
  var _ownedCategories = false;
  var _ownedRecurring = false;
  var _ownedInvestments = false;
  var _ownedGoals = false;
  String? _dataSpaceId;
  DateTime? _lastResumeRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ignore: discarded_futures
    _hydrateAgentMode();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastResumeRefresh;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 2)) {
      return;
    }
    _lastResumeRefresh = DateTime.now();
    // ignore: discarded_futures
    _refreshSpaceData();
  }

  Future<void> _hydrateAgentMode() async {
    final on = await readStoredAgentMode();
    if (!mounted) return;
    setState(() {
      _agentMode = on;
      _agentModeHydrated = true;
      if (on) {
        _tab = DashTab.home;
        _txnCategoryFilter = null;
        _openReconcile = false;
      }
    });
    if (on && _pages.hasClients) {
      _pages.jumpToPage(DashTab.home.index);
    }
  }

  void _setAgentMode(bool on) {
    setState(() {
      _agentMode = on;
      _tab = DashTab.home;
      _txnCategoryFilter = null;
      _openReconcile = false;
    });
    if (_pages.hasClients) {
      _pages.jumpToPage(DashTab.home.index);
    }
    if (_agentModeHydrated) {
      // ignore: discarded_futures
      writeStoredAgentMode(on);
    }
  }

  void _enterAgentMode() => _setAgentMode(true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_spaces != null) return;
    final auth = AuthScope.read(context);
    _spaces = SpacesController(auth);
    _accounts = AccountsController(auth);
    _transactions = TransactionsController(auth);
    _categories = CategoriesController(auth);
    _recurring = RecurringController(auth);
    _investments = InvestmentsController(auth);
    _goals = GoalsController(auth);
    _ownedSpaces = true;
    _ownedAccounts = true;
    _ownedTransactions = true;
    _ownedCategories = true;
    _ownedRecurring = true;
    _ownedInvestments = true;
    _ownedGoals = true;
    _spaces!.addListener(_onSpacesChanged);
    // ignore: discarded_futures
    _spaces!.load();
  }

  void _onSpacesChanged() {
    final spaces = _spaces;
    final accounts = _accounts;
    final transactions = _transactions;
    final categories = _categories;
    final recurring = _recurring;
    final investments = _investments;
    final goals = _goals;
    if (spaces == null ||
        accounts == null ||
        transactions == null ||
        categories == null ||
        recurring == null ||
        investments == null ||
        goals == null ||
        !spaces.ready) {
      return;
    }
    final id = spaces.spaceId;
    if (id == _dataSpaceId) return;
    _dataSpaceId = id;
    // ignore: discarded_futures
    accounts.loadForSpace(id);
    // ignore: discarded_futures
    transactions.loadForSpace(id);
    // ignore: discarded_futures
    categories.loadForSpace(id);
    // ignore: discarded_futures
    recurring.loadForSpace(id);
    // ignore: discarded_futures
    investments.loadForSpace(id);
    // ignore: discarded_futures
    goals.loadForSpace(id);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    _spaces?.removeListener(_onSpacesChanged);
    if (_ownedSpaces) _spaces?.dispose();
    if (_ownedAccounts) _accounts?.dispose();
    if (_ownedTransactions) _transactions?.dispose();
    if (_ownedCategories) _categories?.dispose();
    if (_ownedRecurring) _recurring?.dispose();
    if (_ownedInvestments) _investments?.dispose();
    if (_ownedGoals) _goals?.dispose();
    super.dispose();
  }

  void _go(DashTab tab, {String? categoryFilter, bool clearFilter = false}) {
    setState(() {
      _tab = tab;
      if (tab != DashTab.transactions) {
        _openReconcile = false;
      }
      if (tab == DashTab.transactions) {
        if (clearFilter) {
          _txnCategoryFilter = null;
        } else if (categoryFilter != null) {
          _txnCategoryFilter = categoryFilter;
        }
      } else {
        _txnCategoryFilter = null;
      }
    });
    _pages.jumpToPage(tab.index);
  }

  void _goReconcile() {
    setState(() {
      _tab = DashTab.transactions;
      _txnCategoryFilter = null;
      _openReconcile = true;
    });
    _pages.jumpToPage(DashTab.transactions.index);
    // Clear the one-shot flag after the screen has a chance to open the sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _openReconcile = false);
    });
  }

  void _openCommandSearch(BuildContext scopedContext) {
    // Must use a context under SpacesScope / *Scope — State.context is above them.
    // ignore: discarded_futures
    showCommandSearch(
      scopedContext,
      onSelectTab: (tab) => _go(tab, clearFilter: tab == DashTab.transactions),
      onOpenPage: _handleCommandPage,
      onSelectSpace: (id) {
        // ignore: discarded_futures
        _spaces?.select(id);
      },
    );
  }

  void _handleCommandPage(CommandPage page) {
    switch (page) {
      case CommandPage.home:
        _go(DashTab.home);
      case CommandPage.transactions:
        _go(DashTab.transactions, clearFilter: true);
      case CommandPage.categories:
        _go(DashTab.categories);
      case CommandPage.accounts:
        _go(DashTab.accounts);
      case CommandPage.more:
        _go(DashTab.more);
      case CommandPage.settings:
        _openSettings();
      case CommandPage.reports:
        _openReports();
      case CommandPage.goals:
        _openGoals();
      case CommandPage.investments:
        _openInvestments();
      case CommandPage.recurring:
        _openRecurring();
      case CommandPage.team:
        _openUsersPermissions();
    }
  }

  void _handleNotification(DashNotification n) {
    switch (n.category) {
      case NotifCategory.billing:
        _openSettings(section: 'plan');
      case NotifCategory.accounts:
        _go(DashTab.accounts);
      case NotifCategory.budgets:
        _go(DashTab.categories);
      case NotifCategory.security:
        _openSettings(section: 'security');
      case NotifCategory.system:
        break;
    }
  }

  Widget _withSpaces(Widget child) {
    final spaces = _spaces ?? SpacesController.fake();
    return SpacesScope(controller: spaces, child: child);
  }

  void _openGoals({
    bool openContribute = false,
    String? contributeGoalName,
  }) {
    final spaces = _spaces ?? SpacesController.fake();
    if (!spaces.hasFeature('goals')) {
      _openSettings(section: 'plan');
      toast(context, 'Upgrade to unlock Goals');
      return;
    }
    final style = DashVariantStyle.of(context);
    final goals = _goals ?? GoalsController.fake();
    Navigator.of(context).push(
      dashModalRoute<void>(
        builder: (_) => _withSpaces(
          GoalsScope(
            controller: goals,
            child: DashStyleScope(
              style: style,
              child: GoalsScreen(
                openContributeOnStart: openContribute,
                contributeGoalName: contributeGoalName,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openReports() {
    final style = DashVariantStyle.of(context);
    final transactions = _transactions ?? TransactionsController.fake();
    Navigator.of(context).push(
      dashModalRoute<void>(
        builder: (_) => _withSpaces(
          TransactionsScope(
            controller: transactions,
            child: DashStyleScope(
              style: style,
              child: const ReportsScreen(),
            ),
          ),
        ),
      ),
    );
  }

  void _openRecurring() {
    final style = DashVariantStyle.of(context);
    final recurring = _recurring ?? RecurringController.fake();
    Navigator.of(context).push(
      dashModalRoute<void>(
        builder: (_) => _withSpaces(
          RecurringScope(
            controller: recurring,
            child: DashStyleScope(
              style: style,
              child: const RecurringScreen(),
            ),
          ),
        ),
      ),
    );
  }

  void _openInvestments() {
    final spaces = _spaces ?? SpacesController.fake();
    if (!spaces.hasFeature('investments')) {
      _openSettings(section: 'plan');
      toast(context, 'Upgrade to unlock Investments');
      return;
    }
    final style = DashVariantStyle.of(context);
    final investments = _investments ?? InvestmentsController.fake();
    Navigator.of(context).push(
      dashModalRoute<void>(
        builder: (_) => _withSpaces(
          InvestmentsScope(
            controller: investments,
            child: DashStyleScope(
              style: style,
              child: const InvestmentsScreen(),
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings({String section = 'general'}) {
    final style = DashVariantStyle.of(context);
    final accounts = _accounts;
    Navigator.of(context).push(
      dashModalRoute<void>(
        builder: (_) => _withSpaces(
          DashStyleScope(
            style: style,
            child: accounts != null
                ? AccountsScope(
                    controller: accounts,
                    child: SettingsScreen(
                      onLogout: _confirmLogout,
                      initialSection: section,
                    ),
                  )
                : SettingsScreen(
                    onLogout: _confirmLogout,
                    initialSection: section,
                  ),
          ),
        ),
      ),
    );
  }

  void _openUsersPermissions() {
    final style = DashVariantStyle.of(context);
    Navigator.of(context).push(
      dashModalRoute<void>(
        builder: (_) => _withSpaces(
          DashStyleScope(
            style: style,
            child: const UsersPermissionsScreen(),
          ),
        ),
      ),
    );
  }

  Future<void> _connectBank() async {
    final accounts = _accounts;
    if (accounts == null) return;

    final bank = TextEditingController();
    final last4 = TextEditingController();
    final balance = TextEditingController(text: '0');
    var type = 'Checking';
    var fieldErrors = <String, String?>{};
    await showDashSheet<void>(
      context: context,
      title: 'Connect bank',
      description: 'Link an institution to sync balances',
      builder: (ctx, setLocal) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Institution'),
            DashTextField(
              controller: bank,
              hint: 'Chase, Amex…',
              autofocus: true,
              errorText: fieldErrors['institution'],
            ),
            const SizedBox(height: 12),
            const DashFieldLabel('Account type'),
            DashDropdown<String>(
              value: type,
              items: const [
                'Checking',
                'Savings',
                'Credit',
                'Cash',
                'IOU',
                'Investment',
              ],
              labelOf: (v) => v == 'IOU' ? 'IOU (shared expenses)' : v,
              onChanged: (v) => setLocal(() => type = v),
            ),
            const SizedBox(height: 12),
            const DashFieldLabel('Last 4 digits'),
            DashTextField(
              controller: last4,
              hint: '4242',
              errorText: fieldErrors['lastFour'],
            ),
            const SizedBox(height: 12),
            const DashFieldLabel('Starting balance'),
            DashTextField(
              controller: balance,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              errorText: fieldErrors['balance'],
            ),
            const SizedBox(height: 16),
            sheetCancelSave(
              context: ctx,
              saveLabel: 'Connect',
              onSave: () async {
                final name = bank.text.trim();
                final institutionErr = requiredText(name, 'Institution');
                final lastFourErr = optionalLastFour(last4.text);
                final balanceErr = accountBalanceAmount(balance.text, type);
                final errors = <String, String?>{
                  if (institutionErr != null) 'institution': institutionErr,
                  if (lastFourErr != null) 'lastFour': lastFourErr,
                  if (balanceErr != null) 'balance': balanceErr,
                };
                setLocal(() => fieldErrors = errors);
                if (hasFieldErrors(errors)) {
                  toast(
                    ctx,
                    firstFieldError(errors) ?? 'Fix the highlighted fields',
                  );
                  return;
                }
                final suffix = last4.text.replaceAll(RegExp(r'\D'), '');
                final created = await accounts.create(
                  institution: name,
                  type: type,
                  lastFour: suffix,
                  balance: double.tryParse(balance.text) ?? 0,
                );
                if (!ctx.mounted) return;
                if (created == null) {
                  toast(ctx, 'Could not connect account');
                  return;
                }
                Navigator.pop(ctx);
                _go(DashTab.accounts);
                if (!mounted) return;
                toast(
                  context,
                  suffix.isEmpty
                      ? 'Connected $name · $type'
                      : 'Connected $name · $type ····$suffix',
                );
              },
            ),
          ],
        );
      },
    );
    bank.dispose();
    last4.dispose();
    balance.dispose();
  }

  Future<void> _confirmLogout() async {
    final style = DashStyleScope.maybeOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text(
            'You will return to the landing screen. AI insights stay on this device until you sign in again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: style?.primary ?? AppColors.ink,
              ),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );
    if (ok == true && mounted) {
      await goLoggedOut(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when appearance (light/dark) changes.
    VariationScope.of(context);
    final style = DashVariantStyle.of(context);
    final spaces = _spaces ?? SpacesController.fake();
    final accounts = _accounts ?? AccountsController.fake();
    final transactions = _transactions ?? TransactionsController.fake();
    final categories = _categories ?? CategoriesController.fake();
    final recurring = _recurring ?? RecurringController.fake();
    final investments = _investments ?? InvestmentsController.fake();
    final goals = _goals ?? GoalsController.fake();

    return SpacesScope(
      controller: spaces,
      child: AccountsScope(
        controller: accounts,
        child: TransactionsScope(
          controller: transactions,
          child: CategoriesScope(
            controller: categories,
            child: RecurringScope(
              controller: recurring,
              child: InvestmentsScope(
                controller: investments,
                child: GoalsScope(
                  controller: goals,
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      spaces,
                      accounts,
                      transactions,
                      categories,
                      recurring,
                      investments,
                      goals,
                    ]),
                    builder: (context, _) {
                      return DashStyleScope(
                        style: style,
                        child: _shellChrome(
                          context: context,
                          style: style,
                          spaces: spaces,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _tabPages(SpacesController spaces, DashVariantStyle style) {
    return [
      HomeScreen(
        style: style,
        onRefresh: _refreshSpaceData,
        onViewTransactions: () =>
            _go(DashTab.transactions, clearFilter: true),
        onViewAccounts: () => _go(DashTab.accounts),
        onViewCategories: () => _go(DashTab.categories),
        onViewGoals: () => _openGoals(
          openContribute: true,
          contributeGoalName: 'Emergency fund',
        ),
        onConnectBank: _connectBank,
        onOpenAgent: _enterAgentMode,
      ),
      TransactionsScreen(
        categoryFilter: _txnCategoryFilter,
        openReconcileOnStart: _openReconcile,
        onRefresh: _refreshSpaceData,
      ),
      CategoriesScreen(
        onOpenCategory: (name) => _go(
          DashTab.transactions,
          categoryFilter: name,
        ),
        onRefresh: _refreshSpaceData,
      ),
      AccountsScreen(onRefresh: _refreshSpaceData),
      MoreScreen(
        onRecurring: _openRecurring,
        onInvestments: _openInvestments,
        onGoals: _openGoals,
        onReports: _openReports,
        onSettings: _openSettings,
        onUsersPermissions: _openUsersPermissions,
        onManagePlan: () => _openSettings(section: 'plan'),
        onReconcile: _goReconcile,
        onAgentMode: _enterAgentMode,
        onLogout: _confirmLogout,
        onRefresh: _refreshSpaceData,
        showGoals: spaces.hasFeature('goals'),
        showInvestments: spaces.hasFeature('investments'),
      ),
    ];
  }

  Future<void> _refreshSpaceData() async {
    final spaces = _spaces;
    final id = spaces?.spaceId;
    if (spaces == null || id == null || id.isEmpty) return;
    await Future.wait([
      spaces.load(),
      if (_accounts != null) _accounts!.loadForSpace(id),
      if (_transactions != null) _transactions!.loadForSpace(id),
      if (_categories != null) _categories!.loadForSpace(id),
      if (_recurring != null) _recurring!.loadForSpace(id),
      if (_investments != null) _investments!.loadForSpace(id),
      if (_goals != null) _goals!.loadForSpace(id),
    ]);
  }

  Widget _pageView(SpacesController spaces, DashVariantStyle style) {
    return PageView(
      controller: _pages,
      physics: const NeverScrollableScrollPhysics(),
      children: _tabPages(spaces, style),
    );
  }

  Widget _shellChrome({
    required BuildContext context,
    required DashVariantStyle style,
    required SpacesController spaces,
  }) {
    // Agent mode: keep space switcher + exit only (hide search/bell/nav).
    // Enter agent mode via long-press on the home greeting mascot.
    final chromeActions = <Widget>[
      if (_agentMode)
        IconButton(
          tooltip: 'Exit agent mode',
          onPressed: () => _setAgentMode(false),
          icon: Icon(Icons.close_rounded, color: context.dashInk, size: 22),
        )
      else ...[
        IconButton(
          tooltip: 'Search',
          onPressed: () => _openCommandSearch(context),
          icon: Icon(
            Icons.search_rounded,
            color: context.dashInk,
            size: 22,
          ),
        ),
        NotificationBellButton(onOpenItem: _handleNotification),
      ],
    ];

    final Widget spaceBar;
    if (style.showSpaceBar || _agentMode) {
      spaceBar = SpaceSwitcherBar(trailing: chromeActions);
    } else {
      spaceBar = SizedBox(
        height: 48,
        child: Row(
          children: [
            const Spacer(),
            ...chromeActions,
            const SizedBox(width: 4),
          ],
        ),
      );
    }

    return DashNavChrome(
      selected: _tab,
      style: style,
      spaceBar: spaceBar,
      hideBottomNav: _agentMode,
      onSelect: (tab) => _go(
        tab,
        clearFilter: tab == DashTab.transactions,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_agentMode ? 'agent' : 'dash'),
          child: _agentMode
              ? const AgentModeSurface()
              : _pageView(spaces, style),
        ),
      ),
    );
  }
}
