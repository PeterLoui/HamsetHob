import 'dart:convert';

import 'package:http/http.dart' as http;

const _headers = {'User-Agent': 'HamsetHob/2.0 (Android)'};

Future<String> getText(String url) async {
  final r = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 20));
  if (r.statusCode >= 400) throw HttpStatusError(r.statusCode);
  return utf8.decode(r.bodyBytes);
}

Future<http.Response> getRaw(String url) =>
    http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 30));

Future<dynamic> getJson(String url) async => jsonDecode(await getText(url));

class HttpStatusError implements Exception {
  HttpStatusError(this.code);
  final int code;
  @override
  String toString() => 'HTTP $code';
}

/// إزالة وسوم HTML وتحويل الكيانات الشائعة.
String stripHtml(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>|</p>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#8211;', '–')
    .replaceAll('&#8220;', '“')
    .replaceAll('&#8221;', '”')
    .replaceAll('&#8217;', '’')
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
    .replaceAll(RegExp(r'[ \t]+'), ' ')
    .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
    .trim();

/// إزالة التشكيل وتوحيد الألف والياء والتاء المربوطة للبحث.
String normalizeArabic(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if ((r >= 0x064B && r <= 0x065F) || r == 0x0670 || r == 0x0640 || (r >= 0x06D6 && r <= 0x06ED)) continue;
    final ch = String.fromCharCode(r);
    b.write(switch (ch) {
      'أ' || 'إ' || 'آ' || 'ٱ' => 'ا',
      'ى' => 'ي',
      'ة' => 'ه',
      _ => ch,
    });
  }
  return b.toString();
}
