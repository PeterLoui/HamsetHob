import 'package:flutter/material.dart';

import '../core/coptic.dart' show ar;
import '../data/wird.dart';
import 'glass.dart';
import 'theme.dart';

/// شمعة: مطفية (فتيلة بس) أو منوّرة بلهب ووهج.
class Candle extends StatelessWidget {
  const Candle({super.key, required this.lit, this.size = 28});
  final bool lit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: lit ? 1 : 0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, t, _) => CustomPaint(
        size: Size(size, size * 1.4),
        painter: _CandlePainter(t, c.navGlow, c.isDark ? const Color(0xFF3A342B) : const Color(0xFFD3C9B6), c.isDark ? const Color(0xFFEFE7D8) : const Color(0xFFFFFFFF), c.textFaint),
      ),
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter(this.t, this.flame, this.idle, this.wax, this.wick);
  final double t;
  final Color flame, idle, wax, wick;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 34, size.height / 48);
    final body = RRect.fromLTRBR(12, 18, 22, 44, const Radius.circular(3));
    if (t > 0) {
      canvas.drawCircle(const Offset(17, 14), 15, Paint()..shader = RadialGradient(colors: [flame.withValues(alpha: .55 * t), flame.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: const Offset(17, 14), radius: 15)));
    }
    canvas.drawRRect(body, Paint()..color = Color.lerp(idle, wax, t)!);
    if (t > 0) {
      canvas.drawOval(Rect.fromCenter(center: const Offset(17, 11), width: 8 * t, height: 14 * t), Paint()..color = flame);
      canvas.drawOval(Rect.fromCenter(center: const Offset(17, 13), width: 4 * t, height: 7 * t), Paint()..color = const Color(0xFFFFF3C9));
    } else {
      canvas.drawLine(const Offset(17, 14), const Offset(17, 17.5), Paint()..strokeWidth = 1.6..color = wick..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_CandlePainter o) => o.t != t || o.flame != flame;
}

/// شريط ورد اليوم في الرئيسية: ٤ شمعات وعدّاد، واللمس بيفتح الشاشة.
class WirdStrip extends StatelessWidget {
  const WirdStrip({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = WirdStore.instance;
    if (store == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final done = store.count;
        final hour = WirdStore.hourFor(DateTime.now());
        final sub = store.complete ? 'تمّ ورد اليوم' : '${ar(done)} من ${ar(WirdItem.values.length)} — ${store.isDone(WirdItem.prayer) ? 'كمّل بقية الورد' : '${hour.name} هي الجاية'}';
        return GlassPanel(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < WirdItem.values.length; i++) Padding(padding: const EdgeInsets.only(left: 6), child: Candle(lit: store.isDone(WirdItem.values[i]), size: 20)),
            ]),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('وردك اليوم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                Text(sub, style: TextStyle(fontSize: 12, color: c.textSoft)),
              ]),
            ),
            Icon(Icons.chevron_left, color: c.textFaint),
          ]),
        );
      },
    );
  }
}
