import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/coptic.dart' show ar;
import '../../data/quiz.dart';
import '../../data/study.dart';
import '../glass.dart';
import '../study_wheel.dart';
import '../theme.dart';

EdgeInsets _pad(BuildContext context) {
  final pad = MediaQuery.paddingOf(context);
  return EdgeInsets.fromLTRB(24, pad.top, 24, pad.bottom + 32);
}

/// تبويب «دراسة»: عجلة الكتاب المقدس (تفاسير ومقدمات القمص أنطونيوس فكري) وقسم المسابقات.
class StudyScreen extends StatefulWidget {
  const StudyScreen({
    super.key,
    required this.onOpenBook,
    required this.onOpenDoc,
    required this.onOpenGuide,
    required this.onOpenQuiz,
  });
  final ValueChanged<StudyBook> onOpenBook;
  final void Function(List<StudyDoc> docs, int index, StudyBook? book) onOpenDoc;
  final ValueChanged<StudyGuide> onOpenGuide;
  final void Function(String title, List<QuizQuestion> questions) onOpenQuiz;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int _mode = 0;
  late final Future<(StudyCatalog, StudyProgress, QuizBank, QuizProgress)> _load = () async {
    final r = await Future.wait([StudyCatalog.load(), StudyProgress.load(), QuizBank.load(), QuizProgress.load()]);
    return (r[0] as StudyCatalog, r[1] as StudyProgress, r[2] as QuizBank, r[3] as QuizProgress);
  }();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _load,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (cat, prog, bank, qprog) = snap.data!;
        return ListView(
          padding: _pad(context),
          children: [
            const ScreenHeader('دراسة الكتاب المقدس', subtitle: 'تفاسير ومقدمات القمص أنطونيوس فكري ومسابقات البابا شنوده'),
            AppSegmented(labels: const ['الدراسة', 'المسابقات'], selectedIndex: _mode, onSelected: (i) => setState(() => _mode = i)),
            const SizedBox(height: 18),
            if (_mode == 0)
              _StudyHome(cat: cat, prog: prog, onOpenBook: widget.onOpenBook, onOpenDoc: widget.onOpenDoc, onOpenGuide: widget.onOpenGuide)
            else
              _QuizHome(cat: cat, bank: bank, qprog: qprog, onOpenQuiz: widget.onOpenQuiz),
          ],
        );
      },
    );
  }
}

// ───────────────────────── الدراسة: العجلة ─────────────────────────

class _StudyHome extends StatefulWidget {
  const _StudyHome({required this.cat, required this.prog, required this.onOpenBook, required this.onOpenDoc, required this.onOpenGuide});
  final StudyCatalog cat;
  final StudyProgress prog;
  final ValueChanged<StudyBook> onOpenBook;
  final void Function(List<StudyDoc> docs, int index, StudyBook? book) onOpenDoc;
  final ValueChanged<StudyGuide> onOpenGuide;

  @override
  State<_StudyHome> createState() => _StudyHomeState();
}

class _StudyHomeState extends State<_StudyHome> with SingleTickerProviderStateMixin {
  late final WheelLayout _layout = WheelLayout(widget.cat);
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  String? _group;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _tap(Offset p, Size size) {
    final d = p - size.center(Offset.zero);
    final dist = d.distance;
    final r = size.shortestSide / 2 - 22;
    if (dist < r - 46 || dist > r + 24) return;
    final g = _layout.groupAt(math.atan2(d.dy, d.dx));
    if (g != null) setState(() => _group = _group == g.group.id ? null : g.group.id);
  }

  void _resume() {
    final key = widget.prog.last;
    if (key == null) return;
    final parts = key.split(':');
    final b = widget.cat.byId(parts[0]);
    if (b == null) return;
    if (parts[1] == 'intro' && b.intro != null) {
      widget.onOpenDoc([widget.cat.intro(b)], 0, b);
    } else {
      final ch = int.tryParse(parts[1]);
      if (ch != null) widget.onOpenDoc(_chapterDocs(widget.cat, b), (b.intro != null ? 1 : 0) + ch - 1, b);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cat = widget.cat;
    final sel = _group == null ? null : cat.groups.firstWhere((g) => g.id == _group);
    return ListenableBuilder(
      listenable: widget.prog,
      builder: (context, _) {
        final done = widget.prog.totalDone;
        final pct = (done * 100 / cat.totalChapters);
        final lastKey = widget.prog.last;
        final lastBook = lastKey == null ? null : cat.byId(lastKey.split(':').first);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (lastBook != null) ...[
            GlassPanel(
              onTap: _resume,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Icon(Icons.bookmark_outline, color: c.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('كمّل من حيث وقفت', style: TextStyle(fontSize: 12, color: c.textFaint)),
                    Text(_labelOf(lastKey!, lastBook), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.text)),
                  ]),
                ),
                Icon(Icons.chevron_left, color: c.textFaint),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          Center(
            child: LayoutBuilder(builder: (context, box) {
              final side = math.min(box.maxWidth, 360.0);
              final size = Size(side, side);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _tap(d.localPosition, size),
                child: SizedBox(
                  width: side,
                  height: side,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => CustomPaint(
                      painter: StudyWheelPainter(
                        layout: _layout,
                        progress: widget.prog,
                        dark: c.isDark,
                        track: c.hairline,
                        selected: _group,
                        pulse: Curves.easeInOut.transform(_pulse.value),
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(side * .28),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            if (sel == null) ...[
                              Text('${ar(pct.floor())}٪', style: context.heading(size: 34)),
                              Text('${ar(done)} من ${ar(cat.totalChapters)} أصحاح',
                                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.textSoft)),
                            ] else ...[
                              Text(sel.name, textAlign: TextAlign.center, style: context.heading(size: 22, color: groupColor(sel.id, c.isDark))),
                              Text('${ar(cat.inGroup(sel.id).length)} سفر', style: TextStyle(fontSize: 12, color: c.textSoft)),
                            ],
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(_group == null ? 'المس قوساً لتفتح مجموعة أسفار — الحلقة بتتلوّن كل ما تخلّص أصحاح' : 'اللمس مرة تانية يقفل المجموعة',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.textFaint)),
          ),
          const SizedBox(height: 14),
          // شرائح المجموعات: بديل دقيق للمس على العجلة
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final g in cat.groups)
              AppChip(label: g.name, selected: _group == g.id, onTap: () => setState(() => _group = _group == g.id ? null : g.id)),
          ]),
          const SizedBox(height: 8),
          if (sel != null)
            for (final b in cat.inGroup(sel.id)) _BookRow(book: b, prog: widget.prog, color: groupColor(sel.id, c.isDark), onTap: () => widget.onOpenBook(b)),
          if (sel == null) ...[
            const SizedBox(height: 20),
            Text('مداخل عامة', style: TextStyle(fontSize: 13, color: c.textFaint)),
            const SizedBox(height: 6),
            for (final g in cat.guides)
              InkWell(
                onTap: () => widget.onOpenGuide(g),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
                  child: Row(children: [
                    Expanded(child: Text(g.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.text))),
                    Text('${ar(g.pages.length)} صفحة', style: TextStyle(fontSize: 12, color: c.textFaint)),
                    Icon(Icons.chevron_left, color: c.textFaint, size: 18),
                  ]),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text('المصدر: تفاسير ومقدمات القمص أنطونيوس فكري، موقع الأنبا تكلا هيمانوت. بتتحمّل عند أول قراءة وتتحفظ على جهازك.',
              style: TextStyle(fontSize: 11, color: c.textFaint, height: 1.6)),
        ]);
      },
    );
  }
}

List<StudyDoc> _chapterDocs(StudyCatalog cat, StudyBook b) => [
      if (b.intro != null) cat.intro(b),
      for (var i = 1; i <= b.chapters; i++) cat.chapter(b, i),
    ];

String _labelOf(String key, StudyBook b) {
  final p = key.split(':');
  if (p.length > 1 && p[1] == 'intro') return 'مقدمة ${b.name}';
  final ch = p.length > 1 ? int.tryParse(p[1]) : null;
  return ch == null ? b.name : '${b.name} ${ar(ch)}';
}

class _BookRow extends StatelessWidget {
  const _BookRow({required this.book, required this.prog, required this.color, required this.onTap});
  final StudyBook book;
  final StudyProgress prog;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = prog.doneIn(book);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
        child: Row(children: [
          Container(width: 6, height: 34, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(book.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.text)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: done / book.chapters, minHeight: 3, color: color, backgroundColor: color.withValues(alpha: .18)),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Text('${ar(done)}/${ar(book.chapters)}', style: TextStyle(fontSize: 12, color: c.textFaint)),
          Icon(Icons.chevron_left, color: c.textFaint, size: 18),
        ]),
      ),
    );
  }
}

// ───────────────────────── شاشة السفر ─────────────────────────

class StudyBookScreen extends StatelessWidget {
  const StudyBookScreen({super.key, required this.book, required this.onBack, required this.onOpenDoc, required this.onOpenQuiz});
  final StudyBook book;
  final VoidCallback onBack;
  final void Function(List<StudyDoc> docs, int index, StudyBook? book) onOpenDoc;
  final void Function(String title, List<QuizQuestion> questions) onOpenQuiz;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = groupColor(book.group, c.isDark);
    return FutureBuilder(
      future: Future.wait([StudyCatalog.load(), StudyProgress.load(), QuizBank.load()]),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final cat = snap.data![0] as StudyCatalog;
        final prog = snap.data![1] as StudyProgress;
        final bank = snap.data![2] as QuizBank;
        final docs = _chapterDocs(cat, book);
        final off = book.intro != null ? 1 : 0;
        final qs = bank.inBook(book.id);
        return ListenableBuilder(
          listenable: prog,
          builder: (context, _) => ListView(padding: _pad(context), children: [
            ScreenHeader(book.name, subtitle: '${ar(prog.doneIn(book))} من ${ar(book.chapters)} أصحاح', onBack: onBack),
            if (book.intro != null)
              _ActionRow(icon: Icons.menu_book_outlined, title: 'مقدمة ${book.name}', color: color, onTap: () => onOpenDoc(docs, 0, book)),
            for (final x in book.extras)
              _ActionRow(icon: Icons.school_outlined, title: x.title, color: color, onTap: () => onOpenDoc([cat.extra(book, x)], 0, book)),
            if (qs.isNotEmpty)
              _ActionRow(
                icon: Icons.quiz_outlined,
                title: 'اختبر نفسك في ${book.name}',
                trailing: '${ar(qs.length)} سؤال',
                color: color,
                onTap: () => onOpenQuiz('أسئلة ${book.name}', qs),
              ),
            const SizedBox(height: 16),
            Text('الأصحاحات', style: TextStyle(fontSize: 13, color: c.textFaint)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 1; i <= book.chapters; i++)
                _ChapterCell(
                  label: ar(i),
                  done: prog.isDone('${book.id}:$i'),
                  color: color,
                  onTap: () => onOpenDoc(docs, off + i - 1, book),
                ),
            ]),
          ]),
        );
      },
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.title, required this.color, required this.onTap, this.trailing});
  final IconData icon;
  final String title;
  final String? trailing;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.text))),
          if (trailing != null) Text(trailing!, style: TextStyle(fontSize: 12, color: c.textFaint)),
          Icon(Icons.chevron_left, color: c.textFaint, size: 18),
        ]),
      ),
    );
  }
}

class _ChapterCell extends StatelessWidget {
  const _ChapterCell({required this.label, required this.done, required this.color, required this.onTap});
  final String label;
  final bool done;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: done ? color : c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: done ? color : c.hairline)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 44,
          child: Center(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: done ? Colors.white : c.text))),
        ),
      ),
    );
  }
}

class StudyGuideScreen extends StatelessWidget {
  const StudyGuideScreen({super.key, required this.guide, required this.onBack, required this.onOpenDoc});
  final StudyGuide guide;
  final VoidCallback onBack;
  final void Function(List<StudyDoc> docs, int index, StudyBook? book) onOpenDoc;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FutureBuilder(
      future: StudyCatalog.load(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final cat = snap.data!;
        final docs = [for (final x in guide.pages) cat.guidePage(guide, x)];
        return ListView(padding: _pad(context), children: [
          ScreenHeader(guide.name, subtitle: '${ar(docs.length)} صفحة', onBack: onBack),
          for (var i = 0; i < docs.length; i++)
            InkWell(
              onTap: () => onOpenDoc(docs, i, null),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
                child: Row(children: [
                  SizedBox(width: 32, child: Text(ar(i + 1), style: TextStyle(fontSize: 13, color: c.accent))),
                  Expanded(child: Text(docs[i].title, style: TextStyle(fontSize: 15, color: c.text, height: 1.4))),
                  Icon(Icons.chevron_left, color: c.textFaint, size: 18),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

// ───────────────────────── قراءة التفسير ─────────────────────────

class StudyReaderScreen extends StatefulWidget {
  const StudyReaderScreen({super.key, required this.docs, required this.index, required this.book, required this.onBack});
  final List<StudyDoc> docs;
  final int index;
  final StudyBook? book;
  final VoidCallback onBack;

  @override
  State<StudyReaderScreen> createState() => _StudyReaderScreenState();
}

class _StudyReaderScreenState extends State<StudyReaderScreen> {
  late int _i = widget.index;
  late Future<List<Block>> _blocks;
  final _scroll = ScrollController();

  StudyDoc get _doc => widget.docs[_i];

  @override
  void initState() {
    super.initState();
    _open();
  }

  void _open() {
    _blocks = CommentaryRepository.instance.load(_doc);
    if (widget.book != null) StudyProgress.load().then((p) => p.setLast(_doc.key));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int i) {
    setState(() {
      _i = i;
      _open();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  bool get _isChapter => widget.book != null && RegExp(r'^[a-z0-9]+:\d+$').hasMatch(_doc.key);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(controller: _scroll, padding: _pad(context), children: [
      ScreenHeader(_doc.title, subtitle: widget.book?.name, onBack: widget.onBack),
      FutureBuilder<List<Block>>(
        future: _blocks,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(children: [
                Text('تعذّر تحميل التفسير، اتأكد من الاتصال بالنت.', textAlign: TextAlign.center, style: TextStyle(color: c.textSoft, fontSize: 15)),
                const SizedBox(height: 14),
                AppChip(label: 'حاول تاني', onTap: () => setState(_open)),
              ]),
            );
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final b in snap.data!) _BlockView(b),
            const SizedBox(height: 24),
            if (_isChapter) _DoneButton(docKey: _doc.key, onDone: _i + 1 < widget.docs.length ? () => _go(_i + 1) : null),
            Row(children: [
              if (_i > 0) Expanded(child: AppChip(label: '‹ السابق', onTap: () => _go(_i - 1))),
              if (_i > 0 && _i + 1 < widget.docs.length) const SizedBox(width: 10),
              if (_i + 1 < widget.docs.length) Expanded(child: AppChip(label: 'التالي ›', onTap: () => _go(_i + 1))),
            ]),
            const SizedBox(height: 12),
            Text('تفسير القمص أنطونيوس فكري — موقع الأنبا تكلا هيمانوت', style: TextStyle(fontSize: 11, color: c.textFaint)),
          ]);
        },
      ),
    ]);
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.docKey, required this.onDone});
  final String docKey;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FutureBuilder(
      future: StudyProgress.load(),
      builder: (context, snap) {
        final prog = snap.data;
        if (prog == null) return const SizedBox.shrink();
        return ListenableBuilder(
          listenable: prog,
          builder: (context, _) {
            final done = prog.isDone(docKey);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GlassPanel(
                onTap: () async {
                  await prog.toggle(docKey);
                },
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? c.accent : c.textFaint),
                  const SizedBox(width: 12),
                  Expanded(child: Text(done ? 'تمّت دراسته (المس لإلغاء العلامة)' : 'علّم الأصحاح إنه اتدرس', style: TextStyle(fontSize: 15, color: c.text))),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView(this.b);
  final Block b;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    switch (b.kind) {
      case BlockKind.h1:
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(b.text, style: context.heading(size: 22 * context.readingScale)));
      case BlockKind.h2:
        return Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(b.text, style: context.heading(size: 19 * context.readingScale, color: c.accent)),
        );
      case BlockKind.h3:
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(b.text, style: TextStyle(fontSize: 16 * context.readingScale, fontWeight: FontWeight.w600, color: c.text, height: 1.6)),
        );
      case BlockKind.verse:
        return Container(
          margin: const EdgeInsets.only(top: 14, bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: c.chip,
            borderRadius: BorderRadius.circular(10),
            border: Border(right: BorderSide(color: c.accent, width: 3)),
          ),
          child: Text(b.text, style: context.scripture(size: 18)),
        );
      case BlockKind.bullet:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 10, left: 10), child: Icon(Icons.circle, size: 6, color: c.accent)),
            Expanded(child: Text(b.text, style: TextStyle(fontSize: 16 * context.readingScale, height: 1.9, color: c.text))),
          ]),
        );
      case BlockKind.para:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(b.text, style: TextStyle(fontSize: 16 * context.readingScale, height: 1.9, color: c.text)),
        );
    }
  }
}

// ───────────────────────── المسابقات ─────────────────────────

class _QuizHome extends StatefulWidget {
  const _QuizHome({required this.cat, required this.bank, required this.qprog, required this.onOpenQuiz});
  final StudyCatalog cat;
  final QuizBank bank;
  final QuizProgress qprog;
  final void Function(String title, List<QuizQuestion> questions) onOpenQuiz;

  @override
  State<_QuizHome> createState() => _QuizHomeState();
}

class _QuizHomeState extends State<_QuizHome> {
  int _by = 0; // 0 موضوع، 1 سفر

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bank = widget.bank;
    return ListenableBuilder(
      listenable: widget.qprog,
      builder: (context, _) {
        final q = widget.qprog;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GlassPanel(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مسابقات الكتاب المقدس', style: context.heading(size: 20)),
              const SizedBox(height: 4),
              Text('للبابا شنوده الثالث — ${ar(bank.questions.length)} سؤال في ${ar(bank.topics.length)} موضوع',
                  style: TextStyle(fontSize: 12, color: c.textSoft)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: q.known / bank.questions.length, minHeight: 6, color: c.accent, backgroundColor: c.chip),
              ),
              const SizedBox(height: 8),
              Text('عرفت ${ar(q.known)} · للمراجعة ${ar(q.review)}', style: TextStyle(fontSize: 12, color: c.textFaint)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: AppChip(
                    label: 'جلسة سريعة (١٠ أسئلة)',
                    selected: true,
                    onTap: () => widget.onOpenQuiz('جلسة سريعة', bank.questions),
                  ),
                ),
                if (q.review > 0) ...[
                  const SizedBox(width: 8),
                  AppChip(
                    label: 'راجع (${ar(q.review)})',
                    onTap: () => widget.onOpenQuiz('مراجعة', bank.questions.where((x) => q.inReview(x.id)).toList()),
                  ),
                ],
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          AppSegmented(labels: const ['بحسب الموضوع', 'بحسب الأسفار'], selectedIndex: _by, onSelected: (i) => setState(() => _by = i)),
          const SizedBox(height: 8),
          if (_by == 0) ..._topics(context, bank, q) else ..._books(context, bank, q),
          const SizedBox(height: 16),
          Text('المصدر: ${bank.source}. الأسئلة اتجمّعت كما وردت، وبعض الأسفار ملهاش أسئلة في المصدر.',
              style: TextStyle(fontSize: 11, color: c.textFaint, height: 1.6)),
        ]);
      },
    );
  }

  List<Widget> _topics(BuildContext context, QuizBank bank, QuizProgress q) {
    final c = context.colors;
    return [
      for (final cat in bank.categories) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
          child: Text(cat.name, style: TextStyle(fontSize: 13, color: c.textFaint)),
        ),
        for (final t in bank.topics.where((t) => t.category == cat.id))
          _QuizRow(
            title: t.name,
            total: t.count,
            known: q.knownIn(bank.inTopic(t.index)),
            onTap: () => widget.onOpenQuiz(t.name, bank.inTopic(t.index)),
          ),
      ],
    ];
  }

  List<Widget> _books(BuildContext context, QuizBank bank, QuizProgress q) {
    final c = context.colors;
    final out = <Widget>[];
    for (final nt in [false, true]) {
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
        child: Text(nt ? 'العهد الجديد' : 'العهد القديم', style: TextStyle(fontSize: 13, color: c.textFaint)),
      ));
      for (final b in widget.cat.books.where((b) => b.newTestament == nt)) {
        final qs = bank.inBook(b.id);
        if (qs.isEmpty) continue;
        out.add(_QuizRow(title: b.name, total: qs.length, known: q.knownIn(qs), onTap: () => widget.onOpenQuiz('أسئلة ${b.name}', qs)));
      }
    }
    return out;
  }
}

class _QuizRow extends StatelessWidget {
  const _QuizRow({required this.title, required this.total, required this.known, required this.onTap});
  final String title;
  final int total, known;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.text)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: total == 0 ? 0 : known / total, minHeight: 3, color: c.accent, backgroundColor: c.chip),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Text('${ar(known)}/${ar(total)}', style: TextStyle(fontSize: 12, color: c.textFaint)),
          Icon(Icons.chevron_left, color: c.textFaint, size: 18),
        ]),
      ),
    );
  }
}

/// جلسة أسئلة: بطاقة سؤال، ثم تكشف الإجابة، وتقول عرفتها ولا لأ.
class QuizSessionScreen extends StatefulWidget {
  const QuizSessionScreen({super.key, required this.title, required this.questions, required this.onBack});
  final String title;
  final List<QuizQuestion> questions;
  final VoidCallback onBack;

  @override
  State<QuizSessionScreen> createState() => _QuizSessionScreenState();
}

class _QuizSessionScreenState extends State<QuizSessionScreen> {
  List<QuizQuestion>? _session;
  QuizProgress? _prog;
  int _i = 0;
  bool _shown = false;
  int _right = 0;
  final _wrong = <QuizQuestion>[];

  @override
  void initState() {
    super.initState();
    QuizProgress.load().then((p) {
      if (!mounted) return;
      setState(() {
        _prog = p;
        _session = buildSession(widget.questions, p);
      });
    });
  }

  void _answer(bool knew) {
    final q = _session![_i];
    _prog!.record(q.id, knew: knew);
    if (knew) {
      _right++;
    } else {
      _wrong.add(q);
    }
    setState(() {
      _i++;
      _shown = false;
    });
  }

  void _again(List<QuizQuestion> qs) => setState(() {
        _session = qs;
        _i = 0;
        _right = 0;
        _wrong.clear();
        _shown = false;
      });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = _session;
    if (s == null) return const Center(child: CircularProgressIndicator());
    final finished = _i >= s.length;
    return ListView(padding: _pad(context), children: [
      ScreenHeader(widget.title, subtitle: finished ? 'انتهت الجلسة' : 'سؤال ${ar(_i + 1)} من ${ar(s.length)}', onBack: widget.onBack),
      if (!finished) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(value: _i / s.length, minHeight: 5, color: c.accent, backgroundColor: c.chip),
        ),
        const SizedBox(height: 20),
        GlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s[_i].question, style: context.scripture(size: 20)),
            if (_shown) ...[
              Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Divider(color: c.hairline)),
              Text('الإجابة', style: TextStyle(fontSize: 12, color: c.accent)),
              const SizedBox(height: 4),
              Text(s[_i].answer, style: context.scripture(size: 18, color: c.textSoft)),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        if (!_shown)
          AppChip(label: 'اعرض الإجابة', selected: true, onTap: () => setState(() => _shown = true))
        else
          Row(children: [
            Expanded(child: AppChip(label: 'مش عارفها', onTap: () => _answer(false))),
            const SizedBox(width: 10),
            Expanded(child: AppChip(label: 'عرفتها', selected: true, onTap: () => _answer(true))),
          ]),
      ] else ...[
        const SizedBox(height: 8),
        GlassPanel(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Text('${ar(_right)} من ${ar(s.length)}', style: context.heading(size: 38)),
            const SizedBox(height: 4),
            Text(_right == s.length ? 'ما شاء الله! كلهم صح' : 'استمر، والمراجعة بتثبّت المعلومة', style: TextStyle(color: c.textSoft)),
          ]),
        ),
        const SizedBox(height: 16),
        if (_wrong.isNotEmpty) AppChip(label: 'راجع اللي ماعرفتهوش (${ar(_wrong.length)})', selected: true, onTap: () => _again([..._wrong])),
        const SizedBox(height: 10),
        AppChip(label: 'جلسة جديدة', onTap: () => _again(buildSession(widget.questions, _prog!))),
      ],
    ]);
  }
}
