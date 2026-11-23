import '../data/bible.dart';
import 'coptic.dart';

/// موسم الميلاد: صوم الميلاد ٤٣ يوم من ١٦ هاتور إلى ٢٨ كيهك، والعيد ٢٩ كيهك، وأيام العيد لحد ٥ طوبة.
class NativitySeason {
  const NativitySeason._(this.dayOfFast, this.daysToFast, this.feast);

  /// ١–٤٣ أثناء الصوم، وإلا ٠.
  final int dayOfFast;

  /// عدد الأيام لبداية الصوم لو فاضل أسبوع أو أقل (وإلا ٠).
  final int daysToFast;

  /// من ٢٩ كيهك لحد ٥ طوبة.
  final bool feast;

  static const fastLength = 43;

  bool get inFast => dayOfFast > 0;
  bool get active => inFast || feast;
  bool get comingSoon => daysToFast > 0;

  /// الأيام اللي باقية على عيد الميلاد (٢٩ كيهك).
  int get daysToFeast => inFast ? fastLength + 1 - dayOfFast : 0;

  factory NativitySeason.of(DateTime date) {
    final c = CopticDate.fromGregorian(date);
    // كل الشهور القبطية ٣٠ يوم، فترتيب اليوم من بداية هاتور
    final dayInYear = (c.month - 1) * 30 + c.day;
    const fastStart = 2 * 30 + 16; // ١٦ هاتور
    final idx = dayInYear - fastStart + 1;
    if (c.month <= 5 && idx >= 1 && idx <= fastLength) return NativitySeason._(idx, 0, false);
    final feastStart = 3 * 30 + 29; // ٢٩ كيهك
    final feastEnd = 4 * 30 + 5; // ٥ طوبة
    if (c.month <= 5 && dayInYear >= feastStart && dayInYear <= feastEnd) return const NativitySeason._(0, 0, true);
    final before = fastStart - dayInYear;
    if (c.month <= 3 && before >= 1 && before <= 7) return NativitySeason._(0, before, false);
    return const NativitySeason._(0, 0, false);
  }

  /// آية اليوم في الصوم: بالترتيب على نبوات الميلاد وبشارته.
  static VerseRef verseForDay(int dayOfFast, {int shift = 0}) =>
      nativityVerses[(dayOfFast - 1 + shift) % nativityVerses.length];
}

/// نبوات الميلاد وبشارته (أرقام الأسفار حسب كتاب التطبيق).
const nativityVerses = <VerseRef>[
  VerseRef(1, 3, 15), // نسل المرأة
  VerseRef(1, 12, 3), // بك تتبارك جميع قبائل الأرض
  VerseRef(1, 22, 18), // نسلك
  VerseRef(4, 24, 17), // يبرز كوكب من يعقوب
  VerseRef(5, 18, 15), // نبياً مثلي
  VerseRef(10, 7, 12), // ابن داود
  VerseRef(19, 2, 7), // أنت ابني
  VerseRef(19, 72, 11), // يسجد له كل الملوك
  VerseRef(23, 7, 14), // العذراء تحبل
  VerseRef(23, 9, 6), // ولد لنا ولد
  VerseRef(23, 11, 1), // غصن من جذع يسى
  VerseRef(23, 40, 3), // صوت صارخ في البرية
  VerseRef(24, 23, 5), // غصن بار
  VerseRef(27, 7, 14), // سلطان أبدي
  VerseRef(33, 5, 2), // بيت لحم أفراثة
  VerseRef(38, 9, 9), // ملكك يأتي إليك
  VerseRef(39, 3, 1), // أرسل ملاكي
  VerseRef(40, 1, 23), // عمانوئيل
  VerseRef(42, 1, 31), // ستحبلين وتلدين ابناً
  VerseRef(42, 1, 46), // تعظم نفسي الرب
  VerseRef(42, 2, 10), // أبشركم بفرح عظيم
  VerseRef(42, 2, 11), // وُلد لكم اليوم مخلص
  VerseRef(42, 2, 14), // المجد لله في الأعلى
  VerseRef(43, 1, 14), // الكلمة صار جسداً
  VerseRef(48, 4, 4), // ملء الزمان
  VerseRef(50, 2, 7), // أخلى نفسه
  VerseRef(56, 2, 11), // ظهرت نعمة الله
  VerseRef(54, 3, 16), // الله ظهر في الجسد
];
