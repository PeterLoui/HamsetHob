import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/coptic.dart';

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

class TasbehaLibrary {
  const TasbehaLibrary(this.source, this.books);
  final String source;
  final List<TasbehaBook> books;

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
