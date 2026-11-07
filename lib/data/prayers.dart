import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// جزء من صلاة: عنوان (ممكن يكون فاضي) ونص.
class PrayerSection {
  const PrayerSection(this.title, this.text);
  final String title;
  final String text;
}

class Prayer {
  const Prayer(this.id, this.title, this.subtitle, this.sections);
  final String id;
  final String title;
  final String? subtitle;
  final List<PrayerSection> sections;
}

class Agpeya {
  const Agpeya(this.hours, this.others);

  /// صلوات السواعي، كل ساعة لوحدها.
  final List<Prayer> hours;

  /// صلوات أخرى: قبل التناول وبعده، المشورة، الاعتراف…
  final List<Prayer> others;
}

/// الأجبية من assets/agpeya.json.
/// النص من مشروع abanoubha/agpeya (رخصة MIT، انظر assets/agpeya_LICENSE.txt).
class AgpeyaRepository {
  AgpeyaRepository._();
  static final instance = AgpeyaRepository._();

  Agpeya? _agpeya;

  Future<Agpeya> load() async {
    final cached = _agpeya;
    if (cached != null) return cached;
    final root = jsonDecode(await rootBundle.loadString('assets/agpeya.json')) as Map<String, dynamic>;
    List<Prayer> list(String key) => [
          for (final p in (root[key] as List).cast<Map<String, dynamic>>())
            Prayer(
              p['id'] as String,
              p['title'] as String,
              p['subtitle'] as String?,
              [for (final s in (p['sections'] as List).cast<Map<String, dynamic>>()) PrayerSection(s['t'] as String, s['x'] as String)],
            ),
        ];
    return _agpeya = Agpeya(list('hours'), list('others'));
  }
}

/// قداس من الخولاجي المقدس.
class Liturgy {
  const Liturgy(this.id, this.title, this.subtitle, this.indexPath);
  final String id;
  final String title;
  final String subtitle;
  final String indexPath;
}

const liturgies = [
  Liturgy('basil', 'القداس الباسيلي', 'للقديس باسيليوس الكبير', 'Arab-Copts-Mass-Book-002-index-El-Kodas-El-Basily.html'),
  Liturgy('gregory', 'القداس الغريغوري', 'للقديس غريغوريوس الناطق بالإلهيات', 'Arab-Copts-Mass-Book-003-index-Al-Koddas-Al-Ghreghory.html'),
  Liturgy('cyril', 'القداس الكيرلسي', 'للقديس مرقس الرسول (القداس الكيرلسي)', 'Arab-Copts-Mass-Book-004-index-ElKodas-El-Kirollosy.html'),
];

/// جزء من القداس في الفهرس.
class LiturgyPart {
  const LiturgyPart(this.title, this.url);
  final String title;
  final String url;
}

/// فقرة من القداس. [rubric] = إرشاد طقسي (ما يفعله أو يقوله الكاهن أو الشماس أو الشعب).
class LiturgyBlock {
  const LiturgyBlock(this.text, {this.rubric = false});
  final String text;
  final bool rubric;
}

/// الخولاجي من st-takla.org: فهرس كل قداس، وكل جزء في صفحة.
/// الصفحات بترميز windows-1256، وكل صفحة اتفتحت بتتحفظ عشان تشتغل من غير نت.
class LiturgyRepository {
  LiturgyRepository._();
  static final instance = LiturgyRepository._();

  static final _base = Uri.parse(
      'https://st-takla.org/Lyrics-Spiritual-Songs/Words-of-Coptic-Alhan-Tasbeha-Kodas/Arabic-Coptic-Liturgy-Lyrics/');

  final _indexes = <String, List<LiturgyPart>>{};
  final _parts = <String, List<LiturgyBlock>>{};

  Future<String> _page(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'takla_$url';
    try {
      final r = await http.get(Uri.parse(url), headers: const {'User-Agent': 'HamsetHob/2.0 (Android)'}).timeout(const Duration(seconds: 25));
      if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}');
      final html = decodeWindows1256(r.bodyBytes);
      await prefs.setString(key, html);
      return html;
    } catch (_) {
      final saved = prefs.getString(key);
      if (saved == null) rethrow;
      return saved;
    }
  }

  Future<List<LiturgyPart>> parts(Liturgy l) async {
    final cached = _indexes[l.id];
    if (cached != null) return cached;
    final html = await _page(_base.resolve(l.indexPath).toString());
    final out = <LiturgyPart>[];
    final seen = <String>{};
    for (final m in RegExp(r'<a\b[^>]*href="([^"#:]+\.html)"[^>]*>([\s\S]*?)</a>', caseSensitive: false).allMatches(html)) {
      final href = m.group(1)!;
      final title = _clean(m.group(2)!);
      if (!href.contains('/') || href.startsWith('/') || href.startsWith('..') || href.toLowerCase().contains('index') || title.isEmpty) continue;
      if (!seen.add(href)) continue;
      out.add(LiturgyPart(title, _base.resolve(href).toString()));
    }
    if (out.isEmpty) throw const FormatException('فهرس فاضي');
    return _indexes[l.id] = out;
  }

  Future<List<LiturgyBlock>> part(LiturgyPart p) async {
    final cached = _parts[p.url];
    if (cached != null) return cached;
    return _parts[p.url] = parsePart(await _page(p.url));
  }

  static final _latin = RegExp(r'[A-Za-z]');
  static final _arabic = RegExp(r'[؀-ۿ]');

  /// النص بين عنوان الصفحة (<h1>) وروابط الموقع اللي في الآخر.
  static List<LiturgyBlock> parsePart(String html) {
    var body = html;
    final start = body.indexOf('<div id="bodytext"');
    if (start >= 0) body = body.substring(start);
    final h1 = RegExp(r'</h1>', caseSensitive: false).firstMatch(body);
    if (h1 != null) body = body.substring(h1.end);
    final stop = body.indexOf('الكتاب المقدس (+ بحث');
    if (stop > 0) body = body.substring(0, stop);

    final blocks = <LiturgyBlock>[];
    for (final m in RegExp(r'<p\b[^>]*>([\s\S]*?)</p>', caseSensitive: false).allMatches(body)) {
      final inner = m.group(1)!;
      final text = _clean(inner);
      if (text.isEmpty) continue;
      // سطور الموقع: تقصير الرابط، انظر أيضاً، والترجمة الإنجليزية
      if (text.contains('tak.la') || text.contains('تقصير الرابط') || text.startsWith('*')) continue;
      final latin = _latin.allMatches(text).length, arabic = _arabic.allMatches(text).length;
      if (arabic == 0 || latin > arabic) continue;
      final bold = RegExp(r'^\s*<b\b', caseSensitive: false).hasMatch(inner);
      final rubric = bold || (!text.startsWith('(') && text.length < 180 && text.endsWith(':'));
      blocks.add(LiturgyBlock(text, rubric: rubric));
    }
    return blocks;
  }

  static String _clean(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
      .replaceAll(' ', ' ')
      .replaceAll(RegExp(r'[ \t\r\n]+'), ' ')
      .trim();
}

/// فك ترميز windows-1256 (العربي القديم): البايتات تحت 0x80 زي ASCII، واللي فوقها من الجدول.
String decodeWindows1256(List<int> bytes) {
  final b = StringBuffer();
  for (final x in bytes) {
    b.writeCharCode(x < 0x80 ? x : _cp1256[x - 0x80]);
  }
  return b.toString();
}

const _cp1256 = <int>[
  0x20AC, 0x067E, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
  0x02C6, 0x2030, 0x0679, 0x2039, 0x0152, 0x0686, 0x0698, 0x0688,
  0x06AF, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
  0x06A9, 0x2122, 0x0691, 0x203A, 0x0153, 0x200C, 0x200D, 0x06BA,
  0x00A0, 0x060C, 0x00A2, 0x00A3, 0x00A4, 0x00A5, 0x00A6, 0x00A7,
  0x00A8, 0x00A9, 0x06BE, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x00AF,
  0x00B0, 0x00B1, 0x00B2, 0x00B3, 0x00B4, 0x00B5, 0x00B6, 0x00B7,
  0x00B8, 0x00B9, 0x061B, 0x00BB, 0x00BC, 0x00BD, 0x00BE, 0x061F,
  0x06C1, 0x0621, 0x0622, 0x0623, 0x0624, 0x0625, 0x0626, 0x0627,
  0x0628, 0x0629, 0x062A, 0x062B, 0x062C, 0x062D, 0x062E, 0x062F,
  0x0630, 0x0631, 0x0632, 0x0633, 0x0634, 0x0635, 0x0636, 0x00D7,
  0x0637, 0x0638, 0x0639, 0x063A, 0x0640, 0x0641, 0x0642, 0x0643,
  0x00E0, 0x0644, 0x00E2, 0x0645, 0x0646, 0x0647, 0x0648, 0x00E7,
  0x00E8, 0x00E9, 0x00EA, 0x00EB, 0x0649, 0x064A, 0x00EE, 0x00EF,
  0x064B, 0x064C, 0x064D, 0x064E, 0x00F4, 0x064F, 0x0650, 0x00F7,
  0x0651, 0x00F9, 0x0652, 0x00FB, 0x00FC, 0x200E, 0x200F, 0x06D2,
];

/// محطات الإذاعات المسيحية (بث مباشر).
class Station {
  const Station(this.id, this.name, this.url);
  final String id;
  final String name;
  final String url;
}

const stations = [
  Station('noor514', 'راديو نور العالم 5.14', 'http://45.80.149.67:8000/radio514'),
];
