import 'package:shared_preferences/shared_preferences.dart';

import 'net.dart';

/// صورة التذكار: صفحة ويكيبيديا الإنجليزية المحددة أولاً، ثم البحث في ويكيبيديا
/// العربية باسم القديس (لا تُقبل نتيجة إلا إذا احتوى عنوانها على الاسم).
/// إن لم توجد صورة تعرض الواجهة رسمة الصليب.
class SaintImages {
  SaintImages._();
  static final instance = SaintImages._();

  static const _titles = {
    'نياحه', 'استشهاد', 'تذكار', 'عيد', 'القديس', 'القديسه', 'القديسين', 'البابا', 'الانبا', 'انبا',
    'مار', 'الشهيد', 'الشهيده', 'رئيس', 'الملائكه', 'الملاك', 'السيده', 'ابي', 'ابو', 'البطريرك',
    'الكبير', 'الرسول', 'الرسولين', 'الانجيلي', 'بطاركه', 'الكرازه', 'المرقسيه', 'اسقف', 'الاسقف',
    'التذكار', 'الشهري', 'سنكسار', 'اليوم', 'دخول', 'بدايه', 'صوم', 'المجيد',
  };

  final _memo = <String, Future<String?>>{};

  /// نفس الطلب يرجع نفس الـ Future حتى لا تُعاد الصورة مع كل إعادة رسم.
  Future<String?> imageUrl(String? wikiTitle, String name) =>
      _memo.putIfAbsent('${wikiTitle ?? ''}|$name', () => _imageUrl(wikiTitle, name));

  Future<String?> _imageUrl(String? wikiTitle, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'saint_img_${wikiTitle ?? 'search:$name'}';
    if (prefs.containsKey(key)) {
      final v = prefs.getString(key);
      return v == null || v.isEmpty ? null : v;
    }
    String? url;
    if (wikiTitle != null) url = await _safe(() => _summary(wikiTitle));
    url ??= await _safe(() => _searchArabic(name));
    await prefs.setString(key, url ?? ''); // نحفظ النتيجة الفارغة أيضاً
    return url;
  }

  Future<String?> _safe(Future<String?> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _summary(String title) async {
    final j = await getJson('https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(title)}') as Map;
    final img = (j['originalimage'] ?? j['thumbnail']) as Map?;
    return img?['source'] as String?;
  }

  Future<String?> _searchArabic(String name) async {
    final keys = normalizeArabic(name)
        .split(RegExp(r'[\s،()]+'))
        .map((w) => w.startsWith('و') && w.length > 3 ? w.substring(1) : w)
        .where((w) => w.length >= 3 && !_titles.contains(w))
        .toList();
    if (keys.isEmpty) return null;
    final j = await getJson('https://ar.wikipedia.org/w/api.php?action=query&generator=search'
        '&gsrsearch=${Uri.encodeQueryComponent(keys.join(' '))}&gsrlimit=6&prop=pageimages&piprop=original&format=json') as Map;
    final pages = ((j['query'] as Map?)?['pages'] as Map?)?.values.cast<Map>().toList() ?? [];
    pages.sort((a, b) => (a['index'] as int? ?? 0).compareTo(b['index'] as int? ?? 0));
    for (final p in pages) {
      final title = normalizeArabic(p['title'] as String? ?? '');
      final original = p['original'] as Map?;
      if (original != null && keys.any(title.contains)) return original['source'] as String?;
    }
    return null;
  }
}
