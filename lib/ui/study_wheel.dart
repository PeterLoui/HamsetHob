import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/study.dart';

/// قوس سفر على العجلة.
class WheelArc {
  const WheelArc(this.book, this.start, this.sweep);
  final StudyBook book;
  final double start, sweep;
}

/// قوس مجموعة (الناموس، التاريخ...).
class WheelGroupArc {
  const WheelGroupArc(this.group, this.start, this.sweep);
  final StudyGroup group;
  final double start, sweep;
}

/// تقسيم العجلة: كل سفر قوس بحجم يتناسب (بتخفيف) مع عدد أصحاحاته، وفاصل أكبر بين المجموعات والعهدين.
class WheelLayout {
  WheelLayout(StudyCatalog cat) {
    const gapBook = 0.010, gapGroup = 0.07, gapTestament = 0.16;
    double weight(StudyBook b) => 2.2 + math.pow(b.chapters, 0.62).toDouble();
    var total = 0.0;
    var gaps = 0.0;
    for (var gi = 0; gi < cat.groups.length; gi++) {
      for (final b in cat.inGroup(cat.groups[gi].id)) {
        total += weight(b);
        gaps += gapBook;
      }
      final next = gi + 1 < cat.groups.length ? cat.groups[gi + 1] : null;
      gaps += next == null || next.newTestament != cat.groups[gi].newTestament ? gapTestament : gapGroup;
    }
    final unit = (2 * math.pi - gaps) / total;
    var a = -math.pi / 2;
    for (var gi = 0; gi < cat.groups.length; gi++) {
      final g = cat.groups[gi];
      final gStart = a;
      for (final b in cat.inGroup(g.id)) {
        final s = weight(b) * unit;
        arcs.add(WheelArc(b, a, s));
        a += s + gapBook;
      }
      groups.add(WheelGroupArc(g, gStart, a - gapBook - gStart));
      final next = gi + 1 < cat.groups.length ? cat.groups[gi + 1] : null;
      a += next == null || next.newTestament != g.newTestament ? gapTestament : gapGroup;
    }
  }

  final arcs = <WheelArc>[];
  final groups = <WheelGroupArc>[];

  static double _norm(double x) {
    const t = 2 * math.pi;
    x %= t;
    return x < 0 ? x + t : x;
  }

  /// المجموعة اللي بتقع عندها زاوية معيّنة (أو الأقرب لو وقعت في فاصل صغير).
  WheelGroupArc? groupAt(double angle) {
    WheelGroupArc? best;
    var bestD = double.infinity;
    for (final g in groups) {
      final rel = _norm(angle - g.start);
      if (rel <= g.sweep) return g;
      final d = math.min(rel - g.sweep, 2 * math.pi - rel);
      if (d < bestD) {
        bestD = d;
        best = g;
      }
    }
    return bestD < 0.12 ? best : null;
  }
}

/// ألوان المجموعات: تدرّج دافئ للعهد القديم وبارد للجديد، بإضاءة تناسب الوضع.
Color groupColor(String id, bool dark) {
  const hue = {
    'law': 18.0, 'hist': 36.0, 'wisdom': 52.0, 'major': 340.0, 'minor': 8.0,
    'gospels': 210.0, 'acts': 178.0, 'paul': 232.0, 'general': 262.0, 'rev': 290.0,
  };
  return HSLColor.fromAHSL(1, hue[id] ?? 30, dark ? 0.55 : 0.58, dark ? 0.62 : 0.40).toColor();
}

/// العجلة: حلقة بتتملي بلون كل مجموعة على قد ما الدارس خلّص أصحاحات السفر.
class StudyWheelPainter extends CustomPainter {
  StudyWheelPainter({
    required this.layout,
    required this.progress,
    required this.dark,
    required this.track,
    required this.selected,
    required this.pulse,
  }) : super(repaint: progress);
  final WheelLayout layout;
  final StudyProgress progress;
  final bool dark;
  final Color track;
  final String? selected;
  final double pulse;

  static const thickness = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 22;
    final rect = Rect.fromCircle(center: c, radius: r);
    for (final a in layout.arcs) {
      final isSel = a.book.group == selected;
      final dim = selected != null && !isSel;
      final col = groupColor(a.book.group, dark);
      final w = isSel ? thickness + 6 + 2 * pulse : thickness;
      canvas.drawArc(
        rect,
        a.start,
        a.sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.butt
          ..color = col.withValues(alpha: dim ? 0.10 : 0.22),
      );
      final done = progress.doneIn(a.book) / a.book.chapters;
      if (done > 0) {
        canvas.drawArc(
          rect,
          a.start,
          a.sweep * done,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w
            ..strokeCap = StrokeCap.butt
            ..color = col.withValues(alpha: dim ? 0.45 : 1),
        );
      }
    }
    // حلقة داخلية رفيعة: بتفرّق العهد القديم عن الجديد
    final inner = Rect.fromCircle(center: c, radius: r - thickness / 2 - 12);
    final ot = layout.groups.where((g) => !g.group.newTestament);
    final nt = layout.groups.where((g) => g.group.newTestament);
    void ring(Iterable<WheelGroupArc> gs, Color col) {
      if (gs.isEmpty) return;
      final s = gs.first.start;
      final e = gs.last.start + gs.last.sweep;
      canvas.drawArc(inner, s, e - s, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = col);
    }

    ring(ot, groupColor('law', dark).withValues(alpha: .55));
    ring(nt, groupColor('gospels', dark).withValues(alpha: .55));
  }

  @override
  bool shouldRepaint(StudyWheelPainter old) =>
      old.selected != selected || old.dark != dark || old.pulse != pulse || old.layout != layout;
}
