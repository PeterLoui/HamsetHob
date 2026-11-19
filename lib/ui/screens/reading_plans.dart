import 'package:flutter/material.dart';

import '../../core/coptic.dart' show ar;
import '../../data/bible.dart';
import '../../data/reading_plans.dart';
import '../../data/store.dart';
import '../glass.dart';
import '../theme.dart';

/// قائمة خطط القراءة مع تقدّم كل خطة.
class ReadingPlansScreen extends StatelessWidget {
  const ReadingPlansScreen({super.key, required this.onBack, required this.onOpenPlan});
  final VoidCallback onBack;
  final ValueChanged<ReadingPlan> onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: ReadingProgress.instance,
      builder: (context, _) => ListView(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          ScreenHeader('خطط القراءة', subtitle: 'اقرأ الكتاب بترتيب وتابع تقدّمك', onBack: onBack),
          for (final plan in readingPlans) ...[
            Builder(builder: (context) {
              final total = plan.days.length;
              final done = ReadingProgress.instance.completed(plan.id);
              return GlassPanel(
                radius: 22,
                padding: const EdgeInsets.all(16),
                onTap: () => onOpenPlan(plan),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(plan.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                  Text(plan.subtitle, style: TextStyle(fontSize: 12, color: c.textSoft)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : done / total,
                      minHeight: 5,
                      color: c.live,
                      backgroundColor: c.chip,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    done >= total ? 'اكتملت الخطة ✓' : 'اليوم ${ar(done + 1)} من ${ar(total)}',
                    style: TextStyle(fontSize: 12, color: done >= total ? c.accent : c.textFaint),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          Text('القراءة من الكتاب المحمّل على الجهاز إن وُجد، وإلا تحتاج إنترنت',
              style: TextStyle(fontSize: 11, color: c.textFaint)),
        ],
      ),
    );
  }
}

/// أيام خطة واحدة: قراءة كل يوم، علامة تم، ولمسة تفتح أول إصحاح.
class ReadingPlanScreen extends StatefulWidget {
  const ReadingPlanScreen({super.key, required this.plan, required this.onBack, required this.onOpenChapter});
  final ReadingPlan plan;
  final VoidCallback onBack;
  final ValueChanged<VerseRef> onOpenChapter;

  @override
  State<ReadingPlanScreen> createState() => _ReadingPlanScreenState();
}

class _ReadingPlanScreenState extends State<ReadingPlanScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // ننزل عند اليوم الحالي بعد أول رسم
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cur = ReadingProgress.instance.currentDay(widget.plan.id, widget.plan.days.length);
      if (_scroll.hasClients && cur > 2) {
        _scroll.jumpTo((cur * 68.0).clamp(0, _scroll.position.maxScrollExtent));
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final plan = widget.plan;
    return ListenableBuilder(
      listenable: ReadingProgress.instance,
      builder: (context, _) {
        final cur = ReadingProgress.instance.currentDay(plan.id, plan.days.length);
        return ListView.builder(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, MediaQuery.paddingOf(context).bottom + 24),
          itemCount: plan.days.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) return ScreenHeader(plan.title, subtitle: plan.subtitle, onBack: widget.onBack);
            final day = i - 1;
            final chapters = plan.days[day];
            final done = ReadingProgress.instance.isDone(plan.id, day);
            final isCurrent = day == cur;
            return Container(
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: isCurrent ? c.chip : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                // علامة «تم»
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => ReadingProgress.instance.setDone(plan.id, day, !done),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(done ? Icons.check_circle : Icons.circle_outlined, color: done ? c.live : c.textFaint, size: 24),
                  ),
                ),
                // القراءة — لمسة تفتح أول إصحاح
                Expanded(
                  child: InkWell(
                    onTap: () => widget.onOpenChapter(chapters.first),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('اليوم ${ar(day + 1)}', style: TextStyle(fontSize: 11, color: isCurrent ? c.accent : c.textFaint)),
                        Text(planDayLabel(chapters),
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: done ? c.textSoft : c.text)),
                      ]),
                    ),
                  ),
                ),
                if (chapters.length > 1)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Text('${ar(chapters.length)} إصحاح', style: TextStyle(fontSize: 11, color: c.textFaint)),
                  ),
              ]),
            );
          },
        );
      },
    );
  }
}
