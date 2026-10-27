import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/coptic.dart';
import 'net.dart';

class Book {
  const Book(this.number, this.name, this.chapters);
  final int number;
  final String name;
  final int chapters;
}

class Verse {
  const Verse(this.number, this.text);
  final int number;
  final String text;
}

class VerseRef {
  const VerseRef(this.book, this.chapter, this.verse);
  final int book;
  final int chapter;
  final int verse;

  String get bookName => books[book - 1].name;
  String get label => '$bookName ${ar(chapter)} : ${ar(verse)}';

  @override
  bool operator ==(Object other) =>
      other is VerseRef && other.book == book && other.chapter == chapter && other.verse == verse;
  @override
  int get hashCode => Object.hash(book, chapter, verse);
}

class DailyVerse {
  const DailyVerse(this.ref, this.text);
  final VerseRef ref;
  final String text;
}

class SearchHit {
  const SearchHit(this.ref, this.text);
  final VerseRef ref;
  final String text;
}

const _bookData = [
  ['التكوين', 50], ['الخروج', 40], ['اللاويين', 27], ['العدد', 36], ['التثنية', 34],
  ['يشوع', 24], ['القضاة', 21], ['راعوث', 4], ['صموئيل الأول', 31], ['صموئيل الثاني', 24],
  ['الملوك الأول', 22], ['الملوك الثاني', 25], ['أخبار الأيام الأول', 29], ['أخبار الأيام الثاني', 36],
  ['عزرا', 10], ['نحميا', 13], ['أستير', 10], ['أيوب', 42], ['المزامير', 150], ['الأمثال', 31],
  ['الجامعة', 12], ['نشيد الأنشاد', 8], ['إشعياء', 66], ['إرميا', 52], ['مراثي إرميا', 5],
  ['حزقيال', 48], ['دانيال', 12], ['هوشع', 14], ['يوئيل', 3], ['عاموس', 9], ['عوبديا', 1],
  ['يونان', 4], ['ميخا', 7], ['ناحوم', 3], ['حبقوق', 3], ['صفنيا', 3], ['حجي', 2],
  ['زكريا', 14], ['ملاخي', 4],
  ['متى', 28], ['مرقس', 16], ['لوقا', 24], ['يوحنا', 21], ['أعمال الرسل', 28],
  ['رومية', 16], ['كورنثوس الأولى', 16], ['كورنثوس الثانية', 13], ['غلاطية', 6],
  ['أفسس', 6], ['فيلبي', 4], ['كولوسي', 4], ['تسالونيكي الأولى', 5], ['تسالونيكي الثانية', 3],
  ['تيموثاوس الأولى', 6], ['تيموثاوس الثانية', 4], ['تيطس', 3], ['فليمون', 1], ['العبرانيين', 13],
  ['يعقوب', 5], ['بطرس الأولى', 5], ['بطرس الثانية', 3], ['يوحنا الأولى', 5], ['يوحنا الثانية', 1],
  ['يوحنا الثالثة', 1], ['يهوذا', 1], ['رؤيا يوحنا', 22],
];

/// أسفار الكتاب المقدس الـ66 بترتيب ترجمة فاندايك.
final List<Book> books = [
  for (var i = 0; i < _bookData.length; i++) Book(i + 1, _bookData[i][0] as String, _bookData[i][1] as int),
];

String cleanVerse(String raw) => raw.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// الكتاب المقدس (ترجمة فاندايك SVD) عبر bolls.life، مع نسخة كاملة اختيارية على الجهاز.
class BibleRepository {
  BibleRepository._();
  static final instance = BibleRepository._();

  static const _translation = 'SVD';
  static const dailyVerseKey = 'daily_verse';
  Database? _db;

  Future<Database> _database() async => _db ??= await openDatabase(
        p.join(await getDatabasesPath(), 'bible.db'),
        version: 1,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE verses (book INTEGER, chapter INTEGER, verse INTEGER, text TEXT, plain TEXT, '
          'PRIMARY KEY (book, chapter, verse))',
        ),
      );

  Future<int> offlineCount() async =>
      Sqflite.firstIntValue(await (await _database()).rawQuery('SELECT COUNT(*) FROM verses')) ?? 0;

  Future<bool> isOffline() async => await offlineCount() >= 31000;

  Future<List<Verse>> chapter(int book, int chapter) async {
    final db = await _database();
    final rows = await db.query('verses',
        columns: ['verse', 'text'], where: 'book = ? AND chapter = ?', whereArgs: [book, chapter], orderBy: 'verse');
    if (rows.isNotEmpty) return [for (final r in rows) Verse(r['verse'] as int, r['text'] as String)];

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'chapter_$book:$chapter';
    var json = prefs.getString(cacheKey);
    if (json == null) {
      json = await getText('https://bolls.life/get-text/$_translation/$book/$chapter/');
      await prefs.setString(cacheKey, json);
    }
    final list = jsonDecode(json) as List;
    return [for (final o in list) Verse(o['verse'] as int, cleanVerse(o['text'] as String))];
  }

  /// رسالة اليوم: آية عشوائية من العهدين، ثابتة طوال اليوم ما لم يُطلب غيرها.
  /// تُحفظ بصيغة يقرأها كود الويدجت الأصلي أيضاً.
  Future<DailyVerse> dailyVerse(DateTime today, {bool forceNew = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final day = dateOnly(today).toIso8601String().substring(0, 10);
    final saved = prefs.getString(dailyVerseKey);
    if (!forceNew && saved != null) {
      final o = jsonDecode(saved) as Map<String, dynamic>;
      if (o['date'] == day) {
        return DailyVerse(VerseRef(o['book'] as int, o['chapter'] as int, o['verse'] as int), o['text'] as String);
      }
    }
    final (book, chap) = _randomChapter();
    final verses = await chapter(book, chap);
    final v = verses[Random().nextInt(verses.length)];
    await prefs.setString(
      dailyVerseKey,
      jsonEncode({'date': day, 'book': book, 'chapter': chap, 'verse': v.number, 'text': v.text}),
    );
    return DailyVerse(VerseRef(book, chap, v.number), v.text);
  }

  /// إصحاح عشوائي من الـ1189 إصحاحاً بالتساوي.
  (int, int) _randomChapter() {
    var n = Random().nextInt(books.fold(0, (s, b) => s + b.chapters));
    for (final b in books) {
      if (n < b.chapters) return (b.number, n + 1);
      n -= b.chapters;
    }
    return (43, 3);
  }

  Future<List<SearchHit>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    if (await isOffline()) {
      final words = normalizeArabic(q).split(' ').where((w) => w.isNotEmpty).toList();
      final rows = await (await _database()).query('verses',
          columns: ['book', 'chapter', 'verse', 'text'],
          where: words.map((_) => 'plain LIKE ?').join(' AND '),
          whereArgs: [for (final w in words) '%$w%'],
          orderBy: 'book, chapter, verse',
          limit: 300);
      return [
        for (final r in rows)
          SearchHit(VerseRef(r['book'] as int, r['chapter'] as int, r['verse'] as int), r['text'] as String)
      ];
    }
    final json = await getJson('https://bolls.life/v2/find/$_translation?search=${Uri.encodeQueryComponent(q)}'
        '&match_case=false&match_whole=false&limit=200&page=1');
    final results = (json['results'] as List?) ?? [];
    return [
      for (final o in results)
        if ((o['book'] as int) <= 66)
          SearchHit(VerseRef(o['book'] as int, o['chapter'] as int, o['verse'] as int), cleanVerse(o['text'] as String))
    ];
  }

  /// تحميل الترجمة كاملة (حوالي ٢٫٤ ميجا) وتخزينها محلياً.
  Future<void> downloadOffline(ValueChanged<double> onProgress) async {
    onProgress(0.05);
    final r = await getRaw('https://bolls.life/static/translations/$_translation.zip');
    if (r.statusCode != 200) throw HttpStatusError(r.statusCode);
    onProgress(0.5);
    final archive = ZipDecoder().decodeBytes(r.bodyBytes);
    final file = archive.files.firstWhere((f) => f.isFile);
    final list = jsonDecode(utf8.decode(file.content as List<int>)) as List;
    final db = await _database();
    await db.transaction((txn) async {
      await txn.delete('verses');
      final batch = txn.batch();
      for (final o in list) {
        final book = o['book'] as int;
        if (book < 1 || book > 66) continue;
        final text = cleanVerse(o['text'] as String);
        batch.insert(
          'verses',
          {'book': book, 'chapter': o['chapter'], 'verse': o['verse'], 'text': text, 'plain': normalizeArabic(text)},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
    onProgress(1);
  }

  Future<void> deleteOffline() async => (await _database()).delete('verses');
}
