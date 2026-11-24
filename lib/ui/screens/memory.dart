import 'package:flutter/material.dart';

import '../../core/coptic.dart' show ar, dateOnly;
import '../../data/bible.dart';
import '../../data/memory.dart';
import '../glass.dart';
import '../theme.dart';

/// حفظ الآيات: الآيات اللي بتحفظها ومراجعتها (تكرار متباعد)، وآية الأسبوع.
class MemoryScreen extends StatelessWidget {
  const MemoryScreen({super.key, required this.onBack, required this.onReview});
  final VoidCallback onBack;
  final void Function(List<MemoryVerse> queue) onReview;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = MemoryStore.instance!;
    final pad = MediaQuery.paddingOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final due = store.due();
        final next = store.items.where((m) => m.due.isAfter(dateOnly(DateTime.now()))).map((m) => m.due).fold<DateTime?>(null, (a, d) => a == null || d.isBefore(a) ? d : a);
        final weekRef = weeklyVerse();
        return ListView(
          padding: EdgeInsets.fromLTRB(24, pad.top, 24, pad.bottom + 40),
          children: [
            ScreenHeader('حفظ الآيات', subtitle: 'الآية بتظهر لك قبل ما تنساها: كل مراجعة صح بتبعّد الميعاد', onBack: onBack),
            GlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${ar(store.items.length)} آية محفوظة', style: context.heading(size: 20))),
                  Text(due.isEmpty ? 'مفيش مراجعة' : '${ar(due.length)} للمراجعة النهارده', style: TextStyle(fontSize: 13, color: due.isEmpty ? c.textFaint : c.navGlow, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 12),
                if (due.isNotEmpty)
                  AppChip(label: 'ابدأ المراجعة (${ar(due.length)})', selected: true, onTap: () => onReview(due))
                else
                  Text(
                    store.items.isEmpty
                        ? 'احفظ آية الأسبوع، أو اضغط «احفظها» على أي آية في الكتاب.'
                        : (next == null ? '' : 'المراجعة الجاية ${_when(next)}'),
                    style: TextStyle(fontSize: 13, color: c.textSoft),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            _WeekCard(ref: weekRef),
            if (store.items.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text('آياتي', style: TextStyle(fontSize: 13, color: c.textFaint)),
              const SizedBox(height: 6),
              for (final m in store.items)
                InkWell(
                  onTap: () => onReview([m]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m.ref.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.accent)),
                          const SizedBox(height: 2),
                          Text(m.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, height: 1.6, color: c.text)),
                          const SizedBox(height: 6),
                          Row(children: [
                            for (var i = 0; i <= MemoryStore.topBox; i++)
                              Container(
                                width: 14,
                                height: 5,
                                margin: const EdgeInsets.only(left: 4),
                                decoration: BoxDecoration(color: i <= m.box ? c.navGlow : c.hairline, borderRadius: BorderRadius.circular(3)),
                              ),
                            const SizedBox(width: 8),
                            Text(!m.due.isAfter(dateOnly(DateTime.now())) ? 'مراجعتها النهارده' : 'الجاية ${_when(m.due)}', style: TextStyle(fontSize: 11, color: c.textFaint)),
                          ]),
                        ]),
                      ),
                      RoundAction(icon: Icon(Icons.delete_outline, color: c.textFaint, size: 20), onTap: () => store.remove(m.ref), tooltip: 'شيل من الحفظ'),
                    ]),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  static String _when(DateTime d) {
    final days = d.difference(dateOnly(DateTime.now())).inDays;
    return days <= 0 ? 'النهارده' : (days == 1 ? 'بكرة' : 'بعد ${ar(days)} يوم');
  }
}

/// آية الأسبوع: نصها بيتحمّل من الكتاب، وزرار «احفظها».
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.ref});
  final VerseRef ref;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = MemoryStore.instance!;
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<List<Verse>>(
        future: BibleRepository.instance.chapter(ref.book, ref.chapter),
        builder: (context, snap) {
          final text = snap.data?.where((v) => v.number == ref.verse).firstOrNull?.text;
          final saved = store.contains(ref);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('آية الأسبوع', style: TextStyle(fontSize: 12, color: c.textFaint)),
            const SizedBox(height: 6),
            if (text == null)
              Text(snap.hasError ? 'تعذّر تحميل الآية، اتأكد من النت' : '…', style: TextStyle(color: c.textSoft))
            else
              Text('«$text»', style: context.scripture(size: 20)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text(ref.label, style: TextStyle(fontSize: 14, color: c.accent))),
              if (text != null) AppChip(label: saved ? 'محفوظة ✓' : 'احفظها', selected: !saved, onTap: () => saved ? store.remove(ref) : store.add(ref, text)),
            ]),
          ]);
        },
      ),
    );
  }
}

/// مراجعة آيات: كلمات مخفية بتكمّلها من بنك كلمات، ومن الصندوق ٤ فوق بتفتكر الآية كلها وتقيّم نفسك.
class MemoryReviewScreen extends StatefulWidget {
  const MemoryReviewScreen({super.key, required this.queue, required this.onBack});
  final List<MemoryVerse> queue;
  final VoidCallback onBack;

  @override
  State<MemoryReviewScreen> createState() => _MemoryReviewScreenState();
}

class _MemoryReviewScreenState extends State<MemoryReviewScreen> {
  int _i = 0;
  late BlankPlan _plan = _planFor(widget.queue[0]);
  int _cursor = 0;
  int _mistakes = 0;
  final _used = <int>{};
  int? _wrong;
  bool _revealed = false;
  bool _done = false;
  int _perfect = 0;

  MemoryVerse get _m => widget.queue[_i];
  bool get _recall => BlankPlan.isRecall(_m.box);

  BlankPlan _planFor(MemoryVerse m) => BlankPlan.make(m.text, m.box, seed: Object.hash(m.ref.book, m.ref.chapter, m.ref.verse, m.box, DateTime.now().day));

  Future<void> _finish(int mistakes) async {
    if (_done) return;
    setState(() {
      _done = true;
      _mistakes = mistakes;
      if (mistakes == 0) _perfect++;
    });
    await MemoryStore.instance!.review(_m.ref, mistakes);
  }

  void _pick(int bankIndex) {
    if (_done || _cursor >= _plan.hidden.length) return;
    final word = _plan.bank[bankIndex];
    final target = BlankPlan.bare(_plan.tokens[_plan.hidden[_cursor]]);
    if (word == target) {
      setState(() {
        _used.add(bankIndex);
        _cursor++;
        _wrong = null;
      });
      if (_cursor >= _plan.hidden.length) _finish(_mistakes);
    } else {
      setState(() {
        _mistakes++;
        _wrong = bankIndex;
      });
    }
  }

  void _next() {
    if (_i + 1 >= widget.queue.length) {
      widget.onBack();
      return;
    }
    setState(() {
      _i++;
      _plan = _planFor(_m);
      _cursor = 0;
      _mistakes = 0;
      _used.clear();
      _wrong = null;
      _revealed = false;
      _done = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    final m = _m;
    return ListView(
      padding: EdgeInsets.fromLTRB(24, pad.top, 24, pad.bottom + 40),
      children: [
        ScreenHeader(m.ref.label, subtitle: 'آية ${ar(_i + 1)} من ${ar(widget.queue.length)} — الصندوق ${ar(m.box + 1)} من ${ar(MemoryStore.topBox + 1)}', onBack: widget.onBack),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(value: (_i + (_done ? 1 : 0)) / widget.queue.length, minHeight: 5, color: c.navGlow, backgroundColor: c.chip),
        ),
        const SizedBox(height: 20),
        GlassPanel(
          padding: const EdgeInsets.all(20),
          child: _recall ? _recallBody(context) : _fillBody(context),
        ),
        const SizedBox(height: 16),
        if (!_recall && !_done) ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < _plan.bank.length; i++)
              if (!_used.contains(i))
                Material(
                  color: _wrong == i ? const Color(0x33D9534F) : c.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: _wrong == i ? const Color(0xFFD9534F) : c.hairline)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _pick(i),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Text(_plan.bank[i], style: context.scripture(size: 17).copyWith(height: 1.3))),
                  ),
                ),
          ]),
          const SizedBox(height: 14),
          Center(child: InkWell(onTap: () => _finish(3), child: Padding(padding: const EdgeInsets.all(10), child: Text('اعرض الآية', style: TextStyle(fontSize: 13, color: c.textSoft))))),
        ],
        if (_done) _result(context),
      ],
    );
  }

  Widget _fillBody(BuildContext context) {
    final c = context.colors;
    final spans = <Widget>[];
    for (var i = 0; i < _plan.tokens.length; i++) {
      final h = _plan.hidden.indexOf(i);
      final style = context.scripture(size: 22);
      if (h < 0 || h < _cursor || _done) {
        spans.add(Text(_plan.tokens[i], style: style.copyWith(color: h >= 0 && !_done ? c.navGlow : style.color)));
      } else {
        final current = h == _cursor;
        final w = (BlankPlan.bare(_plan.tokens[i]).length * 9.0).clamp(36.0, 120.0);
        spans.add(Container(
          width: w,
          height: 26,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: current ? c.navGlow : c.textFaint, width: current ? 2.5 : 1.5))),
        ));
      }
    }
    return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: spans);
  }

  Widget _recallBody(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_revealed || _done ? '«${_m.text}»' : 'افتكر الآية كلها، وبعدين اعرضها وقيّم نفسك.', style: _revealed || _done ? context.scripture(size: 22) : TextStyle(fontSize: 15, height: 1.7, color: c.textSoft)),
      const SizedBox(height: 14),
      if (!_revealed && !_done)
        AppChip(label: 'اعرض الآية', selected: true, onTap: () => setState(() => _revealed = true))
      else if (!_done)
        Row(children: [
          Expanded(child: AppChip(label: 'مش عارفها', onTap: () => _finish(3))),
          const SizedBox(width: 10),
          Expanded(child: AppChip(label: 'عرفتها', selected: true, onTap: () => _finish(0))),
        ]),
    ]);
  }

  Widget _result(BuildContext context) {
    final c = context.colors;
    final box = _m.box; // اتحدّث بعد التقييم
    final text = _mistakes == 0 ? 'من غير غلط! الآية طلعت للصندوق ${ar(box + 1)}' : (_mistakes <= 2 ? 'قريب! هتراجعها بكرة' : 'هنرجّعها للبداية ونراجعها بكرة');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _mistakes == 0 ? c.navGlow : c.textSoft))),
      const SizedBox(height: 14),
      AppChip(label: _i + 1 >= widget.queue.length ? 'خلصت (${ar(_perfect)} من ${ar(widget.queue.length)} من غير غلط)' : 'الآية الجاية', selected: true, onTap: _next),
    ]);
  }
}
