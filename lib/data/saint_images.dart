import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'image_search.dart';
import 'net.dart' show normalizeArabic;

/// صورة تذكار اليوم: من البحث في الصور بالاسم (SerpApi أو Brave) بمفتاح المستخدم، وأول نتيجة بتتحمّل.
/// من غير مفتاح مافيش صورة والواجهة بتعرض الصليب القبطي. الصور بتتحفظ على الجهاز.
class SaintImages {
  SaintImages._();
  static final instance = SaintImages._();

  static const imageHeaders = {'User-Agent': 'HamsetHob/2.0 (Android)'};

  final _memo = <String, Future<String?>>{};
  final _bytesMemo = <String, Future<Uint8List?>>{};

  /// رابط الصورة لاسم التذكار (أو null). نفس الطلب بيرجّع نفس الـ Future، فالصورة ماتتحمّلش من جديد مع كل إعادة رسم.
  /// [wikiTitle] و[date] متبقيين عشان الاستدعاءات القديمة، والبحث بالاسم بس.
  Future<String?> imageUrl(String? wikiTitle, String name, DateTime date) {
    if (!ImageSearch.configured) return Future.value(null);
    final key = normalizeArabic(name);
    return _memo.putIfAbsent(key, () async {
      try {
        for (final link in await ImageSearch.forName(name)) {
          if ((await loadBytes(link)) != null) return link;
        }
      } catch (_) {/* الحصة خلصت أو المفتاح غلط أو مفيش نت: من غير صورة */}
      _memo.remove(key); // نجرّب تاني المرة الجاية
      return null;
    });
  }

  /// بعد تغيير إعدادات البحث: نمسح النتايج المحفوظة في الذاكرة عشان تتحسب من جديد.
  void resetMemo() {
    _memo.clear();
    _bytesMemo.clear();
  }

  /// الصورة كـbytes: من الملف المحفوظ على الجهاز لو اتحمّلت قبل كده، وإلا من الرابط.
  /// [log] بيسجّل كل محاولة، و[fresh] بيتخطى الذاكرة (للفحص).
  Future<Uint8List?> loadBytes(String url, {List<String>? log, bool fresh = false}) {
    final hit = fresh ? null : _bytesMemo[url];
    if (hit != null) return hit;
    final f = _fetch(url, log).then((b) {
      if (b == null) _bytesMemo.remove(url); // نجرّب تاني المرة الجاية
      return b;
    });
    return _bytesMemo[url] = f;
  }

  Future<Uint8List?> _fetch(String url, List<String>? log) async {
    final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'saint_imgs'));
    final file = File(p.join(dir.path, url.hashCode.toUnsigned(32).toRadixString(16)));
    if (await file.exists()) {
      final b = await file.readAsBytes();
      if (b.isNotEmpty) return b;
    }
    try {
      final r = await http.get(Uri.parse(url), headers: imageHeaders).timeout(const Duration(seconds: 25));
      final isImage = (r.headers['content-type'] ?? '').startsWith('image');
      log?.add('${r.statusCode}  ${Uri.parse(url).host}  ${(r.bodyBytes.length / 1024).round()} ك.ب${isImage ? '' : '  (مش صورة)'}');
      if (r.statusCode == 200 && isImage && r.bodyBytes.isNotEmpty && r.bodyBytes.length < 8 * 1024 * 1024) {
        await dir.create(recursive: true);
        await file.writeAsBytes(r.bodyBytes, flush: true);
        return r.bodyBytes;
      }
    } catch (e) {
      log?.add('خطأ  ${Uri.parse(url).host}  $e');
    }
    return null;
  }

  /// محاذاة الصورة جوه الصندوق: الوش غالباً في الثلث العلوي، فبنميل للأعلى.
  static Alignment focus(String? wikiTitle, double boxW, double boxH) => const Alignment(0, -.6);
}
