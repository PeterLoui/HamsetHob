import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/audio_levels.dart';
import '../audio/radio_player.dart';
import 'theme.dart';

/// ضوء سائل بيتحرك ورا [child] طول ما فيه صوت شغال، وبيتنفس مع الإيقاع.
///
/// تلات بقع نور ناعمة بتلف ببطء؛ الباص بيكبّر الأولى، والوسط التانية، والحاد التالتة.
/// في سهرانية عسلي وجمر زي نور الشمع، وفي مخطوطة أحمر ومغرة خفاف.
/// لما الصوت يقف الضوء بيخفت ويقف الرسم خالص (مافيش استهلاك بطارية).
class FluidLight extends StatefulWidget {
  const FluidLight({super.key, required this.child, this.spread = 16, this.radius = 16, this.strength = 1, this.when});
  final Widget child;

  /// قد إيه الضوء بيطلع برّه حدود [child].
  final double spread;
  final double radius;
  final double strength;

  /// شرط إضافي للظهور (مثلاً المحطة دي بالذات هي اللي شغالة).
  final bool Function()? when;

  @override
  State<FluidLight> createState() => _FluidLightState();
}

class _FluidLightState extends State<FluidLight> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _player = RadioPlayer.instance;
  final _levels = AudioLevels.instance;
  final _state = _LightState();
  Duration _last = Duration.zero;

  bool get _on => _player.isPlaying && (widget.when?.call() ?? true);

  @override
  void initState() {
    super.initState();
    _player.addListener(_wake);
    _wake();
  }

  void _wake() {
    if ((_on || _state.fade > 0) && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero ? 1 / 60 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final s = _state;
    s.t += dt;
    // يظهر في نص ثانية ويخفت في ثانية
    s.fade = (s.fade + (_on ? dt * 2 : -dt)).clamp(0.0, 1.0);

    // المستويات: حقيقية من أندرويد، أو تنفّس هادي (حوالي ٧٠ نبضة في الدقيقة) لو مش متاحة
    double b, m, h;
    if (_levels.real) {
      b = _levels.bass;
      m = _levels.mid;
      h = _levels.high;
    } else {
      final beat = math.pow(math.max(0.0, math.sin(s.t * math.pi * 2 * 1.17)), 6).toDouble();
      b = .35 + .45 * beat + .05 * math.sin(s.t * 7.3);
      m = .45 + .2 * math.sin(s.t * 1.9) + .1 * math.sin(s.t * 4.1 + 1);
      h = .3 + .15 * math.sin(s.t * 5.7 + 2) + .1 * beat;
    }
    // هجوم سريع ورجوع هادي، عشان الحركة تبان سائلة مش متقطعة
    double follow(double cur, double target) => cur + (target - cur) * (target > cur ? .45 : .08);
    s.b = follow(s.b, b);
    s.m = follow(s.m, m);
    s.h = follow(s.h, h);

    if (s.fade == 0 && !_on) _ticker.stop();
    setState(() {});
  }

  @override
  void dispose() {
    _player.removeListener(_wake);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sp = widget.spread;
    return Stack(clipBehavior: Clip.none, children: [
      if (_state.fade > 0)
        Positioned(
          left: -sp,
          top: -sp,
          right: -sp,
          bottom: -sp,
          child: IgnorePointer(
            child: CustomPaint(painter: _FluidPainter(_state.copy(), c.isDark, widget.strength)),
          ),
        ),
      widget.child,
    ]);
  }
}

class _LightState {
  double t = 0, fade = 0, b = 0, m = 0, h = 0;
  _LightState copy() => _LightState()
    ..t = t
    ..fade = fade
    ..b = b
    ..m = m
    ..h = h;
}

class _FluidPainter extends CustomPainter {
  _FluidPainter(this.s, this.dark, this.strength);
  final _LightState s;
  final bool dark;
  final double strength;

  static const _vigil = [Color(0xFFE2A84B), Color(0xFFC4562C), Color(0xFFF5D38E)];
  static const _manuscript = [Color(0xFFA3271B), Color(0xFFC0852A), Color(0xFFCF7F72)];

  @override
  void paint(Canvas canvas, Size size) {
    final colors = dark ? _vigil : _manuscript;
    final maxAlpha = (dark ? .9 : .6) * strength * s.fade;
    final levels = [s.b, s.m, s.h];
    // نص قطر البقعة من البعد الأصغر، عشان الضوء يفضل ناعم ويخلص جوه المساحة حتى في المشغّل العريض
    final base = math.min(size.width, size.height) * .5;
    for (var i = 0; i < 3; i++) {
      final ph = i * 2.1;
      // كل بقعة بتلف في مسار ليساجو بطيء على العرض كله
      final speed = .35 + .12 * i;
      final cx = size.width * (.5 + .38 * math.sin(s.t * speed + ph));
      final cy = size.height * (.5 + .22 * math.cos(s.t * speed * .8 + ph * 1.3));
      final lv = levels[i].clamp(0.0, 1.0);
      final r = base * (.7 + .5 * lv);
      final center = Offset(cx, cy);
      final paint = Paint()
        ..blendMode = dark ? BlendMode.plus : BlendMode.srcOver
        ..shader = RadialGradient(colors: [
          colors[i].withValues(alpha: maxAlpha * (.35 + .65 * lv)),
          colors[i].withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FluidPainter old) => true;
}
