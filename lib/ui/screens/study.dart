import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/coptic.dart' show ar;
import '../../data/quiz.dart';
import '../../data/study.dart';
import '../glass.dart';
import '../study_path.dart';
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
    required this.onOpenMap,
  });
  final VoidCallback onOpenMap;
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
              _StudyHome(
                  cat: cat,
                  prog: prog,
                  bank: bank,
                  qprog: qprog,
                  onOpenBook: widget.onOpenBook,
                  onOpenDoc: widget.onOpenDoc,
                  onOpenGuide: widget.onOpenGuide,
                  onOpenQuiz: widget.onOpenQuiz,
                  onOpenMap: widget.onOpenMap)
            else
              _QuizHome(cat: cat, bank: bank, qprog: qprog, onOpenQuiz: widget.onOpenQuiz),
          ],
        );
      },
    );
  }
}

// ───────────────────────── الدراسة: الطريق ─────────────────────────

class _StudyHome extends StatefulWidget {
  const _StudyHome({
    required this.cat,
    required this.prog,
    required this.bank,
    required this.qprog,
    required this.onOpenBook,
    required this.onOpenDoc,
    required this.onOpenGuide,
    required this.onOpenQuiz,
    required this.onOpenMap,
  });
  final VoidCallback onOpenMap;
  final StudyCatalog cat;
  final StudyProgress prog;
  final QuizBank bank;
  final QuizProgress qprog;
  final ValueChanged<StudyBook> onOpenBook;
  final void Function(List<StudyDoc> docs, int index, StudyBook? book) onOpenDoc;
  final ValueChanged<StudyGuide> onOpenGuide;
  final void Function(String title, List<QuizQuestion> questions) onOpenQuiz;

  @override
  State<_StudyHome> createState() => _StudyHomeState();
}

class _StudyHomeState extends State<_StudyHome> {
  late final Set<String> _open = {_startGroup()};

  /// المرحلة اللي واقف فيها الدارس تتفتح، وإلا أول مرحلة.
  String _startGroup() {
    final key = widget.prog.last;
    final b = key == null ? null : widget.cat.byId(key.split(':').first);
    return b?.group ?? widget.cat.groups.first.id;
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
    return ListenableBuilder(
      listenable: Listenable.merge([widget.prog, widget.qprog]),
      builder: (context, _) {
        final done = widget.prog.totalDone;
        final lastKey = widget.prog.last;
        final lastBook = lastKey == null ? null : cat.byId(lastKey.split(':').first);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GlassPanel(
            padding: const EdgeInsets.all(16),
            onTap: lastBook == null ? null : _resume,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (lastBook != null) ...[
                Row(children: [
                  Icon(Icons.local_fire_department_outlined, color: c.honey, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('سراجك واقف عند', style: TextStyle(fontSize: 12, color: c.textFaint)),
                      Text(_labelOf(lastKey!, lastBook), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                    ]),
                  ),
                  Icon(Icons.chevron_left, color: c.textFaint),
                ]),
                const SizedBox(height: 12),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: done / cat.totalChapters, minHeight: 5, color: c.honey, backgroundColor: c.chip),
              ),
              const SizedBox(height: 6),
              Text('${ar(done)} من ${ar(cat.totalChapters)} أصحاح — الطريق بينوّر وراك كل ما تخلّص أصحاح', style: TextStyle(fontSize: 12, color: c.textFaint)),
            ]),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            padding: const EdgeInsets.all(14),
            onTap: widget.onOpenMap,
            child: Row(children: [
              Icon(Icons.map_outlined, color: c.honey, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('خريطة الكتاب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                  Text('رحلة إبراهيم والخروج ورحلات بولس، محطة محطة', style: TextStyle(fontSize: 12, color: c.textFaint)),
                ]),
              ),
              Icon(Icons.chevron_left, color: c.textFaint),
            ]),
          ),
          const SizedBox(height: 16),
          // قفز سريع لمرحلة
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cat.groups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final g = cat.groups[i];
                return AppChip(label: g.name, selected: _open.contains(g.id), onTap: () => setState(() => _open.contains(g.id) ? _open.remove(g.id) : _open.add(g.id)));
              },
            ),
          ),
          const SizedBox(height: 4),
          for (final g in cat.groups) _Era(group: g, home: widget, open: _open.contains(g.id), onToggle: () => setState(() => _open.contains(g.id) ? _open.remove(g.id) : _open.add(g.id))),
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
          const SizedBox(height: 16),
          Text('المصدر: تفاسير ومقدمات القمص أنطونيوس فكري، موقع الأنبا تكلا هيمانوت. بتتحمّل عند أول قراءة وتتحفظ على جهازك.',
              style: TextStyle(fontSize: 11, color: c.textFaint, height: 1.6)),
        ]);
      },
    );
  }
}

/// مرحلة على الطريق: عنوانها وتقدمها، ولما تتفتح بتظهر محطاتها (الأسفار) على طريق متعرّج.
class _Era extends StatelessWidget {
  const _Era({required this.group, required this.home, required this.open, required this.onToggle});
  final StudyGroup group;
  final _StudyHome home;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final books = home.cat.inGroup(group.id);
    final col = groupColor(group.id, c.isDark);
    final total = books.fold<int>(0, (a, b) => a + b.chapters);
    final done = books.fold<int>(0, (a, b) => a + home.prog.doneIn(b));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
          child: Row(children: [
            Container(width: 6, height: 40, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(group.name, style: context.heading(size: 21, color: col)),
                Text(eraSubtitles[group.id] ?? '', style: TextStyle(fontSize: 12, color: c.textFaint)),
              ]),
            ),
            Text('${ar(done)}/${ar(total)}', style: TextStyle(fontSize: 12, color: c.textFaint)),
            Icon(open ? Icons.expand_less : Icons.expand_more, color: c.textFaint),
          ]),
        ),
      ),
      if (open) _EraPath(group: group, books: books, home: home, color: col),
    ]);
  }
}

class _EraPath extends StatelessWidget {
  const _EraPath({required this.group, required this.books, required this.home, required this.color});
  final StudyGroup group;
  final List<StudyBook> books;
  final _StudyHome home;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final pts = pathPoints(w, books.length);
      var lit = -1;
      for (var i = 0; i < books.length; i++) {
        if (home.prog.doneIn(books[i]) > 0) lit = i;
      }
      return SizedBox(
        height: pathHeight(books.length),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: EraPathPainter(points: pts, lit: lit, honey: c.honey, dim: c.isDark ? const Color(0xFF3A342B) : const Color(0xFFD3C9B6)))),
          for (var i = 0; i < books.length; i++) _station(context, books[i], pts[i], w, i == lit),
        ]),
      );
    });
  }

  Widget _station(BuildContext context, StudyBook b, Offset p, double w, bool current) {
    final c = context.colors;
    final done = home.prog.doneIn(b);
    final f = done / b.chapters;
    final qs = home.bank.inBook(b.id);
    final starred = qs.isNotEmpty && home.qprog.knownIn(qs) >= math.min(3, qs.length);
    final onRight = p.dx > w / 2;
    final labelW = (onRight ? w - p.dx : p.dx) - 30;
    final label = SizedBox(
      width: labelW,
      child: Column(crossAxisAlignment: onRight ? CrossAxisAlignment.start : CrossAxisAlignment.end, children: [
        Text(b.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: done > 0 ? c.text : c.textSoft)),
        Text(done == 0 ? '${ar(b.chapters)} أصحاح' : (f >= 1 ? 'تمّ' : '${ar(done)} من ${ar(b.chapters)}'),
            style: TextStyle(fontSize: 11.5, color: c.textFaint)),
        // سؤال على الطريق: ٣ أسئلة عن السفر اللي بدأته
        if (done > 0 && qs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => home.onOpenQuiz('أسئلة على الطريق: ${b.name}', buildSession(qs, home.qprog, size: 3)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.hairline)),
                child: Text(starred ? '★ أسئلة' : '٣ أسئلة', style: TextStyle(fontSize: 11, color: c.honey, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
      ]),
    );
    const dotR = 15.0;
    final dot = StationDot(fraction: f, color: color, bg: c.isDark ? const Color(0xFF14120F) : const Color(0xFFF3EEE4), idle: c.hairline, starred: starred);
    return Positioned(
      left: onRight ? p.dx - dotR : null,
      right: onRight ? null : w - p.dx - dotR,
      top: p.dy - 28,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => home.onOpenBook(b),
        child: SizedBox(
          height: 70,
          child: Row(
            textDirection: onRight ? TextDirection.ltr : TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 13), child: dot),
              const SizedBox(width: 10),
              label,
            ],
          ),
        ),
      ),
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
            for (final b in snap.data!) CommentaryBlockView(b),
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

/// فقرة من التفسير: عنوان أو آية أو نقطة أو فقرة.
class CommentaryBlockView extends StatelessWidget {
  const CommentaryBlockView(this.b, {super.key});
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
