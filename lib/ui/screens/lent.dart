import 'package:flutter/material.dart';

import '../../core/coptic.dart' show ar, copticEaster, weekdayName;
import '../../core/season.dart';
import '../../data/katameros.dart';
import '../glass.dart';
import '../season_widgets.dart';
import '../theme.dart';

/// الصوم الكبير: ٨ أسابيع، كل أسبوع صف بلونه وأيامه، وأحده باسمه. اليوم الحالي منوّر.
class LentScreen extends StatelessWidget {
  const LentScreen({
    super.key,
    required this.today,
    required this.onBack,
    required this.onOpenReadings,
    required this.onOpenHolyWeek,
    required this.onOpenVerse,
  });
  final DateTime today;
  final VoidCallback onBack, onOpenReadings, onOpenHolyWeek, onOpenVerse;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = LentSeason.of(today);
    final pad = MediaQuery.paddingOf(context);
    final easter = s.easterWeek;
    final kind = easter ? SkyKind.easter : (s.holyWeek ? SkyKind.passion : SkyKind.lent);
    final tint = easter ? c.navGlow : lentWeekColor(s.inLent ? s.week : 0, c.isDark);
    var dayCounter = 0;
    return Stack(children: [
      Positioned(left: 0, right: 0, top: 0, child: SeasonSky(height: 240, starX: .1, starY: 58, kind: kind, tint: tint)),
      ListView(
        padding: EdgeInsets.fromLTRB(24, pad.top, 24, pad.bottom + 40),
        children: [
          ScreenHeader(easter ? 'عيد القيامة المجيد' : 'الصوم الكبير', subtitle: '٥٥ يوماً: تمهيدي وستة أسابيع وأسبوع البصخة', onBack: onBack),
          const SizedBox(height: 4),
          for (var w = 0; w < LentSeason.weekDays.length; w++) ...[
            () {
              final n = LentSeason.weekDays[w];
              final first = dayCounter;
              dayCounter += n;
              final isCurrent = s.inLent && s.week == w;
              final col = lentWeekColor(w, c.isDark);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isCurrent ? col.withValues(alpha: .8) : c.hairline, width: isCurrent ? 1.5 : 1),
                  boxShadow: isCurrent ? [BoxShadow(color: col.withValues(alpha: .25), blurRadius: 22, spreadRadius: -2)] : null,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 6, height: 34, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(LentSeason.weekNames[w], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                        Text(
                          w == 0 ? 'أسبوع الاستعداد قبل الأربعين' : (w == 7 ? 'من أحد الشعانين لسبت النور' : LentSeason.sundayNames[w]),
                          style: TextStyle(fontSize: 12, color: c.textFaint),
                        ),
                      ]),
                    ),
                    if (w == 7) AppChip(label: 'ساعات البصخة', selected: true, onTap: onOpenHolyWeek),
                  ]),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    for (var d = 0; d < n; d++) _Day(index: first + d + 1, today: s.dayOfLent, color: col, sunday: w >= 1 && d == 0),
                  ]),
                ]),
              );
            }(),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            AppChip(label: 'قراءات اليوم', onTap: onOpenReadings),
            AppChip(label: 'آية اليوم', onTap: onOpenVerse),
            AppChip(label: 'ساعات البصخة', onTap: onOpenHolyWeek),
          ]),
        ],
      ),
    ]);
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.index, required this.today, required this.color, required this.sunday});
  final int index, today;
  final Color color;
  final bool sunday;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final passed = index < today;
    final now = index == today;
    final size = now ? 34.0 : 30.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: now ? color : (passed ? color.withValues(alpha: .28) : Colors.transparent),
        border: Border.all(color: now ? color : (sunday ? color : c.hairline), width: sunday && !now ? 2 : 1.2),
        boxShadow: now ? [BoxShadow(color: color.withValues(alpha: .5), blurRadius: 14)] : null,
      ),
      child: Text(ar(index), style: TextStyle(fontSize: 11, fontWeight: now ? FontWeight.w700 : FontWeight.w400, color: now ? Colors.white : (passed ? c.text : c.textFaint))),
    );
  }
}

/// ساعات البصخة: أيام سبت لعازر إلى سبت النور وعيد القيامة، وتحت كل يوم ساعاته وقراءاتها (من القطمارس).
class HolyWeekScreen extends StatefulWidget {
  const HolyWeekScreen({super.key, required this.today, required this.onBack});
  final DateTime today;
  final VoidCallback onBack;

  @override
  State<HolyWeekScreen> createState() => _HolyWeekScreenState();
}

class _HolyWeekScreenState extends State<HolyWeekScreen> {
  static const _offsets = [-8, -7, -6, -5, -4, -3, -2, -1, 0];
  late int _sel = () {
    final o = LentSeason.of(widget.today).offset;
    return _offsets.contains(o) ? o : -7;
  }();
  late Future<DayReadings> _future = _load();
  int _cached = 0;
  bool _prefetching = false;

  DateTime _date(int off) => copticEaster(widget.today.year).add(Duration(days: off));

  Future<DayReadings> _load() => KatamerosRepository.instance.day(_date(_sel));

  @override
  void initState() {
    super.initState();
    _prefetch();
  }

  /// تنزيل كل أيام البصخة عشان تتفتح من غير نت.
  Future<void> _prefetch() async {
    if (_prefetching) return;
    _prefetching = true;
    for (final o in _offsets) {
      try {
        await KatamerosRepository.instance.day(_date(o));
        if (mounted) setState(() => _cached++);
      } catch (_) {/* نكمّل، والباقي يتحمّل عند فتحه */}
    }
    _prefetching = false;
  }

  String _name(int off) => off == 0 ? 'عيد القيامة' : (LentSeason.holyDayNames[off] ?? '');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    final col = lentWeekColor(7, c.isDark);
    final d = _date(_sel);
    return ListView(
      padding: EdgeInsets.fromLTRB(24, pad.top, 24, pad.bottom + 40),
      children: [
        ScreenHeader('ساعات البصخة', subtitle: 'قراءات كل ساعة من سبت لعازر لعيد القيامة', onBack: widget.onBack),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _offsets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final o = _offsets[i];
              return AppChip(
                label: _name(o),
                selected: _sel == o,
                onTap: () => setState(() {
                  _sel = o;
                  _future = _load();
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text('${weekdayName(d)} ${ar(d.day)}/${ar(d.month)}', style: TextStyle(fontSize: 13, color: c.textFaint)),
        const SizedBox(height: 10),
        FutureBuilder<DayReadings>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) {
              return Column(children: [
                Text('تعذّر تحميل قراءات اليوم، اتأكد من الاتصال بالنت', style: TextStyle(color: c.textSoft)),
                const SizedBox(height: 10),
                AppChip(label: 'حاول تاني', onTap: () => setState(() => _future = _load())),
              ]);
            }
            final sections = [for (final s in snap.data!.sections) if (!s.groups.every((g) => g.isSynaxarium)) s];
            if (sections.isEmpty) return Text('مفيش قراءات لليوم ده', style: TextStyle(color: c.textSoft));
            return Column(children: [for (final s in sections) _Hour(section: s, color: col)]);
          },
        ),
        const SizedBox(height: 14),
        Text('تم تنزيل ${ar(_cached)} من ${ar(_offsets.length)} أيام للقراءة بدون نت', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.textFaint)),
      ],
    );
  }
}

class _Hour extends StatelessWidget {
  const _Hour({required this.section, required this.color});
  final ReadingSection section;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.hairline)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(width: 6, height: 30, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          title: Text(section.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
          children: [
            for (final g in section.groups)
              for (final r in g.readings)
                for (final p in r.passages)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${p.book} ${ar(p.ref)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                      if (g.title.isNotEmpty && g.title != section.title) Text(g.title, style: TextStyle(fontSize: 11, color: c.textFaint)),
                      const SizedBox(height: 4),
                      Text(p.text, style: context.scripture(size: 17)),
                    ]),
                  ),
          ],
        ),
      ),
    );
  }
}
