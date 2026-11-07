import 'package:shared_preferences/shared_preferences.dart';

import 'net.dart';

/// تأمل من قائمة «تأملات روحية» في موقع المسيح أولاً.
class Meditation {
  const Meditation(this.title, this.url);
  final String title;
  final String url;
}

/// فقرة من التأمل. [verse] = آية أو اقتباس (الفقرة كلها بخط مميز في الموقع).
class MeditationBlock {
  const MeditationBlock(this.text, {this.verse = false});
  final String text;
  final bool verse;
}

class MeditationArticle {
  const MeditationArticle(this.title, this.blocks);
  final String title;
  final List<MeditationBlock> blocks;
}

/// تأملات روحية من almaseehawalan.com: القائمة، وتأمل لكل يوم، والمقالة كاملة.
class MeditationRepository {
  MeditationRepository._();
  static final instance = MeditationRepository._();

  static const source = 'almaseehawalan.com';
  static final _base = Uri.parse('https://almaseehawalan.com/');

  List<Meditation>? _list;
  final _articles = <String, MeditationArticle>{};

  /// كل التأملات بترتيب الموقع. آخر نسخة بتتحفظ عشان تشتغل من غير نت.
  Future<List<Meditation>> all() async {
    final cached = _list;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    String html;
    try {
      html = await getText(_base.resolve('meditations.html').toString());
      await prefs.setString('meditations_html', html);
    } catch (_) {
      final saved = prefs.getString('meditations_html');
      if (saved == null) rethrow;
      html = saved;
    }
    final items = parseList(html);
    if (items.isEmpty) throw const FormatException('لا توجد تأملات');
    return _list = items;
  }

  /// تأمل اليوم: نفس التأمل طول اليوم، والتالي في اليوم اللي بعده.
  Future<Meditation> forDay(DateTime date) async {
    final items = await all();
    final day = DateTime.utc(date.year, date.month, date.day).difference(DateTime.utc(2020)).inDays;
    return items[day % items.length];
  }

  Future<MeditationArticle> article(Meditation m) async {
    final cached = _articles[m.url];
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final key = 'meditation_${m.url}';
    String html;
    try {
      html = await getText(m.url);
      await prefs.setString(key, html);
    } catch (_) {
      final saved = prefs.getString(key);
      if (saved == null) rethrow;
      html = saved;
    }
    return _articles[m.url] = parseArticle(html, m.title);
  }

  static String _clean(String html) => stripHtml(html).replaceAll(' ', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// العنوان إما <h3> أو فقرة في النص (align="center")، وبعده رابط «إقرأ المزيد».
  static List<Meditation> parseList(String html) {
    final out = <Meditation>[];
    final seen = <String>{};
    String? title;
    final token = RegExp(r'<(h3|p)([^>]*)>([\s\S]*?)</\1>|href="(files/meditations/[^"]+)"', caseSensitive: false);
    final inner = RegExp(r'href="(files/meditations/[^"]+)"', caseSensitive: false);
    for (final m in token.allMatches(html)) {
      final link = m.group(4) ?? inner.firstMatch(m.group(3) ?? '')?.group(1);
      if (link != null) {
        final url = _base.resolve(link.replaceAll(' ', '%20')).toString();
        if (title != null && seen.add(url)) out.add(Meditation(title, url));
        title = null;
        continue;
      }
      final isTitle = m.group(1)!.toLowerCase() == 'h3' || m.group(2)!.contains('align="center"');
      if (isTitle) {
        final t = _clean(m.group(3)!);
        if (t.isNotEmpty) title = t;
      }
    }
    return out;
  }

  /// المقالة: العنوان في <h2> والنص في فقرات <p> بين المحتوى والفوتر.
  static MeditationArticle parseArticle(String html, String fallbackTitle) {
    final s = html.indexOf('templatemo_content');
    final start = s < 0 ? 0 : s;
    final e = html.indexOf('templatemo_footer', start);
    final body = html.substring(start, e < 0 ? html.length : e);
    final h2 = RegExp(r'<h2[^>]*>([\s\S]*?)</h2>', caseSensitive: false).firstMatch(body);
    final title = h2 == null ? fallbackTitle : _clean(h2.group(1)!);
    final edAttr = RegExp(r'class="[^"]*\bed\b');
    final edSpan = RegExp(r'<span[^>]*class="ed"[^>]*>([\s\S]*?)</span>', caseSensitive: false);
    final blocks = <MeditationBlock>[];
    for (final p in RegExp(r'<p([^>]*)>([\s\S]*?)</p>', caseSensitive: false).allMatches(body)) {
      final text = _clean(p.group(2)!);
      if (text.isEmpty || text == '.') continue;
      final ed = edSpan.allMatches(p.group(2)!).map((s) => _clean(s.group(1)!)).join();
      final verse = edAttr.hasMatch(p.group(1)!) || ed.length >= text.length * .9;
      blocks.add(MeditationBlock(text, verse: verse));
    }
    return MeditationArticle(title.isEmpty ? fallbackTitle : title, blocks);
  }
}
