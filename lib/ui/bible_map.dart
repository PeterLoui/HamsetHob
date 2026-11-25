import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/coptic.dart' show ar;
import '../data/bible.dart';
import '../data/map_data.dart';
import 'glass.dart';
import 'theme.dart';

// ───────────────────────── الجغرافيا (مرسومة باليد، تقريبية) ─────────────────────────

const _lon0 = 9.0, _lon1 = 49.0, _lat0 = 26.5, _lat1 = 44.5;
const _mapW = 1000.0, _mapH = 549.0;

Offset project(double lon, double lat) => Offset((lon - _lon0) / (_lon1 - _lon0) * _mapW, (_lat1 - lat) / (_lat1 - _lat0) * _mapH);

typedef _Pts = List<(double, double)>;

const _Pts _med = [
  (9, 37.2), (10.2, 37.0), (11.0, 37.1), (10.6, 36.2), (10.3, 35.0), (10.1, 34.0), (11.0, 33.3), (12.5, 32.8), (15.2, 32.3),
  (15.7, 31.5), (17, 31.0), (19.5, 30.3), (20, 32.0), (21.5, 32.9), (23, 32.6), (25, 31.7), (27, 31.3), (29, 30.9), (29.9, 31.2),
  (31, 31.5), (32.3, 31.25), (34.2, 31.3), (34.7, 31.9), (35.0, 32.8), (35.1, 33.3), (35.5, 33.9), (35.9, 34.6), (35.85, 35.5),
  (36.0, 36.0), (36.2, 36.6), (35.5, 36.7), (34.6, 36.8), (33.7, 36.15), (32.8, 36.05), (32.0, 36.3), (30.7, 36.9), (30.15, 36.3),
  (29.1, 36.6), (28.3, 36.85), (27.4, 37.0), (27.25, 37.85), (26.8, 38.4), (26.2, 39.5), (26.4, 40.0), (26.2, 40.6), (25.9, 40.85),
  (24.4, 40.9), (23.7, 40.2), (22.9, 40.6), (22.7, 39.5), (23.0, 38.9), (24.0, 38.2), (24.0, 37.7), (23.2, 37.9), (23.1, 37.4),
  (22.4, 36.5), (21.7, 36.8), (21.3, 37.5), (21.8, 38.3), (21.1, 38.9), (20.7, 39.6), (20.2, 39.7), (19.4, 40.4), (19.5, 41.5),
  (19.4, 42.2), (18.5, 42.5), (16.5, 43.5), (15.2, 44.2), (14.7, 44.5), (12.4, 44.5), (12.6, 44.1), (13.6, 43.6), (14.5, 42.2),
  (16.2, 41.9), (17.2, 41.1), (18.5, 40.1), (17.2, 40.4), (16.6, 39.6), (17.1, 39.0), (16.5, 38.4), (15.7, 38.0), (16.0, 39.0),
  (15.8, 40.0), (14.8, 40.4), (14.2, 40.8), (13.0, 41.3), (12.3, 41.7), (11.1, 42.4), (10.5, 43.0), (10.3, 43.8), (9.8, 44.3),
  (9, 44.4),
];
const _Pts _black = [
  (28.0, 44.5), (37.8, 44.5), (39.2, 44.1), (40.0, 43.5), (41.5, 42.5), (41.6, 41.65), (39.7, 41.0), (36.3, 41.3), (35.1, 42.0),
  (33.8, 41.97), (31.8, 41.45), (29.6, 41.2), (29.0, 41.2), (28.0, 41.9), (27.5, 42.5), (27.9, 43.2), (28.7, 44.1),
];
const _Pts _marmara = [(27.0, 40.4), (28.2, 40.35), (29.0, 40.7), (29.1, 41.0), (28.0, 41.0), (27.0, 40.6)];
const _Pts _red = [
  (32.55, 30.0), (32.6, 29.2), (32.9, 28.7), (33.3, 28.1), (33.7, 27.6), (34.0, 27.0), (34.1, 26.5), (36.0, 26.5), (35.5, 27.6),
  (35.05, 28.2), (34.95, 29.3), (35.0, 29.55), (34.85, 29.2), (34.65, 28.7), (34.4, 28.1), (34.25, 27.73), (33.85, 28.1),
  (33.5, 28.7), (33.1, 29.2), (32.85, 29.7),
];
const _Pts _gulf = [(47.95, 29.4), (48.0, 29.9), (48.55, 30.0), (49.0, 30.0), (49.0, 27.6), (48.5, 28.4)];

const _islands = <_Pts>[
  [(32.3, 34.9), (32.9, 34.65), (33.9, 34.95), (34.6, 35.65), (33.5, 35.35), (32.95, 35.4), (32.4, 35.2)], // قبرص
  [(23.5, 35.3), (24.1, 35.6), (25.7, 35.35), (26.3, 35.25), (25.7, 35.0), (24.4, 35.1), (23.6, 35.2)], // كريت
  [(12.4, 37.9), (13.4, 38.2), (15.6, 38.25), (15.1, 37.3), (15.1, 36.7), (14.4, 36.8), (12.7, 37.6)], // صقلية
  [(14.2, 35.85), (14.55, 35.95), (14.5, 35.8), (14.2, 35.82)], // مالطة
  [(9.0, 39.2), (9.6, 39.2), (9.8, 40.0), (9.7, 40.9), (9.3, 41.2), (9.0, 41.2)], // سردينيا
  [(27.7, 36.4), (28.2, 36.45), (28.1, 35.95), (27.75, 36.05)], // رودس
];
const _rivers = <_Pts>[
  [(32.72, 26.5), (31.7, 26.55), (31.2, 27.2), (30.8, 28.1), (31.1, 29.05), (31.25, 30.05), (30.9, 30.6), (30.4, 31.46)], // النيل (رشيد)
  [(31.25, 30.05), (31.4, 30.8), (31.8, 31.42)], // دمياط
  [(35.62, 33.2), (35.6, 32.9), (35.57, 32.7), (35.55, 32.3), (35.5, 31.75)], // الأردن
  [(39.0, 38.8), (38.4, 38.0), (38.0, 37.0), (38.3, 36.65), (39.0, 35.95), (40.1, 35.3), (40.9, 34.45), (42.4, 34.1), (43.3, 33.43), (44.4, 32.5), (46.2, 31.05), (47.4, 31.0), (47.8, 30.5), (48.5, 30.0)], // الفرات
  [(40.0, 38.1), (41.5, 37.7), (43.1, 36.35), (43.9, 34.2), (44.4, 33.3), (45.8, 32.5), (47.1, 31.85), (47.4, 31.0)], // دجلة
];
const _lakes = <_Pts>[
  [(35.4, 31.78), (35.5, 31.78), (35.55, 31.4), (35.45, 31.1), (35.38, 31.35)], // البحر الميت
  [(35.52, 32.72), (35.65, 32.75), (35.62, 32.92), (35.52, 32.9)], // بحر الجليل
];

const _seaLabels = <(String, double, double, double)>[
  ('البحر المتوسط', 20.5, 34.2, 26),
  ('البحر الأسود', 34.5, 43.0, 22),
  ('البحر الأحمر', 35.1, 26.9, 11),
  ('الخليج', 48.5, 29.0, 10),
];
const _regionLabels = <(String, double, double, double)>[
  ('مصر', 29.5, 27.7, 24),
  ('سيناء', 33.7, 29.3, 12),
  ('آسيا الصغرى', 32.3, 39.3, 22),
  ('اليونان', 21.8, 39.5, 13),
  ('إيطاليا', 13.5, 42.7, 16),
  ('سوريا', 38.0, 34.9, 18),
  ('بلاد ما بين النهرين', 43.5, 34.8, 17),
  ('بلاد العرب', 40.0, 28.5, 22),
  ('كنعان', 35.4, 32.25, 9),
  ('ليبيا', 17.5, 29.0, 20),
];

Path _poly(_Pts pts, {bool close = true}) {
  final p = Path();
  for (var i = 0; i < pts.length; i++) {
    final o = project(pts[i].$1, pts[i].$2);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  if (close) p.close();
  return p;
}

/// اتجاه الخريطة الأساسية: الأرض والبحار والأنهار والأسماء.
class _BasePainter extends CustomPainter {
  _BasePainter(this.dark, this.text, this.font);
  final bool dark;
  final Color text;
  final String font;

  @override
  void paint(Canvas canvas, Size size) {
    final land = dark ? const Color(0xFF2B2822) : const Color(0xFFE9DEC2);
    final water = dark ? const Color(0xFF15212A) : const Color(0xFFB7D1D8);
    final shore = dark ? const Color(0xFF3A4B57) : const Color(0xFF8FB0BA);
    canvas.drawRect(Offset.zero & size, Paint()..color = land);
    // تظليل خفيف لحواف الأرض عشان تبان الخريطة مش مسطّحة
    final wp = Paint()..color = water;
    final sp = Paint()
      ..color = shore
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    for (final s in [_med, _black, _marmara, _red, _gulf]) {
      final path = _poly(s);
      canvas.drawPath(path, wp);
      canvas.drawPath(path, sp);
    }
    for (final i in _islands) {
      final path = _poly(i);
      canvas.drawPath(path, Paint()..color = land);
      canvas.drawPath(path, sp);
    }
    final river = Paint()
      ..color = water
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final r in _rivers) {
      canvas.drawPath(_poly(r, close: false), river);
    }
    for (final l in _lakes) {
      canvas.drawPath(_poly(l), wp);
    }
    // خطوط الشبكة (خطوط الطول والعرض كل ٥ درجات)
    final grid = Paint()
      ..color = text.withValues(alpha: .07)
      ..strokeWidth = .8;
    for (var lon = 10.0; lon < _lon1; lon += 5) {
      canvas.drawLine(project(lon, _lat0), project(lon, _lat1), grid);
    }
    for (var lat = 30.0; lat < _lat1; lat += 5) {
      canvas.drawLine(project(_lon0, lat), project(_lon1, lat), grid);
    }
    for (final (t, lon, lat, sz) in _seaLabels) {
      _label(canvas, t, project(lon, lat), sz, text.withValues(alpha: dark ? .30 : .38), font, italic: true, spacing: 3);
    }
    for (final (t, lon, lat, sz) in _regionLabels) {
      _label(canvas, t, project(lon, lat), sz, text.withValues(alpha: dark ? .22 : .30), font, spacing: 2);
    }
  }

  @override
  bool shouldRepaint(_BasePainter o) => o.dark != dark || o.text != text || o.font != font;
}

void _label(Canvas canvas, String t, Offset at, double size, Color color, String font, {bool italic = false, double spacing = 0, bool bold = false, Color? halo}) {
  final tp = TextPainter(
    text: TextSpan(
      text: t,
      style: TextStyle(
        fontFamily: font,
        fontSize: size,
        color: color,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        letterSpacing: 0,
        wordSpacing: spacing,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        shadows: halo == null ? null : [Shadow(color: halo, blurRadius: 3), Shadow(color: halo, blurRadius: 6)],
      ),
    ),
    textDirection: TextDirection.rtl,
  )..layout();
  tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
}

/// الطبقة المتحركة: خط الرحلة والمحطات والعلامة.
class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.journey, required this.progress, required this.selected, required this.controller, required this.dark, required this.text, required this.bg, required this.font})
      : super(repaint: controller);
  final MapJourney journey;
  final double progress; // 0..n-1
  final int selected;
  final TransformationController controller;
  final bool dark;
  final Color text, bg;
  final String font;

  @override
  void paint(Canvas canvas, Size size) {
    final k = controller.value.getMaxScaleOnAxis();
    final stops = journey.stops;
    final pts = [for (final s in stops) project(s.lon, s.lat)];
    final col = journey.color;
    // الطريق كله باهت، والجزء اللي اتقطع واضح
    final faint = Paint()
      ..color = col.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 / k
      ..strokeCap = StrokeCap.round;
    final full = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      full.lineTo(p.dx, p.dy);
    }
    _dashed(canvas, full, faint, 7 / k, 5 / k);
    final done = Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 / k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final i = progress.floor().clamp(0, stops.length - 1);
    final f = progress - i;
    final part = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var j = 1; j <= i; j++) {
      part.lineTo(pts[j].dx, pts[j].dy);
    }
    Offset head = pts[i];
    if (i < stops.length - 1 && f > 0) {
      head = Offset.lerp(pts[i], pts[i + 1], f)!;
      part.lineTo(head.dx, head.dy);
    }
    canvas.drawPath(part, done);

    final showNames = k > 1.6;
    for (var j = 0; j < stops.length; j++) {
      final p = pts[j];
      final sel = j == selected;
      final r = (sel ? 11.5 : 8.5) / k;
      if (sel) {
        canvas.drawCircle(p, r * 1.9, Paint()..color = col.withValues(alpha: .22));
      }
      canvas.drawCircle(p, r, Paint()..color = bg);
      canvas.drawCircle(p, r, Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 2.2 / k);
      _label(canvas, ar(j + 1), p, (sel ? 12 : 10) / k, col, font, bold: true);
      if (sel || showNames) {
        _label(canvas, stops[j].name, p + Offset(0, -(r + 9 / k)), 11.5 / k, text.withValues(alpha: sel ? 1 : .8), font, bold: true, halo: bg);
      }
    }
    // علامة المسافر
    if (progress > 0 || selected > 0) {
      canvas.drawCircle(head, 5.2 / k, Paint()..color = col);
      canvas.drawCircle(head, 5.2 / k, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.6 / k);
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint, double on, double off) {
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + on, m.length)), paint);
        d += on + off;
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePainter o) => o.journey != journey || o.progress != progress || o.selected != selected || o.dark != dark || o.text != text;
}

// ───────────────────────── الشاشة ─────────────────────────

class BibleMapScreen extends StatefulWidget {
  const BibleMapScreen({super.key, required this.onBack, required this.onVerse, required this.onOpenCommentary});
  final VoidCallback onBack;
  final ValueChanged<VerseRef> onVerse;
  final void Function(int book, int chapter) onOpenCommentary;

  @override
  State<BibleMapScreen> createState() => _BibleMapScreenState();
}

class _BibleMapScreenState extends State<BibleMapScreen> with TickerProviderStateMixin {
  final _ctrl = TransformationController();
  late final AnimationController _play = AnimationController(vsync: this)..addListener(_onPlay);
  late final AnimationController _cam = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  int _j = 0;
  int _sel = 0;
  double _progress = 0;
  Size _view = Size.zero;
  Matrix4Tween? _camTween;

  MapJourney get _journey => mapJourneys[_j];

  @override
  void initState() {
    super.initState();
    _cam.addListener(() {
      final t = _camTween;
      if (t != null) _ctrl.value = t.evaluate(CurvedAnimation(parent: _cam, curve: Curves.easeInOutCubic));
    });
  }

  @override
  void dispose() {
    _play.dispose();
    _cam.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  /// أصغر تكبير يغطي الإطار كله (من غير فراغ حوالين الخريطة).
  double get _fit => _view.width <= 0 ? 1 : math.max(_view.width / _mapW, _view.height / _mapH);

  Matrix4 _camera(double scale, Offset center, {double cy = .5}) {
    final tx = (_view.width / 2 - center.dx * scale).clamp(_view.width - _mapW * scale, 0.0);
    final ty = (_view.height * cy - center.dy * scale).clamp(_view.height - _mapH * scale, 0.0);
    return Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale);
  }

  Matrix4 _matrixFor(Rect r, {double pad = .78, double maxScale = 3.2}) {
    final s = math.min(math.min(_view.width / r.width, _view.height / r.height) * pad, _fit * maxScale * 3);
    return _camera(math.max(s, _fit), r.center);
  }

  void _flyTo(Matrix4 m, {bool instant = false}) {
    if (instant) {
      _ctrl.value = m;
      return;
    }
    _camTween = Matrix4Tween(begin: _ctrl.value, end: m);
    _cam.forward(from: 0);
  }

  Rect _boundsOf(MapJourney j) {
    var r = Rect.fromPoints(project(j.stops.first.lon, j.stops.first.lat), project(j.stops.first.lon, j.stops.first.lat));
    for (final s in j.stops) {
      r = r.expandToInclude(Rect.fromCircle(center: project(s.lon, s.lat), radius: 1));
    }
    return r.inflate(40);
  }

  void _frameJourney({bool instant = false}) => _flyTo(_matrixFor(_boundsOf(_journey), pad: .9), instant: instant);

  void _select(int j) {
    _play.stop();
    setState(() {
      _j = j;
      _sel = 0;
      _progress = 0;
    });
    _frameJourney();
  }

  void _goStop(int i, {bool fly = true}) {
    final n = _journey.stops.length;
    final k = i.clamp(0, n - 1);
    _play.stop();
    setState(() {
      _sel = k;
      _progress = k.toDouble();
    });
    if (fly) _focusStop(k);
  }

  void _focusStop(int k) {
    final s = _journey.stops[k];
    final p = project(s.lon, s.lat);
    final scale = math.max(_ctrl.value.getMaxScaleOnAxis(), _fit * 2.6);
    _flyTo(_camera(scale, p, cy: .42));
  }

  void _togglePlay() {
    if (_play.isAnimating) {
      _play.stop();
      setState(() {});
      return;
    }
    final n = _journey.stops.length;
    if (_progress >= n - 1) {
      setState(() {
        _progress = 0;
        _sel = 0;
      });
    }
    final remaining = (n - 1) - _progress;
    _play.duration = Duration(milliseconds: (remaining * 1900).round().clamp(600, 60000));
    _frameJourney();
    _playFrom = _progress;
    _play.forward(from: 0);
    setState(() {});
  }

  double _playFrom = 0;

  void _onPlay() {
    final n = _journey.stops.length;
    final p = (_playFrom + _play.value * ((n - 1) - _playFrom)).clamp(0.0, n - 1.0);
    final s = p.round();
    setState(() {
      _progress = p;
      _sel = s;
    });
  }

  void _onTap(Offset local) {
    final k = _ctrl.value.getMaxScaleOnAxis();
    var best = -1;
    var bestD = 26 / k;
    for (var i = 0; i < _journey.stops.length; i++) {
      final s = _journey.stops[i];
      final d = (project(s.lon, s.lat) - local).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (best >= 0) _goStop(best);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    final j = _journey;
    final stop = j.stops[_sel];
    return Padding(
      padding: EdgeInsets.fromLTRB(0, pad.top, 0, 0),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ScreenHeader('خريطة الكتاب', subtitle: 'اتبع رحلات الآباء والرسل، واضغط على أي محطة', onBack: widget.onBack),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: mapJourneys.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => AppChip(label: mapJourneys[i].name, selected: i == _j, onTap: () => _select(i)),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: c.hairline), borderRadius: BorderRadius.circular(18)),
                child: LayoutBuilder(builder: (context, box) {
                  final first = _view == Size.zero;
                  _view = box.biggest;
                  if (first) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _frameJourney(instant: true));
                  }
                  return InteractiveViewer(
                    transformationController: _ctrl,
                    constrained: false,
                    minScale: _fit,
                    maxScale: _fit * 14,
                    boundaryMargin: EdgeInsets.zero,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _onTap(d.localPosition),
                      child: SizedBox(
                        width: _mapW,
                        height: _mapH,
                        child: Stack(children: [
                          RepaintBoundary(child: CustomPaint(size: const Size(_mapW, _mapH), painter: _BasePainter(c.isDark, c.text, c.uiFont))),
                          CustomPaint(
                            size: const Size(_mapW, _mapH),
                            painter: _RoutePainter(
                              font: c.uiFont,
                              journey: j,
                              progress: _progress,
                              selected: _sel,
                              controller: _ctrl,
                              dark: c.isDark,
                              text: c.text,
                              bg: c.isDark ? const Color(0xFF1B1A17) : const Color(0xFFFFFBF1),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, pad.bottom + 14),
          child: GlassPanel(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: j.color, shape: BoxShape.circle),
                  child: Text(ar(_sel + 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(stop.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.text))),
                Text('${ar(_sel + 1)} / ${ar(j.stops.length)}', style: TextStyle(fontSize: 12, color: c.textFaint)),
              ]),
              const SizedBox(height: 8),
              Text(stop.note, style: TextStyle(fontSize: 13.5, height: 1.7, color: c.textSoft)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in stop.refs) AppChip(label: r.label, onTap: () => widget.onVerse(r)),
                AppChip(label: 'التفسير', onTap: () => widget.onOpenCommentary(stop.refs.first.book, stop.refs.first.chapter)),
              ]),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  tooltip: 'المحطة السابقة',
                  onPressed: _sel > 0 ? () => _goStop(_sel - 1) : null,
                  icon: const Icon(Icons.skip_next_rounded), // في الـRTL السهم بيتقلب
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: _togglePlay,
                  style: FilledButton.styleFrom(backgroundColor: j.color, foregroundColor: Colors.white),
                  icon: Icon(_play.isAnimating ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  label: Text(_play.isAnimating ? 'إيقاف' : 'شغّل الرحلة'),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'المحطة التالية',
                  onPressed: _sel < j.stops.length - 1 ? () => _goStop(_sel + 1) : null,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}
