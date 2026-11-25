import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// ألوان المراحل: دافئة للعهد القديم وباردة للجديد، بإضاءة تناسب الوضع.
Color groupColor(String id, bool dark) {
  const hue = {
    'law': 18.0, 'hist': 36.0, 'wisdom': 52.0, 'major': 340.0, 'minor': 8.0,
    'gospels': 210.0, 'acts': 178.0, 'paul': 232.0, 'general': 262.0, 'rev': 290.0,
  };
  return HSLColor.fromAHSL(1, hue[id] ?? 30, dark ? 0.55 : 0.58, dark ? 0.62 : 0.40).toColor();
}

/// عنوان فرعي لكل مرحلة من مراحل الطريق.
const eraSubtitles = {
  'law': 'من الخليقة إلى موسى',
  'hist': 'من دخول الأرض إلى السبي',
  'wisdom': 'صلاة وحكمة وشعر',
  'major': 'صوت الله وسط شعبه',
  'minor': 'رسائل قصيرة وقوية',
  'gospels': 'الكلمة صار جسداً',
  'acts': 'الكنيسة تنتشر',
  'paul': 'رسائل بولس',
  'general': 'رسائل للكنيسة كلها',
  'rev': 'نهاية الرحلة',
};

const nodeSpacing = 84.0;
const pathTop = 28.0;

/// مواضع المحطات: متعرّجة يمين ويسار الوسط.
List<Offset> pathPoints(double width, int count) => [
      for (var i = 0; i < count; i++) Offset(width * (i.isEven ? 0.64 : 0.36), pathTop + 16 + i * nodeSpacing),
    ];

double pathHeight(int count) => pathTop + 16 + (count - 1) * nodeSpacing + 56;

/// طريق مرحلة واحدة: الجزء اللي اتدرس منيّر بالعسل (السراج)، والباقي منقّط ومعتم.
class EraPathPainter extends CustomPainter {
  EraPathPainter({required this.points, required this.lit, required this.honey, required this.dim});
  final List<Offset> points;

  /// آخر محطة بدأ فيها الدارس (-1 لو لسه)، والطريق بيتنوّر لحد عندها.
  final int lit;
  final Color honey, dim;

  Path _path(Size size) {
    final p = Path()..moveTo(points.first.dx, 0);
    var prev = Offset(points.first.dx, 0);
    for (final o in points) {
      final my = (prev.dy + o.dy) / 2;
      p.cubicTo(prev.dx, my, o.dx, my, o.dx, o.dy);
      prev = o;
    }
    p.lineTo(prev.dx, size.height);
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path(size);
    final litY = lit < 0 ? 0.0 : points[lit].dy;
    // الجزء المعتم: نقط
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, litY, size.width, size.height));
    final dot = Paint()..color = dim;
    for (final PathMetric m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 11) {
        final t = m.getTangentForOffset(d);
        if (t != null) canvas.drawCircle(t.position, 2.6, dot);
      }
    }
    canvas.restore();
    if (lit < 0) return;
    // الجزء المنيّر: وهج ثم خط
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, litY));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = honey.withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..color = honey,
    );
    canvas.restore();
    // سراج: وهج حوالين المحطة الحالية
    final c = points[lit];
    canvas.drawCircle(
      c,
      34,
      Paint()..shader = RadialGradient(colors: [honey.withValues(alpha: .5), honey.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: 34)),
    );
  }

  @override
  bool shouldRepaint(EraPathPainter old) => old.lit != lit || old.honey != honey || old.dim != dim || old.points != points;
}

/// دايرة محطة: فاضية، أو حلقة بتتملي بنسبة الأصحاحات، أو مليانة وعليها ✓.
class StationDot extends StatelessWidget {
  const StationDot({super.key, required this.fraction, required this.color, required this.bg, required this.idle, required this.starred});
  final double fraction;
  final Color color, bg, idle;
  final bool starred;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(painter: _DotPainter(fraction, color, bg, idle, starred)),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.f, this.color, this.bg, this.idle, this.starred);
  final double f;
  final Color color, bg, idle;
  final bool starred;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const r = 13.0;
    if (f >= 1) {
      canvas.drawCircle(c, r, Paint()..color = color);
      final tick = Path()
        ..moveTo(c.dx - 5, c.dy)
        ..lineTo(c.dx - 1.5, c.dy + 4)
        ..lineTo(c.dx + 5.5, c.dy - 4);
      canvas.drawPath(tick, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..color = bg);
    } else {
      canvas.drawCircle(c, r, Paint()..color = bg);
      canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = f > 0 ? color.withValues(alpha: .35) : idle);
      if (f > 0) {
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * f, false,
            Paint()..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round..color = color);
      }
    }
    if (starred) {
      // نجمة صغيرة فوق يمين المحطة: خلّص أسئلة السفر
      final s = Path();
      const R = 6.5, rr = 2.8;
      final o = Offset(size.width - 4, 4);
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2 + i * math.pi / 5;
        final rad = i.isEven ? R : rr;
        final pt = o + Offset(math.cos(a) * rad, math.sin(a) * rad);
        i == 0 ? s.moveTo(pt.dx, pt.dy) : s.lineTo(pt.dx, pt.dy);
      }
      s.close();
      canvas.drawPath(s, Paint()..color = const Color(0xFFE8B04A));
      canvas.drawPath(s, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = bg);
    }
  }

  @override
  bool shouldRepaint(_DotPainter o) => o.f != f || o.color != color || o.bg != bg || o.starred != starred;
}
