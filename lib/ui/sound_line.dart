import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/radio_player.dart';
import '../audio/sound_levels.dart';
import 'theme.dart';

/// تيار ضوء سائل بيجري ويتوهج مع الصوت اللي شغال (الإذاعة أو العظات).
///
/// تلات طبقات ضوء سايلة فوق بعض، بتتخن وترفع مع الإيقاع وبتجري في اتجاه واحد، وجواها نقط ضوء ماشية مع التيار.
/// الغليظ في نص التيار والرفيع على الأطراف، والتوهج والسرعة بيزيدوا مع علوّ الصوت.
/// الإضاءة بتتكيف مع الخلفية: على الغامق ضوء بيتجمّع فوق الخلفية، وعلى الفاتح لون دافي شفاف زي العسل على الورق.
/// لما الصوت يقف التيار بيهدا ويبقى خيط باهت.
class SoundLine extends StatefulWidget {
  const SoundLine({super.key, this.height = 34, this.active = true});

  final double height;

  /// false: التيار هادي حتى لو فيه صوت شغال.
  final bool active;

  @override
  State<SoundLine> createState() => _SoundLineState();
}

class _SoundLineState extends State<SoundLine> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _frame = ValueNotifier(0);
  final _levels = List<double>.filled(SoundLevels.bands, 0);
  double _energy = 0;
  double _time = 0;
  double _flow = 0;
  Duration _last = Duration.zero;

  bool get _live => widget.active && RadioPlayer.instance.isPlaying;

  @override
  void initState() {
    super.initState();
    SoundLevels.instance.attach();
    RadioPlayer.instance.addListener(_wake);
    _wake();
  }

  @override
  void didUpdateWidget(SoundLine old) {
    super.didUpdateWidget(old);
    _wake();
  }

  @override
  void dispose() {
    RadioPlayer.instance.removeListener(_wake);
    SoundLevels.instance.detach();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _wake() {
    if (_live && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero ? 1 / 60 : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, .1);
    _last = elapsed;
    _time += dt;
    final live = _live;
    final target = live ? SoundLevels.instance.sample(_time) : null;
    // بيطلع بسرعة مع الصوت وينزل أهدى، زي الضوء
    final up = 1 - math.exp(-dt * 26), down = 1 - math.exp(-dt * 6);
    var sum = 0.0;
    for (var i = 0; i < _levels.length; i++) {
      final to = target?[i] ?? 0;
      _levels[i] += (to - _levels[i]) * (to > _levels[i] ? up : down);
      sum += _levels[i];
    }
    final e = sum / _levels.length;
    _energy += (e - _energy) * (e > _energy ? up : down);
    // التيار بيجري أسرع مع علوّ الصوت
    _flow += dt * (.35 + 2.6 * _energy);
    _frame.value++;
    // وقف الرسم لما التيار يهدا خالص، عشان البطارية
    if (!live && _energy < .003) {
      _energy = 0;
      _levels.fillRange(0, _levels.length, 0);
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // مخطوطة: الحبر مابينوّرش والأحمر محجوز للتاريخ، فالتيار بلون شمع دافي
    final base = c.isDark ? c.live : (c.classic ? const Color(0xFFB4791F) : c.accent);
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(
          painter: SoundLinePainter(
            repaint: _frame,
            levels: _levels,
            energy: () => _energy,
            time: () => _time,
            flow: () => _flow,
            color: base,
            onDark: c.isDark,
          ),
        ),
      ),
    );
  }
}

class SoundLinePainter extends CustomPainter {
  SoundLinePainter({
    required Listenable repaint,
    required this.levels,
    required this.energy,
    required this.time,
    required this.flow,
    required this.color,
    required this.onDark,
  }) : super(repaint: repaint);

  final List<double> levels;
  final double Function() energy, time, flow;
  final Color color;
  final bool onDark;

  static const _points = 48;

  /// (تردد الموجة، سرعة الجريان، إزاحة، سُمك نسبي، تغبيش)
  static const _layers = [
    (11.0, 2.1, 0.0, 1.00, 7.0),
    (17.0, 3.4, 2.1, .62, 3.5),
    (27.0, 5.2, 4.4, .34, 1.2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final e = energy().clamp(0.0, 1.0), t = time(), f = flow();
    final mid = size.height / 2;
    final reach = size.height / 2 - 1;
    final last = levels.length - 1;

    double ampAt(double x) {
      final u = (2 * x - 1).abs(); // ٠ في النص، ١ على الطرف
      final pos = u * last;
      final b = pos.floor().clamp(0, last - 1);
      final a = levels[b] + (levels[b + 1] - levels[b]) * (pos - b);
      return math.min(1.0, a * 1.9) * math.pow(1 - u * u, .8);
    }

    double centre(double x, double a) => mid + a * reach * .42 * math.sin(x * 9 - f * 2.6 + math.sin(t * .7) * 1.3);

    final hsl = HSLColor.fromColor(color);
    Color shade(double hue, double light) =>
        hsl.withHue((hsl.hue + hue) % 360).withLightness((hsl.lightness + light).clamp(0.0, 1.0)).toColor();
    // حافة أغمق وأدفى، وسط بلون التصميم، وقلب فاتح
    final tones = onDark ? [shade(-14, -.06), color, shade(8, .16)] : [shade(-10, .04), color, shade(6, -.10)];
    final mode = onDark ? BlendMode.plus : BlendMode.srcOver;

    ui.Shader fade(Color c) => ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, 0),
          [c.withValues(alpha: 0), c, c, c.withValues(alpha: 0)],
          const [0, .16, .84, 1],
        );

    // طبقات الضوء السايلة
    if (e > .008) {
      for (var k = 0; k < _layers.length; k++) {
        final (freq, speed, phase, thick, blur) = _layers[k];
        final top = <Offset>[], bottom = <Offset>[];
        for (var i = 0; i <= _points; i++) {
          final x = i / _points;
          final a = ampAt(x);
          final swell = .55 + .45 * math.sin(x * freq - f * speed + phase);
          final half = (1.4 + a * reach * .95 * swell) * thick;
          final drift = a * reach * .16 * math.sin(x * (freq * .6) + f * (speed * .5) + phase * 2);
          final cy = centre(x, a) + drift;
          top.add(Offset(x * size.width, cy - half));
          bottom.add(Offset(x * size.width, cy + half));
        }
        final path = Path()..moveTo(top.first.dx, top.first.dy);
        _smooth(path, top);
        path.lineTo(bottom.last.dx, bottom.last.dy);
        _smooth(path, bottom.reversed.toList());
        path.close();
        final alpha = onDark ? (.24 + .50 * e) * (k == 0 ? .8 : 1) : (.16 + .40 * e) * (k == 0 ? .7 : 1);
        canvas.drawPath(
          path,
          Paint()
            ..blendMode = mode
            ..shader = fade(tones[k].withValues(alpha: alpha.clamp(0.0, 1.0)))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * (.7 + .6 * e)),
        );
      }
    }

    // الخيط اللي في قلب التيار
    final core = Path();
    final pts = <Offset>[for (var i = 0; i <= _points; i++) Offset(i / _points * size.width, centre(i / _points, ampAt(i / _points)))];
    core.moveTo(pts.first.dx, pts.first.dy);
    _smooth(core, pts);
    final coreColor = onDark ? Color.lerp(color, Colors.white, .30 + .45 * e)! : shade(0, -.14);
    canvas.drawPath(
      core,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.1 + .9 * e
        ..shader = fade(coreColor.withValues(alpha: .32 + .60 * math.min(1, e * 3))),
    );

    // نقط ضوء ماشية مع التيار
    if (e > .02) {
      for (var i = 0; i < 6; i++) {
        final x = (f * (.11 + i * .023) + i * .173) % 1.0;
        final a = ampAt(x);
        if (a < .04) continue;
        final edge = math.sin(x * math.pi); // بتظهر وتختفي عند الطرفين
        final at = Offset(x * size.width, centre(x, a) + a * reach * .3 * math.sin(i * 2.4 + f * 1.7));
        final r = 1.2 + a * 3.0;
        final glow = (onDark ? Color.lerp(color, Colors.white, .55)! : tones[0]).withValues(alpha: (.75 * a * edge).clamp(0.0, 1.0));
        canvas.drawCircle(
          at,
          r * 2.6,
          Paint()
            ..blendMode = mode
            ..color = glow.withValues(alpha: glow.a * .45)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.6),
        );
        canvas.drawCircle(at, r, Paint()..blendMode = mode..color = glow);
      }
    }
  }

  /// منحنى ناعم يعدّي على النقط.
  static void _smooth(Path path, List<Offset> pts) {
    for (var i = 1; i < pts.length; i++) {
      final p = pts[i - 1], q = pts[i];
      path.quadraticBezierTo(p.dx, p.dy, (p.dx + q.dx) / 2, (p.dy + q.dy) / 2);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
  }

  @override
  bool shouldRepaint(covariant SoundLinePainter old) => old.color != color || old.onDark != onDark;
}
