import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum AlienMood { calm, happy, alert, worried }

class AlienMoodStyle {
  const AlienMoodStyle({
    required this.body,
    required this.highlight,
    required this.stroke,
    required this.text,
  });

  final Color body;
  final Color highlight;
  final Color stroke;
  final Color text;

  static AlienMoodStyle of(AlienMood mood) {
    switch (mood) {
      case AlienMood.happy:
        return const AlienMoodStyle(
          body: Color(0xFF0D9488),
          highlight: Color(0xFF2DD4BF),
          stroke: Color(0xFF0F766E),
          text: Color(0xFF0F766E),
        );
      case AlienMood.alert:
        return const AlienMoodStyle(
          body: Color(0xFFD69E2E),
          highlight: Color(0xFFECC94B),
          stroke: Color(0xFFB7791F),
          text: Color(0xFFB7791F),
        );
      case AlienMood.worried:
        return const AlienMoodStyle(
          body: Color(0xFFE5484D),
          highlight: Color(0xFFF0757A),
          stroke: Color(0xFFC53030),
          text: Color(0xFFC53030),
        );
      case AlienMood.calm:
        return const AlienMoodStyle(
          body: AppColors.brand,
          highlight: Color(0xFF5BB0EA),
          stroke: AppColors.brandDark,
          text: AppColors.brandDark,
        );
    }
  }
}

/// Animated FinanceAI space-alien mascot (matches the web digest icon).
class SpaceAlienMascot extends StatefulWidget {
  const SpaceAlienMascot({
    super.key,
    this.size = 36,
    this.mood = AlienMood.calm,
  });

  final double size;
  final AlienMood mood;

  @override
  State<SpaceAlienMascot> createState() => _SpaceAlienMascotState();
}

class _SpaceAlienMascotState extends State<SpaceAlienMascot>
    with TickerProviderStateMixin {
  late final AnimationController _bob;
  late final AnimationController _antenna;
  late final AnimationController _blink;
  late final AnimationController _orb;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _antenna = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    _orb = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bob.dispose();
    _antenna.dispose();
    _blink.dispose();
    _orb.dispose();
    super.dispose();
  }

  double _eyeScale(double t) {
    if (t >= 0.42 && t <= 0.46) {
      final local = (t - 0.42) / 0.04;
      final dip = local < 0.5 ? local * 2 : (1 - local) * 2;
      return 1 - 0.88 * Curves.easeInOut.transform(dip);
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AlienMoodStyle.of(widget.mood);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bob, _antenna, _blink, _orb]),
        builder: (context, _) {
          final bob = Curves.easeInOut.transform(_bob.value);
          final antenna = Curves.easeInOut.transform(_antenna.value);
          final orb = Curves.easeInOut.transform(_orb.value);
          return CustomPaint(
            painter: _AlienPainter(
              bob: bob,
              antenna: antenna,
              eyeScale: _eyeScale(_blink.value),
              orb: orb,
              mood: widget.mood,
              colors: colors,
            ),
          );
        },
      ),
    );
  }
}

class _AlienPainter extends CustomPainter {
  _AlienPainter({
    required this.bob,
    required this.antenna,
    required this.eyeScale,
    required this.orb,
    required this.mood,
    required this.colors,
  });

  final double bob;
  final double antenna;
  final double eyeScale;
  final double orb;
  final AlienMood mood;
  final AlienMoodStyle colors;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 24;
    canvas.translate(size.width / 2 - 12 * s, size.height / 2 - 12 * s);
    canvas.scale(s);

    final shadowScale = 1 - 0.18 * bob;
    final shadowOpacity = 0.14 - 0.06 * bob;
    canvas.save();
    canvas.translate(12, 21.2);
    canvas.scale(shadowScale, 1);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 10.4, height: 2.3),
      Paint()..color = AppColors.ink.withValues(alpha: shadowOpacity),
    );
    canvas.restore();

    canvas.save();
    canvas.translate(0, -1 * bob);

    canvas.save();
    canvas.translate(12, 7.2);
    canvas.rotate((-6 + 12 * antenna) * math.pi / 180);
    canvas.translate(-12, -7.2);
    final antennaPaint = Paint()
      ..color = colors.body
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(12, 7.2), const Offset(12, 4.4), antennaPaint);
    final orbScale = 1 + 0.15 * orb;
    canvas.save();
    canvas.translate(12, 3.4);
    canvas.scale(orbScale);
    canvas.drawCircle(
      Offset.zero,
      1.35,
      Paint()..color = colors.body.withValues(alpha: 0.88 + 0.12 * (1 - orb)),
    );
    canvas.drawCircle(
      const Offset(0.35, -0.35),
      0.35,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.restore();
    canvas.restore();

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(12, 14), width: 14, height: 11.6),
      Paint()..color = colors.body,
    );

    for (final cx in [9.2, 14.8]) {
      canvas.save();
      canvas.translate(cx, 13.6);
      canvas.scale(1, eyeScale);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 3.7, height: 4.7),
        Paint()..color = AppColors.ink,
      );
      canvas.drawCircle(
        const Offset(0.35, -0.75),
        0.5,
        Paint()..color = Colors.white,
      );
      canvas.restore();
    }

    final mouth = Path();
    switch (mood) {
      case AlienMood.happy:
        mouth
          ..moveTo(9.8, 16.2)
          ..quadraticBezierTo(12, 18.1, 14.2, 16.2);
      case AlienMood.alert:
        mouth
          ..moveTo(10.4, 17)
          ..lineTo(13.6, 17);
      case AlienMood.worried:
        mouth
          ..moveTo(9.8, 17.6)
          ..quadraticBezierTo(12, 16.1, 14.2, 17.6);
      case AlienMood.calm:
        mouth
          ..moveTo(10.2, 16.7)
          ..quadraticBezierTo(12, 17.9, 13.8, 16.7);
    }
    canvas.drawPath(
      mouth,
      Paint()
        ..color = colors.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AlienPainter oldDelegate) {
    return bob != oldDelegate.bob ||
        antenna != oldDelegate.antenna ||
        eyeScale != oldDelegate.eyeScale ||
        orb != oldDelegate.orb ||
        mood != oldDelegate.mood ||
        colors != oldDelegate.colors;
  }
}
