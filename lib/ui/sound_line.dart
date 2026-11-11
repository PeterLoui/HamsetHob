import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/radio_player.dart';
import '../audio/sound_levels.dart';
import 'theme.dart';

/// خط بيتوهج ويتموّج مع الصوت اللي شغال (الإذاعة أو العظات).
///
/// الغليظ في نص الخط والرفيع على الأطراف، والتوهج بيقوى مع علوّ الصوت.
/// الإضاءة بتتكيف مع الخلفية: على الغامق ضوء بيتجمّع فوق الخلفية (بلون التصميم الحي)،
/// وعلى الفاتح حبر بهالة خفيفة، عشان الضوء الأبيض مايبانش على الورق.
/// لما الصوت يقف الخط بيهدا ويبقى مستقيم باهت.
class SoundLine extends StatefulWidget {
  const SoundLine({super.key, this.height = 28, this.active = true});

  final double height;

  /// false: الخط مستقيم وباهت حتى لو فيه صوت شغال (مثلاً كارت مش بتاع اللي شغال).
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
    final up = 1 - math.exp(-dt * 28), down = 1 - math.exp(-dt * 7);
    var sum = 0.0;
    for (var i = 0; i < _levels.length; i++) {
      final to = target?[i] ?? 0;
      _levels[i] += (to - _levels[i]) * (to > _levels[i] ? up : down);
      sum += _levels[i];
    }
    final e = sum / _levels.length;
    _energy += (e - _energy) * (e > _energy ? up : down);
    _frame.value++;
    // وقف الرسم لما الخط يهدا خالص، عشان البطارية
    if (!live && _energy < .003) {
      _energy = 0;
      _levels.fillRange(0, _levels.length, 0);
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
            color: c.live,
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
    required this.color,
    required this.onDark,
  }) : super(repaint: repaint);

  final List<double> levels;
  final double Function() energy, time;
  final Color color;
  final bool onDark;

  static const _points = 56;

  @override
  void paint(Canvas canvas, Size size) {
    final e = energy().clamp(0.0, 1.0), t = time();
    final mid = size.height / 2;
    final reach = size.height / 2 - 2; // أقصى ارتفاع للموجة
    final last = levels.length - 1;

    final path = Path();
    double px = 0, py = mid;
    for (var i = 0; i <= _points; i++) {
      final x = i / _points;
      final u = (2 * x - 1).abs(); // ٠ في النص، ١ على الطرف
      final pos = u * last;
      final b = pos.floor().clamp(0, last - 1);
      final amp = levels[b] + (levels[b + 1] - levels[b]) * (pos - b);
      final taper = math.pow(1 - u * u, .9); // الطرفين ثابتين
      final wave = math.sin(x * 27 - t * 5.2) * .62 + math.sin(x * 61 + t * 3.4) * .38;
      final y = mid + math.min(1.0, amp * 1.7) * taper * reach * wave;
      final dx = x * size.width;
      if (i == 0) {
        path.moveTo(dx, y);
      } else {
        path.quadraticBezierTo(px, py, (px + dx) / 2, (py + y) / 2);
      }
      px = dx;
      py = y;
    }
    path.lineTo(px, py);

    // الخط بيتلاشى عند الطرفين
    ui.Shader fade(Color c) => ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, 0),
          [c.withValues(alpha: 0), c, c, c.withValues(alpha: 0)],
          const [0, .14, .86, 1],
        );
    Paint stroke(Color c, double width, {double blur = 0, BlendMode mode = BlendMode.srcOver}) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..blendMode = mode
      ..shader = fade(c)
      ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;

    if (onDark) {
      // ضوء: هالة واسعة ووهج قريب بيتجمّعوا فوق الخلفية، وقلب فاتح
      if (e > .01) {
        canvas.drawPath(path, stroke(color.withValues(alpha: .10 + .34 * e), 9 + 7 * e, blur: 7 + 5 * e, mode: BlendMode.plus));
        canvas.drawPath(path, stroke(color.withValues(alpha: .22 + .45 * e), 3.5 + 2 * e, blur: 2.5, mode: BlendMode.plus));
      }
      final core = Color.lerp(color, Colors.white, .25 + .45 * e)!;
      canvas.drawPath(path, stroke(core.withValues(alpha: .38 + .62 * math.min(1, e * 3)), 1.3 + 1.1 * e));
    } else {
      // حبر: هالة خفيفة من نفس اللون وخط واضح
      if (e > .01) {
        canvas.drawPath(path, stroke(color.withValues(alpha: .05 + .16 * e), 7 + 6 * e, blur: 5 + 4 * e));
      }
      canvas.drawPath(path, stroke(color.withValues(alpha: .30 + .60 * math.min(1, e * 3)), 1.2 + 1.0 * e));
    }
  }

  @override
  bool shouldRepaint(covariant SoundLinePainter old) => old.color != color || old.onDark != onDark;
}
