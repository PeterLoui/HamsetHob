import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'store.dart';

/// البحث في الصور بـAPI من مزوّد: SerpApi (نتايج صور جوجل) أو Brave Search. المفتاح بيدخّله المستخدم في الإعدادات
/// وبيتحفظ على جهازه بس (مش في الكود)، وبيتجرّب أول نتايج البحث لحد ما تلاقي صورة بتتحمّل.
class ImageSearch {
  ImageSearch._();

  static bool get configured {
    try {
      final s = AppSettings.instance;
      return s.searchFallback && s.searchKey.isNotEmpty;
    } on Error {
      return false; // الإعدادات لسه ماتحمّلتش
    }
  }

  static const providers = ['SerpApi (صور جوجل)', 'Brave Search'];

  /// روابط الصور من رد SerpApi (engine=google_images): الأصلية ثم المصغّرة اللي على خوادم جوجل (أضمن لو الموقع الأصلي بيمنع).
  static List<String> parseSerpApi(String body, {int count = 3}) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    if (j['error'] is String) throw StateError(j['error'] as String);
    final results = j['images_results'];
    final out = <String>[];
    if (results is List) {
      for (final r in results.whereType<Map>().take(count)) {
        for (final u in [r['original'], r['thumbnail']]) {
          if (u is String && u.startsWith('https://') && !out.contains(u)) out.add(u);
        }
      }
    }
    return out;
  }

  /// روابط الصور من رد Brave: الأصلية ثم المصغّرة اللي بتتحمّل عن طريق Brave.
  static List<String> parseLinks(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    final err = j['error'];
    if (err is Map) throw StateError('${err['code'] ?? ''} ${err['detail'] ?? err['message'] ?? err}'.trim());
    final results = j['results'];
    final out = <String>[];
    if (results is List) {
      for (final r in results.whereType<Map>()) {
        final original = (r['properties'] is Map) ? (r['properties'] as Map)['url'] : null;
        final thumb = (r['thumbnail'] is Map) ? (r['thumbnail'] as Map)['src'] : null;
        for (final u in [original, thumb]) {
          if (u is String && u.startsWith('https://') && !out.contains(u)) out.add(u);
        }
      }
    }
    return out;
  }

  static Future<List<String>> search(String query, {String? key, int? provider, int count = 3}) async {
    final st = AppSettings.instance;
    final k = key ?? st.searchKey;
    final pr = provider ?? st.searchProvider;
    if (pr == 0) {
      final r = await http.get(Uri.https('serpapi.com', '/search.json', {
        'engine': 'google_images',
        'q': query,
        'api_key': k,
        'hl': 'ar',
        'safe': 'active',
      })).timeout(const Duration(seconds: 40));
      final body = utf8.decode(r.bodyBytes);
      if (r.statusCode == 401) throw StateError('المفتاح مش مقبول (٤٠١)');
      if (r.statusCode == 429) throw StateError('الحصة المجانية خلصت (٤٢٩)');
      if (r.statusCode >= 400 && !body.contains('"error"')) throw StateError('رد ${r.statusCode}');
      return parseSerpApi(body, count: count);
    }
    final uri = Uri.https('api.search.brave.com', '/res/v1/images/search', {
      'q': query,
      'count': '$count',
      'safesearch': 'strict',
      'search_lang': 'ar',
    });
    final r = await http.get(uri, headers: {'Accept': 'application/json', 'X-Subscription-Token': k}).timeout(const Duration(seconds: 20));
    if (r.statusCode == 401 || r.statusCode == 403) throw StateError('المفتاح مش مقبول (${r.statusCode})');
    if (r.statusCode == 429) throw StateError('الحصة المجانية خلصت أو الطلبات كتير (٤٢٩)');
    if (r.statusCode >= 400) throw StateError('رد ${r.statusCode}');
    return parseLinks(utf8.decode(r.bodyBytes));
  }

  /// روابط الصور لاسم تذكار، محفوظة ٣٠ يوم عشان نوفّر الحصة المجانية.
  static Future<List<String>> forName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'imgsearch_${name.hashCode.toUnsigned(32).toRadixString(16)}';
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      final o = jsonDecode(cached) as Map<String, dynamic>;
      if (DateTime.now().millisecondsSinceEpoch - (o['at'] as int) < const Duration(days: 30).inMilliseconds) {
        return [for (final x in o['links'] as List) x as String];
      }
    }
    final links = await search('$name أيقونة قديس');
    if (links.isNotEmpty) await prefs.setString(cacheKey, jsonEncode({'at': DateTime.now().millisecondsSinceEpoch, 'links': links}));
    return links;
  }
}
