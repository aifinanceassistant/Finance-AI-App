import 'package:flutter/material.dart';

import '../auth/auth_navigation.dart';
import '../auth/auth_scope.dart';
import '../theme/app_theme.dart';
import '../variations/models.dart';
import 'accounts_controller.dart';
import 'accounts_scope.dart';
import 'categories_controller.dart';
import 'categories_scope.dart';
import 'goals_controller.dart';
import 'goals_scope.dart';
import 'investments_controller.dart';
import 'investments_scope.dart';
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

enum DashTab { home, transactions, categories, accounts, more }

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, this.initialTab = DashTab.home});

  final DashTab initialTab;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  late DashTab _tab = widget.initialTab;
  late final PageController _pages = PageController(initialPage: _tab.index);
  String? _txnCategoryFilter;
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
    final style = DashVariantStyle.forVariation(
      VariationScope.read(context).dashboard,
    );
    final goals = _goals ?? GoalsController.fake();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
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
    final style = DashVariantStyle.forVariation(
      VariationScope.read(context).dashboard,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _withSpaces(
          DashStyleScope(
            style: style,
            child: const ReportsScreen(),
          ),
        ),
      ),
    );
  }

  void _openRecurring() {
    final style = DashVariantStyle.forVariation(
      VariationScope.read(context).dashboard,
    );
    final recurring = _recurring ?? RecurringController.fake();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
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
    final style = DashVariantStyle.forVariation(
      VariationScope.read(context).dashboard,
    );
    final investments = _investments ?? InvestmentsController.fake();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
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
    final style = DashVariantStyle.forVariation(
      VariationScope.read(context).dashboard,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _withSpaces(
          DashStyleScope(
            style: style,
            child: SettingsScreen(
              onLogout: _confirmLogout,
              initialSection: section,
            ),
          ),
        ),
      ),
    );
  }

  void _openUsersPermissions() {
    final style = DashVariantStyle.forVariation(
      VariationScope.read(context).dashboard,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
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
    await showDashSheet<void>(
      context: context,
      title: 'Connect bank',
      description: 'Link an institution to sync balances',
      builder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DashFieldLabel('Institution'),
          DashTextField(controller: bank, hint: 'Chase, Amex…', autofocus: true),
          const SizedBox(height: 12),
          const DashFieldLabel('Account type'),
          DashDropdown<String>(
            value: type,
            items: const ['Checking', 'Savings', 'Credit', 'Cash'],
            labelOf: (v) => v,
            onChanged: (v) => setLocal(() => type = v),
          ),
          const SizedBox(height: 12),
          const DashFieldLabel('Last 4 digits'),
          DashTextField(controller: last4, hint: '4242'),
          const SizedBox(height: 12),
          const DashFieldLabel('Starting balance'),
          DashTextField(
            controller: balance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          sheetCancelSave(
            context: ctx,
            saveLabel: 'Connect',
            onSave: () async {
              final name = bank.text.trim();
              if (name.isEmpty) {
                toast(ctx, 'Enter an institution name');
                return;
              }
              final digits = last4.text.replaceAll(RegExp(r'\D'), '');
              final suffix = digits.length >= 4
                  ? digits.substring(digits.length - 4)
                  : (digits.isEmpty ? '0000' : digits.padLeft(4, '0'));
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
              toast(context, 'Connected $name · $type ····$suffix');
            },
          ),
        ],
      ),
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
    final style = DashVariantStyle.forVariation(
      VariationScope.read(context).dashboard,
    );
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
                child: Scaffold(
                  backgroundColor: style.scaffold,
                  body: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        const SpaceSwitcherBar(),
                        Expanded(
                          child: PageView(
                            controller: _pages,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              HomeScreen(
                                style: style,
                                onViewTransactions: () =>
                                    _go(DashTab.transactions, clearFilter: true),
                                onViewAccounts: () => _go(DashTab.accounts),
                                onViewCategories: () => _go(DashTab.categories),
                                onViewGoals: () => _openGoals(
                                  openContribute: true,
                                  contributeGoalName: 'Emergency fund',
                                ),
                                onConnectBank: _connectBank,
                              ),
                              TransactionsScreen(
                                categoryFilter: _txnCategoryFilter,
                              ),
                              CategoriesScreen(
                                onOpenCategory: (name) => _go(
                                  DashTab.transactions,
                                  categoryFilter: name,
                                ),
                              ),
                              const AccountsScreen(),
                              MoreScreen(
                                onRecurring: _openRecurring,
                                onInvestments: _openInvestments,
                                onGoals: _openGoals,
                                onReports: _openReports,
                                onSettings: _openSettings,
                                onUsersPermissions: _openUsersPermissions,
                                onManagePlan: () =>
                                    _openSettings(section: 'plan'),
                                onLogout: _confirmLogout,
                                showGoals: spaces.hasFeature('goals'),
                                showInvestments:
                                    spaces.hasFeature('investments'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  bottomNavigationBar: NavigationBar(
                    height: 68,
                    backgroundColor: style.navBackground,
                    indicatorColor: style.primary.withValues(alpha: 0.12),
                    selectedIndex: _tab.index,
                    onDestinationSelected: (i) {
                      final tab = DashTab.values[i];
                      _go(tab, clearFilter: tab == DashTab.transactions);
                    },
                    labelBehavior: MediaQuery.sizeOf(context).width < 380
                        ? NavigationDestinationLabelBehavior.onlyShowSelected
                        : NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: [
                      const NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon:
                            Icon(Icons.home_rounded, color: AppColors.brand),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(
                          Icons.receipt_long_rounded,
                          color: style.primary,
                        ),
                        label: style.navLabel,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.label_outline_rounded),
                        selectedIcon: Icon(
                          Icons.label_rounded,
                          color: style.primary,
                        ),
                        label: 'Categories',
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.account_balance_outlined),
                        selectedIcon: Icon(
                          Icons.account_balance_rounded,
                          color: style.primary,
                        ),
                        label: 'Accounts',
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.grid_view_outlined),
                        selectedIcon: Icon(
                          Icons.grid_view_rounded,
                          color: style.primary,
                        ),
                        label: 'More',
                      ),
                    ],
                  ),
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
}
