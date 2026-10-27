import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'net.dart';

class Sermon {
  const Sermon(this.id, this.title, this.summary, this.link, this.categoryId);
  final int id;
  final String title;
  final String summary;
  final String link;
  final int categoryId;
}

class SermonCategory {
  const SermonCategory(this.id, this.name);
  final int id;
  final String name;
}

/// أقسام مكتبة العظات الصوتية في الموقع الرسمي لقداسة البابا شنوده الثالث.
const sermonCategories = [
  SermonCategory(0, 'الكل'),
  SermonCategory(62, 'اللاهوت الروحي'),
  SermonCategory(112, 'الكتاب المقدس'),
  SermonCategory(148, 'أعياد ومناسبات'),
  SermonCategory(186, 'سير القديسين'),
  SermonCategory(166, 'اللاهوت الرعوي'),
  SermonCategory(140, 'اللاهوت المقارن'),
  SermonCategory(63, 'اللاهوت الأدبي'),
  SermonCategory(123, 'اللاهوت العقيدي'),
  SermonCategory(82, 'تاريخ الكنيسة'),
  SermonCategory(192, 'قصائد وأشعار وترانيم'),
  SermonCategory(160, 'قانون الكنيسة'),
  SermonCategory(153, 'اللاهوت الطقسي'),
  SermonCategory(185, 'الإسخاتولوجي'),
  SermonCategory(194, 'الباترولوجي'),
  SermonCategory(173, 'اللاهوت النظري'),
  SermonCategory(177, 'اللاهوت النسكي'),
  SermonCategory(24310, 'اللقاءات والندوات'),
  SermonCategory(193, 'متفرقات'),
];

String categoryName(int id) =>
    sermonCategories.firstWhere((c) => c.id == id, orElse: () => const SermonCategory(0, 'عظات')).name;

class SermonPage {
  const SermonPage(this.items, this.totalPages);
  final List<Sermon> items;
  final int totalPages;
}

/// مكتبة العظات عبر واجهة WordPress للموقع (وسم «قسم الصوتيات» رقم 212)،
/// ورابط الملف الصوتي يُستخرج من صفحة العظة.
class SermonRepository {
  SermonRepository._();
  static final instance = SermonRepository._();

  static const _api = 'https://popeshenouda.org.eg/wp-json/wp/v2';
  static const _tag = 212;
  static const artwork = 'https://popeshenouda.org.eg/wp-content/uploads/2025/10/popeshenoda-podcast-1170x935.webp';
  static const _fields = '_fields=id,title,excerpt,link,categories';

  final _counts = <int, int>{};

  String _base(int category) => '$_api/posts?tags=$_tag&$_fields${category != 0 ? '&categories=$category' : ''}';

  Future<SermonPage> page(int category, String query, int page) async {
    var url = '${_base(category)}&per_page=20&page=$page';
    if (query.trim().isNotEmpty) url += '&search=${Uri.encodeQueryComponent(query.trim())}';
    final r = await getRaw(url);
    // الصفحة بعد الأخيرة تُرجع 400 من WordPress
    if (r.statusCode == 400) return SermonPage(const [], page - 1);
    if (r.statusCode >= 400) throw HttpStatusError(r.statusCode);
    final total = int.tryParse(r.headers['x-wp-totalpages'] ?? '') ?? 1;
    final list = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return SermonPage([for (final o in list) _parse(o as Map<String, dynamic>)], total);
  }

  /// عظة عشوائية (للبث المتواصل).
  Future<Sermon> random([int category = 0]) async {
    final total = _counts[category] ??= await _total(category);
    final index = Random().nextInt(total) + 1;
    final list = await getJson('${_base(category)}&per_page=1&page=$index') as List;
    return _parse(list.first as Map<String, dynamic>);
  }

  Future<int> _total(int category) async {
    final r = await getRaw('$_api/posts?tags=$_tag&per_page=1&_fields=id${category != 0 ? '&categories=$category' : ''}');
    return int.tryParse(r.headers['x-wp-total'] ?? '') ?? 1;
  }

  /// رابط MP3 من صفحة العظة (يُحفظ بعد أول مرة).
  Future<String> audioUrl(Sermon s) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('sermon_audio_${s.id}');
    if (cached != null) return cached;
    final html = await getText(s.link);
    final urls = RegExp(r'''https?://[^"'\s<>]+?\.mp3''', caseSensitive: false).allMatches(html).map((m) => m[0]!).toList();
    final url = urls.firstWhere((u) => u.contains('cdn.popeshenouda.org.eg/Audios') && !u.contains('wasabisys'),
        orElse: () => urls.isNotEmpty ? urls.first : throw StateError('لم يتم العثور على ملف صوتي لهذه العظة'));
    await prefs.setString('sermon_audio_${s.id}', url);
    return url;
  }

  Sermon _parse(Map<String, dynamic> o) => Sermon(
        o['id'] as int,
        stripHtml((o['title'] as Map)['rendered'] as String),
        stripHtml(((o['excerpt'] as Map?)?['rendered'] as String?) ?? '').replaceFirst('الفكرة الرئيسية', '').trim(),
        o['link'] as String,
        ((o['categories'] as List?)?.isNotEmpty ?? false) ? (o['categories'] as List).first as int : 0,
      );
}
