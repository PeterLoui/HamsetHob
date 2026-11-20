import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'net.dart' show stripHtml;

/// مكتبة الكتب المسيحية (christianlib.com): موقع WordPress، فبنقرا التخصصات والكتب من واجهته (wp-json).
/// الموقع عليه جدار حماية بيرفض أي طلب من غير User-Agent متصفح، فكل الطلبات بهيدر متصفح.
/// ملف الكتاب نفسه على mediafire، ولينك «file_premium» بيحوّل على ملف الـ PDF على طول.
const _base = 'https://www.christianlib.com/wp-json/wp/v2';
const _headers = {
  'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36',
  'Accept': 'application/json,text/html,*/*',
  'Accept-Language': 'ar,en;q=0.8',
};

/// تخصصات مالهاش مكان في تطبيق كنسي، أو مش كتب.
const _hidden = {
  1, // غير مصنف
  4, // اسلاميات
  306, // اخبار مسيحية
  554, // فيديوهات و صوتيات
  14304, // اصدارات جديدة (فاضية تقريباً)
  25299, // سياسة
  37041, // يهوديات
};

class BookCategory {
  const BookCategory(this.id, this.name, this.parent, this.count);
  final int id;
  final String name;
  final int parent;
  final int count;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'parent': parent, 'count': count};
  factory BookCategory.fromJson(Map<String, dynamic> j) =>
      BookCategory(j['id'] as int, stripHtml(j['name'] as String), j['parent'] as int, j['count'] as int);
}

class Book {
  const Book({required this.id, required this.title, this.author, this.cover, this.pdf, required this.link, this.about = ''});
  final int id;
  final String title;
  final String? author;
  final String? cover;

  /// لينك الملف على mediafire (أو PDF مباشر). بعض الكتب مالهاش لينك تحميل.
  final String? pdf;
  final String link;
  final String about;

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'author': author, 'cover': cover, 'pdf': pdf, 'link': link, 'about': about};
  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'] as int,
        title: j['title'] as String,
        author: j['author'] as String?,
        cover: j['cover'] as String?,
        pdf: j['pdf'] as String?,
        link: j['link'] as String,
        about: j['about'] as String? ?? '',
      );

  /// من مقال WordPress: العنوان «كتاب X – المؤلف»، والغلاف أول صورة، والتحميل أول لينك mediafire أو pdf.
  factory Book.fromPost(Map<String, dynamic> p) {
    var title = stripHtml((p['title'] as Map)['rendered'] as String).replaceAll('\n', ' ').trim();
    String? author;
    // المؤلف بعد آخر شرطة: «كتاب فيلسوف القلب – الحياة القلقة لكيركغارد – كلير كارلايل»
    final dashes = RegExp(r'\s+–\s+').allMatches(title);
    final dash = dashes.isEmpty ? null : dashes.last;
    if (dash != null) {
      author = title.substring(dash.end).trim();
      title = title.substring(0, dash.start).trim();
    }
    title = title.replaceFirst(RegExp(r'^كتاب\s+'), '');
    final html = (p['content'] as Map)['rendered'] as String;
    final cover = RegExp(r'''<img[^>]+src=["']([^"']+wp-content/uploads/[^"']+)["']''').firstMatch(html)?.group(1);
    String? pdf;
    for (final m in RegExp(r'''href=["']([^"']+)["']''').allMatches(html)) {
      final u = m.group(1)!;
      if (u.contains('mediafire.com/file') || u.toLowerCase().split('?').first.endsWith('.pdf')) {
        pdf = u;
        break;
      }
    }
    return Book(
      id: p['id'] as int,
      title: title,
      author: (author?.isEmpty ?? true) ? null : author,
      cover: cover,
      pdf: pdf,
      link: p['link'] as String,
      about: _contents(html, title, author),
    );
  }

  /// المقال غالباً فيه فهرس الكتاب: بنشيل جدول المحتويات بتاع الموقع، وتكرار العنوان والمؤلف، وجمل التحميل.
  static String _contents(String html, String title, String? author) {
    final body = html
        .replaceAll(RegExp(r'<div[^>]*ez-toc-container.*?</nav>\s*</div>', dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]+>'), '\n');
    final out = <String>[];
    for (var line in stripHtml(body).split('\n')) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('كتاب ')) continue;
      if (line.contains('تحميل') || line.contains('اضغط هنا')) continue;
      if (RegExp(r'^(محتو(ى|يات)|فهرس|فهرست|الفهرس)\s*(الكتاب)?\s*:?$').hasMatch(line)) continue;
      if (line == author || (line.length > 6 && (title.contains(line) || (author?.contains(line) ?? false)))) continue;
      if (out.isNotEmpty && out.last == line) continue;
      out.add(line);
      if (out.length == 30) {
        out.add('…');
        break;
      }
    }
    return out.join('\n');
  }
}

class BookPage {
  const BookPage(this.books, this.totalPages);
  final List<Book> books;
  final int totalPages;
}

/// حالة تنزيل كتاب: لسه بيتنزّل (progress من ٠ لـ ١، أو null لو الحجم مش معروف)، أو خلص، أو فشل.
class BookDownload {
  BookDownload({this.progress, this.done = false, this.error});
  final double? progress;
  final bool done;
  final String? error;
}

class BooksRepository extends ChangeNotifier {
  BooksRepository._();
  static final instance = BooksRepository._();

  static const _catsKey = 'books_cats1';
  static const _catsAt = 'books_cats1_at';
  static const _savedKey = 'books_saved1';
  static const _fields = 'id,title,link,content';

  final _client = http.Client();
  Future<List<BookCategory>>? _cats;
  final _pages = <String, Future<BookPage>>{};

  // ───── التخصصات ─────

  /// التخصصات مخزّنة أسبوع، ولو النت مش موجود بنرجّع آخر نسخة.
  Future<List<BookCategory>> categories() => _cats ??= _loadCategories().catchError((Object e) {
        _cats = null;
        throw e;
      });

  Future<List<BookCategory>> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_catsKey);
    final at = DateTime.fromMillisecondsSinceEpoch(prefs.getInt(_catsAt) ?? 0);
    List<BookCategory> parse(String s) =>
        [for (final j in jsonDecode(s) as List) BookCategory.fromJson(j as Map<String, dynamic>)];
    if (cached != null && DateTime.now().difference(at) < const Duration(days: 7)) return parse(cached);
    try {
      final r = await _get('$_base/categories?per_page=100&_fields=id,name,parent,count');
      final all = [for (final j in jsonDecode(r.body) as List) BookCategory.fromJson(j as Map<String, dynamic>)]
          .where((c) => !_hidden.contains(c.id) && !_hidden.contains(c.parent) && c.count > 0)
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));
      await prefs.setString(_catsKey, jsonEncode([for (final c in all) c.toJson()]));
      await prefs.setInt(_catsAt, DateTime.now().millisecondsSinceEpoch);
      return all;
    } catch (_) {
      if (cached != null) return parse(cached);
      rethrow;
    }
  }

  // ───── الكتب ─────

  /// صفحة كتب من تخصص (أو بحث). الصفحات بتتحفظ في الذاكرة فالرجوع للقائمة مابيحمّلش تاني.
  Future<BookPage> books({int? category, String? search, int page = 1}) {
    final q = StringBuffer('$_base/posts?per_page=20&page=$page&_fields=$_fields');
    if (category != null) q.write('&categories=$category');
    if (search != null && search.trim().isNotEmpty) q.write('&search=${Uri.encodeQueryComponent(search.trim())}');
    final key = q.toString();
    return _pages.putIfAbsent(key, () async {
      try {
        final r = await _get(key);
        final total = int.tryParse(r.headers['x-wp-totalpages'] ?? '') ?? 1;
        final list = [for (final p in jsonDecode(r.body) as List) Book.fromPost(p as Map<String, dynamic>)];
        return BookPage(list, total);
      } catch (e) {
        _pages.remove(key);
        rethrow;
      }
    });
  }

  Future<http.Response> _get(String url) async {
    final r = await _client.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 25));
    // صفحة بعد الأخيرة بترجع ٤٠٠ (rest_post_invalid_page_number)
    if (r.statusCode == 400 && url.contains('page=')) return http.Response('[]', 200, headers: {'x-wp-totalpages': '0'});
    if (r.statusCode >= 400) throw HttpException('HTTP ${r.statusCode}');
    return r;
  }

  /// لينك الـ PDF المباشر: mediafire بيحوّل (302) على سيرفر التحميل، فبناخد العنوان من غير ما ننزّل الملف.
  Future<Uri> directPdf(Book b) async {
    final src = b.pdf;
    if (src == null) throw const FileSystemException('الكتاب ده مالوش ملف تحميل');
    var url = Uri.parse(src);
    for (var hop = 0; hop < 5; hop++) {
      final req = http.Request('GET', url)
        ..followRedirects = false
        ..headers.addAll(_headers);
      final res = await _client.send(req).timeout(const Duration(seconds: 25));
      final type = res.headers['content-type'] ?? '';
      if (res.isRedirect || (res.statusCode >= 300 && res.statusCode < 400)) {
        final loc = res.headers['location'];
        await res.stream.drain<void>();
        if (loc == null) break;
        url = url.resolve(loc);
        // سيرفر التحميل: اللينك خلاص بقى للملف نفسه، مش محتاجين نطلبه
        if (url.path.toLowerCase().endsWith('.pdf')) return url;
        continue;
      }
      if (type.contains('pdf')) {
        // نقفل الاتصال من غير ما ننزّل الملف كله
        await res.stream.listen(null).cancel();
        return url;
      }
      // صفحة mediafire العادية (مش premium): زرار التحميل جواها
      final body = await res.stream.bytesToString();
      final m = RegExp(r'''href=["'](https?://download[^"']+)["']''').firstMatch(body);
      if (m == null) break;
      url = Uri.parse(m.group(1)!.replaceAll('&amp;', '&'));
    }
    throw const FileSystemException('تعذّر الوصول لملف الكتاب');
  }

  // ───── الكتب المحفوظة ─────

  List<Book> _saved = [];
  List<Book> get saved => List.unmodifiable(_saved);
  final downloads = <int, BookDownload>{};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_savedKey);
    if (s != null) {
      _saved = [for (final j in jsonDecode(s) as List) Book.fromJson(j as Map<String, dynamic>)];
    }
    // ملف اتمسح من برّه: نشيله من القائمة
    final kept = <Book>[];
    for (final b in _saved) {
      if (await (await fileOf(b)).exists()) kept.add(b);
    }
    if (kept.length != _saved.length) {
      _saved = kept;
      await _persist();
    }
    notifyListeners();
  }

  Future<File> fileOf(Book b) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/books');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/${b.id}.pdf');
  }

  bool isSaved(Book b) => _saved.any((x) => x.id == b.id);

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedKey, jsonEncode([for (final b in _saved) b.toJson()]));
  }

  /// تنزيل الكتاب لمكتبة التطبيق (يتقري من غير نت). التقدّم بيتبعت مع notifyListeners.
  Future<void> download(Book b) async {
    if (downloads[b.id]?.done == false && downloads[b.id]?.error == null) return; // شغال فعلاً
    downloads[b.id] = BookDownload(progress: 0);
    notifyListeners();
    final file = await fileOf(b);
    final part = File('${file.path}.part');
    try {
      final url = await directPdf(b);
      final req = http.Request('GET', url)..headers.addAll(_headers);
      final res = await _client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode >= 400) throw HttpException('HTTP ${res.statusCode}');
      final total = res.contentLength;
      final sink = part.openWrite();
      var got = 0;
      var lastTick = DateTime.now();
      try {
        await for (final chunk in res.stream.timeout(const Duration(seconds: 40))) {
          sink.add(chunk);
          got += chunk.length;
          final now = DateTime.now();
          if (now.difference(lastTick).inMilliseconds > 150) {
            lastTick = now;
            downloads[b.id] = BookDownload(progress: total == null || total == 0 ? null : got / total);
            notifyListeners();
          }
        }
      } finally {
        await sink.close();
      }
      // نتأكد إنه PDF فعلاً مش صفحة خطأ
      final head = await part.openRead(0, 5).fold<List<int>>([], (a, b) => a..addAll(b));
      if (ascii.decode(head, allowInvalid: true) != '%PDF-') throw const FileSystemException('الملف اللي اتنزّل مش PDF');
      if (await file.exists()) await file.delete();
      await part.rename(file.path);
      _saved.removeWhere((x) => x.id == b.id);
      _saved.insert(0, b);
      await _persist();
      downloads[b.id] = BookDownload(done: true);
    } catch (e) {
      if (await part.exists()) await part.delete().catchError((_) => part);
      downloads[b.id] = BookDownload(error: e is FileSystemException ? e.message : 'تعذّر التنزيل، تأكد من الاتصال بالإنترنت');
    }
    notifyListeners();
  }

  Future<void> remove(Book b) async {
    final f = await fileOf(b);
    if (await f.exists()) await f.delete();
    _saved.removeWhere((x) => x.id == b.id);
    downloads.remove(b.id);
    await _persist();
    notifyListeners();
  }
}
