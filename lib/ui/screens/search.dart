import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/coptic.dart' show ar;
import '../../data/bible.dart';
import '../../data/prayers.dart';
import '../../data/quiz.dart';
import '../../data/search_all.dart';
import '../../data/sermons.dart';
import '../../data/study.dart';
import '../../data/tasbeha.dart';
import '../glass.dart';
import '../theme.dart';

/// وجهات النتايج: الشاشة بتبلّغ بالاختيار، والرئيسية هي اللي بتفتح الشاشة المناسبة.
class SearchActions {
  const SearchActions({
    required this.onVerse,
    required this.onPrayer,
    required this.onTasbeha,
    required this.onFeast,
    required this.onSermon,
    required this.onStudyBook,
    required this.onQuestion,
  });
  final ValueChanged<VerseRef> onVerse;
  final ValueChanged<Prayer> onPrayer;
  final void Function(TasbehaHit hit) onTasbeha;
  final ValueChanged<DateTime> onFeast;
  final ValueChanged<Sermon> onSermon;
  final ValueChanged<StudyBook> onStudyBook;
  final ValueChanged<QuizQuestion> onQuestion;
}

class _Row {
  const _Row(this.title, this.subtitle, this.onTap);
  final String title, subtitle;
  final VoidCallback onTap;
}

class _Section {
  _Section(this.name);
  final String name;
  List<_Row> rows = const [];
  bool loading = false;
  bool failed = false;
  bool expanded = false;
}

/// بحث واحد في التطبيق كله: الكتاب، والأجبية، والتسبحة، والسنكسار، والعظات، والدراسة، والمسابقات.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.onBack, required this.today, required this.actions, this.initialQuery = ''});
  final String initialQuery;
  final VoidCallback onBack;
  final DateTime today;
  final SearchActions actions;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery);

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().length >= 2) WidgetsBinding.instance.addPostFrameCallback((_) => _run(widget.initialQuery));
  }
  Timer? _debounce;
  int _gen = 0;
  String _q = '';

  final _sections = {
    for (final n in ['الكتاب المقدس', 'الأجبية', 'التسبحة', 'السنكسار والأعياد', 'العظات', 'الدراسة', 'المسابقات']) n: _Section(n),
  };

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(v));
  }

  Future<void> _run(String q) async {
    final gen = ++_gen;
    q = q.trim();
    setState(() {
      _q = q;
      for (final s in _sections.values) {
        s.rows = const [];
        s.failed = false;
        s.expanded = false;
        s.loading = q.length >= 2;
      }
    });
    if (q.length < 2) return;
    final a = widget.actions;

    void set(String name, List<_Row> rows, {bool failed = false}) {
      if (!mounted || gen != _gen) return;
      setState(() {
        final s = _sections[name]!;
        s.rows = rows;
        s.failed = failed;
        s.loading = false;
      });
    }

    Future<void> guard(String name, Future<List<_Row>> Function() f) async {
      try {
        set(name, await f());
      } catch (_) {
        set(name, const [], failed: true);
      }
    }

    await Future.wait([
      guard('الكتاب المقدس', () async => [
            for (final h in await BibleRepository.instance.search(q)) _Row(h.ref.label, h.text, () => a.onVerse(h.ref)),
          ]),
      guard('الأجبية', () async => [
            for (final h in LocalSearch.prayers(await AgpeyaRepository.instance.load(), q)) _Row(h.title, h.subtitle, () => a.onPrayer(h.item)),
          ]),
      guard('التسبحة', () async {
        final lib = await TasbehaRepository.instance.load();
        return [for (final h in lib.search(q, widget.today)) _Row(h.piece.title, h.snippet.isEmpty ? '${h.book.title} — ${h.day.name}' : h.snippet, () => a.onTasbeha(h))];
      }),
      guard('السنكسار والأعياد', () async => [
            for (final h in LocalSearch.feasts(widget.today, q)) _Row(h.title, h.subtitle, () => a.onFeast(h.item.date)),
          ]),
      guard('العظات', () async {
        final page = await SermonRepository.instance.page(0, q, 1);
        return [for (final s in page.items) _Row(s.title, s.summary, () => a.onSermon(s))];
      }),
      guard('الدراسة', () async {
        final cat = await StudyCatalog.load();
        return [for (final h in LocalSearch.studyBooks(cat, q)) _Row(h.title, h.subtitle, () => a.onStudyBook(h.item))];
      }),
      guard('المسابقات', () async {
        final bank = await QuizBank.load();
        return [for (final h in LocalSearch.questions(bank, q)) _Row(h.title, h.subtitle, () => a.onQuestion(h.item))];
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    final shown = _sections.values.where((s) => s.loading || s.rows.isNotEmpty || s.failed).toList();
    final total = _sections.values.fold<int>(0, (n, s) => n + s.rows.length);
    final anyLoading = _sections.values.any((s) => s.loading);
    return ListView(
      padding: EdgeInsets.fromLTRB(24, pad.top, 24, pad.bottom + 40),
      children: [
        ScreenHeader('بحث', subtitle: 'في الكتاب والصلوات والتسبحة والسنكسار والعظات والدراسة والمسابقات', onBack: widget.onBack),
        AppSearchBar(placeholder: 'اكتب كلمة أو اسم قديس أو لحن', controller: _controller, onChanged: _onChanged),
        const SizedBox(height: 14),
        if (_q.length < 2)
          Padding(padding: const EdgeInsets.only(top: 24), child: Center(child: Text('اكتب حرفين على الأقل', style: TextStyle(color: c.textFaint))))
        else if (!anyLoading && total == 0 && !_sections.values.any((s) => s.failed))
          Padding(padding: const EdgeInsets.only(top: 24), child: Center(child: Text('مفيش نتايج لـ«$_q»', style: TextStyle(color: c.textSoft))))
        else
          for (final s in shown) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              child: Row(children: [
                Text(s.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.accent)),
                const SizedBox(width: 8),
                if (s.loading)
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6))
                else if (!s.failed)
                  Text(ar(s.rows.length), style: TextStyle(fontSize: 12, color: c.textFaint)),
              ]),
            ),
            if (s.failed) Text('تعذّر البحث هنا، اتأكد من النت', style: TextStyle(fontSize: 12, color: c.textFaint)),
            for (final r in s.rows.take(s.expanded ? 40 : 3))
              InkWell(
                onTap: r.onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
                    if (r.subtitle.isNotEmpty)
                      Text(r.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1.5, color: c.textSoft)),
                  ]),
                ),
              ),
            if (!s.expanded && s.rows.length > 3)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(onPressed: () => setState(() => s.expanded = true), child: Text('عرض ${ar(s.rows.length - 3)} كمان', style: TextStyle(color: c.textSoft))),
              ),
          ],
      ],
    );
  }
}
