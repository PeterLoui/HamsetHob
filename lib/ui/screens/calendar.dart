import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/coptic.dart';
import '../../core/synaxarium.dart';
import '../glass.dart';
import '../theme.dart';

/// النتيجة: شهر ميلادي أو قبطي مع الأعياد وبدايات الأصوام.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.today});
  final DateTime today;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _coptic = false;
  late DateTime _anchor = dateOnly(widget.today);

  // الأسبوع يبدأ السبت: DateTime.weekday للسبت = 6
  static const _weekOrder = [6, 7, 1, 2, 3, 4, 5];

  List<DateTime> get _days {
    if (_coptic) {
      final c = CopticDate.fromGregorian(_anchor);
      final first = CopticDate(c.year, c.month, 1).toGregorian();
      return List.generate(CopticDate.daysInMonth(c.year, c.month), (i) => first.add(Duration(days: i)));
    }
    final first = DateTime.utc(_anchor.year, _anchor.month, 1);
    final count = DateTime.utc(_anchor.year, _anchor.month + 1, 0).day;
    return List.generate(count, (i) => first.add(Duration(days: i)));
  }

  void _shift(int step) {
    final days = _days;
    setState(() {
      _anchor = _coptic
          ? days.first.add(Duration(days: step > 0 ? days.length + 2 : -3))
          : DateTime.utc(_anchor.year, _anchor.month + step, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final days = _days;
    final today = dateOnly(widget.today);
    final events = [for (final d in days) if (Synaxarium.feastOrFast(d) case final e?) (d, e)];

    String title, subtitle;
    if (_coptic) {
      final a = CopticDate.fromGregorian(days.first);
      title = '${a.monthName} ${ar(a.year)} ش';
      final b = days.last;
      subtitle = '${ar(days.first.day)} ${gregorianMonths[days.first.month - 1]} – ${ar(b.day)} ${gregorianMonths[b.month - 1]}';
    } else {
      title = '${gregorianMonths[_anchor.month - 1]} ${ar(_anchor.year)}';
      final a = CopticDate.fromGregorian(days.first), b = CopticDate.fromGregorian(days.last);
      subtitle = a.month == b.month ? a.monthName : '${a.monthName} – ${b.monthName}';
    }

    final leading = _weekOrder.indexOf(days.first.weekday);
    final cells = <DateTime?>[...List.filled(leading, null), ...days];

    return ListView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, 24),
      children: [
        ScreenHeader(
          'النتيجة',
          subtitle: 'الأعياد وبدايات الأصوام',
          trailing: SizedBox(
            width: 150,
            child: GlassSegmentedControl(
              segments: const [GlassSegment(label: 'ميلادي'), GlassSegment(label: 'قبطي')],
              selectedIndex: _coptic ? 1 : 0,
              onSegmentSelected: (i) => setState(() {
                _coptic = i == 1;
                _anchor = today;
              }),
            ),
          ),
        ),
        GlassPanel(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              RoundAction(icon: Icon(Icons.chevron_right, color: c.text), onTap: () => _shift(-1), tooltip: 'الشهر السابق', size: 44),
              Expanded(
                child: Column(children: [
                  Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: c.text)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: c.textSoft)),
                ]),
              ),
              RoundAction(icon: Icon(Icons.chevron_left, color: c.text), onTap: () => _shift(1), tooltip: 'الشهر التالي', size: 44),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              for (final wd in _weekOrder)
                Expanded(
                  child: Text(weekdayNames[wd - 1],
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: c.textFaint)),
                ),
            ]),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: .78,
              children: [for (final d in cells) d == null ? const SizedBox() : _DayCell(date: d, today: today, coptic: _coptic)],
            ),
          ]),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الأعياد والأصوام', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.text)),
            const SizedBox(height: 8),
            if (events.isEmpty)
              Text('لا توجد أعياد كبرى أو بدايات أصوام في هذا الشهر', style: TextStyle(fontSize: 13, color: c.textSoft)),
            for (final (d, e) in events)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: c.kindColor(e.kind))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
                      Text('${weekdayName(d)} ${ar(d.day)} ${gregorianMonths[d.month - 1]}  •  ${CopticDate.fromGregorian(d).label}',
                          style: TextStyle(fontSize: 12, color: c.textSoft)),
                    ]),
                  ),
                  Text(e.kind.label, style: TextStyle(fontSize: 11, color: c.kindColor(e.kind))),
                ]),
              ),
          ]),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.date, required this.today, required this.coptic});
  final DateTime date, today;
  final bool coptic;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cd = CopticDate.fromGregorian(date);
    final event = Synaxarium.feastOrFast(date);
    final isToday = date == today;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isToday ? c.accent.withValues(alpha: .25) : c.chip.withValues(alpha: .5),
        border: isToday ? Border.all(color: c.accent, width: 1.2) : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(ar(coptic ? cd.day : date.day), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
        Text(ar(coptic ? date.day : cd.day), style: TextStyle(fontSize: 10, color: c.textFaint)),
        const SizedBox(height: 2),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(shape: BoxShape.circle, color: event == null ? Colors.transparent : c.kindColor(event.kind)),
        ),
      ]),
    );
  }
}
