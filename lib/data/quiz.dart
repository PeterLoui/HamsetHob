import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wird.dart';

class QuizCategory {
  const QuizCategory(this.id, this.name);
  final String id, name;
}

class QuizTopic {
  const QuizTopic(this.index, this.id, this.name, this.category, this.count);
  final int index, count;
  final String id, name, category;
}

class QuizQuestion {
  const QuizQuestion(this.id, this.topic, this.question, this.answer, this.books);
  final int id, topic;
  final String question, answer;

  /// أسفار الإجابة (معرّفات زي gen أو mat) لما الإجابة بتشير لشواهد.
  final List<String> books;
}

class QuizBank {
  QuizBank._(this.source, this.categories, this.topics, this.questions);
  final String source;
  final List<QuizCategory> categories;
  final List<QuizTopic> topics;
  final List<QuizQuestion> questions;

  static QuizBank? _cache;
  static Future<QuizBank> load() async =>
      _cache ??= parse(await rootBundle.loadString('assets/study_quiz.json'));

  static QuizBank parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final topics = <QuizTopic>[
      for (var i = 0; i < (j['topics'] as List).length; i++)
        QuizTopic(i, j['topics'][i]['id'], j['topics'][i]['n'], j['topics'][i]['c'], j['topics'][i]['q']),
    ];
    final qs = <QuizQuestion>[
      for (var i = 0; i < (j['q'] as List).length; i++)
        QuizQuestion(i, j['q'][i][0], j['q'][i][1], j['q'][i][2], [for (final b in j['q'][i][3] as List) b as String]),
    ];
    return QuizBank._(
      j['src'],
      [for (final c in j['cats'] as List) QuizCategory(c[0], c[1])],
      topics,
      qs,
    );
  }

  List<QuizQuestion> inTopic(int t) => questions.where((q) => q.topic == t).toList();
  List<QuizQuestion> inBook(String bookId) => questions.where((q) => q.books.contains(bookId)).toList();
  int countForBook(String bookId) => questions.where((q) => q.books.contains(bookId)).length;
}

/// نتيجة الدارس: الأسئلة اللي «عرفها» والأسئلة اللي عايز يراجعها.
class QuizProgress extends ChangeNotifier {
  QuizProgress._(this._prefs)
      : _known = {...?_prefs.getStringList('quiz_known')},
        _review = {...?_prefs.getStringList('quiz_review')};
  final SharedPreferences _prefs;
  final Set<String> _known, _review;
  static QuizProgress? instance;
  static Future<QuizProgress> load() async => instance ??= QuizProgress._(await SharedPreferences.getInstance());

  bool isKnown(int id) => _known.contains('$id');
  bool inReview(int id) => _review.contains('$id');
  int get known => _known.length;
  int get review => _review.length;
  int knownIn(Iterable<QuizQuestion> qs) => qs.where((q) => isKnown(q.id)).length;

  Future<void> record(int id, {required bool knew}) async {
    WirdStore.markIf(WirdItem.quiz);
    if (knew) {
      _known.add('$id');
      _review.remove('$id');
    } else {
      _known.remove('$id');
      _review.add('$id');
    }
    await _prefs.setStringList('quiz_known', _known.toList());
    await _prefs.setStringList('quiz_review', _review.toList());
    notifyListeners();
  }

  Future<void> reset() async {
    _known.clear();
    _review.clear();
    await _prefs.remove('quiz_known');
    await _prefs.remove('quiz_review');
    notifyListeners();
  }
}

/// ترتيب جلسة أسئلة: اللي مراجعته مطلوبة الأول، وبعدها اللي لسه ماتجاوبش، وآخرها اللي اتعرف.
List<QuizQuestion> buildSession(List<QuizQuestion> pool, QuizProgress progress, {int size = 10, Random? rnd}) {
  final r = rnd ?? Random();
  final review = pool.where((q) => progress.inReview(q.id)).toList()..shuffle(r);
  final fresh = pool.where((q) => !progress.isKnown(q.id) && !progress.inReview(q.id)).toList()..shuffle(r);
  final known = pool.where((q) => progress.isKnown(q.id)).toList()..shuffle(r);
  return [...review, ...fresh, ...known].take(size).toList();
}
