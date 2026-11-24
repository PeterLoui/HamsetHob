import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/coptic.dart';
import 'bible.dart';

/// آية بتتحفظ: صندوقها (٠–٦) بيحدد بعد كام يوم تتراجع، وكل مراجعة صح بتطلّعها صندوق.
class MemoryVerse {
  MemoryVerse({required this.ref, required this.text, this.box = 0, DateTime? due, DateTime? added})
      : due = due ?? dateOnly(DateTime.now()),
        added = added ?? DateTime.now();
  final VerseRef ref;
  final String text;
  int box;
  DateTime due;
  final DateTime added;

  Map<String, dynamic> toJson() =>
      {'b': ref.book, 'c': ref.chapter, 'v': ref.verse, 't': text, 'x': box, 'd': due.toIso8601String(), 'a': added.toIso8601String()};

  factory MemoryVerse.fromJson(Map<String, dynamic> o) => MemoryVerse(
        ref: VerseRef(o['b'] as int, o['c'] as int, o['v'] as int),
        text: o['t'] as String,
        box: o['x'] as int,
        due: DateTime.parse(o['d'] as String),
        added: DateTime.parse(o['a'] as String),
      );
}

/// قايمة الآيات اللي بتحفظها ومواعيد مراجعتها (تكرار متباعد: بتظهر قبل ما تنساها).
class MemoryStore extends ChangeNotifier {
  MemoryStore._(this._prefs) {
    final raw = jsonDecode(_prefs.getString('memory_verses') ?? '[]') as List;
    items.addAll(raw.map((o) => MemoryVerse.fromJson(o as Map<String, dynamic>)));
  }
  final SharedPreferences _prefs;
  final items = <MemoryVerse>[];
  static MemoryStore? instance;

  static Future<MemoryStore> load() async => instance ??= MemoryStore._(await SharedPreferences.getInstance());

  /// الأيام بين المراجعات لكل صندوق.
  static const intervals = [1, 2, 4, 8, 16, 32, 64];
  static const topBox = 6;

  bool contains(VerseRef ref) => items.any((m) => m.ref == ref);

  Future<void> _save() async {
    await _prefs.setString('memory_verses', jsonEncode([for (final m in items) m.toJson()]));
    notifyListeners();
  }

  Future<void> add(VerseRef ref, String text) async {
    if (contains(ref)) return;
    items.insert(0, MemoryVerse(ref: ref, text: text));
    await _save();
  }

  Future<void> remove(VerseRef ref) async {
    items.removeWhere((m) => m.ref == ref);
    await _save();
  }

  /// الآيات اللي معادها النهارده أو فات.
  List<MemoryVerse> due([DateTime? now]) {
    final today = dateOnly(now ?? DateTime.now());
    final list = items.where((m) => !m.due.isAfter(today)).toList()..sort((a, b) => a.due.compareTo(b.due));
    return list;
  }

  /// نتيجة مراجعة: [mistakes] عدد الغلطات (٠ = من غير غلط). من غير غلط بيطلع صندوق، وغلطة أو اتنين بيفضل مكانه،
  /// وأكتر من كده بيرجع لأول صندوق.
  Future<void> review(VerseRef ref, int mistakes, [DateTime? now]) async {
    final m = items.where((e) => e.ref == ref).firstOrNull;
    if (m == null) return;
    final today = dateOnly(now ?? DateTime.now());
    if (mistakes == 0) {
      m.box = math.min(m.box + 1, topBox);
    } else if (mistakes > 2) {
      m.box = 0;
    }
    m.due = today.add(Duration(days: intervals[m.box]));
    await _save();
  }
}

/// حجب كلمات من آية للتمرين: كل ما الصندوق يعلى بنخبّي أكتر. نفس الآية بنفس الصندوق في نفس اليوم بتتخبّى بنفس الشكل.
class BlankPlan {
  BlankPlan._(this.tokens, this.hidden, this.bank);

  /// كلمات الآية بعلامات الترقيم.
  final List<String> tokens;

  /// أرقام الكلمات المحجوبة بالترتيب.
  final List<int> hidden;

  /// الكلمات اللي تختار منها (المحجوبة + كلمات تشتيت)، مخلوطة.
  final List<String> bank;

  static final _punct = RegExp(r'^[\s«»"“”‘’\(\)\[\]\{\}،,.؛;:؟?!\-–—…]+|[\s«»"“”‘’\(\)\[\]\{\}،,.؛;:؟?!\-–—…]+$');

  /// الكلمة من غير علامات ترقيم.
  static String bare(String w) => w.replaceAll(_punct, '');

  /// نسبة الكلمات المحجوبة لكل صندوق.
  static double ratio(int box) => const [.25, .4, .55, .7, .85, 1.0, 1.0][box.clamp(0, 6)];

  /// من الصندوق ٤ فوق: تفتكر الآية كلها (من غير اختيار كلمات) وتقيّم نفسك.
  static bool isRecall(int box) => box >= 4;

  static const _decoys = ['الرب', 'الله', 'قلبي', 'نفسي', 'الأرض', 'السماء', 'يسوع', 'المسيح', 'الحياة', 'محبة', 'نور', 'سلام', 'كل', 'أبدا', 'ملكوت', 'الروح'];

  factory BlankPlan.make(String text, int box, {int seed = 0}) {
    final tokens = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final rnd = math.Random(seed);
    // الكلمات الطويلة أولى بالحجب (كلمات الوصل أسهل ومالهاش معنى)
    final candidates = [for (var i = 0; i < tokens.length; i++) if (bare(tokens[i]).length >= 3) i];
    final want = (candidates.length * ratio(box)).round().clamp(candidates.isEmpty ? 0 : 1, candidates.length);
    candidates.shuffle(rnd);
    final hidden = candidates.take(want).toList()..sort();
    final words = [for (final i in hidden) bare(tokens[i])];
    final present = {for (final t in tokens) bare(t)};
    final decoys = _decoys.where((d) => !present.contains(d)).toList()..shuffle(rnd);
    final bank = [...words, ...decoys.take(2)]..shuffle(rnd);
    return BlankPlan._(tokens, hidden, bank);
  }
}

/// آيات الأسبوع (آيات معروفة للحفظ)، بالترتيب: ٣٠ آية بنمشي عليها أسبوع أسبوع.
const weeklyVerses = <VerseRef>[
  VerseRef(43, 3, 16), VerseRef(19, 23, 1), VerseRef(50, 4, 13), VerseRef(20, 3, 5), VerseRef(23, 41, 10),
  VerseRef(40, 6, 33), VerseRef(45, 8, 28), VerseRef(43, 14, 6), VerseRef(19, 119, 105), VerseRef(62, 4, 8),
  VerseRef(40, 11, 28), VerseRef(23, 40, 31), VerseRef(46, 13, 4), VerseRef(50, 4, 6), VerseRef(43, 8, 12),
  VerseRef(19, 46, 1), VerseRef(40, 5, 16), VerseRef(48, 2, 20), VerseRef(58, 11, 1), VerseRef(59, 1, 5),
  VerseRef(19, 27, 1), VerseRef(43, 15, 5), VerseRef(45, 12, 2), VerseRef(23, 26, 3), VerseRef(40, 28, 20),
  VerseRef(19, 121, 1), VerseRef(43, 1, 12), VerseRef(51, 3, 23), VerseRef(46, 10, 31), VerseRef(62, 1, 9),
];

/// آية الأسبوع الحالي (بتتغير كل أسبوع).
VerseRef weeklyVerse([DateTime? now]) {
  final days = dateOnly(now ?? DateTime.now()).difference(DateTime.utc(2024, 1, 1)).inDays;
  return weeklyVerses[(days ~/ 7) % weeklyVerses.length];
}
