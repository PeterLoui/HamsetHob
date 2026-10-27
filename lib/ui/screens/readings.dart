import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/coptic.dart';
import '../../data/katameros.dart';
import '../glass.dart';
import '../theme.dart';

/// شريط التاريخ: اليوم السابق/التالي.
class DateSwitcher extends StatelessWidget {
  const DateSwitcher({super.key, required this.date, required this.onChange});
  final DateTime date;
  final ValueChanged<DateTime> onChange;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final coptic = CopticDate.fromGregorian(date);
    return GlassPanel(
      radius: 26,
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        RoundAction(
          icon: Icon(Icons.chevron_right, color: c.text),
          onTap: () => onChange(date.subtract(const Duration(days: 1))),
          tooltip: 'اليوم السابق',
          size: 44,
        ),
        Expanded(
          child: Column(children: [
            Text(coptic.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
            Text('${weekdayName(date)} ${gregorianLabel(date)}', style: TextStyle(fontSize: 12, color: c.textSoft)),
          ]),
        ),
        RoundAction(
          icon: Icon(Icons.chevron_left, color: c.text),
          onTap: () => onChange(date.add(const Duration(days: 1))),
          tooltip: 'اليوم التالي',
          size: 44,
        ),
      ]),
    );
  }
}

/// قراءات القطمارس اليومية.
class ReadingsScreen extends StatefulWidget {
  const ReadingsScreen({super.key, required this.today, required this.onOpenSynaxarium});
  final DateTime today;
  final ValueChanged<DateTime> onOpenSynaxarium;

  @override
  State<ReadingsScreen> createState() => _ReadingsScreenState();
}

class _ReadingsScreenState extends State<ReadingsScreen> {
  late DateTime _date = widget.today;
  late Future<DayReadings> _future = KatamerosRepository.instance.day(_date);
  final _open = <String>{};

  void _setDate(DateTime d) => setState(() {
        _date = d;
        _future = KatamerosRepository.instance.day(d);
        _open.clear();
      });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, 24),
      children: [
        const ScreenHeader('القراءات', subtitle: 'القطمارس اليومي'),
        DateSwitcher(date: _date, onChange: _setDate),
        const SizedBox(height: 16),
        FutureBuilder<DayReadings>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return Column(children: [
                Text('تعذّر تحميل القراءات، تأكد من الاتصال بالإنترنت', style: TextStyle(color: c.textSoft)),
                const SizedBox(height: 12),
                GlassChip(label: 'إعادة المحاولة', onTap: () => _setDate(_date)),
              ]);
            }
            final r = snap.data;
            if (r == null) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final s in r.sections) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                  child: Text(s.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.accent)),
                ),
                for (final g in s.groups) ...[
                  if (g.isSynaxarium) _synaxariumLink(g) else _groupCard('${s.title}/${g.title}', g),
                  const SizedBox(height: 10),
                ],
              ],
            ]);
          },
        ),
      ],
    );
  }

  Widget _groupCard(String id, ReadingGroup g) {
    final c = context.colors;
    final open = _open.contains(id);
    final refs = g.readings.expand((r) => r.passages).map((p) => '${p.book} ${ar(p.ref)}').join(' ، ');
    return GlassPanel(
      radius: 24,
      padding: EdgeInsets.zero,
      settings: frostedSettings,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => setState(() => open ? _open.remove(id) : _open.add(id)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
                  if (refs.isNotEmpty) Text(refs, style: TextStyle(fontSize: 12, color: c.textSoft)),
                ]),
              ),
              Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: c.textSoft),
            ]),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (g.introduction != null) _faint(g.introduction!),
              for (final r in g.readings) ...[
                if (r.introduction != null) _faint(r.introduction!),
                for (final p in r.passages) ...[
                  Text('${p.book} ${ar(p.ref)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
                  const SizedBox(height: 4),
                  Text(p.text, style: context.scripture(size: 18)),
                  const SizedBox(height: 12),
                ],
                if (r.conclusion != null) _faint(r.conclusion!),
              ],
            ]),
          ),
      ]),
    );
  }

  Widget _faint(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t, style: TextStyle(fontSize: 13, height: 1.6, color: context.colors.textFaint)),
      );

  Widget _synaxariumLink(ReadingGroup g) {
    final c = context.colors;
    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      onTap: () => widget.onOpenSynaxarium(_date),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('السنكسار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
            Text(g.readings.map((r) => r.title).whereType<String>().join(' • '),
                maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSoft)),
          ]),
        ),
        const SizedBox(width: 8),
        Pill('اقرأ السير  ‹', onTap: () => widget.onOpenSynaxarium(_date)),
      ]),
    );
  }
}

/// سير قديسي اليوم كاملة.
class SynaxariumScreen extends StatefulWidget {
  const SynaxariumScreen({super.key, required this.start, required this.onBack});
  final DateTime start;
  final VoidCallback onBack;

  @override
  State<SynaxariumScreen> createState() => _SynaxariumScreenState();
}

class _SynaxariumScreenState extends State<SynaxariumScreen> {
  late DateTime _date = widget.start;
  late Future<DayReadings> _future = KatamerosRepository.instance.day(_date);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, MediaQuery.paddingOf(context).bottom + 24),
      children: [
        ScreenHeader('السنكسار', subtitle: 'سير القديسين وتذكاراتهم', onBack: widget.onBack),
        DateSwitcher(
          date: _date,
          onChange: (d) => setState(() {
            _date = d;
            _future = KatamerosRepository.instance.day(d);
          }),
        ),
        const SizedBox(height: 16),
        FutureBuilder<DayReadings>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return Text('تعذّر تحميل السنكسار، تأكد من الاتصال بالإنترنت', style: TextStyle(color: c.textSoft));
            final stories = snap.data?.synaxarium;
            if (stories == null) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
            if (stories.isEmpty) return Text('لا يوجد سنكسار لهذا اليوم', style: TextStyle(color: c.textSoft));
            return Column(children: [
              for (final s in stories) ...[
                GlassPanel(
                  radius: 26,
                  settings: frostedSettings,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.title, style: TextStyle(fontSize: 18, height: 1.5, fontWeight: FontWeight.w700, color: c.accent)),
                    const SizedBox(height: 10),
                    Text(s.text, style: context.scripture(size: 17)),
                  ]),
                ),
                const SizedBox(height: 14),
              ],
            ]);
          },
        ),
      ],
    );
  }
}
