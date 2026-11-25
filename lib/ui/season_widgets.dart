import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/coptic.dart' show ar;
import '../core/season.dart';
import 'glass.dart';
import 'theme.dart';

/// نجمة بيت لحم ثمانية الأطراف.
Path starPath(Offset c, double outer, double inner) {
  final p = Path();
  for (var i = 0; i < 8; i++) {
    final a = -math.pi / 2 + i * math.pi / 4;
    final r = i.isEven ? outer : inner;
    final o = c + Offset(math.cos(a) * r, math.sin(a) * r);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

enum SkyKind { nativity, lent, passion, easter }

/// سماء الموسم ورا الرئيسية: نجوم صغيرة بتلمع ببطء، ونجمة بيت لحم بوهج في الركن اليمين فوق.
class SeasonSky extends StatefulWidget {
  const SeasonSky({super.key, required this.height, this.starX = .5, this.starY = 62, this.kind = SkyKind.nativity, this.tint});
  final double height;
  final SkyKind kind;

  /// لون الموسم (لو مش محدد: لون الشمعة).
  final Color? tint;

  /// موضع نجمة بيت لحم: نسبة من العرض، وبعد من فوق.
  final double starX, starY;

  @override
  State<SeasonSky> createState() => _SeasonSkyState();
}

class _SeasonSkyState extends State<SeasonSky> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  static final _stars = () {
    final r = math.Random(7);
    return [for (var i = 0; i < 46; i++) (r.nextDouble(), r.nextDouble() * .8, 0.8 + r.nextDouble() * 0.9, r.nextDouble())];
  }();

  @override
  void initState() {
    super.initState();
    final still = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (!still) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IgnorePointer(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _SkyPainter(_stars, widget.tint ?? c.navGlow, c.isDark, _c.value, widget.starX, widget.starY, widget.kind)),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.stars, this.color, this.dark, this.t, this.starX, this.starY, this.kind);
  final double starX, starY;
  final SkyKind kind;
  final List<(double, double, double, double)> stars;
  final Color color;
  final bool dark;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // وهج دافي من ورا النجمة
    final star = Offset(size.width * starX, starY);
    canvas.drawCircle(
      star,
      size.width * .6,
      Paint()
        ..shader = RadialGradient(colors: [color.withValues(alpha: dark ? .26 : .16), color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: star, radius: size.width * .6)),
    );
    if (kind == SkyKind.lent || kind == SkyKind.passion) {
      // الصوم والبصخة: من غير نجوم، حبيبات هادية بتتنفّس وصليب خافت
      for (final (x, y, r, ph) in stars.take(18)) {
        final tw = .5 + .5 * math.sin((t + ph) * math.pi * 2);
        canvas.drawCircle(Offset(x * size.width, y * size.height), r * .9, Paint()..color = color.withValues(alpha: (dark ? .12 : .1) + .18 * tw));
      }
      final cross = Paint()..color = color.withValues(alpha: kind == SkyKind.passion ? .55 : .42)..strokeWidth = 3..strokeCap = StrokeCap.round;
      final glow = 1 + .05 * math.sin(t * math.pi * 2);
      canvas.drawLine(star.translate(0, -20 * glow), star.translate(0, 26 * glow), cross);
      canvas.drawLine(star.translate(-14 * glow, -6), star.translate(14 * glow, -6), cross);
      return;
    }
    for (final (x, y, r, ph) in stars) {
      final tw = .5 + .5 * math.sin((t + ph) * math.pi * 2);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        r,
        Paint()..color = (dark ? const Color(0xFFF5E3B0) : color).withValues(alpha: (dark ? .2 : .14) + .5 * tw * (dark ? 1 : .6)),
      );
    }
    final glow = 1 + .08 * math.sin(t * math.pi * 2);
    final big = kind == SkyKind.easter ? 1.5 : 1.0;
    canvas.drawPath(starPath(star, 19 * glow * big, 5 * big), Paint()..color = color.withValues(alpha: .95));
    canvas.drawLine(star, star.translate(0, -38), Paint()..color = color.withValues(alpha: .35));
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.t != t || old.color != color || old.dark != dark || old.kind != kind;
}

/// كارت الصوم في الرئيسية: حلقة بتتملي بأيام الصوم، وفي العيد نجمة وتهنئة.
class NativityCard extends StatelessWidget {
  const NativityCard({super.key, required this.season, required this.onTap});
  final NativitySeason season;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final glow = c.navGlow;
    final title = season.feast ? 'عيد الميلاد المجيد' : (season.inFast ? 'صوم الميلاد المجيد' : 'صوم الميلاد المجيد');
    final line1 = season.feast
        ? 'كل سنة وإنتم طيبين'
        : season.inFast
            ? 'اليوم ${ar(season.dayOfFast)} من ${ar(NativitySeason.fastLength)}'
            : 'بيبدأ ١٦ هاتور';
    final line2 = season.feast
        ? 'المسيح وُلد، بالحقيقة وُلد'
        : season.inFast
            ? (season.daysToFeast == 1 ? 'بكرة العيد' : 'باقي ${ar(season.daysToFeast)} يوم على العيد')
            : (season.daysToFast == 1 ? 'بيبدأ بكرة' : 'بعد ${ar(season.daysToFast)} أيام');
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: glow.withValues(alpha: c.isDark ? .16 : .12), blurRadius: 26, spreadRadius: -2)],
      ),
      child: GlassPanel(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CustomPaint(painter: _RingPainter(season.inFast ? season.dayOfFast / NativitySeason.fastLength : 1, glow, c.hairline)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 2),
              Text(line1, style: TextStyle(fontSize: 14, color: c.textSoft)),
              const SizedBox(height: 4),
              Text(line2, style: TextStyle(fontSize: 13, color: glow, fontWeight: FontWeight.w500)),
            ]),
          ),
          Icon(Icons.chevron_left, color: c.textFaint),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.f, this.color, this.track);
  final double f;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 5;
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 5..color = track);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * f.clamp(0, 1), false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round..color = color);
    canvas.drawPath(starPath(c, 14, 4), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.f != f || o.color != color;
}

/// فانوس يوم: مطفي، أو منوّر، أو فانوس النهارده (أكبر وبوهج).
class LanternDot extends StatelessWidget {
  const LanternDot({super.key, required this.state, required this.color, required this.idle});
  final int state; // 0 مطفي، 1 عدّى، 2 النهارده
  final Color color, idle;

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(44, 54), painter: _LanternPainter(state, color, idle));
}

class _LanternPainter extends CustomPainter {
  _LanternPainter(this.state, this.color, this.idle);
  final int state;
  final Color color, idle;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final scale = state == 2 ? 1.12 : 1.0;
    final body = RRect.fromLTRBR(cx - 11 * scale, 16, cx + 11 * scale, 16 + 30 * scale, Radius.circular(7 * scale));
    final cap = Path()
      ..moveTo(cx - 6 * scale, 16)
      ..lineTo(cx, 8)
      ..lineTo(cx + 6 * scale, 16);
    if (state == 0) {
      final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = idle;
      canvas.drawRRect(body, p);
      canvas.drawPath(cap, p..strokeWidth = 1.8);
      return;
    }
    if (state == 2) {
      canvas.drawCircle(Offset(cx, 32), 24, Paint()..shader = RadialGradient(colors: [color.withValues(alpha: .75), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: Offset(cx, 32), radius: 24)));
    } else {
      canvas.drawCircle(Offset(cx, 32), 16, Paint()..color = color.withValues(alpha: .14));
    }
    final fill = state == 2 ? Color.lerp(color, Colors.white, .45)! : color;
    canvas.drawRRect(body, Paint()..color = fill.withValues(alpha: state == 2 ? 1 : .9));
    canvas.drawPath(cap, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2..color = fill);
    canvas.drawRRect(body, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withValues(alpha: .35), Colors.white.withValues(alpha: 0)]).createShader(body.outerRect));
  }

  @override
  bool shouldRepaint(_LanternPainter o) => o.state != state || o.color != color;
}


/// لون أسبوع من أسابيع الصوم: تدرّج بنفسجي لحد الأسبوع السادس، وأسبوع البصخة قرمزي.
Color lentWeekColor(int week, bool dark) {
  const hues = [262.0, 268.0, 276.0, 284.0, 292.0, 300.0, 310.0, 352.0];
  final i = week.clamp(0, 7);
  return HSLColor.fromAHSL(1, hues[i], i == 7 ? .62 : .46, dark ? (i == 7 ? .6 : .68) : (i == 7 ? .42 : .42)).toColor();
}

/// كارت الصوم الكبير والقيامة في الرئيسية: حلقة من ثمانية أقواس (الأسابيع) بتتملي، ونجمة في القيامة.
class LentCard extends StatelessWidget {
  const LentCard({super.key, required this.season, required this.onTap});
  final LentSeason season;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final easter = season.easterWeek;
    final col = easter ? c.navGlow : lentWeekColor(season.inLent ? season.week : 0, c.isDark);
    final String title, line1, line2;
    if (easter) {
      title = 'عيد القيامة المجيد';
      line1 = 'المسيح قام! بالحقيقة قام';
      line2 = 'خريستوس آنستي — آليثوس آنستي';
    } else if (season.inLent) {
      title = season.holyWeek ? (LentSeason.holyDayNames[season.offset] ?? 'أسبوع البصخة') : 'الصوم الكبير';
      line1 = 'اليوم ${ar(season.dayOfLent)} من ${ar(LentSeason.length)} — ${season.isSunday ? season.sundayName : season.weekName}';
      line2 = season.daysToEaster == 1 ? 'بكرة القيامة' : 'باقي ${ar(season.daysToEaster)} يوم على القيامة';
    } else {
      title = 'الصوم الكبير';
      line1 = 'بيبدأ ${season.daysToStart == 1 ? 'بكرة' : 'بعد ${ar(season.daysToStart)} أيام'}';
      line2 = 'استعد بالصلاة والتوبة';
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: col.withValues(alpha: c.isDark ? .18 : .12), blurRadius: 26, spreadRadius: -2)],
      ),
      child: GlassPanel(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CustomPaint(painter: _LentRingPainter(season.dayOfLent, easter, c.isDark, c.hairline, col)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 2),
              Text(line1, style: TextStyle(fontSize: 13.5, color: c.textSoft)),
              const SizedBox(height: 4),
              Text(line2, style: TextStyle(fontSize: 13, color: col, fontWeight: FontWeight.w500)),
            ]),
          ),
          Icon(Icons.chevron_left, color: c.textFaint),
        ]),
      ),
    );
  }
}

class _LentRingPainter extends CustomPainter {
  _LentRingPainter(this.day, this.easter, this.dark, this.track, this.accent);
  final int day;
  final bool easter, dark;
  final Color track, accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 5;
    final rect = Rect.fromCircle(center: c, radius: r);
    var passed = 0;
    var start = -math.pi / 2;
    const gap = .09;
    for (var w = 0; w < LentSeason.weekDays.length; w++) {
      final n = LentSeason.weekDays[w];
      final sweep = 2 * math.pi * n / LentSeason.length - gap;
      canvas.drawArc(rect, start, sweep, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 5..color = track);
      final done = easter ? 1.0 : ((day - passed) / n).clamp(0.0, 1.0);
      if (done > 0) {
        canvas.drawArc(rect, start, sweep * done, false,
            Paint()..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round..color = lentWeekColor(w, dark));
      }
      passed += n;
      start += sweep + gap;
    }
    if (easter) {
      canvas.drawPath(starPath(c, 14, 4), Paint()..color = accent);
    } else {
      final p = Paint()..color = accent..strokeWidth = 3..strokeCap = StrokeCap.round;
      canvas.drawLine(c.translate(0, -11), c.translate(0, 13), p);
      canvas.drawLine(c.translate(-8, -4), c.translate(8, -4), p);
    }
  }

  @override
  bool shouldRepaint(_LentRingPainter o) => o.day != day || o.easter != easter || o.dark != dark;
}
