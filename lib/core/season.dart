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

/// الصوم الكبير ٥٥ يوم: من اثنين قبل القيامة بـ٥٥ يوم لحد سبت النور. الأسبوع التمهيدي (٦ أيام) ثم ستة أسابيع
/// (كل أسبوع من الأحد للسبت، وأحده له اسمه وإنجيله)، وآخرها أسبوع البصخة اللي بيبدأ بأحد الشعانين.
class LentSeason {
  const LentSeason._(this.offset);

  /// الأيام من عيد القيامة: سالب قبله، وصفر يوم القيامة.
  final int offset;

  static const length = 55;

  /// أسماء الأسابيع، وأسماء أحادها (الأحد الأول بيبدأ الأسبوع الأول).
  static const weekNames = ['الأسبوع التمهيدي', 'الأسبوع الأول', 'الأسبوع الثاني', 'الأسبوع الثالث', 'الأسبوع الرابع', 'الأسبوع الخامس', 'الأسبوع السادس', 'أسبوع البصخة'];
  static const sundayNames = ['', 'أحد الكنوز', 'أحد التجربة', 'أحد الابن الضال', 'أحد السامرية', 'أحد المخلع', 'أحد المولود أعمى', 'أحد الشعانين'];
  static const weekDays = [6, 7, 7, 7, 7, 7, 7, 7];

  /// ١–٥٥ أثناء الصوم، وإلا ٠.
  int get dayOfLent => offset >= -55 && offset <= -1 ? offset + 56 : 0;
  bool get inLent => dayOfLent > 0;

  /// أسبوع الصوم (٠ تمهيدي … ٧ البصخة)، أو -1 خارج الصوم.
  int get week => !inLent ? -1 : (offset < -49 ? 0 : (offset + 49) ~/ 7 + 1);

  /// اليوم داخل الأسبوع (١…).
  int get dayInWeek => !inLent ? 0 : (week == 0 ? offset + 56 : (offset + 49) % 7 + 1);

  bool get holyWeek => offset >= -7 && offset <= -1;
  bool get lazarusSaturday => offset == -8;
  bool get isSunday => week >= 1 && dayInWeek == 1;

  /// أسبوع القيامة: من يوم القيامة لسبت الفرح.
  bool get easterWeek => offset >= 0 && offset <= 6;

  bool get active => inLent || easterWeek;

  /// قبل بداية الصوم بأسبوع: عدّاد.
  int get daysToStart => offset >= -62 && offset < -55 ? -55 - offset : 0;
  bool get comingSoon => daysToStart > 0;

  int get daysToEaster => offset < 0 ? -offset : 0;

  String get weekName => week < 0 ? '' : weekNames[week];
  String get sundayName => week < 0 ? '' : sundayNames[week];

  /// اسم اليوم في أسبوع البصخة وسبت لعازر.
  static const holyDayNames = {
    -8: 'سبت لعازر',
    -7: 'أحد الشعانين',
    -6: 'اثنين البصخة',
    -5: 'ثلاثاء البصخة',
    -4: 'أربعاء البصخة',
    -3: 'خميس العهد',
    -2: 'الجمعة العظيمة',
    -1: 'سبت النور',
  };

  factory LentSeason.of(DateTime date) {
    final easter = copticEaster(date.year);
    return LentSeason._(daysBetween(easter, date));
  }

  /// تاريخ يوم من أيام البصخة (offset من -8 لـ ٠).
  static DateTime dateOfOffset(int year, int off) => copticEaster(year).add(Duration(days: off));

  /// آية اليوم: صوم وتوبة، وفي البصخة آلام، وفي القيامة قيامة.
  static VerseRef? verseFor(LentSeason s) {
    if (s.holyWeek) return passionVerses[s.offset + 7];
    if (s.easterWeek) return resurrectionVerses[s.offset];
    if (s.inLent) return lentVerses[(s.dayOfLent - 1) % lentVerses.length];
    return null;
  }
}

const lentVerses = <VerseRef>[
  VerseRef(29, 2, 12), // ارجعوا إليّ بكل قلوبكم
  VerseRef(19, 51, 10), // قلباً نقياً
  VerseRef(19, 51, 17), // ذبائح الله روح منكسرة
  VerseRef(23, 58, 6), // الصوم الذي اختاره
  VerseRef(23, 55, 7), // فيرحمه
  VerseRef(28, 6, 1), // هلم نرجع إلى الرب
  VerseRef(32, 3, 5), // آمن أهل نينوى
  VerseRef(33, 6, 8), // ما هو صالح
  VerseRef(40, 4, 4), // ليس بالخبز وحده
  VerseRef(40, 6, 6), // صلّ إلى أبيك في الخفاء
  VerseRef(40, 6, 18), // الصوم في الخفاء
  VerseRef(40, 6, 21), // حيث كنزك
  VerseRef(40, 6, 33), // اطلبوا أولاً ملكوت الله
  VerseRef(40, 7, 7), // اسألوا تعطوا
  VerseRef(41, 1, 15), // توبوا وآمنوا
  VerseRef(42, 9, 23), // يحمل صليبه
  VerseRef(42, 15, 18), // أقوم وأذهب إلى أبي
  VerseRef(42, 15, 20), // ركض ووقع على عنقه
  VerseRef(43, 4, 14), // الماء الحي
  VerseRef(43, 9, 25), // كنت أعمى والآن أبصر
  VerseRef(45, 12, 1), // ذبيحة حية
  VerseRef(47, 7, 10), // الحزن الذي بحسب مشيئة الله
  VerseRef(48, 2, 20), // مع المسيح صلبت
  VerseRef(48, 6, 14), // حاشا لي أن أفتخر إلا بصليب
  VerseRef(49, 5, 14), // استيقظ أيها النائم
  VerseRef(50, 3, 10), // لأعرفه وقوة قيامته
  VerseRef(50, 4, 6), // لا تهتموا بشيء
  VerseRef(58, 12, 2), // ناظرين إلى يسوع
  VerseRef(59, 4, 8), // اقتربوا إلى الله
  VerseRef(62, 1, 9), // إن اعترفنا بخطايانا
];

/// آيات أسبوع البصخة، من أحد الشعانين (٠) لسبت النور (٦).
const passionVerses = <VerseRef>[
  VerseRef(40, 21, 9), // أحد الشعانين: أوصنا
  VerseRef(41, 11, 17), // الاثنين: بيتي بيت الصلاة
  VerseRef(40, 24, 42), // الثلاثاء: اسهروا
  VerseRef(40, 26, 12), // الأربعاء: الطيب لدفني
  VerseRef(42, 22, 19), // الخميس: هذا هو جسدي
  VerseRef(43, 19, 30), // الجمعة: قد أُكمل
  VerseRef(23, 53, 5), // السبت: بجراحه شفينا
];

/// آيات القيامة، من الأحد (٠) للسبت (٦).
const resurrectionVerses = <VerseRef>[
  VerseRef(40, 28, 6), // ليس هو ههنا لأنه قام
  VerseRef(42, 24, 5), // لماذا تطلبون الحي
  VerseRef(43, 20, 19), // سلام لكم
  VerseRef(46, 15, 20), // باكورة الراقدين
  VerseRef(45, 6, 4), // نسلك في جدة الحياة
  VerseRef(66, 1, 18), // أنا هو الحي
  VerseRef(43, 11, 25), // أنا هو القيامة والحياة
];
