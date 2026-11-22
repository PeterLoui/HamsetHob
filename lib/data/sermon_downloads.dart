import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'net.dart';
import 'sermons.dart';

/// العظات اللي اتحمّلت على الجهاز، عشان تشتغل من غير نت.
///
/// الملفات في مجلد التطبيق الخاص (sermons/‎<id>.mp3) وقايمتها في الإعدادات، فبتتمسح مع التطبيق.
/// التحميل بيتكتب في ملف مؤقت (.part) ويتسمّى بعد ما يخلص، فمافيش عظة نص محمّلة بتظهر كأنها كاملة.
class SermonDownloads extends ChangeNotifier {
  SermonDownloads._(this._prefs, this._dir);
  final SharedPreferences _prefs;
  final Directory _dir;
  static late SermonDownloads instance;

  static const _key = 'sermon_downloads';

  static Future<void> load() async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/sermons');
    await dir.create(recursive: true);
    final d = instance = SermonDownloads._(await SharedPreferences.getInstance(), dir);
    d._restore();
  }

  final _items = <int, _Saved>{};
  final _progress = <int, double>{};
  final _clients = <int, http.Client>{};
  final _failed = <int>{};

  /// العظات المحمّلة، الأحدث أولاً.
  List<Sermon> get sermons => [for (final s in _items.values.toList().reversed) s.sermon];

  int get count => _items.length;
  int get totalBytes => _items.values.fold(0, (a, s) => a + s.bytes);

  bool has(int id) => _items.containsKey(id);
  bool isDownloading(int id) => _progress.containsKey(id);

  /// من ٠ لـ ١، أو null لو مش بيتحمّل. ٠ يعني لسه بيبدأ ومش معروف الحجم.
  double? progressOf(int id) => _progress[id];
  bool failed(int id) => _failed.contains(id);

  /// مسار الملف لو العظة محمّلة وسليمة.
  String? pathOf(int id) {
    final s = _items[id];
    if (s == null) return null;
    final f = File(_path(id));
    if (f.existsSync() && f.lengthSync() == s.bytes) return f.path;
    return null;
  }

  String _path(int id) => '${_dir.path}/$id.mp3';

  void _restore() {
    try {
      for (final o in jsonDecode(_prefs.getString(_key) ?? '[]') as List) {
        final s = _Saved.fromJson(o as Map<String, dynamic>);
        if (File(_path(s.sermon.id)).existsSync()) _items[s.sermon.id] = s;
      }
    } catch (_) {
      // قايمة تالفة: نبدأ من جديد، والملفات اليتيمة بتتشال تحت
    }
    // ملفات مؤقتة من تحميل اتقطع بقفل التطبيق
    for (final f in _dir.listSync()) {
      if (f is File && f.path.endsWith('.part')) f.deleteSync();
    }
  }

  Future<void> _save() =>
      _prefs.setString(_key, jsonEncode([for (final s in _items.values) s.toJson()]));

  Future<void> download(Sermon s) async {
    final id = s.id;
    if (has(id) || isDownloading(id)) return;
    _failed.remove(id);
    _progress[id] = 0;
    notifyListeners();
    final client = _clients[id] = http.Client();
    final part = File('${_path(id)}.part');
    try {
      final url = await SermonRepository.instance.audioUrl(s);
      final res = await openStream(client, url);
      if (res.statusCode >= 400) throw HttpStatusError(res.statusCode);
      final total = res.contentLength ?? 0;
      var done = 0, lastTick = 0;
      final sink = part.openWrite();
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          done += chunk.length;
          // تحديث الشريط كل ٢٥٦ كيلو بس عشان الشاشة ماتتعاد رسمها آلاف المرات
          if (total > 0 && done - lastTick > 256 * 1024) {
            lastTick = done;
            _progress[id] = (done / total).clamp(0.0, .99);
            notifyListeners();
          }
        }
      } finally {
        await sink.close();
      }
      // لو الحجم المعلن مش مطابق، التحميل اتقطع في النص
      if (total > 0 && done != total) throw const HttpException('incomplete');
      await part.rename(_path(id));
      _items[id] = _Saved(s, done);
      await _save();
    } catch (_) {
      if (_progress.containsKey(id)) _failed.add(id); // لو الإلغاء مش هو السبب
      if (part.existsSync()) part.deleteSync();
    } finally {
      client.close();
      _clients.remove(id);
      _progress.remove(id);
      notifyListeners();
    }
  }

  /// إلغاء تحميل شغال.
  void cancel(int id) {
    _progress.remove(id); // قبل الإغلاق عشان مايتعدّش فشل
    _clients[id]?.close();
    notifyListeners();
  }

  Future<void> delete(int id) async {
    final f = File(_path(id));
    if (f.existsSync()) f.deleteSync();
    _items.remove(id);
    await _save();
    notifyListeners();
  }

  Future<void> deleteAll() async {
    for (final id in _items.keys.toList()) {
      final f = File(_path(id));
      if (f.existsSync()) f.deleteSync();
    }
    _items.clear();
    await _save();
    notifyListeners();
  }
}

class _Saved {
  const _Saved(this.sermon, this.bytes);
  final Sermon sermon;
  final int bytes;

  factory _Saved.fromJson(Map<String, dynamic> o) => _Saved(
        Sermon(o['id'] as int, o['t'] as String, o['s'] as String, o['l'] as String, o['c'] as int),
        o['b'] as int,
      );

  Map<String, dynamic> toJson() =>
      {'id': sermon.id, 't': sermon.title, 's': sermon.summary, 'l': sermon.link, 'c': sermon.categoryId, 'b': bytes};
}
