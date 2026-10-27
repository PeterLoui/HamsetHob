import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/coptic.dart';
import '../../data/bible.dart';
import '../glass.dart';
import '../theme.dart';
import 'home.dart' show VerseActions;

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
          GlassSearchBar(
            placeholder: 'ابحث في الكتاب المقدس… (مثال: المحبة)',
            onChanged: _onQuery,
            height: 48,
            textStyle: TextStyle(color: c.text, fontSize: 15),
            placeholderStyle: TextStyle(color: c.textFaint, fontSize: 15),
          ),
          const SizedBox(height: 14),
          if (!searching) ...[
            GlassSegmentedControl(
              segments: const [GlassSegment(label: 'العهد القديم'), GlassSegment(label: 'العهد الجديد')],
              selectedIndex: _testament,
              onSegmentSelected: (i) => setState(() {
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
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
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
  const ChapterScreen({super.key, required this.start, required this.onBack});
  final VerseRef start;
  final VoidCallback onBack;

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
    });
    try {
      final v = await BibleRepository.instance.chapter(_book, _chapter);
      if (!mounted) return;
      setState(() => _verses = v);
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
        ScreenHeader(books[_book - 1].name, subtitle: 'الإصحاح ${ar(_chapter)}', onBack: widget.onBack),
        Expanded(
          child: verses == null
              ? Center(
                  child: _failed
                      ? Text('تعذّر تحميل الإصحاح، تأكد من الاتصال بالإنترنت', style: TextStyle(color: c.textSoft))
                      : const CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(children: [
                    for (final v in verses)
                      Container(
                        key: _keys.putIfAbsent(v.number, GlobalKey.new),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: v.number == _selected
                              ? c.chip
                              : v.number == _highlight
                                  ? c.accent.withValues(alpha: .2)
                                  : Colors.transparent,
                        ),
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
                              if (v.number == _selected)
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: VerseActions(ref: VerseRef(_book, _chapter, v.number), text: v.text, showCopy: true),
                                  ),
                                ),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GlassButton(icon: Icon(Icons.chevron_right, color: c.text), label: 'الإصحاح السابق', onTap: () => _move(-1), width: 64, height: 48, shape: const LiquidRoundedSuperellipse(borderRadius: 24), useOwnLayer: true, settings: glassSettings),
          GlassButton(icon: Icon(Icons.chevron_left, color: c.text), label: 'الإصحاح التالي', onTap: () => _move(1), width: 64, height: 48, shape: const LiquidRoundedSuperellipse(borderRadius: 24), useOwnLayer: true, settings: glassSettings),
        ]),
      ]),
    );
  }
}
