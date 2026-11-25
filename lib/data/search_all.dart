import 'prayers.dart';
import 'net.dart' show normalizeArabic;
import 'quiz.dart';
import 'study.dart';
import '../core/synaxarium.dart';

/// نتيجة بحث محلية (من غير شبكة) في الأجبية والسنكسار والدراسة والمسابقات.
class LocalHit<T> {
  const LocalHit(this.item, this.title, this.subtitle);
  final T item;
  final String title;
  final String subtitle;
}

/// كلمات البحث: من غير تشكيل والألف والياء والتاء المربوطة موحّدين. كل الكلمات لازم تكون موجودة.
List<String> searchWords(String q) => normalizeArabic(q).split(RegExp(r'\s+')).where((w) => w.length > 1).toList();

bool _all(String text, List<String> words) => words.every(text.contains);

String _snippet(String text, String word, {int radius = 45}) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ');
  final at = normalizeArabic(flat).indexOf(word);
  if (at < 0) return flat.length > radius * 2 ? '${flat.substring(0, radius * 2)}…' : flat;
  final from = (at - radius).clamp(0, flat.length);
  final to = (at + word.length + radius).clamp(0, flat.length);
  return '${from > 0 ? '…' : ''}${flat.substring(from, to)}${to < flat.length ? '…' : ''}';
}

class LocalSearch {
  LocalSearch._();

  /// الأجبية: العنوان أو أي قسم من نص الصلاة.
  static List<LocalHit<Prayer>> prayers(Agpeya agpeya, String query, {int limit = 30}) {
    final words = searchWords(query);
    if (words.isEmpty) return const [];
    final byTitle = <LocalHit<Prayer>>[], byText = <LocalHit<Prayer>>[];
    for (final p in [...agpeya.hours, ...agpeya.others]) {
      final title = normalizeArabic('${p.title} ${p.subtitle ?? ''}');
      if (_all(title, words)) {
        byTitle.add(LocalHit(p, p.title, p.subtitle ?? ''));
        continue;
      }
      for (final s in p.sections) {
        if (_all(normalizeArabic('${s.title} ${s.text}'), words)) {
          byText.add(LocalHit(p, p.title, _snippet(s.text, words.first)));
          break;
        }
      }
    }
    return [...byTitle, ...byText].take(limit).toList();
  }

  /// فهرس الأعياد والتذكارات المعروفة (بيفتح سنكسار يومها).
  static List<LocalHit<SynaxEntry>> feasts(DateTime today, String query) {
    final words = searchWords(query);
    if (words.isEmpty) return const [];
    return [
      for (final e in Synaxarium.browse(today))
        if (_all(normalizeArabic('${e.commemoration.title} ${e.commemoration.detail}'), words))
          LocalHit(e, e.commemoration.title, e.commemoration.detail),
    ];
  }

  /// أسفار الدراسة بالاسم.
  static List<LocalHit<StudyBook>> studyBooks(StudyCatalog cat, String query) {
    final words = searchWords(query);
    if (words.isEmpty) return const [];
    return [
      for (final b in cat.books)
        if (_all(normalizeArabic('${b.name} ${b.short}'), words)) LocalHit(b, b.name, 'تفسير ومقدمة القمص أنطونيوس فكري'),
    ];
  }

  /// أسئلة المسابقات: في نص السؤال أو الإجابة.
  static List<LocalHit<QuizQuestion>> questions(QuizBank bank, String query, {int limit = 30}) {
    final words = searchWords(query);
    if (words.isEmpty) return const [];
    final out = <LocalHit<QuizQuestion>>[];
    for (final q in bank.questions) {
      final text = normalizeArabic('${q.question} ${q.answer}');
      if (_all(text, words)) {
        out.add(LocalHit(q, q.question, _snippet(q.answer, words.first)));
        if (out.length >= limit) break;
      }
    }
    return out;
  }
}
