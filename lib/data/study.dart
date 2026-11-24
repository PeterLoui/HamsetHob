import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'net.dart';
import 'wird.dart';
import 'prayers.dart' show decodeWindows1256;

/// مجموعة أسفار في العجلة (الناموس، التاريخ، الحكمة...).
class StudyGroup {
  const StudyGroup(this.id, this.name, this.newTestament);
  final String id, name;
  final bool newTestament;
}

/// صفحة إضافية في سفر (دراسة أو بحث) أو دليل عام.
class StudyPage {
  const StudyPage(this.title, this.file);
  final String title, file;
}

class StudyBook {
  const StudyBook({
    required this.id,
    required this.name,
    required this.short,
    required this.newTestament,
    required this.group,
    required this.chapters,
    required this.dir,
    required this.intro,
    required this.pages,
    required this.extras,
    required this.bibleNumber,
  });
  final String id, name, short, group, dir;
  final bool newTestament;
  final int chapters;
  final String? intro;
  final List<String> pages;
  final List<StudyPage> extras;

  /// رقم السفر في كتاب التطبيق (1–66)، وبيكون null للأسفار القانونية الثانية.
  final int? bibleNumber;

  String chapterFile(int chapter) => pages[chapter - 1];
}

class StudyGuide {
  const StudyGuide(this.id, this.name, this.dir, this.pages);
  final String id, name, dir;
  final List<StudyPage> pages;
}

/// عنصر قابل للقراءة: مقدمة، أصحاح، دراسة، أو صفحة دليل.
class StudyDoc {
  const StudyDoc({required this.key, required this.title, required this.url});
  final String key, title, url;
}

class StudyCatalog {
  StudyCatalog._(this.root, this.groups, this.books, this.guides);
  final String root;
  final List<StudyGroup> groups;
  final List<StudyBook> books;
  final List<StudyGuide> guides;

  static StudyCatalog? _cache;

  static Future<StudyCatalog> load() async {
    if (_cache != null) return _cache!;
    return _cache = parse(await rootBundle.loadString('assets/study_fekry.json'));
  }

  static StudyCatalog parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final books = <StudyBook>[
      for (final b in j['books'] as List)
        StudyBook(
          id: b['id'],
          name: b['n'],
          short: b['s'],
          newTestament: b['t'] == 'NT',
          group: b['g'],
          chapters: b['ch'],
          dir: b['dir'],
          intro: b['intro'],
          pages: [for (final f in b['pages'] as List) f as String],
          extras: [for (final x in (b['x'] as List)) StudyPage(x[0], x[1])],
          bibleNumber: b['bible'] as int?,
        ),
    ];
    final ntGroups = {'gospels', 'acts', 'paul', 'general', 'rev'};
    return StudyCatalog._(
      j['root'],
      [for (final g in j['groups'] as List) StudyGroup(g['id'], g['n'], ntGroups.contains(g['id']))],
      books,
      [
        for (final g in j['guides'] as List)
          StudyGuide(g['id'], g['n'], g['dir'], [for (final x in g['pages'] as List) StudyPage(x[0], x[1])]),
      ],
    );
  }

  StudyBook? byId(String id) => books.where((b) => b.id == id).firstOrNull;
  List<StudyBook> inGroup(String g) => books.where((b) => b.group == g).toList();
  int get totalChapters => books.fold(0, (a, b) => a + b.chapters);

  StudyDoc intro(StudyBook b) =>
      StudyDoc(key: '${b.id}:intro', title: 'مقدمة ${b.name}', url: root + b.dir + b.intro!);
  StudyDoc chapter(StudyBook b, int ch) =>
      StudyDoc(key: '${b.id}:$ch', title: '${b.short} $ch', url: root + b.dir + b.chapterFile(ch));
  StudyDoc extra(StudyBook b, StudyPage x) =>
      StudyDoc(key: '${b.id}:x:${x.file}', title: x.title, url: root + b.dir + x.file);
  StudyDoc guidePage(StudyGuide g, StudyPage x) =>
      StudyDoc(key: 'guide:${g.id}:${x.file}', title: x.title, url: root + g.dir + x.file);
}

/// ما قرأه الدارس: أصحاحات (سفر:رقم) فقط هي اللي بتتحسب في العجلة.
class StudyProgress extends ChangeNotifier {
  StudyProgress._(this._prefs) : _done = {...?_prefs.getStringList('study_done')};
  final SharedPreferences _prefs;
  final Set<String> _done;
  static StudyProgress? instance;

  static Future<StudyProgress> load() async => instance ??= StudyProgress._(await SharedPreferences.getInstance());

  bool isDone(String key) => _done.contains(key);
  int doneIn(StudyBook b) {
    var n = 0;
    for (var i = 1; i <= b.chapters; i++) {
      if (_done.contains('${b.id}:$i')) n++;
    }
    return n;
  }

  int get totalDone => _done.where((k) => RegExp(r':\d+$').hasMatch(k)).length;

  Future<void> toggle(String key) async {
    final added = !_done.remove(key);
    if (added) {
      _done.add(key);
      if (RegExp(r':\d+$').hasMatch(key)) WirdStore.markIf(WirdItem.chapter);
    }
    await _prefs.setStringList('study_done', _done.toList());
    notifyListeners();
  }

  Future<void> mark(String key) async {
    if (_done.add(key)) {
      if (RegExp(r':\d+$').hasMatch(key)) WirdStore.markIf(WirdItem.chapter);
      await _prefs.setStringList('study_done', _done.toList());
      notifyListeners();
    }
  }

  /// آخر مكان فتحه الدارس (key) لزرار «كمّل».
  String? get last => _prefs.getString('study_last');
  Future<void> setLast(String key) async {
    await _prefs.setString('study_last', key);
    notifyListeners();
  }
}

enum BlockKind { h1, h2, h3, para, verse, bullet }

class Block {
  const Block(this.kind, this.text);
  final BlockKind kind;
  final String text;
  Map<String, dynamic> toJson() => {'k': kind.index, 't': text};
  factory Block.fromJson(Map<String, dynamic> j) => Block(BlockKind.values[j['k'] as int], j['t'] as String);
}

/// يحوّل صفحة تفسير القمص أنطونيوس فكري من موقع الأنبا تكلا لكتل نصية مرتبة.
List<Block> parseCommentary(String htmlSource) {
  final doc = html_parser.parse(htmlSource);
  final body = doc.getElementById('bodytext');
  if (body == null) return const [];
  final out = <Block>[];
  // سطر جديد (br) بيفصل الفقرات، فنحط علامة نقسم عليها
  for (final br in body.querySelectorAll('br')) {
    br.replaceWith(dom.Text('¶'));
  }
  String clean(String s) => s.replaceAll('¶', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  var stop = false;

  void addPara(String t) {
    t = clean(t);
    // آخر الصفحة: قائمة أصحاحات السفر ثم فهرس كل التفاسير
    final end = t.indexOf('تفاسير أصحاحات');
    if (end >= 0) {
      stop = true;
      t = clean(t.substring(0, end).replaceAll('←', ''));
    }
    if (t.startsWith('←') || (t.length < 120 && t.contains('الكتاب المقدس المسموع'))) return;
    if (t.isEmpty || t.startsWith('St-Takla.org') || t.contains('صورة في موقع الأنبا تكلا')) return;
    final isVerse = RegExp(r'^(الآيات?|الآية|الآيه|آيات|آية|آيه)\s*[\(:]?\s*\d').hasMatch(t);
    out.add(Block(isVerse ? BlockKind.verse : BlockKind.para, t));
  }
  void para(String raw) {
    for (final piece in raw.split('¶')) {
      if (stop) return;
      addPara(piece);
    }
  }
  void walk(List<dom.Node> nodes) {
    for (final n in nodes) {
      if (stop) return;
      if (n is dom.Text) {
        para(n.text);
      } else if (n is dom.Element) {
        final t = clean(n.text);
        switch (n.localName) {
          case 'form' || 'hr':
            stop = true;
          case 'h1':
            if (t.isNotEmpty) out.add(Block(BlockKind.h1, t));
          case 'h2':
            // اسم الموقع في أول الصفحة مش من التفسير
            if (t.isNotEmpty && !t.startsWith('شرح الكتاب المقدس') && !t.startsWith('تفسير الكتاب المقدس')) {
              out.add(Block(BlockKind.h2, t));
            }
          case 'h3' || 'h4' || 'h5':
            if (t.isNotEmpty) out.add(Block(BlockKind.h3, t));
          case 'p':
            if (!t.startsWith('اذهب')) para(n.text);
          case 'ul' || 'ol':
            for (final li in n.querySelectorAll('li')) {
              final x = clean(li.text);
              if (x.isNotEmpty) out.add(Block(BlockKind.bullet, x));
            }
          case 'table':
            if (t.startsWith('اضغط هنا') || t.contains('اذهب مباشرة')) break;
            for (final tr in n.querySelectorAll('tr')) {
              final x = clean(tr.text);
              if (x.isNotEmpty) para(x);
            }
          case 'span' || 'font' || 'b' || 'i' || 'em' || 'strong' || 'a':
            if (t.isEmpty || t.startsWith('St-Takla.org') || t.startsWith('صورة في موقع الأنبا تكلا')) break;
            // وسم مفتوح بيبلع فقرات كاملة: ندخل جواه بدل ما نعامله فقرة واحدة
            if (n.querySelector('p, div, table, ul, ol, h1, h2, h3, h4') != null) {
              walk(n.nodes);
            } else {
              para(n.text);
            }
          case 'div' || 'section' || 'center' || 'blockquote':
            // تذييل «قسم تفاسير…»
            if (t.length < 300 && t.contains('قسم تفاسير')) break;
            walk(n.nodes);
          default:
            break;
        }
      }
    }
  }

  walk(body.nodes);
  // تنظيف: تكرار متتالي، وأسطر التنقل
  final res = <Block>[];
  for (final b in out) {
    if (res.isNotEmpty && res.last.text == b.text) continue;
    if (b.text.startsWith('اضغط هنا لإظهار الفهرس')) continue;
    res.add(b);
  }
  return res;
}

/// جلب صفحات التفسير مع حفظها على الجهاز، فتتفتح بعد كده من غير نت.
class CommentaryRepository {
  CommentaryRepository._();
  static final instance = CommentaryRepository._();
  Directory? _dir;

  Future<Directory> _cacheDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final d = Directory(p.join(base.path, 'fekry'));
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  File _file(Directory d, String key) => File(p.join(d.path, '${key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.json'));

  Future<bool> isCached(StudyDoc doc) async => _file(await _cacheDir(), doc.key).exists();

  Future<List<Block>> load(StudyDoc doc, {bool forceRefresh = false}) async {
    final f = _file(await _cacheDir(), doc.key);
    if (!forceRefresh && await f.exists()) {
      try {
        final j = jsonDecode(await f.readAsString()) as List;
        return [for (final e in j) Block.fromJson(e as Map<String, dynamic>)];
      } catch (_) {/* ملف تالف: نجيبه تاني */}
    }
    final r = await getRaw(doc.url);
    if (r.statusCode >= 400) throw HttpStatusError(r.statusCode);
    String text;
    try {
      text = utf8.decode(r.bodyBytes);
    } on FormatException {
      text = decodeWindows1256(r.bodyBytes);
    }
    final blocks = parseCommentary(text);
    if (blocks.length < 2) throw const FormatException('empty commentary');
    await f.writeAsString(jsonEncode([for (final b in blocks) b.toJson()]));
    return blocks;
  }
}


/// الأصحاح الجاي في الدراسة: اللي بعد آخر حاجة فتحها الدارس، أو أول أصحاح لسه ماخلّصوش في نفس السفر.
/// لو ماحدش بدأ: إنجيل يوحنا. بيرجّع الوثائق والترتيب والسفر عشان يفتح القارئ.
Future<({StudyBook book, List<StudyDoc> docs, int index, int chapter})?> nextStudyChapter() async {
  final cat = await StudyCatalog.load();
  final prog = await StudyProgress.load();
  final lastKey = prog.last;
  final book = (lastKey == null ? null : cat.byId(lastKey.split(':').first)) ?? cat.byId('jhn');
  if (book == null) return null;
  var chapter = 1;
  final last = lastKey == null ? null : int.tryParse(lastKey.split(':').last);
  if (last != null && lastKey!.startsWith('${book.id}:')) {
    // نكمّل من اللي بعد آخر أصحاح (لو خلصناه)، وإلا نفس الأصحاح
    chapter = prog.isDone('${book.id}:$last') ? last + 1 : last;
  }
  if (chapter > book.chapters || prog.isDone('${book.id}:$chapter')) {
    final undone = [for (var i = 1; i <= book.chapters; i++) if (!prog.isDone('${book.id}:$i')) i];
    if (undone.isEmpty) return null;
    chapter = undone.first;
  }
  final docs = [
    if (book.intro != null) cat.intro(book),
    for (var i = 1; i <= book.chapters; i++) cat.chapter(book, i),
  ];
  return (book: book, docs: docs, index: (book.intro != null ? 1 : 0) + chapter - 1, chapter: chapter);
}
