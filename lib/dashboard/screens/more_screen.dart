import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../dash_sheets.dart';
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
  });

  final VoidCallback onRecurring;
  final VoidCallback onInvestments;
  final VoidCallback onGoals;
  final VoidCallback onReports;
  final VoidCallback onSettings;
  final VoidCallback onManagePlan;
  final VoidCallback onLogout;

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
                toast(context, 'FAQ · financeai.app/faq');
              },
            ),
            const Divider(height: 1, color: AppColors.line),
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
                toast(context, 'Docs · financeai.app/docs');
              },
            ),
            const Divider(height: 1, color: AppColors.line),
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        const DashPageHeader(
          title: 'More',
          subtitle: 'Goals, reports, and your workspace',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DashPanel(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Text(
                    'AR',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alex Rivera',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'alex@financeai.app',
                        style: TextStyle(
                          color: AppColors.mute,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DashPanel(
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.autorenew_rounded,
                  title: 'Recurring',
                  subtitle: 'Subscriptions, bills, and income',
                  onTap: onRecurring,
                  showDivider: false,
                ),
                _NavTile(
                  icon: Icons.trending_up_rounded,
                  title: 'Investments',
                  subtitle: 'Brokerage and crypto holdings',
                  onTap: onInvestments,
                ),
                _NavTile(
                  icon: Icons.flag_outlined,
                  title: 'Goals',
                  subtitle: 'Emergency fund, trips, and more',
                  onTap: onGoals,
                ),
                _NavTile(
                  icon: Icons.insights_outlined,
                  title: 'Reports',
                  subtitle: 'Cash flow and category insights',
                  onTap: onReports,
                ),
                _NavTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  subtitle: 'Profile, security, and billing',
                  onTap: onSettings,
                ),
                _NavTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Get help',
                  subtitle: 'FAQ and support',
                  onTap: () => _openHelpSheet(context),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DashPanel(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EEFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.smart_toy_outlined,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI credits',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '842 of 1,200 · Resets Apr 1',
                            style: TextStyle(
                              color: AppColors.mute,
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
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plus · Family',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '\$14.99/mo',
                              style: TextStyle(
                                color: AppColors.mute,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      LinkAction(
                        label: 'Manage',
                        onTap: onManagePlan,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DashPanel(
            child: _NavTile(
              icon: Icons.logout_rounded,
              title: 'Log out',
              subtitle: 'Return to the landing screen',
              danger: true,
              showDivider: false,
              onTap: onLogout,
            ),
          ),
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(top: BorderSide(color: AppColors.line))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: danger ? AppColors.danger : AppColors.ink,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: danger ? AppColors.danger : AppColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.mute,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.softMute,
            ),
          ],
        ),
      ),
    );
  }
}
