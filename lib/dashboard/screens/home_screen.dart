import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_scope.dart';
import '../../theme/app_theme.dart';
import '../accounts_scope.dart';
import '../dash_colors.dart';
import '../data.dart';
import '../goals_scope.dart';
import '../shimmer.dart';
import '../transactions_scope.dart';
import '../ui.dart';
import '../variant_style.dart';
import '../widgets/space_alien.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.style,
    required this.onRefresh,
    required this.onViewTransactions,
    required this.onViewAccounts,
    required this.onViewCategories,
    required this.onViewGoals,
    required this.onConnectBank,
    this.onOpenAgent,
  });

  final DashVariantStyle style;
  final Future<void> Function() onRefresh;
  final VoidCallback onViewTransactions;
  final VoidCallback onViewAccounts;
  final VoidCallback onViewCategories;
  final VoidCallback onViewGoals;
  final VoidCallback onConnectBank;
  final VoidCallback? onOpenAgent;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeData {
  const _HomeData({
    required this.firstName,
    required this.greeting,
    required this.dateLabel,
    required this.totalBalance,
    required this.cashLeft,
    required this.spend,
    required this.income,
    required this.daysLeftInMonth,
    required this.accountCount,
    required this.goal,
    required this.recent,
    required this.accounts,
    required this.alienMood,
    required this.digestLine,
  });

  final String firstName;
  final String greeting;
  final String dateLabel;
  final double totalBalance;
  final double cashLeft;
  final double spend;
  final double income;
  final int daysLeftInMonth;
  final int accountCount;
  final DemoGoal? goal;
  final List<DemoTxn> recent;
  final List<DemoAccount> accounts;
  final AlienMood alienMood;
  final String digestLine;

  String get digestBullets {
    final ahead = cashLeft >= 0;
    final accountPhrase = accountCount == 0
        ? 'No accounts linked yet — connect one when you’re ready'
        : accountCount == 1
            ? 'You’re sitting on ${money(totalBalance)} in your account'
            : 'You’re sitting on ${money(totalBalance)} across $accountCount accounts';

    final flowPhrase = ahead
        ? 'This month you’ve taken in ${money(income)} and spent ${money(spend)}, so you’re ${money(cashLeft)} ahead'
        : 'This month you’ve spent ${money(spend)} against ${money(income)} in — you’re ${money(cashLeft.abs())} short for now';

    final daysPhrase = daysLeftInMonth <= 0
        ? 'That’s the end of the month — a good moment to glance at what’s left'
        : daysLeftInMonth == 1
            ? 'One day left in the month — finish strong'
            : '$daysLeftInMonth days left in the month to work with';

    final goalPhrase = goal == null
        ? null
        : () {
            final g = goal!;
            final pct =
                g.target <= 0 ? 0 : ((g.saved / g.target) * 100).round();
            if (pct >= 100) {
              return 'Nice work — ${g.name} is fully funded';
            }
            if (pct >= 70) {
              return 'You’re close on ${g.name}: $pct% there (${money(g.saved)} of ${money(g.target)})';
            }
            return 'Toward ${g.name}, you’ve saved ${money(g.saved)} of ${money(g.target)} — that’s $pct% of the way';
          }();

    return [
      accountPhrase,
      if (accountCount > 0) flowPhrase,
      daysPhrase,
      if (goalPhrase != null) goalPhrase,
      digestLine,
    ].join('\n');
  }
}

class _HomeScreenState extends State<HomeScreen> {
  _HomeData _assemble(BuildContext context) {
    final txns = TransactionsScope.of(context).transactions;
    final accounts = AccountsScope.of(context).accounts;
    final goals = GoalsScope.of(context).goals;
    final auth = AuthScope.of(context);
    final goal = pickPrimaryGoal(goals);

    final fullName = (auth.user?.name ?? '').trim();
    final firstName = fullName.isEmpty
        ? 'there'
        : fullName.split(RegExp(r'\s+')).first;

    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    const months = [
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
    final dateLabel = '${months[now.month - 1]} ${now.day}, ${now.year}';
    final daysLeft = daysLeftInMonth(now: now);

    final monthTxns = txnsInCurrentMonth(txns, now: now);
    final spend = monthTxns
        .where((t) => t.amount < 0)
        .fold<double>(0, (s, t) => s + t.amount.abs());
    final income = monthTxns
        .where((t) => t.amount > 0)
        .fold<double>(0, (s, t) => s + t.amount);
    final cashLeft = income - spend;
    final totalBalance = accounts.fold<double>(0, (s, a) => s + a.balance);
    final pendingStatus =
        txns.where((t) => t.status == TxnStatus.pending).toList();
    final needsApproval = txns
        .where((t) => t.approvalStatus == ApprovalStatus.pending)
        .toList();

    final diningSpend = monthTxns
        .where(
          (t) =>
              t.amount < 0 && t.category.toLowerCase().contains('dining'),
        )
        .fold<double>(0, (s, t) => s + t.amount.abs());

    final alienMood = pendingStatus.isNotEmpty || diningSpend > 200
        ? AlienMood.alert
        : cashLeft < 0
            ? AlienMood.worried
            : AlienMood.happy;

    final digestLine = needsApproval.isNotEmpty
        ? needsApproval.length == 1
            ? 'One transaction needs your approval'
            : '${needsApproval.length} transactions need your approval'
        : pendingStatus.isNotEmpty
            ? pendingStatus.length == 1
                ? 'One pending charge is waiting for a quick look'
                : '${pendingStatus.length} pending charges are waiting for a quick look'
            : diningSpend > 200
                ? 'Dining’s been busy this month (${money(diningSpend)}) — worth a glance if you want to cool it off'
                : cashLeft >= 0
                    ? 'Overall you’re in good shape — keep the rhythm going'
                    : 'A little behind this month — small cuts this week will help catch up';

    final sortedAccounts = [...accounts]
      ..sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));

    return _HomeData(
      firstName: firstName,
      greeting: greeting,
      dateLabel: dateLabel,
      totalBalance: totalBalance,
      cashLeft: cashLeft,
      spend: spend,
      income: income,
      daysLeftInMonth: daysLeft,
      accountCount: accounts.length,
      goal: goal,
      recent: txns.take(12).toList(),
      accounts: sortedAccounts,
      alienMood: alienMood,
      digestLine: digestLine,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _assemble(context);
    final txLoading = TransactionsScope.of(context).loading;
    final acLoading = AccountsScope.of(context).loading;
    final goalsLoading = GoalsScope.of(context).loading;
    return _ClassicHome(
      style: widget.style,
      data: data,
      transactionsLoading: txLoading,
      accountsLoading: acLoading,
      goalsLoading: goalsLoading,
      onRefresh: widget.onRefresh,
      onViewTransactions: widget.onViewTransactions,
      onViewAccounts: widget.onViewAccounts,
      onViewGoals: widget.onViewGoals,
      onOpenAgent: widget.onOpenAgent,
    );
  }
}

const _kHomePhysics = AlwaysScrollableScrollPhysics(
  parent: ClampingScrollPhysics(),
);

Widget _refreshable({
  required Future<void> Function() onRefresh,
  required Widget child,
  required Color color,
  required Color backgroundColor,
}) {
  return RefreshIndicator(
    color: color,
    backgroundColor: backgroundColor,
    displacement: 48,
    onRefresh: onRefresh,
    child: child,
  );
}

class _Hairline extends StatelessWidget {
  const _Hairline({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: color);
}

/// Greeting-row mascot: tap opens digest, long-press enters agent mode.
class _AgentMascotButton extends StatefulWidget {
  const _AgentMascotButton({
    required this.mood,
    required this.digestOpen,
    required this.onTap,
    this.onOpenAgent,
  });

  final AlienMood mood;
  final bool digestOpen;
  final VoidCallback onTap;
  final VoidCallback? onOpenAgent;

  @override
  State<_AgentMascotButton> createState() => _AgentMascotButtonState();
}

class _AgentMascotButtonState extends State<_AgentMascotButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails _) {
    // ignore: discarded_futures
    _press.forward(from: 0);
  }

  void _onLongPress() {
    HapticFeedback.mediumImpact();
    widget.onOpenAgent?.call();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    // ignore: discarded_futures
    _press.reverse();
  }

  void _onLongPressCancel() {
    // ignore: discarded_futures
    _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final canAgent = widget.onOpenAgent != null;
    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: canAgent ? _onLongPressStart : null,
      onLongPress: canAgent ? _onLongPress : null,
      onLongPressEnd: canAgent ? _onLongPressEnd : null,
      onLongPressCancel: canAgent ? _onLongPressCancel : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_press.value);
          final scale = 1 + 0.18 * t;
          return Transform.scale(
            scale: scale,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (t > 0)
                  Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 1 + t * 0.9,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.brand.withValues(alpha: 0.45),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: widget.digestOpen
                        ? Border.all(
                            color: AppColors.brand.withValues(alpha: 0.35),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: SpaceAlienMascot(
                    size: 44,
                    mood: widget.mood,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ClassicHome extends StatefulWidget {
  const _ClassicHome({
    required this.style,
    required this.data,
    required this.transactionsLoading,
    required this.accountsLoading,
    required this.goalsLoading,
    required this.onRefresh,
    required this.onViewTransactions,
    required this.onViewAccounts,
    required this.onViewGoals,
    this.onOpenAgent,
  });

  final DashVariantStyle style;
  final _HomeData data;
  final bool transactionsLoading;
  final bool accountsLoading;
  final bool goalsLoading;
  final Future<void> Function() onRefresh;
  final VoidCallback onViewTransactions;
  final VoidCallback onViewAccounts;
  final VoidCallback onViewGoals;
  final VoidCallback? onOpenAgent;

  bool get moneyLoading => accountsLoading || transactionsLoading;
  bool get digestLoading =>
      accountsLoading || transactionsLoading || goalsLoading;

  @override
  State<_ClassicHome> createState() => _ClassicHomeState();
}

class _ClassicHomeState extends State<_ClassicHome> {
  var _digestOpen = false;
  var _typedLen = 0;
  String _typedSource = '';
  Timer? _typeTimer;

  _HomeData get data => widget.data;

  @override
  void didUpdateWidget(covariant _ClassicHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_digestOpen) return;
    if (oldWidget.digestLoading && !widget.digestLoading) {
      _startTyping(data.digestBullets);
      return;
    }
    if (!widget.digestLoading) {
      final next = data.digestBullets;
      if (next != _typedSource) {
        _startTyping(next);
      }
    }
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    super.dispose();
  }

  void _toggleDigest() {
    if (_digestOpen) {
      _typeTimer?.cancel();
      setState(() {
        _digestOpen = false;
        _typedLen = 0;
        _typedSource = '';
      });
      return;
    }
    setState(() => _digestOpen = true);
    if (!widget.digestLoading) {
      _startTyping(data.digestBullets);
    }
  }

  void _startTyping(String full) {
    _typeTimer?.cancel();
    _typedSource = full;
    setState(() => _typedLen = 0);
    // Slow, readable typewriter (~1 char every 42ms).
    _typeTimer = Timer.periodic(const Duration(milliseconds: 42), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_typedLen >= full.length) {
        timer.cancel();
        return;
      }
      setState(() {
        _typedLen = (_typedLen + 1).clamp(0, full.length);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final fullDigest = data.digestBullets;
    final typed = fullDigest.substring(0, _typedLen.clamp(0, fullDigest.length));

    return _refreshable(
      onRefresh: widget.onRefresh,
      color: widget.style.primary,
      backgroundColor: context.dashPanel,
      child: ListView(
        physics: _kHomePhysics,
        key: const ValueKey('classic'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      '${data.greeting}, ${data.firstName}',
                      style: TextStyle(
                        fontSize:
                            MediaQuery.sizeOf(context).width < 380 ? 24 : 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        height: 1.15,
                        color: context.dashInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Tap for digest · Hold for Agent mode',
                    child: _AgentMascotButton(
                      mood: data.alienMood,
                      digestOpen: _digestOpen,
                      onTap: _toggleDigest,
                      onOpenAgent: widget.onOpenAgent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                data.dateLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.dashMute,
                ),
              ),
            ],
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _digestOpen
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      decoration: BoxDecoration(
                        color: context.dashPanel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.dashLine),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'AI Agent Digest',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: context.dashMute,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 14,
                                color: AppColors.brand.withValues(alpha: 0.8),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (widget.digestLoading)
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShimmerBox(width: 280, height: 12),
                                SizedBox(height: 10),
                                ShimmerBox(width: 220, height: 12),
                                SizedBox(height: 10),
                                ShimmerBox(width: 180, height: 12),
                                SizedBox(height: 10),
                                ShimmerBox(width: 200, height: 12),
                              ],
                            )
                          else
                            _DigestBody(
                              fullText: fullDigest,
                              typedText: typed,
                            ),
                          if (!widget.digestLoading) ...[
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: AccentButton(
                                label: 'Open agent',
                                onPressed: widget.onOpenAgent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 28),

          Text(
            'Total net worth',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.dashMute,
            ),
          ),
          const SizedBox(height: 6),
          if (widget.moneyLoading) ...[
            const ShimmerBox(width: 200, height: 34, borderRadius: 8),
            const SizedBox(height: 10),
            const ShimmerBox(width: 260, height: 13),
          ] else ...[
            Text(
              money(data.totalBalance),
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
                height: 1.1,
                color: context.dashInk,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Out ${money(data.spend)} · In ${money(data.income)} · '
              '${data.cashLeft >= 0 ? 'Ahead' : 'Behind'} ${money(data.cashLeft.abs())} this month',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.dashMute,
              ),
            ),
          ],

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent transactions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.dashInk,
                  ),
                ),
              ),
              LinkAction(
                label: 'View all',
                onTap: widget.onViewTransactions,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.transactionsLoading)
            const _TxnListShimmer(rows: 5)
          else ...[
            Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    'DATE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: context.dashMute,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'DESCRIPTION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: context.dashMute,
                    ),
                  ),
                ),
                Text(
                  'AMOUNT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: context.dashMute,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Hairline(color: context.dashLine),
            if (data.recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  'No transactions yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.dashMute,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              for (final t in data.recent.take(12)) ...[
                InkWell(
                  onTap: widget.onViewTransactions,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(
                            t.date,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.dashMute,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            t.merchant,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: context.dashInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          money(t.amount, signed: true),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.amount < 0
                                ? context.dashInk
                                : AppColors.success,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _Hairline(color: context.dashLine),
              ],
          ],

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Accounts',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.dashInk,
                  ),
                ),
              ),
              LinkAction(
                label: 'View all',
                onTap: widget.onViewAccounts,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (widget.accountsLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: ShimmerBox(width: 160, height: 12),
            )
          else
            Text(
              '${data.accountCount} linked · ${money(data.totalBalance)} total',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.dashMute,
              ),
            ),
          const SizedBox(height: 12),
          if (widget.accountsLoading)
            const _AccountListShimmer(rows: 4)
          else if (data.accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No accounts linked yet',
                style: TextStyle(
                  color: context.dashMute,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            for (final a in data.accounts.take(5)) ...[
              InkWell(
                onTap: widget.onViewAccounts,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.dashElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.dashLine),
                        ),
                        child: Text(
                          a.bank.isNotEmpty ? a.bank[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.dashInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.dashInk,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${a.type} · ··${a.digits}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.dashMute,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        money(a.balance),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: a.balance < 0
                              ? AppColors.danger
                              : context.dashInk,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _Hairline(color: context.dashLine),
            ],
        ],
      ),
    );
  }
}

class _DigestBody extends StatelessWidget {
  const _DigestBody({
    required this.fullText,
    required this.typedText,
  });

  final String fullText;
  final String typedText;

  static TextStyle _style(BuildContext context) => TextStyle(
        fontSize: 15,
        height: 1.55,
        fontWeight: FontWeight.w500,
        color: context.dashInk,
      );

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    final stillTyping = typedText.length < fullText.length;
    final source = stillTyping ? typedText : fullText;
    final lines = source
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 18,
                child: Text('•', style: style),
              ),
              Expanded(
                child: Text(lines[i], style: style),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TxnListShimmer extends StatelessWidget {
  const _TxnListShimmer({this.rows = 5});
  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                const ShimmerBox(width: 40, height: 12),
                const SizedBox(width: 16),
                Expanded(
                  child: ShimmerBox(
                    width: 120 + (i % 3) * 20.0,
                    height: 14,
                  ),
                ),
                const SizedBox(width: 12),
                const ShimmerBox(width: 56, height: 14),
              ],
            ),
          ),
          _Hairline(color: context.dashLine),
        ],
      ],
    );
  }
}

class _AccountListShimmer extends StatelessWidget {
  const _AccountListShimmer({this.rows = 4});
  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                const ShimmerBox(width: 36, height: 36, borderRadius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 100 + (i % 2) * 24.0, height: 13),
                      const SizedBox(height: 8),
                      const ShimmerBox(width: 88, height: 10),
                    ],
                  ),
                ),
                const ShimmerBox(width: 64, height: 14),
              ],
            ),
          ),
          _Hairline(color: context.dashLine),
        ],
      ],
    );
  }
}
