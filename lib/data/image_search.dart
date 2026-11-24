import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'store.dart';

/// البحث في الصور بالـAPI الرسمي لـBrave Search. المفتاح بيدخّله المستخدم في الإعدادات وبيتحفظ على جهازه بس
/// (مش في الكود)، وبيتجرّب أول نتايج البحث لحد ما تلاقي صورة بتتحمّل.
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

  /// روابط الصور من رد الـAPI: الأصلية ثم المصغّرة اللي بتتحمّل عن طريق Brave (أضمن لو الموقع الأصلي بيمنع).
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

  static Future<List<String>> search(String query, {String? key, int count = 3}) async {
    final uri = Uri.https('api.search.brave.com', '/res/v1/images/search', {
      'q': query,
      'count': '$count',
      'safesearch': 'strict',
      'search_lang': 'ar',
    });
    final r = await http.get(uri, headers: {
      'Accept': 'application/json',
      'X-Subscription-Token': key ?? AppSettings.instance.searchKey,
    }).timeout(const Duration(seconds: 20));
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
