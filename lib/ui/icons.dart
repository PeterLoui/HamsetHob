import 'package:flutter/widgets.dart';

/// أيقونات مرسومة خصيصاً (شبكة 24×24) — منها الكتاب الذي في وسطه صليب.
enum AppIcon { home, bible, readings, calendar, more, radio, play, pause, back30, forward30, next }

class AppIconView extends StatelessWidget {
  const AppIconView(this.icon, {super.key, this.size = 24, this.color});
  final AppIcon icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? const Color(0xFFFFFFFF);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _IconPainter(icon, c)),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color);
  final AppIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    Path line(List<Offset> pts) {
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final o in pts.skip(1)) {
        p.lineTo(o.dx, o.dy);
      }
      return p;
    }

    switch (icon) {
      case AppIcon.home:
        canvas.drawPath(line(const [Offset(3.5, 11), Offset(12, 4), Offset(20.5, 11)]), stroke);
        canvas.drawPath(line(const [Offset(5.5, 9.5), Offset(5.5, 20), Offset(18.5, 20), Offset(18.5, 9.5)]), stroke);
        canvas.drawPath(line(const [Offset(10, 20), Offset(10, 15), Offset(14, 15), Offset(14, 20)]), stroke);
      case AppIcon.bible:
        // كتاب مغلق في وسطه صليب
        canvas.drawRRect(RRect.fromLTRBR(4, 3, 19.5, 21, const Radius.circular(2.2)), stroke);
        canvas.drawLine(const Offset(7.5, 3), const Offset(7.5, 21), stroke);
        canvas.drawLine(const Offset(13.5, 7.5), const Offset(13.5, 16.5), stroke);
        canvas.drawLine(const Offset(10.5, 10.5), const Offset(16.5, 10.5), stroke);
      case AppIcon.readings:
        final p = Path()
          ..moveTo(12, 6.5)
          ..cubicTo(10, 5, 7, 4.5, 3, 5)
          ..lineTo(3, 18)
          ..cubicTo(7, 17.5, 10, 18, 12, 19.5)
          ..cubicTo(14, 18, 17, 17.5, 21, 18)
          ..lineTo(21, 5)
          ..cubicTo(17, 4.5, 14, 5, 12, 6.5)
          ..close();
        canvas.drawPath(p, stroke);
        canvas.drawLine(const Offset(12, 6.5), const Offset(12, 19.5), stroke);
      case AppIcon.calendar:
        canvas.drawRRect(RRect.fromLTRBR(3.5, 5, 20.5, 20, const Radius.circular(1.5)), stroke);
        canvas.drawLine(const Offset(3.5, 9.5), const Offset(20.5, 9.5), stroke);
        canvas.drawLine(const Offset(8, 3), const Offset(8, 7), stroke);
        canvas.drawLine(const Offset(16, 3), const Offset(16, 7), stroke);
        canvas.drawLine(const Offset(12, 11.5), const Offset(12, 17.5), stroke);
        canvas.drawLine(const Offset(9.75, 13.5), const Offset(14.25, 13.5), stroke);
      case AppIcon.more:
        for (final x in [6.0, 12.0, 18.0]) {
          canvas.drawCircle(Offset(x, 12), 1.7, fill);
        }
      case AppIcon.radio:
        canvas.drawRRect(RRect.fromLTRBR(9, 3, 15, 14, const Radius.circular(3)), stroke);
        canvas.drawArc(const Rect.fromLTRB(6, 5, 18, 17), 0, 3.14159, false, stroke);
        canvas.drawLine(const Offset(12, 17), const Offset(12, 21), stroke);
        canvas.drawLine(const Offset(9, 21), const Offset(15, 21), stroke);
      case AppIcon.play:
        canvas.drawPath(
            Path()
              ..moveTo(8, 5)
              ..lineTo(19.5, 12)
              ..lineTo(8, 19)
              ..close(),
            fill);
      case AppIcon.pause:
        canvas.drawRect(const Rect.fromLTWH(6.5, 5, 3.5, 14), fill);
        canvas.drawRect(const Rect.fromLTWH(14, 5, 3.5, 14), fill);
      case AppIcon.next:
        canvas.drawPath(
            Path()
              ..moveTo(6, 6)
              ..lineTo(15, 12)
              ..lineTo(6, 18)
              ..close(),
            fill);
        canvas.drawRect(const Rect.fromLTWH(16.5, 6, 2, 12), fill);
      case AppIcon.back30:
        canvas.drawArc(const Rect.fromLTRB(4.5, 5, 19.5, 20), -1.57, 4.71, false, stroke);
        canvas.drawPath(line(const [Offset(12, 1.8), Offset(8.8, 5), Offset(12, 8.2)]), stroke);
      case AppIcon.forward30:
        canvas.drawArc(const Rect.fromLTRB(4.5, 5, 19.5, 20), -1.57, -4.71, false, stroke);
        canvas.drawPath(line(const [Offset(12, 1.8), Offset(15.2, 5), Offset(12, 8.2)]), stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _IconPainter old) => old.icon != icon || old.color != color;
}
