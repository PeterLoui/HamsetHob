import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/coptic.dart';
import 'net.dart';

class Passage {
  const Passage(this.book, this.ref, this.text);
  final String book;
  final String ref;
  final String text;
}

class Reading {
  const Reading({this.title, this.introduction, this.conclusion, this.passages = const [], this.story});
  final String? title;
  final String? introduction;
  final String? conclusion;
  final List<Passage> passages;
  final String? story;
}

class ReadingGroup {
  const ReadingGroup(this.title, this.introduction, this.readings);
  final String title;
  final String? introduction;
  final List<Reading> readings;

  bool get isSynaxarium => title.contains('السنكسار');
}

class ReadingSection {
  const ReadingSection(this.title, this.groups);
  final String title;
  final List<ReadingGroup> groups;
}

class SaintStory {
  const SaintStory(this.title, this.text);
  final String title;
  final String text;
}

class DayReadings {
  const DayReadings(this.sections);
  final List<ReadingSection> sections;

  /// سير السنكسار الكاملة لهذا اليوم.
  List<SaintStory> get synaxarium => [
        for (final g in sections.expand((s) => s.groups))
          if (g.isSynaxarium)
            for (final r in g.readings)
              if (r.story != null) SaintStory(r.title ?? 'سنكسار اليوم', r.story!)
      ];

  /// إنجيل القداس.
  Passage? get liturgyGospel {
    for (final s in sections) {
      if (!s.title.contains('قداس')) continue;
      final groups = s.groups.where((g) => g.title.contains('الإنجيل')).toList();
      if (groups.isEmpty) continue;
      final passages = groups.last.readings.expand((r) => r.passages).toList();
      if (passages.isNotEmpty) return passages.last;
    }
    return null;
  }
}

/// القطمارس اليومي والسنكسار الكامل من api.katameros.app.
class KatamerosRepository {
  KatamerosRepository._();
  static final instance = KatamerosRepository._();

  final _memory = <String, DayReadings>{};

  Future<DayReadings> day(DateTime date) async {
    final d = dateOnly(date);
    final key = d.toIso8601String().substring(0, 10);
    final cached = _memory[key];
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    var json = prefs.getString('katameros_$key');
    if (json == null) {
      String two(int n) => n.toString().padLeft(2, '0');
      json = await getText('https://api.katameros.app/readings/gregorian/${two(d.day)}-${two(d.month)}-${d.year}?languageId=3');
      await prefs.setString('katameros_$key', json);
    }
    return _memory[key] = _parse(jsonDecode(json) as Map<String, dynamic>);
  }

  static String? _opt(Map o, String k) {
    final v = o[k];
    return v is String && v.trim().isNotEmpty ? v.trim() : null;
  }

  static List<Map<String, dynamic>> _list(Object? v) =>
      v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];

  DayReadings _parse(Map<String, dynamic> root) => DayReadings([
        for (final s in _list(root['sections']))
          ReadingSection(s['title'] as String? ?? '', [
            for (final g in _list(s['subSections']))
              ReadingGroup(g['title'] as String? ?? '', _opt(g, 'introduction'), [
                for (final r in _list(g['readings']))
                  Reading(
                    title: _opt(r, 'title'),
                    introduction: _opt(r, 'introduction'),
                    conclusion: _opt(r, 'conclusion'),
                    passages: [
                      for (final p in _list(r['passages']))
                        Passage(
                          p['bookTranslation'] as String? ?? '',
                          p['ref'] as String? ?? '',
                          _list(p['verses']).map((v) => '(${ar(v['number'])}) ${(v['text'] as String? ?? '').trim()}').join(' '),
                        )
                    ],
                    story: _opt(r, 'html') == null ? null : stripHtml(_opt(r, 'html')!),
                  )
              ])
          ])
      ]);
}
