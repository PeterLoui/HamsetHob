import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

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
}

class TasbehaBook {
  const TasbehaBook(this.title, this.source, this.days);
  final String title;
  final String source;
  final List<TasbehaDay> days;
}

/// تسبحة كيهك من assets/tasbeha_kiahk.json، فبتتقري من غير نت.
/// الترتيب على ترتيب تسبحة نصف الليل، والنص من الإبصلمودية على st-takla.org.
class TasbehaRepository {
  TasbehaRepository._();
  static final instance = TasbehaRepository._();

  Future<TasbehaBook>? _kiahk;

  Future<TasbehaBook> kiahk() => _kiahk ??= _load('assets/tasbeha_kiahk.json');

  static Future<TasbehaBook> _load(String path) async {
    final root = jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>;
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
    return TasbehaBook(root['title'] as String, root['source'] as String, [
      for (final d in root['days'] as List)
        TasbehaDay(d['id'] as String, d['name'] as String, d['sub'] as String, [
          for (final s in d['sections'] as List)
            TasbehaSection(s['title'] as String, [for (final id in s['pieces'] as List) pieces['$id']!]),
        ]),
    ]);
  }
}
