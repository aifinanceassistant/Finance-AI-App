import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/auth_scope.dart';
import '../../theme/app_theme.dart';
import '../dash_colors.dart';
import '../dash_sheets.dart';
import '../spaces_scope.dart';
import '../ui.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.onRecurring,
    required this.onInvestments,
    required this.onGoals,
    required this.onReports,
    required this.onSettings,
    required this.onManagePlan,
    required this.onLogout,
    this.onUsersPermissions,
    this.onReconcile,
    this.onAgentMode,
    this.onRefresh,
    this.showGoals = true,
    this.showInvestments = true,
  });

  final VoidCallback onRecurring;
  final VoidCallback onInvestments;
  final VoidCallback onGoals;
  final VoidCallback onReports;
  final VoidCallback onSettings;
  final VoidCallback onManagePlan;
  final VoidCallback onLogout;
  final VoidCallback? onUsersPermissions;
  final VoidCallback? onReconcile;
  final VoidCallback? onAgentMode;
  final Future<void> Function()? onRefresh;
  final bool showGoals;
  final bool showInvestments;

  Future<void> _openHelpUrl(BuildContext context, String path) async {
    final uri = Uri.parse('https://financeai.app$path');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) toast(context, 'Could not open link');
  }

  Future<void> _openHelpSheet(BuildContext context) async {
    await showDashSheet<void>(
      context: context,
      title: 'Get help',
      description: 'FAQ, docs, and support',
      builder: (ctx, setSheet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline_rounded),
              title: const Text(
                'FAQ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Common questions about linking and billing'),
              onTap: () {
                Navigator.pop(ctx);
                // ignore: discarded_futures
                _openHelpUrl(context, '/faq');
              },
            ),
            Divider(height: 1, color: context.dashLine),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text(
                'Docs',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Guides for accounts, goals, and AI'),
              onTap: () {
                Navigator.pop(ctx);
                // ignore: discarded_futures
                _openHelpUrl(context, '/docs');
              },
            ),
            Divider(height: 1, color: context.dashLine),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text(
                'Contact support',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('support@financeai.app · usually under 1 day'),
              onTap: () {
                Navigator.pop(ctx);
                toast(context, 'Support chat opening…');
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

  List<_MoreDest> _destinations(BuildContext context) {
    final spaces = SpacesScope.maybeOf(context);
    final goalsUnlocked = showGoals || (spaces?.hasFeature('goals') ?? false);
    final investmentsUnlocked =
        showInvestments || (spaces?.hasFeature('investments') ?? false);

    return [
      _MoreDest(
        icon: Icons.autorenew_rounded,
        title: 'Recurring',
        onTap: onRecurring,
      ),
      if (investmentsUnlocked)
        _MoreDest(
          icon: Icons.trending_up_rounded,
          title: 'Investments',
          onTap: onInvestments,
        )
      else
        _MoreDest(
          icon: Icons.lock_outline_rounded,
          title: 'Investments',
          onTap: onManagePlan,
        ),
      if (goalsUnlocked)
        _MoreDest(
          icon: Icons.flag_outlined,
          title: 'Goals',
          onTap: onGoals,
        )
      else
        _MoreDest(
          icon: Icons.lock_outline_rounded,
          title: 'Goals',
          onTap: onManagePlan,
        ),
      _MoreDest(
        icon: Icons.insights_outlined,
        title: 'Reports',
        onTap: onReports,
      ),
      _MoreDest(
        icon: Icons.smart_toy_outlined,
        title: 'AI Agent',
        onTap: onAgentMode ?? onSettings,
      ),
      if (onReconcile != null)
        _MoreDest(
          icon: Icons.fact_check_outlined,
          title: 'Reconcile',
          onTap: onReconcile!,
        ),
      if (onUsersPermissions != null)
        _MoreDest(
          icon: Icons.group_outlined,
          title: 'Team',
          onTap: onUsersPermissions!,
        ),
      _MoreDest(
        icon: Icons.settings_outlined,
        title: 'Profile and Settings',
        onTap: onSettings,
      ),
      _MoreDest(
        icon: Icons.help_outline_rounded,
        title: 'Get help',
        onTap: () => _openHelpSheet(context),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Keep auth watch so the tab rebuilds on sign-in changes.
    AuthScope.of(context);
    final dests = _destinations(context);

    return dashPullToRefresh(
      onRefresh: onRefresh ?? () async {},
      backgroundColor: context.dashPanel,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Text(
            'Workspace',
            style: TextStyle(
              color: context.dashMute,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final d in dests)
          _FeedRow(
            icon: d.icon,
            title: d.title,
            onTap: d.onTap,
          ),
        const SizedBox(height: 8),
        _FeedRow(
          icon: Icons.logout_rounded,
          title: 'Log out',
          onTap: onLogout,
          danger: true,
        ),
      ],
    ),
    );
  }
}

class _MoreDest {
  const _MoreDest({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.dashLine)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: danger ? AppColors.danger : context.dashInk,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: danger ? AppColors.danger : context.dashInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.dashSoftMute,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
