import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/coptic.dart';
import 'net.dart' show normalizeArabic;

/// سطر من التسبحة: النص العربي، والقبطي مكتوب بحروف عربية لو موجود. أو ملاحظة طقسية (rubric).
class TasbehaLine {
  const TasbehaLine({required this.arabic, this.coptic, this.rubric = false});
  final String arabic;
  final String? coptic;
  final bool rubric;
}

class TasbehaPiece {
  const TasbehaPiece(this.id, this.title, this.lines);
  final String id;
  final String title;
  final List<TasbehaLine> lines;
}

class TasbehaSection {
  const TasbehaSection(this.title, this.pieces);
  final String title;
  final List<TasbehaPiece> pieces;
}

class TasbehaDay {
  const TasbehaDay(this.id, this.name, this.subtitle, this.sections);
  final String id;
  final String name;
  final String subtitle;
  final List<TasbehaSection> sections;

  /// كل القطع بالترتيب، للقراءة صفحة صفحة.
  List<TasbehaPiece> get pieces => [for (final s in sections) ...s.pieces];

  /// عنوان القسم اللي فيه القطعة رقم [i].
  String sectionOf(int i) {
    var n = 0;
    for (final s in sections) {
      n += s.pieces.length;
      if (i < n) return s.title;
    }
    return '';
  }
}

/// التسبحة السنوية أو الكيهكية: أيام، كل يوم بترتيبه.
class TasbehaBook {
  const TasbehaBook(this.id, this.title, this.subtitle, this.days);
  final String id;
  final String title;
  final String subtitle;
  final List<TasbehaDay> days;

  TasbehaDay? day(String id) {
    for (final d in days) {
      if (d.id == id) return d;
    }
    return null;
  }
}

/// نتيجة بحث: لحن في يوم معيّن، وسطر من نصه فيه الكلمة.
class TasbehaHit {
  const TasbehaHit(this.book, this.day, this.index, this.piece, this.snippet);
  final TasbehaBook book;
  final TasbehaDay day;
  final int index;
  final TasbehaPiece piece;
  final String snippet;
}

class TasbehaLibrary {
  TasbehaLibrary(this.source, this.books);
  final String source;
  final List<TasbehaBook> books;

  /// نص كل لحن متوحّد للبحث (من غير تشكيل، والألف والياء والتاء المربوطة موحّدين)، بيتعمل أول مرة بس.
  late final Map<String, (String, List<String>)> _index = {
    for (final b in books)
      for (final d in b.days)
        for (final p in d.pieces)
          p.id: (
            normalizeArabic(p.title),
            [for (final l in p.lines) normalizeArabic('${l.arabic} ${l.coptic ?? ''}')],
          ),
  };

  /// بحث عن لحن أو كلمة في العناوين والنصوص (العربي والقبطي المعرّب). كل الكلمات لازم تكون موجودة.
  /// اللحن بيظهر مرة واحدة في كل تسبحة، في يوم الليلة لو موجود فيه، وإلا في أول يوم بيتقال فيه.
  List<TasbehaHit> search(String query, DateTime now, {int limit = 60}) {
    final words = normalizeArabic(query).split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    if (words.isEmpty) return const [];
    final inTitle = <TasbehaHit>[], inText = <TasbehaHit>[];
    for (final b in books) {
      final seen = <String>{};
      final today = b.days.length > now.weekday % 7 ? b.days[now.weekday % 7] : null;
      final order = [if (today != null) today, ...b.days.where((d) => !identical(d, today))];
      for (final d in order) {
        final pieces = d.pieces;
        for (var i = 0; i < pieces.length; i++) {
          final p = pieces[i];
          if (!seen.add(p.id)) continue;
          final (title, lines) = _index[p.id]!;
          final all = '$title ${lines.join(' ')}';
          if (!words.every(all.contains)) {
            seen.remove(p.id);
            continue;
          }
          if (words.every(title.contains)) {
            inTitle.add(TasbehaHit(b, d, i, p, ''));
          } else {
            final at = lines.indexWhere((l) => l.contains(words.first));
            final line = at < 0 ? p.lines.first : p.lines[at];
            // السطر اللي فيه الكلمة: العربي لو هي فيه، وإلا القبطي المعرّب
            final inArabic = normalizeArabic(line.arabic).contains(words.first);
            inText.add(TasbehaHit(b, d, i, p, inArabic ? line.arabic : (line.coptic ?? line.arabic)));
          }
        }
      }
    }
    return [...inTitle, ...inText].take(limit).toList();
  }

  TasbehaBook? book(String id) {
    for (final b in books) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// تسبحة الليلة: الكيهكية في شهر كيهك، والسنوية باقي السنة، ويوم الأسبوع النهارده.
  (TasbehaBook, TasbehaDay) tonight(DateTime now) {
    final kiahk = CopticDate.fromGregorian(now).month == 4;
    final b = book(kiahk ? 'kiahk' : 'annual') ?? books.first;
    return (b, b.days[now.weekday % 7]); // الأحد = ٠
  }
}

/// مكان القراءة الأخير، عشان «كمّل من حيث وقفت».
class TasbehaPosition {
  const TasbehaPosition(this.book, this.day, this.index);
  final TasbehaBook book;
  final TasbehaDay day;
  final int index;
}

/// التسبحة من assets/tasbeha.json، فبتتقري من غير نت.
/// الترتيب على ترتيب تسبحة نصف الليل، والنص من الإبصلمودية على st-takla.org.
class TasbehaRepository {
  TasbehaRepository._();
  static final instance = TasbehaRepository._();
  static const _lastKey = 'tasbeha_last';

  Future<TasbehaLibrary>? _library;

  Future<TasbehaLibrary> load() => _library ??= _load();

  static Future<TasbehaLibrary> _load() async {
    final root = jsonDecode(await rootBundle.loadString('assets/tasbeha.json')) as Map<String, dynamic>;
    final raw = root['pieces'] as Map<String, dynamic>;
    final pieces = <String, TasbehaPiece>{};
    raw.forEach((id, v) {
      final m = v as Map<String, dynamic>;
      pieces[id] = TasbehaPiece(id, m['t'] as String, [
        for (final b in m['b'] as List)
          if ((b as Map).containsKey('r'))
            TasbehaLine(arabic: b['r'] as String, rubric: true)
          else
            TasbehaLine(arabic: b['a'] as String, coptic: b['c'] as String?),
      ]);
    });
    return TasbehaLibrary(root['source'] as String, [
      for (final bk in root['books'] as List)
        TasbehaBook(bk['id'] as String, bk['title'] as String, bk['sub'] as String, [
          for (final d in bk['days'] as List)
            TasbehaDay(d['id'] as String, d['name'] as String, d['sub'] as String, [
              for (final s in d['sections'] as List)
                TasbehaSection(s['title'] as String, [for (final id in s['pieces'] as List) pieces['$id']!]),
            ]),
        ]),
    ]);
  }

  Future<void> saveLast(TasbehaBook book, TasbehaDay day, int index) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_lastKey, '${book.id}|${day.id}|$index');
  }

  Future<TasbehaPosition?> last() async {
    final p = await SharedPreferences.getInstance();
    final parts = (p.getString(_lastKey) ?? '').split('|');
    if (parts.length != 3) return null;
    final lib = await load();
    final b = lib.book(parts[0]);
    final d = b?.day(parts[1]);
    final i = int.tryParse(parts[2]);
    if (b == null || d == null || i == null || i < 0 || i >= d.pieces.length) return null;
    return TasbehaPosition(b, d, i);
  }
}
