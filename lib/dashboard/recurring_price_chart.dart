import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RecurringPriceChart extends StatefulWidget {
  const RecurringPriceChart({
    super.key,
    required this.history,
    required this.currency,
    required this.name,
  });
  final List<Map<String, dynamic>> history;
  final String currency;
  final String name;
  @override
  State<RecurringPriceChart> createState() => _RecurringPriceChartState();
}

class _RecurringPriceChartState extends State<RecurringPriceChart> {
  int? _active;
  void _step(int index) =>
      setState(() => _active = index.clamp(0, widget.history.length - 1));
  @override
  Widget build(BuildContext context) {
    if (widget.history.isEmpty) return const SizedBox.shrink();
    final index = (_active ?? widget.history.length - 1).clamp(
      0,
      widget.history.length - 1,
    );

    String money(Object? value) =>
        '${widget.currency} ${(value as num).toStringAsFixed(2)}';
    String labelAt(int i) {
      final row = widget.history[i];
      final change = row['change'] as num?;
      return '${row['date']} · ${money(row['amount'])}${change == null ? '' : ' · ${change > 0 ? '+' : ''}${money(change)}'}';
    }

    final label = labelAt(index);
    return Focus(
      onFocusChange: (focused) =>
          setState(() => _active = focused ? index : null),
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowDown) {
          _step(index - 1);
        } else if (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.arrowUp) {
          _step(index + 1);
        } else if (key == LogicalKeyboardKey.home) {
          _step(0);
        } else if (key == LogicalKeyboardKey.end) {
          _step(widget.history.length - 1);
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: Semantics(
        label: '${widget.name} price history',
        value: label,
        slider: true,
        increasedValue: index < widget.history.length - 1
            ? labelAt(index + 1)
            : null,
        decreasedValue: index > 0 ? labelAt(index - 1) : null,
        onIncrease: index < widget.history.length - 1
            ? () => _step(index + 1)
            : null,
        onDecrease: index > 0 ? () => _step(index - 1) : null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            void inspect(double x) => _step(
              ((x / constraints.maxWidth).clamp(0, 1) *
                      (widget.history.length - 1))
                  .round(),
            );
            return MouseRegion(
              cursor: SystemMouseCursors.precise,
              onHover: (event) => inspect(event.localPosition.dx),
              onExit: (_) => setState(() => _active = null),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (event) => inspect(event.localPosition.dx),
                onHorizontalDragStart: (event) =>
                    inspect(event.localPosition.dx),
                onHorizontalDragUpdate: (event) =>
                    inspect(event.localPosition.dx),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _PriceTrend(
                          widget.history
                              .map((row) => (row['amount'] as num).toDouble())
                              .toList(),
                          _active == null ? null : index,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 32,
                      child: _active == null
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${widget.history.first['date']}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                                Text(
                                  '${widget.history.last['date']}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            )
                          : Text(label, style: const TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PriceTrend extends CustomPainter {
  _PriceTrend(this.amounts, this.active);
  final List<double> amounts;
  final int? active;
  @override
  void paint(Canvas canvas, Size size) {
    final sorted = [...amounts]..sort();
    final low = sorted.first, high = sorted.last;
    Offset point(int i) => Offset(
      amounts.length == 1
          ? size.width / 2
          : 4 + i / (amounts.length - 1) * (size.width - 8),
      high == low
          ? size.height / 2
          : size.height -
                4 -
                (amounts[i] - low) / (high - low) * (size.height - 8),
    );
    final path = Path();
    for (var i = 0; i < amounts.length; i++) {
      final p = point(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF3B9AE0)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    if (active != null) {
      final p = point(active!);
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, size.height),
        Paint()..color = const Color(0xFF8BBDE2),
      );
      canvas.drawCircle(p, 3, Paint()..color = const Color(0xFF1479BD));
    }
  }

  @override
  bool shouldRepaint(covariant _PriceTrend oldDelegate) =>
      oldDelegate.amounts != amounts || oldDelegate.active != active;
}
