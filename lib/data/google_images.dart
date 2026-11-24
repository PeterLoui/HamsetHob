import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'store.dart';

/// البحث في صور جوجل بالـAPI الرسمي (Programmable Search، بحث الصور). المفتاح ومعرّف محرك البحث
/// بيدخّلهم المستخدم في الإعدادات وبيتحفظوا على جهازه بس (مش في الكود)، والمجاني ١٠٠ بحث في اليوم.
class GoogleImageSearch {
  GoogleImageSearch._();

  static bool get configured {
    try {
      final s = AppSettings.instance;
      return s.googleFallback && s.googleKey.isNotEmpty && s.googleCx.isNotEmpty;
    } on Error {
      return false; // الإعدادات لسه ماتحمّلتش
    }
  }

  /// روابط الصور من رد الـAPI.
  static List<String> parseLinks(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    if (j['error'] != null) {
      final e = j['error'] as Map<String, dynamic>;
      throw StateError('${e['code']}: ${e['message']}');
    }
    final items = j['items'];
    return [
      if (items is List)
        for (final e in items.whereType<Map>())
          if (e['link'] is String && (e['link'] as String).startsWith('https://')) e['link'] as String,
    ];
  }

  static Future<List<String>> search(String query, {String? key, String? cx, int num = 3}) async {
    final s = AppSettings.instance;
    final uri = Uri.https('www.googleapis.com', '/customsearch/v1', {
      'key': key ?? s.googleKey,
      'cx': cx ?? s.googleCx,
      'q': query,
      'searchType': 'image',
      'num': '$num',
      'safe': 'active',
      'imgSize': 'medium',
    });
    final r = await http.get(uri).timeout(const Duration(seconds: 20));
    return parseLinks(utf8.decode(r.bodyBytes));
  }

  /// روابط الصور لاسم تذكار، محفوظة ٣٠ يوم عشان نوفّر الحصة المجانية.
  static Future<List<String>> forName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'gimg_${name.hashCode.toUnsigned(32).toRadixString(16)}';
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
