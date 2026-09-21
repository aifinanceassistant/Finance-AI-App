import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'data.dart';
import 'variant_style.dart';

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: MediaQuery.sizeOf(context).width < 380 ? 24 : 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    height: 1.1,
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
              style: const TextStyle(
                color: AppColors.mute,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions!),
          ],
        ],
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
    final radius = style?.radius ?? 12;

    return Container(
      margin: margin,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A32325D),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.mute,
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
        sparkColor ?? (sparkUp ? AppColors.accent : AppColors.softMute);
    return DashPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.mute,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.ink,
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
                        color: sparkUp ? AppColors.success : AppColors.mute,
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
                  color: sparkUp ? AppColors.success : AppColors.mute,
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
    final fg = foregroundColor ?? AppColors.ink;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        backgroundColor: Colors.white,
        disabledForegroundColor: AppColors.softMute,
        side: BorderSide(
          color: foregroundColor != null
              ? const Color(0xFFCFE4F6)
              : AppColors.line,
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
          const Color(0xFFE6F9F1),
          AppColors.success,
          'Succeeded',
        ),
      TxnStatus.pending => (
          const Color(0xFFFFF8E6),
          AppColors.warning,
          'Pending',
        ),
      TxnStatus.failed => (
          const Color(0xFFFDE8E8),
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
        const TextStyle(
          color: AppColors.softMute,
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
                color: AppColors.softMute,
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
          const Color(0xFFE6F9F1),
          AppColors.success,
          const Color(0xFFA7F3D0),
          'Approved',
        ),
      ApprovalStatus.rejected => (
          const Color(0xFFFDE8E8),
          AppColors.danger,
          const Color(0xFFFECACA),
          'Rejected',
        ),
      ApprovalStatus.pending => (
          const Color(0xFFFFF8E6),
          AppColors.warning,
          const Color(0xFFFDE68A),
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
          color: const Color(0xFFFFF8E6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
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
      MoneyMove.income => (const Color(0xFFE6F9F1), AppColors.success),
      MoneyMove.transfer => (const Color(0xFFEEF4FF), AppColors.brand),
      MoneyMove.expense => (const Color(0xFFF6F9FC), AppColors.mute),
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
          backgroundColor: AppColors.surface,
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
        painter: _AreaPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AreaPainter extends CustomPainter {
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
      ..color = AppColors.line
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
        style: const TextStyle(
          color: AppColors.softMute,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    final max = math.max(
      inc.reduce(math.max),
      sp.reduce(math.max),
    );
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
                              height: (inc[i] / max) * 160,
                              decoration: BoxDecoration(
                                color: const Color(0xFFC7C3FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Container(
                              height: (sp[i] / max) * 160,
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
                      style: const TextStyle(
                        color: AppColors.softMute,
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
