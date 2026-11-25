import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bible.dart';

enum ThemeChoice {
  system('تلقائي'),
  light('فاتح'),
  dark('داكن');

  const ThemeChoice(this.label);
  final String label;
}

/// إعدادات التطبيق، تُحفظ فور تغييرها.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);
  final SharedPreferences _prefs;
  static late AppSettings instance;

  static Future<void> load() async => instance = AppSettings._(await SharedPreferences.getInstance());

  ThemeChoice get theme => ThemeChoice.values.byName(_prefs.getString('theme') ?? 'system');
  set theme(ThemeChoice v) => _set(() => _prefs.setString('theme', v.name));

  bool get scriptureFont => _prefs.getBool('amiri') ?? true;
  set scriptureFont(bool v) => _set(() => _prefs.setBool('amiri', v));

  /// لون التظليل في الوضع الفاتح (رقم من AppColors.lightAccents). ٠ = النبيتي الأصلي.
  int get lightAccent => (_prefs.getInt('light_accent') ?? 0).clamp(0, 99);
  set lightAccent(int v) => _set(() => _prefs.setInt('light_accent', v));

  /// مقياس حجم خط القراءة في كل الشاشات (الكتاب، الأجبية، القداس، التأمل، السنكسار، التسبحة).
  double get readingScale => _prefs.getDouble('reading_scale') ?? 1.0;
  set readingScale(double v) => _set(() => _prefs.setDouble('reading_scale', v.clamp(0.8, 1.7)));

  /// القبطي المعرّب (بحروف عربية) في الخولاجي والتسبحة، في مربع منفصل تحت العربي.
  bool get showCoptic => _prefs.getBool('show_coptic') ?? (_prefs.getBool('tasbeha_show_coptic') ?? true);
  set showCoptic(bool v) => _set(() => _prefs.setBool('show_coptic', v));

  /// الجولة التعريفية اتشافت؟ (أول تشغيل بس)
  bool get introSeen => _prefs.getBool('intro_seen') ?? false;
  set introSeen(bool v) => _prefs.setBool('intro_seen', v);

  bool get lockNotification => _prefs.getBool('lock_notif') ?? true;
  set lockNotification(bool v) => _set(() => _prefs.setBool('lock_notif', v));

  bool get morningEnabled => _prefs.getBool('morning') ?? false;
  set morningEnabled(bool v) => _set(() => _prefs.setBool('morning', v));

  /// الضوء اللي بيتحرك مع الصوت يتزامن مع الإيقاع الحقيقي (محتاج إذن الميكروفون).
  bool get syncLight => _prefs.getBool('sync_light') ?? false;
  set syncLight(bool v) => _set(() => _prefs.setBool('sync_light', v));

  int get morningMinutes => _prefs.getInt('morning_at') ?? 7 * 60;
  set morningMinutes(int v) => _set(() => _prefs.setInt('morning_at', v));

  /// البحث في الصور (Brave) كاحتياطي لصور التذكار: مفتاح الـAPI من حساب المستخدم، ومحفوظ على جهازه بس.
  String get searchKey => _prefs.getString('br_key') ?? '';
  set searchKey(String v) => _set(() => _prefs.setString('br_key', v.trim()));
  /// ٠ SerpApi (صور جوجل)، ١ Brave Search.
  int get searchProvider => (_prefs.getInt('sr_provider') ?? 0).clamp(0, 1);
  set searchProvider(int v) => _set(() => _prefs.setInt('sr_provider', v));
  bool get searchFallback => _prefs.getBool('br_on') ?? true;
  set searchFallback(bool v) => _set(() => _prefs.setBool('br_on', v));

  /// فحص إصدارات GitHub وتعريف المستخدم بالنسخة الجديدة.
  bool get autoUpdate => _prefs.getBool('auto_update') ?? true;
  set autoUpdate(bool v) => _set(() => _prefs.setBool('auto_update', v));

  /// تضمين الإصدارات التجريبية (بناء الفروع قيد التطوير، مش بس main).
  bool get betaUpdates => _prefs.getBool('beta_updates') ?? true;
  set betaUpdates(bool v) => _set(() => _prefs.setBool('beta_updates', v));

  // ── تذكيرات الصلاة والأعياد ──
  bool hourOn(String id) => _prefs.getBool('rem_$id') ?? false;
  void setHourOn(String id, bool v) => _set(() => _prefs.setBool('rem_$id', v));
  int hourAt(String id, int fallback) => _prefs.getInt('rem_at_$id') ?? fallback;
  void setHourAt(String id, int minutes) => _set(() => _prefs.setInt('rem_at_$id', minutes));

  /// تنبيه مساء اليوم السابق للأعياد وبدايات الأصوام.
  bool get feastReminders => _prefs.getBool('rem_feast') ?? false;
  set feastReminders(bool v) => _set(() => _prefs.setBool('rem_feast', v));

  int get feastAt => _prefs.getInt('rem_feast_at') ?? 20 * 60;
  set feastAt(int v) => _set(() => _prefs.setInt('rem_feast_at', v));

  void _set(Future<bool> Function() write) {
    write();
    notifyListeners();
  }
}

class Favorite {
  const Favorite(this.ref, this.text);
  final VerseRef ref;
  final String text;
}

/// علامات الكتاب المقدس: آخر موضع قراءة، العلامات المرجعية على الإصحاحات، وتظليل الآيات بألوان.
class BibleMarks extends ChangeNotifier {
  BibleMarks._(this._prefs) {
    for (final o in jsonDecode(_prefs.getString('bible_bookmarks') ?? '[]') as List) {
      _bookmarks.add(_chapterKey(o['b'] as int, o['c'] as int));
    }
    (jsonDecode(_prefs.getString('bible_highlights') ?? '{}') as Map).forEach((k, v) => highlights[k as String] = v as int);
  }
  final SharedPreferences _prefs;
  static late BibleMarks instance;

  static Future<void> load() async => instance = BibleMarks._(await SharedPreferences.getInstance());

  // ── آخر موضع قراءة ──
  VerseRef? get lastRead {
    final p = (_prefs.getString('bible_last') ?? '').split('.');
    if (p.length != 3) return null;
    final n = p.map(int.tryParse).toList();
    return n.any((x) => x == null) ? null : VerseRef(n[0]!, n[1]!, n[2]!);
  }

  void saveLast(int book, int chapter, int verse) => _prefs.setString('bible_last', '$book.$chapter.$verse');

  // ── العلامات المرجعية (سفر.إصحاح) ──
  final _bookmarks = <String>{};
  static String _chapterKey(int b, int c) => '$b.$c';

  bool isBookmarked(int b, int c) => _bookmarks.contains(_chapterKey(b, c));

  /// العلامات كمراجع (الآية ٠ = الإصحاح كله)، بترتيب السفر ثم الإصحاح.
  List<VerseRef> get bookmarks {
    final list = _bookmarks.map((k) {
      final p = k.split('.');
      return VerseRef(int.parse(p[0]), int.parse(p[1]), 0);
    }).toList();
    list.sort((a, b) => a.book != b.book ? a.book - b.book : a.chapter - b.chapter);
    return list;
  }

  void toggleBookmark(int book, int chapter) {
    final k = _chapterKey(book, chapter);
    if (!_bookmarks.remove(k)) _bookmarks.add(k);
    _prefs.setString('bible_bookmarks', jsonEncode([
      for (final k in _bookmarks) {'b': int.parse(k.split('.')[0]), 'c': int.parse(k.split('.')[1])},
    ]));
    notifyListeners();
  }

  // ── تظليل الآيات (سفر.إصحاح.آية → رقم اللون) ──
  final highlights = <String, int>{};
  static String _verseKey(VerseRef r) => '${r.book}.${r.chapter}.${r.verse}';

  int? highlightOf(VerseRef r) => highlights[_verseKey(r)];

  void setHighlight(VerseRef r, int? color) {
    final k = _verseKey(r);
    if (color == null) {
      highlights.remove(k);
    } else {
      highlights[k] = color;
    }
    _prefs.setString('bible_highlights', jsonEncode(highlights));
    notifyListeners();
  }
}

/// تقدّم خطط قراءة الكتاب: أيام كل خطة اللي اتقرأت.
class ReadingProgress extends ChangeNotifier {
  ReadingProgress._(this._prefs);
  final SharedPreferences _prefs;
  static late ReadingProgress instance;

  static Future<void> load() async => instance = ReadingProgress._(await SharedPreferences.getInstance());

  Set<int> done(String planId) =>
      ((jsonDecode(_prefs.getString('plan_$planId') ?? '[]')) as List).map((e) => e as int).toSet();

  bool isDone(String planId, int day) => done(planId).contains(day);

  int completed(String planId) => done(planId).length;

  /// أول يوم لسه ماتقراش (= عدد الأيام يعني الخطة خلصت).
  int currentDay(String planId, int total) {
    final s = done(planId);
    for (var i = 0; i < total; i++) {
      if (!s.contains(i)) return i;
    }
    return total;
  }

  void setDone(String planId, int day, bool value) {
    final s = done(planId);
    if (value) {
      s.add(day);
    } else {
      s.remove(day);
    }
    _prefs.setString('plan_$planId', jsonEncode(s.toList()..sort()));
    notifyListeners();
  }
}

/// الآيات المحفوظة، الأحدث أولاً.
class Favorites extends ChangeNotifier {
  Favorites._(this._prefs) {
    final raw = jsonDecode(_prefs.getString('favorites') ?? '[]') as List;
    items.addAll(raw.map((o) => Favorite(VerseRef(o['b'] as int, o['c'] as int, o['v'] as int), o['t'] as String)));
  }
  final SharedPreferences _prefs;
  final items = <Favorite>[];
  static late Favorites instance;

  static Future<void> load() async => instance = Favorites._(await SharedPreferences.getInstance());

  bool contains(VerseRef ref) => items.any((f) => f.ref == ref);

  void toggle(VerseRef ref, String text) {
    if (contains(ref)) {
      items.removeWhere((f) => f.ref == ref);
    } else {
      items.insert(0, Favorite(ref, text));
    }
    _prefs.setString(
      'favorites',
      jsonEncode([for (final f in items) {'b': f.ref.book, 'c': f.ref.chapter, 'v': f.ref.verse, 't': f.text}]),
    );
    notifyListeners();
  }
}
