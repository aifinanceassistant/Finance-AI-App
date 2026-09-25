import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../dash_colors.dart';
import '../../auth/auth_scope.dart';
import '../accounts_controller.dart';
import '../accounts_scope.dart';
import '../categories_scope.dart';
import '../dash_sheets.dart';
import '../data.dart';
import '../filter_sort.dart';
import '../form_validation.dart';
import '../shimmer.dart';
import '../transactions_controller.dart';
import '../transactions_scope.dart';
import '../spaces_scope.dart';
import '../ui.dart';

const _filterFields = [
  FilterFieldDef(
    id: 'merchant',
    label: 'Description',
    type: FilterFieldType.text,
  ),
  FilterFieldDef(id: 'type', label: 'Type', type: FilterFieldType.select),
  FilterFieldDef(
    id: 'category',
    label: 'Category',
    type: FilterFieldType.select,
  ),
  FilterFieldDef(
    id: 'account',
    label: 'Account',
    type: FilterFieldType.select,
  ),
  FilterFieldDef(id: 'amount', label: 'Amount', type: FilterFieldType.number),
  FilterFieldDef(id: 'status', label: 'Status', type: FilterFieldType.select),
  FilterFieldDef(
    id: 'approvalStatus',
    label: 'Approval',
    type: FilterFieldType.select,
  ),
  FilterFieldDef(id: 'date', label: 'Date', type: FilterFieldType.date),
];

const _statusLabels = ['Succeeded', 'Pending', 'Failed'];
const _approvalLabels = ['Pending', 'Approved', 'Rejected'];

String _statusLabel(TxnStatus status) {
  switch (status) {
    case TxnStatus.succeeded:
      return 'Succeeded';
    case TxnStatus.pending:
      return 'Pending';
    case TxnStatus.failed:
      return 'Failed';
  }
}

String _approvalLabel(ApprovalStatus status) {
  switch (status) {
    case ApprovalStatus.pending:
      return 'Pending';
    case ApprovalStatus.approved:
      return 'Approved';
    case ApprovalStatus.rejected:
      return 'Rejected';
  }
}

Object? _txnValue(DemoTxn t, String field) {
  switch (field) {
    case 'merchant':
      return t.merchant;
    case 'type':
      return moneyMoveLabel(t.type);
    case 'category':
      return t.category;
    case 'account':
      return t.account;
    case 'amount':
      return t.amount;
    case 'status':
      return _statusLabel(t.status);
    case 'approvalStatus':
      return _approvalLabel(t.approvalStatus);
    case 'date':
      return t.dateIso ?? t.date;
    default:
      return '';
  }
}

class _CashBucket {
  _CashBucket({
    required this.key,
    required this.label,
  });

  final String key;
  final String label;
  double inflow = 0;
  double outflow = 0;
  double get net => inflow - outflow;
}

DateTime? _parseDay(String? raw) {
  if (raw == null || raw.length < 10) return null;
  final iso = raw.substring(0, 10);
  final parts = iso.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d, 12);
}

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _todayLocal() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 12);
}

String _monthLabel(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return "${months[d.month - 1]} ${d.year}";
}

String _monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// Trailing [months] ending at the current month (default 12).
List<_CashBucket> _buildCashflowBuckets(
  List<DemoTxn> txns, {
  int months = 12,
}) {
  final count = months < 1 ? 1 : months;
  final today = _todayLocal();
  final end = DateTime(today.year, today.month, 1, 12);
  final min = DateTime(end.year, end.month - (count - 1), 1, 12);

  final buckets = <_CashBucket>[
    for (var i = 0; i < count; i++)
      _CashBucket(
        key: _dayKey(DateTime(min.year, min.month + i, 1, 12)),
        label: _monthLabel(DateTime(min.year, min.month + i, 1, 12)),
      ),
  ];

  for (final t in txns) {
    final day = _parseDay(t.dateIso);
    if (day == null) continue;
    final i = (day.year - min.year) * 12 + (day.month - min.month);
    if (i < 0 || i >= count) continue;
    if (t.amount > 0) {
      buckets[i].inflow += t.amount;
    } else if (t.amount < 0) {
      buckets[i].outflow += t.amount.abs();
    }
  }
  return buckets;
}

int _cashflowAllMonthSpan(List<DemoTxn> txns) {
  final end = DateTime(_todayLocal().year, _todayLocal().month, 1, 12);
  DateTime? earliest;
  for (final t in txns) {
    final day = _parseDay(t.dateIso);
    if (day == null) continue;
    final m = DateTime(day.year, day.month, 1, 12);
    if (earliest == null || m.isBefore(earliest)) earliest = m;
  }
  if (earliest == null) return 1;
  return ((end.year - earliest.year) * 12 + (end.month - earliest.month) + 1)
      .clamp(1, 1200);
}

bool _hasTxnsOlderThanTwoYears(List<DemoTxn> txns) {
  final cutoff = DateTime(
    _todayLocal().year,
    _todayLocal().month - 24,
    _todayLocal().day,
    12,
  );
  for (final t in txns) {
    final day = _parseDay(t.dateIso);
    if (day != null && day.isBefore(cutoff)) return true;
  }
  return false;
}

int _currentMonthBucketIndex(List<_CashBucket> buckets) {
  if (buckets.isEmpty) return 0;
  final prefix = _monthKey(_todayLocal());
  var inMonth = -1;
  for (var i = 0; i < buckets.length; i++) {
    if (buckets[i].key.startsWith(prefix)) inMonth = i;
  }
  if (inMonth >= 0) return inMonth;
  return buckets.length - 1;
}

enum _CashMetric { inflow, outflow, net }

enum _CashChartType { bars, line, area, step, combined }

List<_CashChartType> _chartTypesFor(_CashMetric metric) => metric == _CashMetric.net
    ? const [
        _CashChartType.combined,
        _CashChartType.bars,
        _CashChartType.line,
        _CashChartType.area,
        _CashChartType.step,
      ]
    : const [
        _CashChartType.bars,
        _CashChartType.line,
        _CashChartType.area,
        _CashChartType.step,
      ];

String _chartTypeLabel(_CashChartType t) => switch (t) {
      _CashChartType.bars => 'Bars',
      _CashChartType.line => 'Line',
      _CashChartType.area => 'Area',
      _CashChartType.step => 'Step',
      _CashChartType.combined => 'Combined',
    };

class _CashBarsPainter extends CustomPainter {
  _CashBarsPainter({
    required this.buckets,
    required this.metric,
    required this.chartType,
    required this.focus,
    required this.lineColor,
    required this.labelColor,
  });

  final List<_CashBucket> buckets;
  final _CashMetric metric;
  final _CashChartType chartType;
  final int focus;
  final Color lineColor;
  final Color labelColor;

  static const _inColor = Color(0xFF0D9488);
  static const _outColor = Color(0xFFE11D48);
  static const _netColor = Color(0xFF635BFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    final combined = chartType == _CashChartType.combined;
    final padBottom = combined ? 14.0 : 0.0;
    final chartH = size.height - padBottom;
    final n = buckets.length;
    final gap = 1.0;
    final slot = ((size.width - gap * (n - 1)) / n).clamp(2.0, 80.0);
    final barGap = combined ? 1.0 : 0.0;
    final barW = combined
        ? math.max(1.5, (slot - barGap) / 2)
        : slot;

    double seriesOf(_CashBucket b) {
      if (metric == _CashMetric.inflow) return b.inflow;
      if (metric == _CashMetric.outflow) return b.outflow;
      return b.net;
    }

    final seriesColor = metric == _CashMetric.outflow
        ? _outColor
        : metric == _CashMetric.net
            ? _netColor
            : _inColor;

    final scaleMax = combined
        ? buckets
            .map((b) => math.max(b.inflow, math.max(b.outflow, b.net.abs())))
            .reduce(math.max)
            .clamp(1.0, double.infinity)
        : buckets
            .map(seriesOf)
            .map((v) => v.abs())
            .reduce(math.max)
            .clamp(1.0, double.infinity);

    final yMin = combined
        ? math.min(0.0, buckets.map((b) => b.net).reduce(math.min))
        : math.min(0.0, buckets.map(seriesOf).reduce(math.min));
    final yMax = scaleMax;
    final yRange = (yMax - yMin).abs() < 0.001 ? 1.0 : yMax - yMin;

    double yAt(double v) => ((yMax - v) / yRange) * chartH;
    double slotX(int i) => i * (slot + gap);
    double xCenter(int i) => slotX(i) + slot / 2;
    final zeroY = yAt(0);
    const zeroBump = 3.5;

    ({double y, double h}) barAboveZero(double value) {
      if (value <= 0) {
        return (y: zeroY - zeroBump, h: zeroBump);
      }
      final top = yAt(value);
      final h = math.max(zeroBump, zeroY - top);
      return (y: zeroY - h, h: h);
    }

    ({double y, double h}) barBelowZero(double value) {
      if (value >= 0) {
        return (y: zeroY, h: zeroBump);
      }
      final bottom = yAt(value);
      final h = math.max(zeroBump, bottom - zeroY);
      return (y: zeroY, h: h);
    }

    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()
        ..color = lineColor
        ..strokeWidth = 1,
    );

    if (combined || chartType == _CashChartType.bars) {
      for (var i = 0; i < n; i++) {
        final b = buckets[i];
        final opacity = focus == i ? 1.0 : 0.85;
        final x0 = slotX(i);
        if (combined) {
          final pairLeft = x0;
          final inc = barAboveZero(b.inflow);
          final out = barAboveZero(b.outflow);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(pairLeft, inc.y, barW, inc.h),
              const Radius.circular(1.5),
            ),
            Paint()..color = _inColor.withValues(alpha: opacity),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(pairLeft + barW + barGap, out.y, barW, out.h),
              const Radius.circular(1.5),
            ),
            Paint()..color = _outColor.withValues(alpha: opacity),
          );
        } else {
          final v = seriesOf(b);
          final geom = v >= 0 ? barAboveZero(v) : barBelowZero(v);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x0, geom.y, barW, geom.h),
              const Radius.circular(1.5),
            ),
            Paint()..color = seriesColor.withValues(alpha: opacity),
          );
        }
      }
    }

    if (chartType == _CashChartType.area) {
      final fill = Path();
      for (var i = 0; i < n; i++) {
        final p = Offset(xCenter(i), yAt(seriesOf(buckets[i])));
        if (i == 0) {
          fill.moveTo(p.dx, p.dy);
        } else {
          fill.lineTo(p.dx, p.dy);
        }
      }
      fill
        ..lineTo(xCenter(n - 1), zeroY)
        ..lineTo(xCenter(0), zeroY)
        ..close();
      canvas.drawPath(
        fill,
        Paint()..color = seriesColor.withValues(alpha: 0.2),
      );
    }

    if (chartType == _CashChartType.line ||
        chartType == _CashChartType.area ||
        chartType == _CashChartType.step ||
        combined) {
      final path = Path();
      if (combined) {
        for (var i = 0; i < n; i++) {
          final p = Offset(xCenter(i), yAt(buckets[i].net));
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
      } else if (chartType == _CashChartType.step) {
        for (var i = 0; i < n; i++) {
          final x = xCenter(i);
          final y = yAt(seriesOf(buckets[i]));
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, yAt(seriesOf(buckets[i - 1])));
            path.lineTo(x, y);
          }
        }
      } else {
        for (var i = 0; i < n; i++) {
          final p = Offset(xCenter(i), yAt(seriesOf(buckets[i])));
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = combined ? _netColor : seriesColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      final fi = focus.clamp(0, n - 1);
      final fy = combined
          ? yAt(buckets[fi].net)
          : yAt(seriesOf(buckets[fi]));
      canvas.drawCircle(
        Offset(xCenter(fi), fy),
        3.5,
        Paint()..color = combined ? _netColor : seriesColor,
      );
      canvas.drawCircle(
        Offset(xCenter(fi), fy),
        3.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    if (combined) {
      final tp = TextPainter(textDirection: TextDirection.ltr);
      void legend(double x, Color c, String label, {bool line = false}) {
        if (line) {
          canvas.drawLine(
            Offset(x, size.height - 6),
            Offset(x + 10, size.height - 6),
            Paint()
              ..color = c
              ..strokeWidth = 2,
          );
          tp.text = TextSpan(
            text: label,
            style: TextStyle(
              color: labelColor,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          );
          tp.layout();
          tp.paint(canvas, Offset(x + 14, size.height - 10));
        } else {
          canvas.drawCircle(
            Offset(x + 3, size.height - 6),
            3,
            Paint()..color = c,
          );
          tp.text = TextSpan(
            text: label,
            style: TextStyle(
              color: labelColor,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          );
          tp.layout();
          tp.paint(canvas, Offset(x + 10, size.height - 10));
        }
      }

      legend(0, _inColor, 'Income');
      legend(48, _outColor, 'Expenses');
      legend(108, _netColor, 'Net', line: true);
    }
  }

  @override
  bool shouldRepaint(covariant _CashBarsPainter oldDelegate) =>
      oldDelegate.buckets != buckets ||
      oldDelegate.metric != metric ||
      oldDelegate.chartType != chartType ||
      oldDelegate.focus != focus ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.labelColor != labelColor;
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    super.key,
    this.categoryFilter,
    this.openReconcileOnStart = false,
    this.onRefresh,
  });

  final String? categoryFilter;
  final bool openReconcileOnStart;
  final Future<void> Function()? onRefresh;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late List<FilterRule> _filterRules;
  List<SortRule> _sortRules = [];
  String _search = '';
  final _scroll = ScrollController();
  bool _stickyPinned = false;
  bool _stickyStatsOpen = false;
  bool _stickyInteract = false;
  bool _foldingEnabled = true;

  TransactionsController get _ctrl => TransactionsScope.of(context);
  List<DemoTxn> get _txns => _ctrl.transactions;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    final filter = widget.categoryFilter?.trim();
    _filterRules = filter != null && filter.isNotEmpty
        ? [
            FilterRule(
              id: newRuleId(),
              field: 'category',
              operator: 'is',
              value: filter,
            ),
          ]
        : [];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: discarded_futures
      _loadFoldingPref();
      if (widget.openReconcileOnStart && mounted) {
        // ignore: discarded_futures
        _openReconcileSheet();
      }
    });
  }

  Future<void> _loadFoldingPref() async {
    final auth = AuthScope.read(context);
    final data = await auth.apiDecode('GET', '/api/profile');
    if (!mounted || data is! Map<String, dynamic>) return;
    if (data['transactionsFoldingMode'] is bool) {
      setState(() {
        _foldingEnabled = data['transactionsFoldingMode'] as bool;
        if (!_foldingEnabled) {
          _stickyPinned = false;
          _stickyStatsOpen = false;
          _stickyInteract = false;
        }
      });
    }
    final currency = (data['currency'] as String?)?.trim();
    if (currency != null && currency.isNotEmpty) {
      DisplayCurrency.setCode(currency);
      final rateData = await auth.apiDecode(
        'GET',
        '/api/currency/rate?from=${Uri.encodeQueryComponent(currency)}',
      );
      if (rateData is Map<String, dynamic>) {
        final rate = (rateData['rate'] as num?)?.toDouble();
        if (rate != null && rate.isFinite && rate > 0) {
          DisplayCurrency.setRateToUsd(currency, rate);
        }
      }
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_foldingEnabled) return;
    if (!_scroll.hasClients) return;
    if (_stickyInteract) return;

    final openAt = MediaQuery.sizeOf(context).height * 0.55;
    final hideAt = 72.0;
    final offset = _scroll.offset;

    if (!_stickyPinned) {
      if (offset >= openAt) {
        setState(() => _stickyPinned = true);
      }
      return;
    }

    // Fold away when the user scrolls back near the top.
    if (offset <= hideAt) {
      setState(() {
        _stickyPinned = false;
        _stickyStatsOpen = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openReconcileOnStart && !oldWidget.openReconcileOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // ignore: discarded_futures
          _openReconcileSheet();
        }
      });
    }
    final next = widget.categoryFilter?.trim();
    final prev = oldWidget.categoryFilter?.trim();
    if (next == prev) return;
    setState(() {
      _filterRules = next != null && next.isNotEmpty
          ? [
              FilterRule(
                id: newRuleId(),
                field: 'category',
                operator: 'is',
                value: next,
              ),
            ]
          : [];
    });
  }

  List<String> _selectOptions(String field) {
    if (field == 'status') return _statusLabels;
    if (field == 'approvalStatus') return _approvalLabels;
    if (field == 'type') return kMoneyMoveLabels;
    if (field == 'category') {
      return [...{..._txns.map((t) => t.category)}].toList()..sort();
    }
    if (field == 'account') {
      return [...{..._txns.map((t) => t.account)}].toList()..sort();
    }
    return [];
  }

  List<DemoTxn> get _filtered {
    final searched = applySearch(_txns, _search, _filterFields, _txnValue);
    final filtered = applyFilters(searched, _filterRules, _txnValue);
    return applySort(filtered, _sortRules, _txnValue);
  }

  void _exportCsv() {
    final filtered = _filtered;
    final rows = [
      'Amount,Type,Status,Approval,Description,Category,Account,Date',
      for (final t in filtered)
        '${t.amount},${moneyMoveLabel(t.type)},${_statusLabel(t.status)},'
        '${_approvalLabel(t.approvalStatus)},'
        '"${t.merchant.replaceAll('"', '""')}",'
        '"${t.category.replaceAll('"', '""')}",'
        '"${t.account.replaceAll('"', '""')}",'
        '"${t.date.replaceAll('"', '""')}"',
    ];
    Clipboard.setData(ClipboardData(text: rows.join('\n')));
    toast(
      context,
      'CSV copied · ${filtered.length} transaction${filtered.length == 1 ? '' : 's'}',
    );
  }

  Future<void> _openAddSheet() async {
    final accounts = AccountsScope.of(context).accounts;
    final merchantCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final categoryOptions = [
      'Uncategorized',
      ...{..._txns.map((t) => t.category)}.where((c) => c != 'Uncategorized'),
    ]..sort();
    var type = MoneyMove.expense;
    var category = categoryOptions.first;
    final accountKeys = [
      for (final a in accounts) AccountsController.accountKey(a),
    ];
    var accountKey = accountKeys.isNotEmpty ? accountKeys.first : '';
    var currency = DisplayCurrency.code;
    var fieldErrors = <String, String?>{};
    final dateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );

    await showDashSheet<void>(
      context: context,
      title: 'Add transaction',
      description: 'Record a payment in this space',
      builder: (ctx, setSheetState) {
        DemoAccount? selectedAccount() {
          for (final a in accounts) {
            if (AccountsController.accountKey(a) == accountKey) return a;
          }
          return accounts.isEmpty ? null : accounts.first;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashFieldLabel('Description'),
            DashTextField(
              controller: merchantCtrl,
              hint: 'Coffee, rent, payroll…',
              autofocus: true,
              errorText: fieldErrors['description'],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Amount'),
            Row(
              children: [
                Expanded(
                  child: DashTextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    hint: '0.00',
                    errorText: fieldErrors['amount'],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: DashDropdown<String>(
                    value: currency,
                    items: kSupportedCurrencies,
                    labelOf: (c) => c,
                    onChanged: (v) => setSheetState(() => currency = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Type'),
            DashDropdown<MoneyMove>(
              value: type,
              items: const [
                MoneyMove.expense,
                MoneyMove.income,
                MoneyMove.transfer,
              ],
              labelOf: moneyMoveLabel,
              onChanged: (v) => setSheetState(() => type = v),
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Category'),
            DashDropdown<String>(
              value: category,
              items: categoryOptions,
              labelOf: (c) => c,
              onChanged: (v) => setSheetState(() => category = v),
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Account'),
            if (accounts.isEmpty)
              Text(
                fieldErrors['account'] ?? 'Connect a bank account first',
                style: TextStyle(
                  color: fieldErrors['account'] != null
                      ? AppColors.danger
                      : context.dashSoftMute,
                  fontSize: 13,
                ),
              )
            else
              DashDropdown<String>(
                value: accountKey,
                items: accountKeys,
                labelOf: (key) {
                  final a = accounts.firstWhere(
                    (x) => AccountsController.accountKey(x) == key,
                    orElse: () => accounts.first,
                  );
                  return '${a.bank} · ${a.number}';
                },
                onChanged: (v) => setSheetState(() => accountKey = v),
              ),
            const SizedBox(height: 14),
            const DashFieldLabel('Date'),
            DashTextField(
              controller: dateCtrl,
              hint: 'YYYY-MM-DD',
              errorText: fieldErrors['date'],
            ),
            const SizedBox(height: 18),
            AccentButton(
              label: 'Add',
              onPressed: () async {
                final merchant = merchantCtrl.text.trim();
                final descErr = requiredText(merchant, 'Description');
                final amountErr = positiveAmount(amountCtrl.text);
                final dateErr = requiredIsoDate(dateCtrl.text);
                final acct = selectedAccount();
                final accountErr = acct == null
                    ? 'Account is required.'
                    : null;
                final id = acct?.id?.trim() ?? '';
                final errors = <String, String?>{
                  if (descErr != null) 'description': descErr,
                  if (amountErr != null) 'amount': amountErr,
                  if (accountErr != null) 'account': accountErr,
                  if (dateErr != null) 'date': dateErr,
                };
                setSheetState(() => fieldErrors = errors);
                if (hasFieldErrors(errors)) {
                  toast(
                    context,
                    firstFieldError(errors) ?? 'Fix the highlighted fields',
                  );
                  return;
                }
                if (id.isEmpty && !_ctrl.spaceId.startsWith('fake')) {
                  toast(context, 'Connect a bank account first');
                  return;
                }
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                final created = await _ctrl.create(
                  merchant: merchant,
                  amount: amount,
                  accountId: id.isNotEmpty ? id : accountKey,
                  accountLabel: '${acct!.bank} · ${acct.number}',
                  category: category,
                  type: type,
                  date: dateCtrl.text.trim(),
                  currency: currency,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                toast(
                  context,
                  created == null
                      ? 'Couldn’t add transaction'
                      : 'Transaction added',
                );
              },
            ),
          ],
        );
      },
    );

    merchantCtrl.dispose();
    amountCtrl.dispose();
    dateCtrl.dispose();
  }

  List<String> _categoryOptionsFor(DemoTxn t) {
    final fromScope = context
            .getInheritedWidgetOfExactType<CategoriesScope>()
            ?.notifier
            ?.categories
            .map((c) => c.name)
            .toList() ??
        const <String>[];
    final names = <String>{
      if (t.category.trim().isNotEmpty) t.category,
      'Uncategorized',
      ...fromScope,
      ..._txns.map((x) => x.category),
    };
    final list = names.where((n) => n.trim().isNotEmpty).toList()..sort();
    if (!list.contains(t.category) && t.category.trim().isNotEmpty) {
      list.insert(0, t.category);
    }
    return list.isEmpty ? ['Uncategorized'] : list;
  }

  Future<void> _openDetailSheet(DemoTxn txn) async {
    var category = txn.category;
    var type = txn.type;
    var reconciled = txn.status == TxnStatus.succeeded;
    final categoryOptions = _categoryOptionsFor(txn);
    if (!categoryOptions.contains(category)) {
      category = categoryOptions.first;
    }

    await showDashSheet<void>(
      context: context,
      title: txn.merchant,
      description: '${txn.account} · ${txn.date}',
      builder: (ctx, setSheetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                StatusPill(status: txn.status),
                const SizedBox(width: 8),
                ApprovalActions(
                  status: txn.approvalStatus,
                  onApprove: () async {
                    await _ctrl.setApproval(txn.id, ApprovalStatus.approved);
                    if (!mounted) return;
                    Navigator.pop(context);
                    toast(context, 'Approved · ${txn.merchant}');
                  },
                  onReject: () async {
                    await _ctrl.setApproval(txn.id, ApprovalStatus.rejected);
                    if (!mounted) return;
                    Navigator.pop(context);
                    toast(context, 'Rejected · ${txn.merchant}');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            ConvertedAmountText(
              amount: (txn.originalAmount ?? txn.amount).abs(),
              originalCurrency: txn.originalCurrency ?? 'USD',
              signed: true,
              isIncome: txn.amount > 0,
              primaryStyle: TextStyle(
                color: txn.amount > 0 ? AppColors.success : context.dashInk,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            const DashFieldLabel('Category'),
            DashDropdown<String>(
              value: category,
              items: categoryOptions,
              labelOf: (c) => c,
              onChanged: (v) => setSheetState(() => category = v),
            ),
            const SizedBox(height: 14),
            const DashFieldLabel('Type'),
            DashDropdown<MoneyMove>(
              value: type,
              items: const [
                MoneyMove.expense,
                MoneyMove.income,
                MoneyMove.transfer,
              ],
              labelOf: moneyMoveLabel,
              onChanged: (v) => setSheetState(() => type = v),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => setSheetState(() => reconciled = !reconciled),
              child: Row(
                children: [
                  Checkbox(
                    value: reconciled,
                    onChanged: (v) =>
                        setSheetState(() => reconciled = v ?? false),
                    activeColor: AppColors.brand,
                  ),
                  Expanded(
                    child: Text(
                      'Reconciled',
                      style: TextStyle(
                        color: context.dashInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (txn.status == TxnStatus.pending ||
                txn.status == TxnStatus.failed) ...[
              const SizedBox(height: 8),
              GhostButton(
                label: 'Mark settled',
                onPressed: () async {
                  await _ctrl.markSettled(txn.id);
                  if (!mounted) return;
                  Navigator.pop(context);
                  toast(context, 'Settled · ${txn.merchant}');
                },
              ),
            ],
          ],
        );
      },
      actions: [
        TextButton(
          onPressed: () async {
            final ok = await _ctrl.remove(txn.id);
            if (!mounted) return;
            Navigator.pop(context);
            toast(context, ok ? 'Transaction removed' : 'Could not remove');
          },
          child: const Text(
            'Delete',
            style: TextStyle(
              color: Color(0xFFC53030),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: GhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Expanded(
          child: AccentButton(
            label: 'Save',
            onPressed: () async {
              await _ctrl.updateDetail(
                id: txn.id,
                category: category,
                type: type,
                reconciled: reconciled,
              );
              if (!mounted) return;
              Navigator.pop(context);
              toast(context, 'Transaction updated · ${txn.merchant}');
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openReconcileSheet() async {
    await showDashSheet<void>(
      context: context,
      title: 'Reconcile',
      description: 'Settle pending or failed transactions',
      builder: (ctx, setSheetState) {
        final open = _txns
            .where(
              (t) =>
                  t.status == TxnStatus.pending ||
                  t.status == TxnStatus.failed,
            )
            .toList();
        if (open.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nothing to reconcile',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.dashSoftMute, fontSize: 13),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final t in open)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  border: Border.all(color: context.dashLine),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.merchant,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.dashInk,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_statusLabel(t.status)} · ${t.category}',
                            style: TextStyle(
                              color: context.dashSoftMute,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _ctrl.markSettled(t.id);
                        if (!ctx.mounted) return;
                        setSheetState(() {});
                        if (!mounted) return;
                        toast(context, 'Settled · ${t.merchant}');
                      },
                      child: const Text(
                        'Settle',
                        style: TextStyle(
                          color: Color(0xFF3B9AE0),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
      actions: [
        Expanded(
          child: GhostButton(
            label: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Expanded(
          child: AccentButton(
            label: 'Settle all',
            onPressed: () async {
              final open = _txns
                  .where(
                    (t) =>
                        t.status == TxnStatus.pending ||
                        t.status == TxnStatus.failed,
                  )
                  .length;
              if (open == 0) {
                Navigator.pop(context);
                toast(context, 'Nothing to reconcile');
                return;
              }
              await _ctrl.settleAll();
              if (!mounted) return;
              Navigator.pop(context);
              toast(
                context,
                'Settled $open transaction${open == 1 ? '' : 's'}',
              );
            },
          ),
        ),
      ],
    );
  }

  void _openCashflowDetail(List<DemoTxn> txns, _CashMetric metric) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        fullscreenDialog: true,
        opaque: true,
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _CashflowDetailPage(
            txns: List<DemoTxn>.from(txns),
            initialMetric: metric,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.22, 1, 0.36, 1),
            reverseCurve: Curves.easeIn,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.025),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final kpiMonths =
        _defaultCashTimeframe(filtered).monthsFor(filtered);
    final kpiBuckets =
        _buildCashflowBuckets(filtered, months: kpiMonths);
    final inflow =
        kpiBuckets.fold<double>(0, (s, b) => s + b.inflow);
    final outflow =
        kpiBuckets.fold<double>(0, (s, b) => s + b.outflow);
    final net = inflow - outflow;

    return Stack(
      children: [
        dashPullToRefresh(
          onRefresh: widget.onRefresh ??
              () async {
                final id = _ctrl.spaceId;
                if (id.isEmpty) return;
                await _ctrl.loadForSpace(id);
              },
          backgroundColor: context.dashPanel,
          child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              opacity: _stickyPinned ? 0.35 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_ctrl.loading)
                    const DashLoadingBody(kpiCount: 2, listRows: 7)
                  else
                    _ActivityPageChrome(
                      canWrite: SpacesScope.maybeOf(context)
                              ?.can('transactions', 'write') !=
                          false,
                      search: _search,
                      filterRules: _filterRules,
                      sortRules: _sortRules,
                      stickyPinned: _stickyPinned,
                      selectOptions: _selectOptions,
                      onSearchChanged: (v) => setState(() => _search = v),
                      onRulesChanged: (r) =>
                          setState(() => _filterRules = r),
                      onSortsChanged: (s) =>
                          setState(() => _sortRules = s),
                      onExport: _exportCsv,
                      onReconcile: _openReconcileSheet,
                      onAdd: _openAddSheet,
                      inflow: inflow,
                      outflow: outflow,
                      filtered: filtered,
                    ),
                ],
              ),
            ),
            if (!_ctrl.loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ActivityPaymentsBody(
                  filtered: filtered,
                  onTxnTap: _openDetailSheet,
                ),
              ),
          ],
        ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            ignoring: !(_foldingEnabled && _stickyPinned),
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 780),
              curve: _foldingEnabled && _stickyPinned
                  ? const Cubic(0.22, 1, 0.36, 1)
                  : Curves.easeIn,
              offset: _foldingEnabled && _stickyPinned
                  ? Offset.zero
                  : const Offset(0, -1.1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 640),
                opacity: _foldingEnabled && _stickyPinned ? 1 : 0,
                child: Focus(
                  onFocusChange: (hasFocus) {
                    _stickyInteract = hasFocus;
                    if (!hasFocus) {
                      _onScroll();
                    } else if (!_stickyPinned) {
                      setState(() => _stickyPinned = true);
                    }
                  },
                  child: Material(
                  color: context.dashPanel,
                  elevation: context.isDark ? 0 : 6,
                  shadowColor: Colors.black26,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilterSortBar(
                                fields: _filterFields,
                                rules: _filterRules,
                                sorts: _sortRules,
                                selectOptions: _selectOptions,
                                defaultFilterField: 'category',
                                defaultSortField: 'date',
                                search: _search,
                                onSearchChanged: (v) =>
                                    setState(() => _search = v),
                                searchHint: 'Search activity…',
                                onRulesChanged: (rules) =>
                                    setState(() => _filterRules = rules),
                                onSortsChanged: (sorts) =>
                                    setState(() => _sortRules = sorts),
                                iconButtons: true,
                                expandSearch: true,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () => setState(
                                () => _stickyStatsOpen = !_stickyStatsOpen,
                              ),
                              tooltip: _stickyStatsOpen
                                  ? 'Hide stats'
                                  : 'Show stats',
                              icon: Icon(
                                Icons.speed_outlined,
                                size: 18,
                                color: _stickyStatsOpen
                                    ? AppColors.brandDark
                                    : context.dashMute,
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _stickyPinned = false;
                                  _stickyStatsOpen = false;
                                  _stickyInteract = false;
                                });
                                if (_scroll.hasClients) {
                                  _scroll.animateTo(
                                    0,
                                    duration:
                                        const Duration(milliseconds: 420),
                                    curve: Curves.easeOutCubic,
                                  );
                                }
                              },
                              icon: const Icon(Icons.close, size: 18),
                              color: context.dashMute,
                              tooltip: 'Close folded view',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: const Cubic(0.22, 1, 0.36, 1),
                        alignment: Alignment.topCenter,
                        child: _stickyStatsOpen
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Divider(
                                    height: 1,
                                    color: context.dashLine,
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _StickyKpiChip(
                                          label: 'Inflow',
                                          value: money(inflow),
                                          color: const Color(0xFF0D9488),
                                          onTap: () => _openCashflowDetail(
                                            filtered,
                                            _CashMetric.inflow,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 44,
                                        color: context.dashLine,
                                      ),
                                      Expanded(
                                        child: _StickyKpiChip(
                                          label: 'Outflow',
                                          value: money(outflow),
                                          color: const Color(0xFFE11D48),
                                          onTap: () => _openCashflowDetail(
                                            filtered,
                                            _CashMetric.outflow,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 44,
                                        color: context.dashLine,
                                      ),
                                      Expanded(
                                        child: _StickyKpiChip(
                                          label: 'Net',
                                          value: money(net, signed: true),
                                          color: const Color(0xFF635BFF),
                                          onTap: () => _openCashflowDetail(
                                            filtered,
                                            _CashMetric.net,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityPageChrome extends StatelessWidget {
  const _ActivityPageChrome({
    required this.canWrite,
    required this.search,
    required this.filterRules,
    required this.sortRules,
    required this.stickyPinned,
    required this.selectOptions,
    required this.onSearchChanged,
    required this.onRulesChanged,
    required this.onSortsChanged,
    required this.onExport,
    required this.onReconcile,
    required this.onAdd,
    required this.inflow,
    required this.outflow,
    required this.filtered,
  });

  final bool canWrite;
  final String search;
  final List<FilterRule> filterRules;
  final List<SortRule> sortRules;
  final bool stickyPinned;
  final List<String> Function(String field) selectOptions;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<List<FilterRule>> onRulesChanged;
  final ValueChanged<List<SortRule>> onSortsChanged;
  final VoidCallback onExport;
  final VoidCallback onReconcile;
  final VoidCallback onAdd;
  final double inflow;
  final double outflow;
  final List<DemoTxn> filtered;

  Widget _filterBar() {
    return IgnorePointer(
      ignoring: stickyPinned,
      child: Opacity(
        opacity: stickyPinned ? 0 : 1,
        child: FilterSortBar(
          fields: _filterFields,
          rules: filterRules,
          sorts: sortRules,
          selectOptions: selectOptions,
          defaultFilterField: 'category',
          defaultSortField: 'date',
          search: search,
          onSearchChanged: onSearchChanged,
          searchHint: 'Search activity…',
          onRulesChanged: onRulesChanged,
          onSortsChanged: onSortsChanged,
          iconButtons: true,
          expandSearch: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashFeedChrome(
      title: 'Activity',
      subtitle: '${filtered.length} moves',
      onSecondary: onExport,
      secondaryTooltip: 'Export CSV',
      extraActions: [
        IconButton(
          onPressed: onReconcile,
          tooltip: 'Reconcile',
          icon: const Icon(Icons.fact_check_outlined, size: 22),
          color: context.dashInk,
          visualDensity: VisualDensity.compact,
        ),
      ],
      onPrimary: onAdd,
      primaryEnabled: canWrite,
      metaLine: 'In ${money(inflow)} · Out ${money(outflow)}',
      filterBar: _filterBar(),
    );
  }
}

class _ActivityPaymentsBody extends StatelessWidget {
  const _ActivityPaymentsBody({
    required this.filtered,
    required this.onTxnTap,
  });

  final List<DemoTxn> filtered;
  final ValueChanged<DemoTxn> onTxnTap;

  Widget _empty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
      child: Text(
        'No transactions match these filters',
        style: TextStyle(
          color: context.dashMute,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (filtered.isEmpty) {
      return _empty(context);
    }
    final groups = <String, List<DemoTxn>>{};
    final order = <String>[];
    for (final t in filtered) {
      final key = t.date;
      if (!groups.containsKey(key)) {
        groups[key] = [];
        order.add(key);
      }
      groups[key]!.add(t);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final date in order) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
            child: Text(
              date,
              style: TextStyle(
                color: context.dashMute,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final t in groups[date]!)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTxnTap(t),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: context.dashLine),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.merchant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.dashInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        money(t.amount, signed: true),
                        style: TextStyle(
                          color: t.amount > 0
                              ? AppColors.success
                              : context.dashInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _StickyKpiChip extends StatelessWidget {
  const _StickyKpiChip({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.dashMute,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.02,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


enum _CashTimeframe { m6, y1, y2, all }

extension on _CashTimeframe {
  String get label => switch (this) {
        _CashTimeframe.m6 => 'Last 6 months',
        _CashTimeframe.y1 => 'Last 1 year',
        _CashTimeframe.y2 => 'Last 2 years',
        _CashTimeframe.all => 'All years',
      };

  int monthsFor(List<DemoTxn> txns) => switch (this) {
        _CashTimeframe.m6 => 6,
        _CashTimeframe.y1 => 12,
        _CashTimeframe.y2 => 24,
        // All years: if history fits in 2 years, match the 2y window exactly.
        _CashTimeframe.all =>
          _cashflowAllMonthSpan(txns) > 24 ? _cashflowAllMonthSpan(txns) : 24,
      };
}

_CashTimeframe _defaultCashTimeframe(List<DemoTxn> txns) =>
    _hasTxnsOlderThanTwoYears(txns) ? _CashTimeframe.all : _CashTimeframe.y2;

class _CashflowDetailPage extends StatefulWidget {
  const _CashflowDetailPage({
    required this.txns,
    required this.initialMetric,
  });

  final List<DemoTxn> txns;
  final _CashMetric initialMetric;

  @override
  State<_CashflowDetailPage> createState() => _CashflowDetailPageState();
}

class _CashflowDetailPageState extends State<_CashflowDetailPage> {
  late _CashMetric _metric = widget.initialMetric;
  late _CashChartType _chartType = widget.initialMetric == _CashMetric.net
      ? _CashChartType.combined
      : _CashChartType.bars;
  late _CashTimeframe _timeframe = _defaultCashTimeframe(widget.txns);
  int? _active;
  late int _pinned;

  List<_CashBucket> get _buckets => _buildCashflowBuckets(
        widget.txns,
        months: _timeframe.monthsFor(widget.txns),
      );

  @override
  void initState() {
    super.initState();
    _pinned = _currentMonthBucketIndex(_buckets);
  }

  @override
  Widget build(BuildContext context) {
    final buckets = _buckets;
    final combined = _chartType == _CashChartType.combined;
    final chartType = _chartType;
    final focus = (_active ?? _pinned).clamp(
      0,
      buckets.isEmpty ? 0 : buckets.length - 1,
    );
    final b = buckets.isEmpty ? null : buckets[focus];

    double periodTotal = 0;
    for (final row in buckets) {
      if (_metric == _CashMetric.inflow) {
        periodTotal += row.inflow;
      } else if (_metric == _CashMetric.outflow) {
        periodTotal += row.outflow;
      } else {
        periodTotal += row.net;
      }
    }

    final glowColor = switch (_metric) {
      _CashMetric.inflow => const Color(0xFF0D9488),
      _CashMetric.outflow => const Color(0xFFE11D48),
      _CashMetric.net => const Color(0xFF635BFF),
    };

    return Scaffold(
      backgroundColor: context.dashPanel,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 180,
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -1.15),
                    radius: 1.1,
                    colors: [
                      glowColor.withValues(alpha: 0.18),
                      glowColor.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<_CashChartType>(
                      value: _chartType,
                      isDense: true,
                      style: TextStyle(
                        color: context.dashInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      icon: Icon(
                        Icons.expand_more,
                        size: 18,
                        color: context.dashSoftMute,
                      ),
                      items: [
                        for (final t in _chartTypesFor(_metric))
                          DropdownMenuItem(
                            value: t,
                            child: Text(_chartTypeLabel(t)),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _chartType = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 1,
                    height: 16,
                    color: context.dashLine,
                  ),
                  const SizedBox(width: 8),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<_CashTimeframe>(
                      value: _timeframe,
                      isDense: true,
                      style: TextStyle(
                        color: context.dashInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      icon: Icon(
                        Icons.expand_more,
                        size: 18,
                        color: context.dashSoftMute,
                      ),
                      items: [
                        for (final t in _CashTimeframe.values)
                          DropdownMenuItem(
                            value: t,
                            child: Text(t.label),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _timeframe = v;
                          _pinned = _currentMonthBucketIndex(
                            _buildCashflowBuckets(
                              widget.txns,
                              months: v.monthsFor(widget.txns),
                            ),
                          );
                          _active = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 1,
                    height: 16,
                    color: context.dashLine,
                  ),
                  const SizedBox(width: 8),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<_CashMetric>(
                      value: _metric,
                      isDense: true,
                      style: TextStyle(
                        color: context.dashInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      icon: Icon(
                        Icons.expand_more,
                        size: 18,
                        color: context.dashSoftMute,
                      ),
                      items: [
                        for (final m in _CashMetric.values)
                          DropdownMenuItem(
                            value: m,
                            child: Text(switch (m) {
                              _CashMetric.inflow => 'Inflow',
                              _CashMetric.outflow => 'Outflow',
                              _CashMetric.net => 'Net',
                            }),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _metric = v;
                          final allowed = _chartTypesFor(v);
                          if (!allowed.contains(_chartType)) {
                            _chartType = v == _CashMetric.net
                                ? _CashChartType.combined
                                : _CashChartType.bars;
                          }
                          _active = null;
                        });
                      },
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: context.dashMute),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                children: [
                  Text(
                    b?.label ?? '',
                    style: TextStyle(
                      color: context.dashSoftMute,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (combined && b != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CashStat(
                          label: 'Income',
                          value: money(b.inflow),
                          color: const Color(0xFF0D9488),
                        ),
                        const SizedBox(width: 28),
                        _CashStat(
                          label: 'Expenses',
                          value: money(b.outflow),
                          color: const Color(0xFFE11D48),
                        ),
                        const SizedBox(width: 28),
                        _CashStat(
                          label: 'Net',
                          value: money(b.net, signed: true),
                          color: context.dashInk,
                        ),
                      ],
                    )
                  else
                    Text(
                      money(
                        _metric == _CashMetric.inflow
                            ? (b?.inflow ?? 0)
                            : _metric == _CashMetric.outflow
                                ? (b?.outflow ?? 0)
                                : (b?.net ?? 0),
                        signed: _metric == _CashMetric.net,
                      ),
                      style: TextStyle(
                        color: context.dashInk,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'Period total ${money(periodTotal, signed: _metric == _CashMetric.net)}',
                    style: const TextStyle(
                      color: Color(0xFFA3ACB9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onTapDown: (d) => _select(
                        d.localPosition.dx,
                        constraints.maxWidth,
                        buckets,
                        pin: true,
                      ),
                      onHorizontalDragUpdate: (d) => _select(
                        d.localPosition.dx,
                        constraints.maxWidth,
                        buckets,
                        pin: false,
                      ),
                      onHorizontalDragEnd: (_) =>
                          setState(() => _active = null),
                      child: CustomPaint(
                        size: Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        ),
                        painter: _CashBarsPainter(
                          buckets: buckets,
                          metric: _metric,
                          chartType: chartType,
                          focus: focus,
                          lineColor: context.dashLine,
                          labelColor: context.dashSoftMute,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
            ),
          ),
        ],
      ),
    );
  }

  void _select(
    double dx,
    double width,
    List<_CashBucket> buckets, {
    required bool pin,
  }) {
    final n = buckets.length;
    if (n == 0 || width <= 0) return;
    final i = (dx / width * n).floor().clamp(0, n - 1);
    setState(() {
      if (pin) {
        _pinned = i;
        _active = i;
      } else {
        _active = i;
      }
    });
  }
}

class _CashStat extends StatelessWidget {
  const _CashStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.dashSoftMute,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

