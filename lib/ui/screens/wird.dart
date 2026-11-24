import 'package:flutter/material.dart';

import '../../core/coptic.dart' show ar, CopticDate, weekdayName, gregorianMonths;
import '../../data/study.dart';
import '../../data/wird.dart';
import '../glass.dart';
import '../theme.dart';
import '../wird_widgets.dart';

/// شاشة ورد اليوم: ٤ شمعات فوق، وتحتها البنود. كل بند بيفتح مكانه، وبيتعلّم تلقائياً أو بإيدك.
class WirdScreen extends StatelessWidget {
  const WirdScreen({
    super.key,
    required this.today,
    required this.onBack,
    required this.onPrayer,
    required this.onChapter,
    required this.onSermon,
    required this.onQuiz,
    required this.sermonLine,
  });
  final DateTime today;

  /// السطر الفرعي لبند العظة (آخر عظة سمعها، أو دعوة لاختيار عظة).
  final String sermonLine;
  final VoidCallback onBack, onPrayer, onChapter, onSermon, onQuiz;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = WirdStore.instance!;
    final pad = MediaQuery.paddingOf(context);
    final cd = CopticDate.fromGregorian(today);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final msg = store.complete ? 'تمّ ورد اليوم. ربنا يقبل منك' : '${ar(store.count)} من ${ar(WirdItem.values.length)} — خطوة خطوة، من غير ضغط';
        return Stack(children: [
          if (store.complete)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: Container(
                  height: 320,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(center: const Alignment(0, -.6), radius: .9, colors: [c.navGlow.withValues(alpha: c.isDark ? .28 : .16), c.navGlow.withValues(alpha: 0)]),
                  ),
                ),
              ),
            ),
          ListView(
            padding: EdgeInsets.fromLTRB(24, pad.top, 24, pad.bottom + 40),
            children: [
              ScreenHeader('وردك اليوم', subtitle: '${weekdayName(today)} ${ar(today.day)} ${gregorianMonths[today.month - 1]} — ${ar(cd.day)} ${cd.monthName}', onBack: onBack),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final i in WirdItem.values) Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Candle(lit: store.isDone(i), size: 40)),
              ]),
              const SizedBox(height: 12),
              Center(child: Text(msg, style: TextStyle(fontSize: 14, color: c.textSoft))),
              const SizedBox(height: 20),
              _Row(item: WirdItem.prayer, title: 'ساعة الأجبية', subtitle: '${WirdStore.hourFor(DateTime.now()).name} — الآن وقتها', source: 'الأجبية', onOpen: onPrayer),
              FutureBuilder(
                future: nextStudyChapter(),
                builder: (context, snap) {
                  final n = snap.data;
                  final sub = n == null ? 'ابدأ بإنجيل يوحنا' : '${n.book.name} ${ar(n.chapter)} — ${StudyProgress.instance?.last == null ? 'ابدأ من هنا' : 'كمّل من حيث وقفت'}';
                  return _Row(item: WirdItem.chapter, title: 'أصحاح اليوم', subtitle: sub, source: 'تفسير القمص أنطونيوس فكري', onOpen: onChapter);
                },
              ),
              _Row(
                item: WirdItem.sermon,
                title: 'عظة اليوم',
                subtitle: sermonLine,
                source: 'البابا شنوده الثالث',
                onOpen: onSermon,
              ),
              _Row(item: WirdItem.quiz, title: 'سؤال من المسابقات', subtitle: 'سؤال واحد من المسابقات', source: 'المسابقات', onOpen: onQuiz),
              const SizedBox(height: 14),
              Text('القائمة بتتجدد كل يوم، وبتتعلّم لوحدها لما تخلّص الأصحاح أو السؤال، أو تسمع دقيقة من العظة، أو تقعد مع الصلاة.\nمفيش سلسلة أيام ولا عدّ للي فاتك.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 11, height: 1.7, color: c.textFaint)),
            ],
          ),
        ]);
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.title, required this.subtitle, required this.source, required this.onOpen});
  final WirdItem item;
  final String title, subtitle, source;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = WirdStore.instance!;
    final done = store.isDone(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: done ? [BoxShadow(color: c.navGlow.withValues(alpha: .16), blurRadius: 20, spreadRadius: -2)] : null,
        ),
        child: GlassPanel(
          onTap: onOpen,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            SizedBox(width: 30, child: Center(child: Candle(lit: done, size: 24))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.textSoft)),
                Text(source, style: TextStyle(fontSize: 11, color: c.textFaint)),
              ]),
            ),
            // تعليم باليد: لو عملته من برّه
            InkResponse(
              onTap: () => store.toggle(item),
              radius: 22,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? c.navGlow : c.textFaint, size: 24),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
