import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/coptic.dart';
import '../../data/bible.dart';
import '../../data/store.dart';
import '../../data/study.dart';
import '../glass.dart';
import 'study.dart' show CommentaryBlockView;
import '../theme.dart';
import 'home.dart' show VerseActions;

/// ألوان تظليل الآيات: شفافة عشان تبان كويس في مخطوطة وسهرانية.
const highlightColors = [Color(0x55E0A64A), Color(0x4D6FA875), Color(0x4DC56E8E), Color(0x4D6E8EC5)];

/// تصفح الأسفار بالعهدين والبحث في نص الكتاب المقدس.
class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key, required this.onOpenChapter});
  final ValueChanged<VerseRef> onOpenChapter;

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  int _testament = 0;
  int _openBook = 0;
  String _query = '';
  List<SearchHit>? _results;
  bool _searching = false;
  bool _failed = false;
  Timer? _debounce;

  void _onQuery(String q) {
    _query = q;
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _results = null;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() {
        _searching = true;
        _failed = false;
      });
      try {
        final r = await BibleRepository.instance.search(q);
        if (mounted && q == _query) setState(() => _results = r);
      } catch (_) {
        if (mounted) setState(() => _failed = true);
      }
      if (mounted) setState(() => _searching = false);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final searching = _query.trim().length >= 2;
    final list = _testament == 0 ? books.take(39).toList() : books.skip(39).toList();

    return CustomScrollView(slivers: [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, 0),
        sliver: SliverList.list(children: [
          const ScreenHeader('الكتاب المقدس', subtitle: 'ترجمة فاندايك'),
          AppSearchBar(
            placeholder: 'ابحث في الكتاب المقدس',
            onChanged: _onQuery,
          ),
          const SizedBox(height: 14),
          if (!searching) ...[
            ListenableBuilder(
              listenable: BibleMarks.instance,
              builder: (context, _) {
                final last = BibleMarks.instance.lastRead;
                final marks = BibleMarks.instance.bookmarks;
                if (last == null && marks.isEmpty) return const SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (last != null)
                    GlassPanel(
                      radius: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      onTap: () => widget.onOpenChapter(last),
                      child: Row(children: [
                        Icon(Icons.menu_book_outlined, size: 20, color: c.textFaint),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('كمّل القراءة', style: TextStyle(fontSize: 12, color: c.textFaint)),
                            Text('${books[last.book - 1].name} ${ar(last.chapter)}',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
                          ]),
                        ),
                        Icon(Icons.chevron_left, color: c.textFaint),
                      ]),
                    ),
                  if (marks.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 8),
                      child: Text('العلامات المرجعية', style: TextStyle(fontSize: 13, color: c.textFaint)),
                    ),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final m in marks)
                        Material(
                          color: c.chip,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => widget.onOpenChapter(m),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Text('${books[m.book - 1].name} ${ar(m.chapter)}', style: TextStyle(fontSize: 13, color: c.text)),
                            ),
                          ),
                        ),
                    ]),
                  ],
                  const SizedBox(height: 16),
                ]);
              },
            ),
            AppSegmented(
              labels: const ['العهد القديم', 'العهد الجديد'],
              selectedIndex: _testament,
              onSelected: (i) => setState(() {
                _testament = i;
                _openBook = 0;
              }),
            ),
            const SizedBox(height: 12),
          ],
        ]),
      ),
      if (searching)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: _searching
              ? const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())))
              : _failed
                  ? SliverToBoxAdapter(
                      child: Text('تعذّر البحث، تأكد من الاتصال أو حمّل الكتاب كاملاً من «المزيد»', style: TextStyle(color: c.textSoft)))
                  : (_results?.isEmpty ?? true)
                      ? SliverToBoxAdapter(child: Text('لا توجد نتائج', style: TextStyle(color: c.textSoft)))
                      : SliverList.separated(
                          itemCount: _results!.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final hit = _results![i];
                            return GlassPanel(
                              radius: 22,
                              padding: const EdgeInsets.all(16),
                              onTap: () => widget.onOpenChapter(hit.ref),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(hit.ref.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
                                const SizedBox(height: 4),
                                Text(hit.text, style: context.scripture(size: 17)),
                              ]),
                            );
                          },
                        ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final b = list[i];
              final open = _openBook == b.number;
              return GlassPanel(
                radius: 22,
                padding: EdgeInsets.zero,
                child: Column(children: [
                  InkWell(
                    onTap: () => setState(() => _openBook = open ? 0 : b.number),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Row(children: [
                        Expanded(child: Text(b.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: c.text))),
                        Text('${ar(b.chapters)} إصحاح', style: TextStyle(fontSize: 12, color: c.textFaint)),
                      ]),
                    ),
                  ),
                  if (open)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        for (var ch = 1; ch <= b.chapters; ch++)
                          Material(
                            color: c.chip,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => widget.onOpenChapter(VerseRef(b.number, ch, 0)),
                              child: SizedBox(width: 44, height: 44, child: Center(child: Text(ar(ch), style: TextStyle(color: c.text)))),
                            ),
                          ),
                      ]),
                    ),
                ]),
              );
            },
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ]);
  }
}

/// الإصحاح كاملاً مع تمييز الآية المطلوبة (verse = 0 بدون تمييز) والتنقل بين الإصحاحات.
class ChapterScreen extends StatefulWidget {
  const ChapterScreen({super.key, required this.start, required this.onBack, this.onOpenCommentary, this.loadVerses});
  final VerseRef start;
  final VoidCallback onBack;

  /// فتح تفسير الأصحاح كاملاً (رقم السفر في الكتاب، والأصحاح).
  final void Function(int book, int chapter)? onOpenCommentary;

  /// مصدر آيات الأصحاح (للاختبار؛ الافتراضي قاعدة الكتاب).
  final Future<List<Verse>> Function(int book, int chapter)? loadVerses;

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  late int _book = widget.start.book;
  late int _chapter = widget.start.chapter;
  List<Verse>? _verses;
  bool _failed = false;
  int _selected = 0;
  final _keys = <int, GlobalKey>{};

  // تفسير القمص أنطونيوس فكري للآية المختارة (بيتحمّل أول مرة بس لكل أصحاح ويتحفظ)
  Map<int, VerseCommentary>? _comm;
  bool _commLoading = false;
  bool _commFailed = false;
  bool _commNone = false;
  int _commFor = 0;

  Future<void> _showCommentary(int verse) async {
    setState(() => _commFor = _commFor == verse ? 0 : verse);
    if (_commFor == 0 || _comm != null || _commNone || _commLoading) return;
    setState(() {
      _commLoading = true;
      _commFailed = false;
    });
    final book = _book, chapter = _chapter;
    try {
      final m = await CommentaryRepository.instance.forChapter(book, chapter);
      if (!mounted || book != _book || chapter != _chapter) return;
      setState(() {
        _comm = m;
        _commNone = m == null;
        _commLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _commFailed = true;
        _commLoading = false;
      });
    }
  }

  int get _highlight => _book == widget.start.book && _chapter == widget.start.chapter ? widget.start.verse : -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _verses = null;
      _failed = false;
      _selected = 0;
      _keys.clear();
      _comm = null;
      _commNone = false;
      _commFailed = false;
      _commLoading = false;
      _commFor = 0;
    });
    try {
      final v = await (widget.loadVerses ?? BibleRepository.instance.chapter)(_book, _chapter);
      if (!mounted) return;
      setState(() => _verses = v);
      // آخر موضع قراءة، عشان «كمّل القراءة» في شاشة الكتاب
      BibleMarks.instance.saveLast(_book, _chapter, _highlight > 0 ? _highlight : 1);
      if (_highlight > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _keys[_highlight]?.currentContext;
          if (ctx != null) Scrollable.ensureVisible(ctx, alignment: .2, duration: const Duration(milliseconds: 400));
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Widget _commentaryPanel(BuildContext context, int verse) {
    final c = context.colors;
    Widget note(String text, {Widget? action}) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text, style: TextStyle(fontSize: 13, height: 1.6, color: c.textSoft)),
            if (action != null) Padding(padding: const EdgeInsets.only(top: 8), child: action),
          ]),
        );
    if (_commLoading) return const Padding(padding: EdgeInsets.all(14), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    if (_commFailed) return note('تعذّر تحميل التفسير، اتأكد من الاتصال بالنت', action: AppChip(label: 'حاول تاني', onTap: () {
          setState(() => _commFor = 0);
          _showCommentary(verse);
        }));
    if (_commNone) return note('مفيش تفسير للسفر ده في تفاسير القمص أنطونيوس فكري.');
    final vc = _comm?[verse];
    final full = widget.onOpenCommentary == null ? null : AppChip(label: 'افتح تفسير الأصحاح كاملاً', onTap: () => widget.onOpenCommentary!(_book, _chapter));
    if (vc == null) return note('تفسير الأصحاح مش مقسّم على الآية دي.', action: full);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border(right: BorderSide(color: c.accent, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('تفسير القمص أنطونيوس فكري — ${vc.label}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent)),
        const SizedBox(height: 8),
        for (final b in vc.blocks) CommentaryBlockView(b),
        if (full != null) Align(alignment: AlignmentDirectional.centerStart, child: full),
      ]),
    );
  }

  void _move(int step) {
    final b = books[_book - 1];
    final next = _chapter + step;
    if (next >= 1 && next <= b.chapters) {
      _chapter = next;
    } else if (step > 0 && _book < books.length) {
      _book++;
      _chapter = 1;
    } else if (step < 0 && _book > 1) {
      _book--;
      _chapter = books[_book - 1].chapters;
    } else {
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final verses = _verses;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, MediaQuery.paddingOf(context).bottom + 8),
      child: Column(children: [
        ScreenHeader(
          books[_book - 1].name,
          subtitle: 'الإصحاح ${ar(_chapter)}',
          onBack: widget.onBack,
          trailing: ListenableBuilder(
            listenable: BibleMarks.instance,
            builder: (context, _) {
              final on = BibleMarks.instance.isBookmarked(_book, _chapter);
              return IconButton(
                icon: Icon(on ? Icons.bookmark : Icons.bookmark_border, color: on ? c.accent : c.text),
                tooltip: on ? 'إزالة العلامة' : 'علامة مرجعية',
                onPressed: () => BibleMarks.instance.toggleBookmark(_book, _chapter),
              );
            },
          ),
        ),
        Expanded(
          child: verses == null
              ? Center(
                  child: _failed
                      ? Text('تعذّر تحميل الإصحاح، تأكد من الاتصال بالإنترنت', style: TextStyle(color: c.textSoft))
                      : const CircularProgressIndicator())
              : ListenableBuilder(
                  listenable: BibleMarks.instance,
                  builder: (context, _) => SingleChildScrollView(
                    child: Column(children: [
                      for (final v in verses)
                        Builder(builder: (context) {
                          final ref = VerseRef(_book, _chapter, v.number);
                          final hi = BibleMarks.instance.highlightOf(ref);
                          final bg = v.number == _selected
                              ? c.chip
                              : hi != null
                                  ? highlightColors[hi % highlightColors.length]
                                  : v.number == _highlight
                                      ? c.chip
                                      : Colors.transparent;
                          return Container(
                            key: _keys.putIfAbsent(v.number, GlobalKey.new),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: bg),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => setState(() => _selected = _selected == v.number ? 0 : v.number),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    SizedBox(
                                      width: 30,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(ar(v.number), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
                                      ),
                                    ),
                                    Expanded(child: Text(v.text, style: context.scripture())),
                                  ]),
                                  if (v.number == _selected) ...[
                                    const SizedBox(height: 8),
                                    _VerseTools(ref: ref, text: v.text, current: hi),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: AlignmentDirectional.centerStart,
                                      child: AppChip(label: _commFor == v.number ? 'إخفاء التفسير' : 'تفسير الآية', selected: _commFor == v.number, onTap: () => _showCommentary(v.number)),
                                    ),
                                    if (_commFor == v.number) _commentaryPanel(context, v.number),
                                  ],
                                ]),
                              ),
                            ),
                          );
                        }),
                    ]),
                  ),
                ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          AppIconButton(icon: Icon(Icons.chevron_right, color: c.text), label: 'الإصحاح السابق', onTap: () => _move(-1)),
          AppIconButton(icon: Icon(Icons.chevron_left, color: c.text), label: 'الإصحاح التالي', onTap: () => _move(1)),
        ]),
      ]),
    );
  }
}

/// أدوات الآية المختارة: تظليل بالألوان، وحفظ ومشاركة ونسخ.
class _VerseTools extends StatelessWidget {
  const _VerseTools({required this.ref, required this.text, required this.current});
  final VerseRef ref;
  final String text;
  final int? current;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      for (var i = 0; i < highlightColors.length; i++)
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => BibleMarks.instance.setHighlight(ref, current == i ? null : i),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: highlightColors[i].withValues(alpha: 1),
                border: Border.all(color: current == i ? c.text : c.hairline, width: current == i ? 2 : 1),
              ),
              child: current == i ? Icon(Icons.check, size: 15, color: c.text) : null,
            ),
          ),
        ),
      const Spacer(),
      VerseActions(ref: ref, text: text, showCopy: true),
    ]);
  }
}
