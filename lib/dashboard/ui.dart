import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'dash_colors.dart';
import 'data.dart';
import 'variant_style.dart';

/// Shared pull-to-refresh chrome for dashboard lists.
Widget dashPullToRefresh({
  required Future<void> Function() onRefresh,
  required Widget child,
  Color? color,
  Color? backgroundColor,
}) {
  return RefreshIndicator(
    color: color ?? AppColors.brand,
    backgroundColor: backgroundColor,
    displacement: 48,
    onRefresh: onRefresh,
    child: child,
  );
}

class DashPageHeader extends StatelessWidget {
  const DashPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final header =
        DashStyleScope.maybeOf(context)?.headerStyle ?? DashHeaderStyle.classic;
    final showEyebrow = header == DashHeaderStyle.terminal;
    final showMark = header != DashHeaderStyle.minimal;
    final titleSize = header == DashHeaderStyle.minimal
        ? (MediaQuery.sizeOf(context).width < 380 ? 20.0 : 22.0)
        : (MediaQuery.sizeOf(context).width < 380 ? 22.0 : 26.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, header == DashHeaderStyle.minimal ? 14 : 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showEyebrow) ...[
            Text(
              'FinanceAI · ${title.toLowerCase()}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: context.dashInk.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.dashInk,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    height: 1.15,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                color: context.dashMute,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ],
          if (showMark) ...[
            const SizedBox(height: 10),
            Container(
              height: 3,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: actions!),
          ],
        ],
      ),
    );
  }
}

/// Shared feed chrome matching Activity: title + subtitle + icon actions,
/// full-width filter bar, optional mute meta strip.
class DashFeedChrome extends StatelessWidget {
  const DashFeedChrome({
    super.key,
    required this.title,
    required this.subtitle,
    this.filterBar,
    this.metaLine,
    this.onSecondary,
    this.secondaryIcon = Icons.download_outlined,
    this.secondaryTooltip = 'Export',
    this.onPrimary,
    this.primaryIcon = Icons.add_circle_outline,
    this.primaryTooltip = 'Add',
    this.primaryEnabled = true,
    this.showPrimary = true,
    this.extraActions,
  });

  final String title;
  final String subtitle;
  final Widget? filterBar;
  final String? metaLine;
  final VoidCallback? onSecondary;
  final IconData secondaryIcon;
  final String secondaryTooltip;
  final VoidCallback? onPrimary;
  final IconData primaryIcon;
  final String primaryTooltip;
  final bool primaryEnabled;
  final bool showPrimary;
  final List<Widget>? extraActions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 10, showPrimary || onSecondary != null || (extraActions?.isNotEmpty ?? false) ? 8 : 20, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.dashInk,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.dashMute,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (onSecondary != null)
                IconButton(
                  onPressed: onSecondary,
                  tooltip: secondaryTooltip,
                  icon: Icon(secondaryIcon, size: 22),
                  color: context.dashInk,
                  visualDensity: VisualDensity.compact,
                ),
              if (extraActions != null) ...extraActions!,
              if (showPrimary)
                IconButton(
                  onPressed: primaryEnabled ? onPrimary : null,
                  tooltip: primaryTooltip,
                  icon: Icon(primaryIcon, size: 26),
                  color: AppColors.brand,
                ),
            ],
          ),
        ),
        if (filterBar != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: filterBar,
          ),
        if (metaLine != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              metaLine!,
              style: TextStyle(
                color: context.dashSoftMute,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Full-height sheet that slides up from the bottom with rounded top corners
/// (same language as [showDashSheet]: grab handle to dismiss).
Route<T> dashModalRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    opaque: false,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
  );
}

/// Scaffold chrome for [dashModalRoute]: soft curved top + grab handle.
/// Drag the handle, or pull down once the body is scrolled to the top, to close.
class DashModalScaffold extends StatefulWidget {
  const DashModalScaffold({
    super.key,
    required this.body,
    this.backgroundColor,
  });

  final Widget body;
  final Color? backgroundColor;

  @override
  State<DashModalScaffold> createState() => _DashModalScaffoldState();
}

class _DashModalScaffoldState extends State<DashModalScaffold>
    with SingleTickerProviderStateMixin {
  static const _radius = 28.0;
  static const _dismissDistance = 110.0;

  double _dragOffset = 0;
  late final AnimationController _snapBack = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<double>? _snapAnim;

  @override
  void dispose() {
    _snapBack.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _snapBack.stop();
    final next = _dragOffset + details.delta.dy;
    setState(() => _dragOffset = next < 0 ? 0 : next);
  }

  /// Pull-down at the top of the body list drags the sheet (Facebook-style).
  bool _onBodyScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll < 0) {
      _snapBack.stop();
      setState(() => _dragOffset -= n.overscroll);
    } else if (n is ScrollUpdateNotification &&
        n.dragDetails != null &&
        _dragOffset > 0 &&
        (n.scrollDelta ?? 0) > 0) {
      final next = _dragOffset - n.scrollDelta!;
      setState(() => _dragOffset = next < 0 ? 0 : next);
    } else if (n is ScrollEndNotification && _dragOffset > 0) {
      _onDragEnd(n.dragDetails ?? DragEndDetails());
    }
    return false;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset > _dismissDistance ||
        (velocity > 900 && _dragOffset > 0)) {
      Navigator.of(context).maybePop();
      return;
    }
    if (_dragOffset == 0) return;
    final from = _dragOffset;
    _snapAnim = Tween<double>(begin: from, end: 0).animate(
      CurvedAnimation(parent: _snapBack, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() => _dragOffset = _snapAnim!.value);
      });
    _snapBack
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final topGap = MediaQuery.paddingOf(context).top + 10;
    return Transform.translate(
      offset: Offset(0, _dragOffset),
      child: Padding(
        padding: EdgeInsets.only(top: topGap),
        child: Material(
          color: widget.backgroundColor ?? context.dashSurface,
          elevation: 12,
          shadowColor: Colors.black38,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_radius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                onTap: () => Navigator.of(context).maybePop(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
                  child: Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: context.dashMute.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  // Clamping so top overscroll emits notifications on iOS too.
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      physics: const ClampingScrollPhysics(),
                    ),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onBodyScroll,
                      child: widget.body,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashPanel extends StatelessWidget {
  const DashPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final style = DashStyleScope.maybeOf(context);
    final radius = style?.radius ?? 8;

    return Container(
      margin: margin,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.dashPanel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: context.dashLine),
      ),
      child: child,
    );
  }
}

class DashPanelHeader extends StatelessWidget {
  const DashPanelHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.dashLine)),
      ),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: context.dashMute,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class DashKpi extends StatelessWidget {
  const DashKpi({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.valueColor,
    this.spark,
    this.sparkUp = true,
    this.sparkColor,
  });

  final String label;
  final String value;
  final String? hint;
  final Color? valueColor;
  final List<double>? spark;
  final bool sparkUp;
  final Color? sparkColor;

  @override
  Widget build(BuildContext context) {
    final lineColor =
        sparkColor ?? (sparkUp ? AppColors.accent : context.dashSoftMute);
    return DashPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.dashMute,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? context.dashInk,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          if (hint != null || spark != null) ...[
            const SizedBox(height: 10),
            if (hint != null && spark != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hint!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sparkUp ? AppColors.success : context.dashMute,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Sparkline(values: spark!, color: lineColor),
                ],
              )
            else if (hint != null)
              Text(
                hint!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: sparkUp ? AppColors.success : context.dashMute,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (spark != null)
              SizedBox(
                width: double.infinity,
                height: 32,
                child: Sparkline(
                  values: spark!,
                  color: lineColor,
                  width: double.infinity,
                  height: 32,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final style = DashStyleScope.maybeOf(context);
    final radius = style?.radius ?? 8;
    final fg = foregroundColor ?? context.dashInk;
    final activeBorder = context.isDark
        ? AppColors.brand.withValues(alpha: 0.45)
        : const Color(0xFFCFE4F6);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        backgroundColor: context.dashPanel,
        disabledForegroundColor: context.dashSoftMute,
        side: BorderSide(
          color: foregroundColor != null ? activeBorder : context.dashLine,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius * 0.7),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

class AccentButton extends StatelessWidget {
  const AccentButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = DashStyleScope.maybeOf(context);
    final primary = style?.primary ?? AppColors.accent;
    final radius = style?.radius ?? 8;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: primary.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius * 0.7),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

class LinkAction extends StatelessWidget {
  const LinkAction({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final primary =
        DashStyleScope.maybeOf(context)?.primary ?? AppColors.accent;
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Text(
        label,
        style: TextStyle(
          color: primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final TxnStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      TxnStatus.succeeded => (
          context.dashSuccessFill,
          AppColors.success,
          'Succeeded',
        ),
      TxnStatus.pending => (
          context.dashWarningFill,
          AppColors.warning,
          'Pending',
        ),
      TxnStatus.failed => (
          context.dashDangerFill,
          AppColors.danger,
          'Failed',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AccountNumber extends StatefulWidget {
  const AccountNumber({
    super.key,
    required this.account,
    this.style,
  });

  final DemoAccount account;
  final TextStyle? style;

  @override
  State<AccountNumber> createState() => _AccountNumberState();
}

class _AccountNumberState extends State<AccountNumber> {
  var _revealed = false;

  @override
  Widget build(BuildContext context) {
    final digits = widget.account.digits;
    if (digits.isEmpty) return const SizedBox.shrink();

    final style = widget.style ??
        TextStyle(
          color: context.dashSoftMute,
          fontSize: 12,
          letterSpacing: 1.2,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _revealed ? digits : '••••',
          style: style,
        ),
        const SizedBox(width: 2),
        Tooltip(
          key: ValueKey(_revealed ? 'hide' : 'view'),
          message: _revealed ? 'Hide' : 'View',
          waitDuration: const Duration(milliseconds: 250),
          child: InkWell(
            onTap: () {
              // Dismiss any open tooltip before flipping state.
              Tooltip.dismissAllToolTips();
              setState(() => _revealed = !_revealed);
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                _revealed
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 14,
                color: context.dashSoftMute,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ApprovalPill extends StatelessWidget {
  const ApprovalPill({super.key, required this.status});

  final ApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border, label) = switch (status) {
      ApprovalStatus.approved => (
          context.dashSuccessFill,
          AppColors.success,
          AppColors.success.withValues(alpha: context.isDark ? 0.35 : 0.45),
          'Approved',
        ),
      ApprovalStatus.rejected => (
          context.dashDangerFill,
          AppColors.danger,
          AppColors.danger.withValues(alpha: context.isDark ? 0.35 : 0.45),
          'Rejected',
        ),
      ApprovalStatus.pending => (
          context.dashWarningFill,
          AppColors.warning,
          AppColors.warning.withValues(alpha: context.isDark ? 0.35 : 0.45),
          'Pending',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Pending opens Approve / Reject; settled shows a status pill.
class ApprovalActions extends StatelessWidget {
  const ApprovalActions({
    super.key,
    required this.status,
    required this.onApprove,
    required this.onReject,
  });

  final ApprovalStatus status;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    if (status != ApprovalStatus.pending) {
      return ApprovalPill(status: status);
    }

    return PopupMenuButton<ApprovalStatus>(
      padding: EdgeInsets.zero,
      offset: const Offset(0, 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (value) {
        if (value == ApprovalStatus.approved) {
          onApprove();
        } else if (value == ApprovalStatus.rejected) {
          onReject();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: ApprovalStatus.approved,
          child: Row(
            children: [
              Icon(Icons.check_rounded, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Text(
                'Approve',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: ApprovalStatus.rejected,
          child: Row(
            children: [
              Icon(Icons.close_rounded, size: 18, color: AppColors.danger),
              const SizedBox(width: 8),
              Text(
                'Reject',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: context.dashWarningFill,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppColors.warning.withValues(
              alpha: context.isDark ? 0.35 : 0.45,
            ),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pending',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 16, color: AppColors.warning),
          ],
        ),
      ),
    );
  }
}

class TypePill extends StatelessWidget {
  const TypePill({super.key, required this.type});

  final MoneyMove type;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (type) {
      MoneyMove.income => (context.dashSuccessFill, AppColors.success),
      MoneyMove.transfer => (context.dashBrandFill, AppColors.brand),
      MoneyMove.expense => (context.dashSurface, context.dashMute),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        moneyMoveLabel(type),
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.progress,
    required this.color,
    this.height = 8,
  });

  final double progress;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: context.dashSurface,
          color: color,
          minHeight: height,
        ),
      ),
    );
  }
}

class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.color = AppColors.accent,
    this.width = 72,
    this.height = 28,
  });

  final List<double> values;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (width.isInfinite) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, height),
            painter: _SparkPainter(values: values, color: color),
          );
        },
      );
    }
    return CustomPaint(
      size: Size(width, height),
      painter: _SparkPainter(values: values, color: color),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    final range = (max - min).abs() < 0.001 ? 1.0 : max - min;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = size.height - ((values[i] - min) / range) * (size.height - 4) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.75
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class AreaSpendChart extends StatelessWidget {
  const AreaSpendChart({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: CustomPaint(
        painter: _AreaPainter(
          lineColor: context.dashLine,
          labelColor: context.dashSoftMute,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AreaPainter extends CustomPainter {
  _AreaPainter({required this.lineColor, required this.labelColor});

  final Color lineColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final series = spendSeries;
    final max = series.reduce(math.max);
    const padT = 8.0;
    const padB = 24.0;
    const padL = 4.0;
    const padR = 4.0;
    final innerW = size.width - padL - padR;
    final innerH = size.height - padT - padB;

    final grid = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (final t in [0.25, 0.5, 0.75, 1.0]) {
      final y = padT + innerH * (1 - t);
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), grid);
    }

    final points = <Offset>[];
    for (var i = 0; i < series.length; i++) {
      final x = padL + (i / (series.length - 1)) * innerW;
      final y = padT + innerH - (series[i] / max) * innerH;
      points.add(Offset(x, y));
    }

    final area = Path()..moveTo(padL, padT + innerH);
    for (final p in points) {
      area.lineTo(p.dx, p.dy);
    }
    area
      ..lineTo(padL + innerW, padT + innerH)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.accent.withValues(alpha: 0.22),
            AppColors.accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < spendMonths.length; i++) {
      if (i % 2 == 1) continue;
      final x = padL + (i / (series.length - 1)) * innerW;
      tp.text = TextSpan(
        text: spendMonths[i],
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant _AreaPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor || oldDelegate.labelColor != labelColor;
}

class IncomeSpendBars extends StatelessWidget {
  const IncomeSpendBars({
    super.key,
    this.months,
    this.income,
    this.spend,
  });

  final List<String>? months;
  final List<double>? income;
  final List<double>? spend;

  @override
  Widget build(BuildContext context) {
    final m = months ?? reportMonths;
    final inc = income ?? reportIncome;
    final sp = spend ?? reportSpend;
    if (m.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'No cashflow data yet',
            style: TextStyle(
              color: context.dashMute,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
    final rawMax = math.max(
      inc.isEmpty ? 0.0 : inc.reduce(math.max),
      sp.isEmpty ? 0.0 : sp.reduce(math.max),
    );
    final max = rawMax <= 0 ? 1.0 : rawMax;
    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < m.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Container(
                              height: ((i < inc.length ? inc[i] : 0) / max) * 160,
                              decoration: BoxDecoration(
                                color: const Color(0xFFC7C3FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Container(
                              height: ((i < sp.length ? sp[i] : 0) / max) * 160,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      m[i],
                      style: TextStyle(
                        color: context.dashSoftMute,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
