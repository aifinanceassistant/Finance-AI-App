import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_scope.dart';
import '../../billing/stripe_billing.dart';
import '../../locale/locale_controller.dart';
import '../../onboarding/onboarding_flow.dart';
import '../../theme/app_theme.dart';
import '../accounts_scope.dart';
import '../dash_colors.dart';
import '../../variations/models.dart';
import '../dash_sheets.dart';
import '../data.dart';
import '../form_validation.dart';
import '../shimmer.dart';
import '../spaces_scope.dart';
import '../ui.dart';
import 'mcp_keys_screen.dart';
import 'users_permissions_screen.dart';

const _appVersion = '26.9.8+1521 (Build: 981)';

const _sections = [
  ('general', 'General'),
  ('profile', 'Profile'),
  ('preferences', 'Preferences'),
  ('users-permissions', 'Users & permissions'),
  ('mcp-keys', 'MCP & API keys'),
  ('account', 'Account'),
  ('security', 'Security'),
  ('plan', 'Plan'),
  ('subscription', 'Subscription'),
  ('banks', 'Banks'),
  ('privacy', 'Privacy'),
  ('about', 'About'),
];

const _languages = [
  ('en', 'English'),
  ('fr', 'Français'),
];

const _currencies = [
  'USD',
  'CAD',
  'EUR',
  'GBP',
  'AED',
  'SGD',
  'JPY',
  'INR',
  'MYR',
  'AUD',
  'CHF',
];

const _invoices = [
  ('inv_1042', 'Mar 2026 · Plus Family', r'$14.99'),
  ('inv_1031', 'Feb 2026 · Plus Family', r'$14.99'),
  ('inv_1020', 'Jan 2026 · Plus Family', r'$14.99'),
];

const _spaceSwitcherOptions = [
  ('tabs', 'Top tabs', 'Browser-style tabs above the dashboard'),
  ('sidebar', 'Sidebar', 'Space list in the left navigation'),
];

const _planTiers = [
  ('solo', 'Starter', r'$4.99/mo', '1 space'),
  ('team', 'Plus', r'$9.99/mo', 'Popular'),
  ('family', 'Family', r'$14.99/mo', 'Up to 5 members'),
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onLogout, this.initialSection = 'general'});

  final VoidCallback? onLogout;
  final String initialSection;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController(text: 'Alex Rivera');
  final _emailCtrl = TextEditingController(text: 'alex@financeai.app');
  final _phoneCtrl = TextEditingController(text: '+1 (415) 555-0142');
  String _initials = 'AR';
  String _currency = 'USD';
  bool _digest = true;
  bool _alerts = true;
  String _card = '4242';
  bool _budgeting = true;
  bool _rollover = false;
  bool _recurringAutoApply = false;
  bool _transactionsFoldingMode = true;
  bool _shareAnalytics = false;
  String _planId = 'team';
  String _planLabel = 'No active plan';
  String _planSubtitle = 'Start a free trial to unlock Plus';
  bool _subscriptionActive = false;
  bool _billingLoaded = false;
  String _spaceSwitcher = 'tabs';
  List<String> _tags = ['Business'];
  String _language = 'en';
  String? _nameError;
  String? _emailError;
  String? _phoneError;

  String get _email => _emailCtrl.text.trim().isEmpty
      ? 'alex@financeai.app'
      : _emailCtrl.text.trim();

  /// Prefer live AccountsController when settings was opened under the shell;
  /// fall back to [accountsStore] (kept in sync by AccountsController._publish).
  List<DemoAccount> get _banks {
    final fromScope = AccountsScope.maybeOf(context)?.accounts;
    if (fromScope != null) return fromScope;
    return accountsStore.value;
  }

  @override
  void initState() {
    super.initState();
    accountsStore.addListener(_onBanksChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ignore: discarded_futures
      _loadBilling();
      // ignore: discarded_futures
      _loadProfilePrefs();
    });
  }

  Future<void> _loadProfilePrefs() async {
    final auth = AuthScope.read(context);
    final data = await auth.apiDecode('GET', '/api/profile');
    if (!mounted || data is! Map<String, dynamic>) return;
    setState(() {
      if (data['recurringAutoApply'] is bool) {
        _recurringAutoApply = data['recurringAutoApply'] as bool;
      }
      if (data['transactionsFoldingMode'] is bool) {
        _transactionsFoldingMode = data['transactionsFoldingMode'] as bool;
      }
      final first = (data['firstName'] as String?)?.trim() ?? '';
      final last = (data['lastName'] as String?)?.trim() ?? '';
      final full = (data['full_name'] as String?)?.trim() ?? '';
      final name = [first, last].where((p) => p.isNotEmpty).join(' ');
      final display = name.isNotEmpty ? name : full;
      if (display.isNotEmpty) {
        _nameCtrl.text = display;
        final parts = display.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
        _initials = parts.take(2).map((p) => p[0].toUpperCase()).join();
      }
      final email = (data['email'] as String?)?.trim();
      if (email != null && email.isNotEmpty) _emailCtrl.text = email;
      if (data['phone'] is String) _phoneCtrl.text = data['phone'] as String;
      final currency = (data['currency'] as String?)?.trim().toUpperCase();
      if (currency != null && currency.isNotEmpty) {
        _currency = _currencies.contains(currency) ? currency : 'USD';
        DisplayCurrency.setCode(_currency);
      }
      final lang = (data['language'] as String?)?.trim().toLowerCase();
      if (lang != null && lang.isNotEmpty) {
        _language = lang.startsWith('fr') ? 'fr' : 'en';
        final localeCtrl = LocaleScope.maybeOf(context);
        if (localeCtrl != null) {
          // ignore: discarded_futures
          localeCtrl.applyCode(_language, persist: true);
        }
      }
    });
    await _refreshFxRate(AuthScope.read(context), _currency);
  }

  Future<void> _setLanguage(String code) async {
    final next = code.startsWith('fr') ? 'fr' : 'en';
    setState(() => _language = next);
    final auth = AuthScope.read(context);
    final localeCtrl = LocaleScope.maybeOf(context);
    await auth.apiDecode(
      'PATCH',
      '/api/profile',
      body: {'language': next},
    );
    if (localeCtrl != null) {
      await localeCtrl.setLanguage(next);
    }
    if (!mounted) return;
    toast(
      context,
      next == 'fr'
          ? 'Langue enregistrée · more translations rolling out'
          : 'Language saved · more translations rolling out',
    );
  }

  Future<void> _saveProfile() async {
    final nameErr = requiredText(_nameCtrl.text, 'Name');
    final emailErr = emailValidator(_emailCtrl.text);
    final phoneErr = optionalPhone(_phoneCtrl.text);
    setState(() {
      _nameError = nameErr;
      _emailError = emailErr;
      _phoneError = phoneErr;
    });
    final first = nameErr ?? emailErr ?? phoneErr;
    if (first != null) {
      toast(context, first);
      return;
    }

    final parts = _nameCtrl.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final firstName = parts.isEmpty ? '' : parts.first;
    final lastName = parts.length <= 1 ? '' : parts.sublist(1).join(' ');
    final fullName = [firstName, lastName].where((p) => p.isNotEmpty).join(' ');

    final auth = AuthScope.read(context);
    final result = await auth.apiDecode(
      'PATCH',
      '/api/profile',
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'full_name': fullName,
        'phone': _phoneCtrl.text.trim(),
      },
    );
    if (!mounted) return;
    if (result == null) {
      toast(context, 'Could not save profile');
      return;
    }
    setState(() {
      _initials = parts.take(2).map((p) => p[0].toUpperCase()).join();
      if (_initials.isEmpty) _initials = 'AR';
    });
    toast(context, 'Profile saved');
  }

  Future<void> _openHelpUrl(String path) async {
    final uri = Uri.parse('https://financeai.app$path');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) toast(context, 'Could not open link');
  }

  Future<void> _refreshFxRate(AuthController auth, String currency) async {
    final code = currency.trim().toUpperCase();
    if (code.isEmpty || code == 'USD') return;
    final data = await auth.apiDecode(
      'GET',
      '/api/currency/rate?from=${Uri.encodeQueryComponent(code)}',
    );
    if (data is! Map<String, dynamic>) return;
    final rate = (data['rate'] as num?)?.toDouble();
    if (rate == null || !rate.isFinite || rate <= 0) return;
    DisplayCurrency.setRateToUsd(code, rate);
    if (mounted) setState(() {});
  }

  Future<void> _setDisplayCurrency(String value) async {
    setState(() => _currency = value);
    DisplayCurrency.setCode(value);
    final auth = AuthScope.read(context);
    await auth.apiDecode(
      'PATCH',
      '/api/profile',
      body: {'currency': value},
    );
    await _refreshFxRate(auth, value);
  }

  Future<void> _setRecurringAutoApply(bool value) async {
    setState(() => _recurringAutoApply = value);
    final auth = AuthScope.read(context);
    await auth.apiDecode(
      'PATCH',
      '/api/profile',
      body: {'recurringAutoApply': value},
    );
  }

  Future<void> _setTransactionsFoldingMode(bool value) async {
    setState(() => _transactionsFoldingMode = value);
    final auth = AuthScope.read(context);
    await auth.apiDecode(
      'PATCH',
      '/api/profile',
      body: {'transactionsFoldingMode': value},
    );
  }

  Future<void> _loadBilling() async {
    final auth = AuthScope.read(context);
    final data = await fetchBillingStatus(auth);
    if (!mounted || data == null) return;
    final active = data['subscriptionActive'] == true;
    final label = (data['planLabel'] as String?) ?? 'No subscription';
    final seats = (data['seatLimit'] as num?)?.toInt() ?? 1;
    setState(() {
      _billingLoaded = true;
      _subscriptionActive = active;
      _planLabel = active ? label : 'No active plan';
      _planSubtitle = active
          ? '$seats space${seats == 1 ? '' : 's'} included'
          : 'Start a free trial to unlock Plus';
    });
  }

  Future<void> _manageBilling({String plan = 'team'}) async {
    final auth = AuthScope.read(context);
    if (_subscriptionActive) {
      final err = await openStripeBillingPortal(auth);
      if (!mounted) return;
      if (err != null) toast(context, err);
      return;
    }
    final err = await startStripeCheckout(
      auth,
      billing: 'yearly',
      plan: plan,
    );
    if (!mounted) return;
    if (err != null) toast(context, err);
  }

  @override
  void dispose() {
    accountsStore.removeListener(_onBanksChanged);
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _onBanksChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DashModalScaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const DashFeedChrome(
            title: 'Profile and settings',
            subtitle: 'Account, plan, privacy, and connections',
            showPrimary: false,
          ),
          for (final s in _sections)
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: ExpansionTile(
                key: PageStorageKey<String>('settings-stack-${s.$1}'),
                initiallyExpanded: false,
                maintainState: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                backgroundColor: Colors.transparent,
                collapsedBackgroundColor: Colors.transparent,
                shape: Border(
                  bottom: BorderSide(color: context.dashLine),
                ),
                collapsedShape: Border(
                  bottom: BorderSide(color: context.dashLine),
                ),
                iconColor: context.dashMute,
                collapsedIconColor: context.dashMute,
                textColor: context.dashInk,
                collapsedTextColor: context.dashInk,
                title: Text(
                  s.$2,
                  style: TextStyle(
                    color: context.dashInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                children: [_bodyFor(s.$1)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bodyFor(String section) {
    switch (section) {
      case 'profile':
        return _profileBody();
      case 'preferences':
        return _preferencesBody();
      case 'users-permissions':
        return _usersPermissionsBody();
      case 'mcp-keys':
        return _mcpKeysBody();
      case 'account':
        return _accountBody();
      case 'security':
        return _securityBody();
      case 'plan':
        return _planBody();
      case 'subscription':
        return _subscriptionBody();
      case 'banks':
        return _banksBody();
      case 'privacy':
        return _privacyBody();
      case 'about':
        return _aboutBody();
      case 'general':
      default:
        return _generalBody();
    }
  }

  Widget _mcpKeysBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Create keys for Claude, ChatGPT, and other MCP clients.',
          style: TextStyle(color: context.dashMute, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 14),
        AccentButton(
          label: 'Manage MCP & API keys',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const McpKeysScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _usersPermissionsBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Manage who can access this space and what they can do.',
          style: TextStyle(color: context.dashMute, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 14),
        AccentButton(
          label: 'Open users & permissions',
          onPressed: () {
            final spaces = SpacesScope.maybeOf(context);
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => spaces != null
                    ? SpacesScope(
                        controller: spaces,
                        child: const UsersPermissionsScreen(),
                      )
                    : const UsersPermissionsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _generalBody() {
    final variations = VariationScope.of(context);
    final appearance = variations.appearance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BlockTitle('Appearance'),
        _SettingsRow(
          title: 'Theme',
          body: 'Customize how FinanceAI looks',
          trailing: const SizedBox.shrink(),
          showDivider: false,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final option in AppAppearance.values) ...[
              if (option != AppAppearance.values.first) const SizedBox(width: 8),
              Expanded(
                child: _AppearanceChip(
                  option: option,
                  selected: appearance == option,
                  onTap: () {
                    VariationScope.read(context).setAppearance(option);
                    toast(context, 'Theme · ${option.label}');
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        const _BlockTitle('Budgeting'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable budgeting'),
          subtitle: const Text('Set monthly budgets for your categories'),
          value: _budgeting,
          onChanged: (v) => setState(() => _budgeting = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable rollover'),
          subtitle: const Text('Allow budgets to be spent across months'),
          value: _rollover,
          onChanged: (v) => setState(() => _rollover = v),
        ),
        const SizedBox(height: 8),
        const _BlockTitle('Recurring'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Recurring transactions auto apply'),
          subtitle: const Text(
            'Post due recurring rules when you open Transactions or Recurring, and on the scheduled cron',
          ),
          value: _recurringAutoApply,
          onChanged: (v) {
            // ignore: discarded_futures
            _setRecurringAutoApply(v);
          },
        ),
        const SizedBox(height: 8),
        const _BlockTitle('Transactions'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Folding mode'),
          subtitle: const Text(
            'When scrolling Transactions, fold search and cashflow stats into a sticky header',
          ),
          value: _transactionsFoldingMode,
          onChanged: (v) {
            // ignore: discarded_futures
            _setTransactionsFoldingMode(v);
          },
        ),
        const SizedBox(height: 8),
        const _BlockTitle('Tags'),
        _SettingsRow(
          title: 'Manage tags',
          body: 'Use tags to group together any transactions',
          action: '${_tags.length} tag${_tags.length == 1 ? '' : 's'}',
          onTap: _tagsSheet,
          showDivider: false,
        ),
      ],
    );
  }

  Widget _profileBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: context.dashWash,
              child: Text(
                _initials,
                style: const TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile photo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.dashInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LinkAction(label: 'Change photo', onTap: _photoSheet),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const DashFieldLabel('Full name'),
        DashTextField(
          controller: _nameCtrl,
          hint: 'Your name',
          errorText: _nameError,
        ),
        const SizedBox(height: 12),
        const DashFieldLabel('Email'),
        DashTextField(
          controller: _emailCtrl,
          hint: 'you@email.com',
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
        ),
        const SizedBox(height: 12),
        const DashFieldLabel('Phone'),
        DashTextField(
          controller: _phoneCtrl,
          hint: '+1 …',
          keyboardType: TextInputType.phone,
          errorText: _phoneError,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: AccentButton(
            label: 'Save',
            onPressed: _saveProfile,
          ),
        ),
      ],
    );
  }

  Widget _preferencesBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashFieldLabel('Language'),
        DashDropdown<String>(
          value: _language,
          items: _languages.map((e) => e.$1).toList(),
          onChanged: (v) {
            // ignore: discarded_futures
            _setLanguage(v);
          },
          labelOf: (code) => _languages
              .firstWhere((e) => e.$1 == code, orElse: () => _languages.first)
              .$2,
        ),
        const SizedBox(height: 16),
        const DashFieldLabel('Display currency'),
        DashDropdown<String>(
          value: _currency,
          items: _currencies,
          onChanged: (v) => _setDisplayCurrency(v),
          labelOf: (c) => c,
        ),
        const SizedBox(height: 16),
        const DashFieldLabel('Space switcher'),
        const SizedBox(height: 4),
        Text(
          'Choose where you switch between spaces',
          style: TextStyle(
            color: context.dashMute,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        for (final opt in _spaceSwitcherOptions) ...[
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _spaceSwitcher = opt.$1),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _spaceSwitcher == opt.$1
                        ? AppColors.accent
                        : context.dashLine,
                  ),
                  color: _spaceSwitcher == opt.$1
                      ? context.dashElevated
                      : context.dashPanel,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opt.$2,
                      style: TextStyle(
                        color: context.dashInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      opt.$3,
                      style: TextStyle(
                        color: context.dashMute,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Morning digest email'),
          subtitle: const Text('A short briefing when new insights are ready'),
          value: _digest,
          onChanged: (v) => setState(() => _digest = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Payment alerts'),
          subtitle: const Text('Notify on failed or unusual transactions'),
          value: _alerts,
          onChanged: (v) => setState(() => _alerts = v),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: AccentButton(
            label: 'Save',
            onPressed: () => toast(context, 'Preferences saved'),
          ),
        ),
      ],
    );
  }

  Widget _accountBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BlockTitle('Information'),
        _SettingsRow(
          title: 'Email',
          body: _email,
          action: 'Copy',
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: _email));
            if (mounted) toast(context, 'Email copied');
          },
        ),
        _SettingsRow(
          title: 'Reset password',
          action: 'Contact support',
          onTap: _passwordSheet,
        ),
        _SettingsRow(
          title: 'Two-factor authentication',
          body: 'Authenticator codes · coming soon',
          action: 'Coming soon',
          onTap: () => toast(context, 'Two-factor authentication · coming soon'),
        ),
        const SizedBox(height: 12),
        const _BlockTitle('Actions'),
        _SettingsRow(
          title: 'Restart onboarding',
          body: 'Go through onboarding without logging out',
          action: 'Restart',
          onTap: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) => const OnboardingFlow(),
              ),
              (route) => false,
            );
          },
        ),
        _SettingsRow(
          title: 'Export all transactions',
          body: 'Download a detailed CSV of your data',
          action: 'Download',
          onTap: () async {
            await Clipboard.setData(
              const ClipboardData(
                text: 'merchant,amount,date\nCoffee,4.50,2026-03-01',
              ),
            );
            if (mounted) toast(context, 'CSV copied to clipboard');
          },
        ),
        _SettingsRow(
          title: 'Clear local cache',
          body: 'Use if support asked you to clear cache',
          action: 'Clear cache',
          onTap: () => toast(context, 'Local cache cleared'),
        ),
        const SizedBox(height: 12),
        const _BlockTitle('Privacy'),
        _SettingsRow(
          title: 'Your privacy choices',
          body: 'We don’t ever sell your financial data',
          action: 'Manage',
          onTap: _privacyChoicesSheet,
          showDivider: false,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () {
                if (widget.onLogout != null) {
                  widget.onLogout!();
                } else {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              child: const Text('Log out'),
            ),
            OutlinedButton(
              onPressed: () =>
                  toast(context, 'Log out of all devices · coming soon'),
              child: const Text('Log out of all devices'),
            ),
            TextButton(
              onPressed: _deleteSheet,
              child: const Text(
                'Delete account',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _securityBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsRow(
          title: 'Password',
          body: 'Last changed 42 days ago',
          action: 'Update',
          onTap: _passwordSheet,
        ),
        _SettingsRow(
          title: 'Authenticator',
          body: 'Two-factor codes via authenticator app · coming soon',
          action: 'Coming soon',
          onTap: () => toast(context, 'Two-factor authentication · coming soon'),
        ),
        _SettingsRow(
          title: 'Active sessions',
          body: 'Sign out of other devices · coming soon',
          action: 'Coming soon',
          onTap: () => toast(context, 'Session management · coming soon'),
          showDivider: false,
        ),
      ],
    );
  }

  Widget _planBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.dashSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.dashLine),
          ),
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
                        if (_billingLoaded)
                          Text(
                            _planLabel,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: context.dashInk,
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(top: 2, bottom: 2),
                            child: ShimmerBox(width: 120, height: 16),
                          ),
                        const SizedBox(height: 2),
                        if (_billingLoaded)
                          Text(
                            _planSubtitle,
                            style: TextStyle(
                              color: context.dashMute,
                              fontSize: 13,
                            ),
                          )
                        else
                          const ShimmerBox(width: 180, height: 12),
                      ],
                    ),
                  ),
                  AccentButton(
                    label: _subscriptionActive ? 'Manage' : 'Subscribe',
                    onPressed: () => _manageBilling(plan: _planId),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SettingsRow(
          title: 'Payment & invoices',
          body: 'Update card, cancel, or download receipts in Stripe',
          action: 'Open',
          onTap: () => _manageBilling(plan: _planId),
          showDivider: false,
        ),
        const SizedBox(height: 12),
        for (final tier in _planTiers) ...[
          Material(
            color: _planId == tier.$1
                ? AppColors.brand.withValues(alpha: 0.08)
                : context.dashSurface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _planId = tier.$1),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _planId == tier.$1
                        ? AppColors.brand
                        : context.dashLine,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tier.$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tier.$3,
                            style: TextStyle(
                              color: context.dashMute,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      tier.$4,
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (!_subscriptionActive)
          AccentButton(
            label: 'Start ${_planTiers.firstWhere((t) => t.$1 == _planId).$2}',
            onPressed: () => _manageBilling(plan: _planId),
          ),
      ],
    );
  }

  Widget _subscriptionBody() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.dashSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.dashLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.dashWash,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.smart_toy_outlined,
                      color: AppColors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI credits',
                          style: TextStyle(
                            color: context.dashInk,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '842 of 1,200 · Resets Apr 1',
                          style: TextStyle(
                            color: context.dashMute,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const ProgressTrack(
                progress: 842 / 1200,
                color: AppColors.accent,
                height: 6,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _billingLoaded ? _planLabel : '…',
                          style: TextStyle(
                            color: context.dashInk,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _billingLoaded
                              ? _planSubtitle
                              : 'Loading plan…',
                          style: TextStyle(
                            color: context.dashMute,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  LinkAction(
                    label: _subscriptionActive ? 'Manage' : 'Subscribe',
                    onTap: () => _manageBilling(plan: _planId),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Subscribe to FinanceAI today',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'See for yourself how FinanceAI can help you own your financial future.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.dashMute, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 14),
        const Text(
          '21,000 5-star reviews',
          style: TextStyle(
            color: AppColors.brand,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.dashSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.dashLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('★★★★★', style: TextStyle(color: Color(0xFFF5B942))),
              SizedBox(height: 6),
              Text(
                'Simply the best',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                'This is by far the best budgeting app I have ever used.',
                style: TextStyle(color: context.dashMute, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AccentButton(
          label: 'Get started',
          onPressed: _subscribeSheet,
        ),
        const SizedBox(height: 10),
        Text(
          'Sales tax may apply. Subscription renews automatically. Cancel anytime.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.dashSoftMute, fontSize: 11),
        ),
      ],
    );
  }

  Widget _banksBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Banks & institutions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            LinkAction(label: '+ New', onTap: _connectBank),
          ],
        ),
        const SizedBox(height: 8),
        if (_banks.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Text(
              'No institutions connected.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.dashMute,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          for (var i = 0; i < _banks.length; i++)
            _SettingsRow(
              title: _banks[i].bank,
              body: '${_banks[i].type} · ${_banks[i].number}',
              action: 'Disconnect',
              onTap: () {
                final key = '${_banks[i].bank}-${_banks[i].number}';
                accountsStore.value = _banks
                    .where((b) => '${b.bank}-${b.number}' != key)
                    .toList();
                toast(context, 'Institution disconnected');
              },
              showDivider: i < _banks.length - 1,
            ),
      ],
    );
  }

  Widget _privacyBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsRow(
          title: 'Download your data',
          body: 'Export account and transaction history',
          action: 'Request',
          onTap: () => toast(context, 'Export started · link emailed'),
        ),
        _SettingsRow(
          title: 'Delete account',
          body: 'Permanently remove your FinanceAI account',
          action: 'Delete',
          onTap: _deleteSheet,
        ),
        const SizedBox(height: 12),
        Text(
          'Legal',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: context.dashSoftMute,
          ),
        ),
        const SizedBox(height: 4),
        _SettingsRow(
          title: 'Terms of Service',
          action: 'View',
          onTap: () => _legalSheet(
            'Terms of Service',
            'By using FinanceAI you agree to our service terms. '
            'You are responsible for the accuracy of linked account credentials. '
            'Subscriptions renew automatically until canceled. '
            'We may update these terms with notice in the app.',
          ),
        ),
        _SettingsRow(
          title: 'Privacy Policy',
          action: 'View',
          onTap: () => _legalSheet(
            'Privacy Policy',
            'FinanceAI processes account balances and transactions to power '
            'budgeting and AI insights. We do not sell your financial data. '
            'Bank connections use encrypted partners. You can export or delete '
            'your data from Settings at any time.',
          ),
        ),
        _SettingsRow(
          title: 'California Privacy Notice',
          action: 'View',
          onTap: () => _legalSheet(
            'California Privacy Notice',
            'California residents may request access, deletion, or correction '
            'of personal information. We do not sell personal information as '
            'defined under the CCPA. Contact support@financeai.app to exercise '
            'your rights.',
          ),
          showDivider: false,
        ),
      ],
    );
  }

  Widget _aboutBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BlockTitle('About'),
        _SettingsRow(
          title: 'Version',
          body: _appVersion,
          action: 'Copy',
          onTap: () async {
            await Clipboard.setData(const ClipboardData(text: _appVersion));
            if (mounted) toast(context, 'Version copied');
          },
        ),
        const SizedBox(height: 8),
        const _BlockTitle('Help'),
        _SettingsRow(
          title: 'FAQ',
          body: 'Common questions about FinanceAI',
          action: 'Open',
          onTap: () => _openHelpUrl('/faq'),
        ),
        _SettingsRow(
          title: 'Docs',
          body: 'Guides and product documentation',
          action: 'Open',
          onTap: () => _openHelpUrl('/docs'),
        ),
        _SettingsRow(
          title: 'Browse help articles',
          action: 'Open help center',
          onTap: _helpSheet,
        ),
        _SettingsRow(
          title: 'Contact us',
          action: 'Contact support',
          onTap: _contactSheet,
        ),
        const SizedBox(height: 8),
        const _BlockTitle('Legal'),
        _SettingsRow(
          title: 'Terms of service',
          action: 'View',
          onTap: () => _legalSheet(
            'Terms of Service',
            'By using FinanceAI you agree to our service terms. '
            'You are responsible for the accuracy of linked account credentials. '
            'Subscriptions renew automatically until canceled. '
            'We may update these terms with notice in the app.',
          ),
        ),
        _SettingsRow(
          title: 'Privacy policy',
          action: 'View',
          onTap: () => _legalSheet(
            'Privacy Policy',
            'FinanceAI processes account balances and transactions to power '
            'budgeting and AI insights. We do not sell your financial data. '
            'Bank connections use encrypted partners. You can export or delete '
            'your data from Settings at any time.',
          ),
        ),
        _SettingsRow(
          title: 'California Privacy Notice',
          action: 'View',
          onTap: () => _legalSheet(
            'California Privacy Notice',
            'California residents may request access, deletion, or correction '
            'of personal information. We do not sell personal information as '
            'defined under the CCPA. Contact support@financeai.app to exercise '
            'your rights.',
          ),
          showDivider: false,
        ),
      ],
    );
  }

  Future<void> _photoSheet() async {
    await showDashSheet<void>(
      context: context,
      title: 'Change photo',
      description: 'Use initials for now — image upload ships next',
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Preview:',
                  style: TextStyle(color: context.dashMute, fontSize: 13),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: context.dashWash,
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            sheetCancelSave(
              context: ctx,
              saveLabel: 'Update',
              onSave: () {
                final next = _nameCtrl.text
                    .trim()
                    .split(RegExp(r'\s+'))
                    .where((p) => p.isNotEmpty)
                    .take(2)
                    .map((p) => p[0].toUpperCase())
                    .join();
                setState(() => _initials = next.isEmpty ? 'AR' : next);
                Navigator.pop(ctx);
                toast(context, 'Avatar updated');
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _passwordSheet() async {
    final pass = TextEditingController();
    final confirm = TextEditingController();
    String? passError;
    String? confirmError;
    await showDashSheet<void>(
      context: context,
      title: 'Reset password',
      description: 'Or contact support if you can’t access email',
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('New password'),
            DashTextField(
              controller: pass,
              hint: '••••••••',
              obscureText: true,
              autofocus: true,
              errorText: passError,
            ),
            const SizedBox(height: 12),
            const DashFieldLabel('Confirm password'),
            DashTextField(
              controller: confirm,
              hint: '••••••••',
              obscureText: true,
              errorText: confirmError,
            ),
            const SizedBox(height: 10),
            GhostButton(
              label: 'Contact support',
              onPressed: () {
                Navigator.pop(ctx);
                toast(context, 'Support · password reset');
              },
            ),
            const SizedBox(height: 12),
            sheetCancelSave(
              context: ctx,
              saveLabel: 'Update',
              onSave: () {
                String? pErr;
                String? cErr;
                if (pass.text.trim().isEmpty) {
                  pErr = 'Password is required.';
                } else if (pass.text.length < 8) {
                  pErr = 'Use at least 8 characters';
                }
                if (pass.text != confirm.text) {
                  cErr = 'Passwords must match';
                }
                setSheet(() {
                  passError = pErr;
                  confirmError = cErr;
                });
                if (pErr != null || cErr != null) {
                  toast(context, pErr ?? cErr!);
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                final auth = AuthScope.read(context);
                Navigator.pop(ctx);
                // ignore: discarded_futures
                () async {
                  final err = await auth.updatePassword(pass.text);
                  if (err != null) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(err),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Password updated'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }();
              },
            ),
          ],
        );
      },
    );
    pass.dispose();
    confirm.dispose();
  }

  Future<void> _paymentSheet() async {
    final card = TextEditingController(text: _card);
    String? cardError;
    await showDashSheet<void>(
      context: context,
      title: 'Update payment method',
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Card last 4'),
            DashTextField(
              controller: card,
              hint: '4242',
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              errorText: cardError,
            ),
            const SizedBox(height: 16),
            sheetCancelSave(
              context: ctx,
              saveLabel: 'Save card',
              onSave: () {
                final err = optionalLastFour(card.text);
                setSheet(() => cardError = err);
                if (err != null) {
                  toast(context, err);
                  return;
                }
                final digits = card.text.replaceAll(RegExp(r'\D'), '');
                final next = digits.isEmpty ? _card : digits;
                setState(() => _card = next);
                Navigator.pop(ctx);
                toast(context, 'Card updated · Visa ···· $next');
              },
            ),
          ],
        );
      },
    );
    card.dispose();
  }

  Future<void> _invoicesSheet() async {
    await showDashSheet<void>(
      context: context,
      title: 'Invoices',
      description: 'Download past receipts',
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final inv in _invoices) ...[
              _SettingsRow(
                title: inv.$2,
                body: inv.$1,
                action: inv.$3,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: inv.$1));
                  if (mounted) toast(context, 'Invoice ${inv.$1} copied');
                },
                showDivider: false,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: LinkAction(
                  label: 'Save',
                  onTap: () async {
                    final receipt = StringBuffer()
                      ..writeln('FinanceAI receipt')
                      ..writeln('Invoice: ${inv.$1}')
                      ..writeln('Period: ${inv.$2}')
                      ..writeln('Amount: ${inv.$3}')
                      ..writeln('Billed to: $_email')
                      ..writeln('Payment: Visa ····$_card');
                    await Clipboard.setData(
                      ClipboardData(text: receipt.toString()),
                    );
                    if (mounted) {
                      toast(context, 'Receipt saved to clipboard');
                    }
                  },
                ),
              ),
              if (inv != _invoices.last)
                Divider(height: 20, color: context.dashLine),
            ],
            const SizedBox(height: 12),
            GhostButton(
              label: 'Close',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        );
      },
    );
  }

  Future<void> _subscribeSheet() async {
    var selected = _planId;
    await showDashSheet<void>(
      context: context,
      title: 'Choose your plan',
      description: 'Confirm a Plus tier — cancel anytime',
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final tier in _planTiers) ...[
              Material(
                color: selected == tier.$1
                    ? AppColors.brand.withValues(alpha: 0.08)
                    : context.dashSurface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setSheet(() => selected = tier.$1),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected == tier.$1
                            ? AppColors.brand
                            : context.dashLine,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tier.$2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tier.$3,
                                style: TextStyle(
                                  color: context.dashMute,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          tier.$4,
                          style: TextStyle(
                            color: AppColors.brand,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          selected == tier.$1
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: selected == tier.$1
                              ? AppColors.brand
                              : context.dashSoftMute,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              'Sales tax may apply. Subscription renews automatically.',
              style: TextStyle(color: context.dashSoftMute, fontSize: 11),
            ),
            const SizedBox(height: 14),
            sheetCancelSave(
              context: ctx,
              saveLabel: 'Confirm',
              onSave: () {
                final label = _planTiers
                    .firstWhere((t) => t.$1 == selected, orElse: () => _planTiers.last)
                    .$2;
                setState(() => _planId = selected);
                Navigator.pop(ctx);
                toast(context, 'Subscribed · $label');
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _legalSheet(String title, String body) async {
    await showDashSheet<void>(
      context: context,
      title: title,
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: Text(
                  body,
                  style: TextStyle(
                    color: context.dashMute,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GhostButton(
              label: 'Close',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        );
      },
    );
  }

  Future<void> _helpSheet() async {
    await showDashSheet<void>(
      context: context,
      title: 'Help center',
      description: 'Guides and troubleshooting',
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'FAQ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Common questions'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () {
                Navigator.pop(ctx);
                // ignore: discarded_futures
                _openHelpUrl('/faq');
              },
            ),
            Divider(height: 1, color: context.dashLine),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Docs',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Product documentation'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () {
                Navigator.pop(ctx);
                // ignore: discarded_futures
                _openHelpUrl('/docs');
              },
            ),
            const SizedBox(height: 12),
            GhostButton(
              label: 'Close',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        );
      },
    );
  }

  Future<void> _contactSheet() async {
    await showDashSheet<void>(
      context: context,
      title: 'Contact support',
      description: 'We typically reply within one business day',
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Email support@financeai.app or start a chat from this screen. '
              'Include your account email so we can find your workspace faster.',
              style: TextStyle(color: context.dashMute, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            AccentButton(
              label: 'Open support chat',
              onPressed: () {
                Navigator.pop(ctx);
                toast(context, 'Support chat opening…');
              },
            ),
            const SizedBox(height: 8),
            GhostButton(
              label: 'Close',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        );
      },
    );
  }

  Future<void> _privacyChoicesSheet() async {
    var share = _shareAnalytics;
    await showDashSheet<void>(
      context: context,
      title: 'Your privacy choices',
      description: 'We don’t ever sell your financial data',
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Share product analytics'),
              subtitle: const Text(
                'Help improve FinanceAI with anonymous usage signals',
              ),
              value: share,
              onChanged: (v) => setSheet(() => share = v),
            ),
            const SizedBox(height: 12),
            sheetCancelSave(
              context: ctx,
              saveLabel: 'Save',
              onSave: () {
                setState(() => _shareAnalytics = share);
                Navigator.pop(ctx);
                toast(
                  context,
                  share
                      ? 'Analytics sharing on'
                      : 'Analytics sharing off',
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSheet() async {
    await showDashSheet<void>(
      context: context,
      title: 'Delete account',
      description: 'This permanently removes your FinanceAI account',
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'You’ll lose access to linked banks, goals, and AI history. Export first if you need a copy.',
              style: TextStyle(color: context.dashMute, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      toast(context, 'Deletion requested');
                    },
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _tagsSheet() async {
    final draft = TextEditingController();
    await showDashSheet<void>(
      context: context,
      title: 'Manage tags',
      description: 'Use tags to group transactions',
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DashTextField(controller: draft, hint: 'New tag', autofocus: true),
            const SizedBox(height: 10),
            AccentButton(
              label: 'Add tag',
              onPressed: () {
                final next = draft.text.trim();
                if (next.isEmpty) return;
                setState(() {
                  if (!_tags.any((t) => t.toLowerCase() == next.toLowerCase())) {
                    _tags = [..._tags, next];
                  }
                });
                setSheet(() {});
                draft.clear();
              },
            ),
            const SizedBox(height: 12),
            for (final t in _tags)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    setState(() => _tags = _tags.where((x) => x != t).toList());
                    setSheet(() {});
                  },
                ),
              ),
          ],
        );
      },
    );
    draft.dispose();
  }

  Future<void> _connectBank() async {
    final bank = TextEditingController();
    await showDashSheet<void>(
      context: context,
      title: 'Connect institution',
      description: 'Link a bank or card to sync balances',
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Institution'),
            DashTextField(
              controller: bank,
              hint: 'Chase, Amex, Fidelity…',
              autofocus: true,
            ),
            const SizedBox(height: 16),
            sheetCancelSave(
              context: ctx,
              onSave: () {
                final name =
                    bank.text.trim().isEmpty ? 'New bank' : bank.text.trim();
                accountsStore.value = [
                  ..._banks,
                  DemoAccount(
                    bank: name,
                    type: 'Checking',
                    number: '····${1000 + _banks.length}',
                    balance: 0,
                    status: TxnStatus.succeeded,
                    synced: 'Just now',
                  ),
                ];
                Navigator.pop(ctx);
                toast(context, 'Institution connected · $name');
              },
            ),
          ],
        );
      },
    );
    bank.dispose();
  }
}

class _BlockTitle extends StatelessWidget {
  const _BlockTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: context.dashInk,
        ),
      ),
    );
  }
}

class _AppearanceChip extends StatelessWidget {
  const _AppearanceChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppAppearance option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.brand.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.brand : context.dashLine,
            ),
          ),
          child: Column(
            children: [
              _swatch(option),
              const SizedBox(height: 6),
              Text(
                option.label,
                style: TextStyle(
                  color: context.dashInk,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _swatch(AppAppearance option) {
    switch (option) {
      case AppAppearance.dark:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.lineDark),
          ),
        );
      case AppAppearance.system:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: const Row(
            children: [
              Expanded(child: ColoredBox(color: AppColors.surface)),
              Expanded(child: ColoredBox(color: AppColors.surfaceDark)),
            ],
          ),
        );
      case AppAppearance.light:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.line),
          ),
        );
    }
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    this.body,
    this.action,
    this.onTap,
    this.trailing,
    this.showDivider = true,
  });

  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: context.dashLine))
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.dashInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    body!,
                    style: TextStyle(
                      color: context.dashMute,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (action != null && onTap != null)
            LinkAction(label: action!, onTap: onTap!),
        ],
      ),
    );
  }
}
