import 'package:flutter/material.dart';

/// 16×16 pixel buddy sprites — ports web `pixel-agent.tsx`.
enum PixelAgentId { coach, detective, invest, goals, tax, ops }

class _Tone {
  const _Tone({
    required this.body,
    required this.dark,
    required this.light,
    required this.accent,
  });

  final Color body;
  final Color dark;
  final Color light;
  final Color accent;
}

const _tones = <PixelAgentId, _Tone>{
  PixelAgentId.coach: _Tone(
    body: Color(0xFF3B9AE0),
    dark: Color(0xFF0A2540),
    light: Color(0xFF9FD0F5),
    accent: Color(0xFFEAF4FB),
  ),
  PixelAgentId.detective: _Tone(
    body: Color(0xFF7C3AED),
    dark: Color(0xFF2E1065),
    light: Color(0xFFC4B5FD),
    accent: Color(0xFFF3E8FF),
  ),
  PixelAgentId.invest: _Tone(
    body: Color(0xFF0D9488),
    dark: Color(0xFF134E4A),
    light: Color(0xFF5EEAD4),
    accent: Color(0xFFCCFBF1),
  ),
  PixelAgentId.goals: _Tone(
    body: Color(0xFFF59E0B),
    dark: Color(0xFF78350F),
    light: Color(0xFFFCD34D),
    accent: Color(0xFFFEF3C7),
  ),
  PixelAgentId.tax: _Tone(
    body: Color(0xFFEF4444),
    dark: Color(0xFF7F1D1D),
    light: Color(0xFFFCA5A5),
    accent: Color(0xFFFEE2E2),
  ),
  PixelAgentId.ops: _Tone(
    body: Color(0xFF64748B),
    dark: Color(0xFF0F172A),
    light: Color(0xFFCBD5E1),
    accent: Color(0xFFE2E8F0),
  ),
};

class PixelAgent extends StatelessWidget {
  const PixelAgent({
    super.key,
    required this.id,
    this.size = 20,
  });

  final PixelAgentId id;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PixelAgentPainter(id: id, tone: _tones[id]!),
      ),
    );
  }
}

class _PixelAgentPainter extends CustomPainter {
  _PixelAgentPainter({required this.id, required this.tone});

  final PixelAgentId id;
  final _Tone tone;

  void _px(Canvas canvas, double x, double y, Color c, {double w = 1, double h = 1}) {
    canvas.drawRect(
      Rect.fromLTWH(x, y, w, h),
      Paint()..color = c,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 16;
    canvas.scale(s, s);

    // Shadow
    _px(canvas, 3, 15, tone.dark.withValues(alpha: 0.13), w: 10);

    // Antenna
    _px(canvas, 7, 0, tone.light, w: 2);
    _px(canvas, 6, 1, tone.body, w: 4);

    // Head
    _px(canvas, 3, 2, tone.body, w: 10, h: 8);
    _px(canvas, 4, 2, tone.light, w: 8);
    _px(canvas, 2, 4, tone.body, h: 4);
    _px(canvas, 13, 4, tone.body, h: 4);

    // Eyes
    _px(canvas, 5, 5, tone.dark, w: 2, h: 3);
    _px(canvas, 5, 5, Colors.white);
    _px(canvas, 9, 5, tone.dark, w: 2, h: 3);
    _px(canvas, 9, 5, Colors.white);

    // Cheeks + mouth
    _px(canvas, 4, 8, tone.accent);
    _px(canvas, 11, 8, tone.accent);
    _px(canvas, 7, 8, tone.dark, w: 2);

    if (id == PixelAgentId.detective) {
      _px(canvas, 10, 4, tone.dark, w: 3);
    }
    if (id == PixelAgentId.goals) {
      _px(canvas, 12, 3, tone.light, w: 2, h: 2);
    }
    if (id == PixelAgentId.tax) {
      _px(canvas, 4, 5, tone.dark, h: 2);
      _px(canvas, 11, 5, tone.dark, h: 2);
    }

    // Body + legs
    _px(canvas, 5, 10, tone.body, w: 6, h: 3);
    _px(canvas, 4, 11, tone.body);
    _px(canvas, 11, 11, tone.body);
    _px(canvas, 5, 13, tone.dark, w: 2, h: 2);
    _px(canvas, 9, 13, tone.dark, w: 2, h: 2);

    if (id == PixelAgentId.ops) {
      _px(canvas, 2, 11, tone.light);
      _px(canvas, 13, 11, tone.light);
    }
    if (id == PixelAgentId.invest) {
      _px(canvas, 12, 10, tone.light, h: 2);
    }
  }

  @override
  bool shouldRepaint(covariant _PixelAgentPainter oldDelegate) =>
      oldDelegate.id != id;
}
