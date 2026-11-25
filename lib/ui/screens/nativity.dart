import 'package:flutter/material.dart';

import '../../core/coptic.dart' show ar;
import '../../core/season.dart';
import '../glass.dart';
import '../season_widgets.dart';
import '../theme.dart';

/// شاشة الصوم: ٤٣ فانوس، فانوس لكل يوم، واختصارات للتسبحة والقراءات ونبوة اليوم.
class NativityScreen extends StatelessWidget {
  const NativityScreen({
    super.key,
    required this.today,
    required this.onBack,
    required this.onOpenTasbeha,
    required this.onOpenReadings,
    required this.onOpenProphecy,
  });
  final DateTime today;
  final VoidCallback onBack, onOpenTasbeha, onOpenReadings;
  final VoidCallback onOpenProphecy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final season = NativitySeason.of(today);
    final pad = MediaQuery.paddingOf(context);
    final day = season.inFast ? season.dayOfFast : (season.feast ? 44 : 0);
    return Stack(children: [
      const Positioned(left: 0, right: 0, top: 0, child: SeasonSky(height: 220, starX: .1, starY: 58)),
      ListView(
        padding: EdgeInsets.fromLTRB(24, pad.top, 24, pad.bottom + 40),
        children: [
          ScreenHeader(
            season.feast ? 'عيد الميلاد المجيد' : 'صوم الميلاد المجيد',
            subtitle: '٤٣ يوماً من ١٦ هاتور إلى ٢٨ كيهك — كل يوم بيعدّي يتنوّر فانوسه',
            onBack: onBack,
          ),
          const SizedBox(height: 8),
          for (var row = 0; row < 7; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (var col = 0; col < 7; col++)
                  if (row * 7 + col + 1 <= NativitySeason.fastLength)
                    _cell(c, row * 7 + col + 1, day)
                  else
                    const SizedBox(width: 44),
              ]),
            ),
          const SizedBox(height: 18),
          Center(
            child: Column(children: [
              CustomPaint(size: const Size(70, 70), painter: _StarPainter(c.navGlow, day > NativitySeason.fastLength)),
              Text(season.feast ? 'المسيح وُلد، بالحقيقة وُلد' : 'وفي الآخر… نجمة العيد ٢٩ كيهك', style: TextStyle(fontSize: 13, color: c.textSoft)),
            ]),
          ),
          const SizedBox(height: 20),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            AppChip(label: 'تسبحة كيهك', onTap: onOpenTasbeha),
            AppChip(label: 'قراءات اليوم', onTap: onOpenReadings),
            if (season.inFast) AppChip(label: 'نبوة اليوم', selected: true, onTap: onOpenProphecy),
          ]),
        ],
      ),
    ]);
  }

  Widget _cell(AppColors c, int d, int day) {
    final state = d < day ? 1 : (d == day ? 2 : 0);
    return SizedBox(
      width: 44,
      child: Column(children: [
        LanternDot(state: state, color: c.navGlow, idle: c.isDark ? const Color(0xFF3A342B) : const Color(0xFFD3C9B6)),
        Text(ar(d), style: TextStyle(fontSize: 11, color: state == 2 ? c.navGlow : c.textFaint, fontWeight: state == 2 ? FontWeight.w700 : FontWeight.w400)),
      ]),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.color, this.lit);
  final Color color;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, 34, Paint()..shader = RadialGradient(colors: [color.withValues(alpha: lit ? .8 : .35), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: 34)));
    canvas.drawPath(starPath(c, 22, 6), Paint()..color = lit ? color : color.withValues(alpha: .6));
  }

  @override
  bool shouldRepaint(_StarPainter o) => o.lit != lit || o.color != color;
}
