import 'coptic.dart';

enum Kind {
  feast('عيد'),
  saint('تذكار اليوم'),
  fast('صوم');

  const Kind(this.label);
  final String label;
}

class Commemoration {
  const Commemoration(this.title, this.detail, this.kind, [this.wiki, this.generic = false]);
  final String title;
  final String detail;
  final Kind kind;

  /// عنوان صفحة ويكيبيديا الإنجليزية لجلب الصورة.
  final String? wiki;

  /// تذكار عام بديل؛ يُستبدل باسم قديس اليوم من السنكسار الكامل إن توفر.
  final bool generic;
}

int _key(int m, int d) => m * 100 + d;

const _c = Commemoration.new;

final Map<int, Commemoration> _fixed = {
  // توت
  _key(1, 1): _c('عيد النيروز', 'رأس السنة القبطية وتذكار الشهداء', Kind.feast, 'Nayrouz'),
  _key(1, 2): _c('استشهاد القديس يوحنا المعمدان', 'السابق الصابغ', Kind.saint, 'John_the_Baptist'),
  _key(1, 17): _c('عيد الصليب المجيد', 'ظهور الصليب على يد الملكة هيلانة', Kind.feast, 'True_Cross'),
  _key(1, 26): _c('بشارة زكريا الكاهن', 'بميلاد القديس يوحنا المعمدان', Kind.saint, 'Zechariah_(New_Testament_figure)'),
  // بابه
  _key(2, 12): _c('استشهاد القديس متى الإنجيلي', 'أحد الاثني عشر رسولاً', Kind.saint, 'Matthew_the_Apostle'),
  _key(2, 16): _c('نياحة البابا أغاثون', 'البابا التاسع والثلاثون من باباوات الإسكندرية', Kind.saint),
  _key(2, 20): _c('نياحة القديس يحنس القصير', 'صاحب شجرة الطاعة', Kind.saint, 'John_the_Dwarf'),
  _key(2, 22): _c('استشهاد القديس لوقا الإنجيلي', 'الطبيب كاتب الإنجيل وسفر الأعمال', Kind.saint, 'Luke_the_Evangelist'),
  // هاتور
  _key(3, 9): _c('تذكار مجمع نيقية المسكوني', 'اجتماع الـ318 أباً', Kind.saint, 'First_Council_of_Nicaea'),
  _key(3, 12): _c('عيد رئيس الملائكة ميخائيل', 'رئيس جند السماء', Kind.feast, 'Michael_(archangel)'),
  _key(3, 15): _c('استشهاد القديس مار مينا العجايبي', 'صانع العجائب', Kind.saint, 'Saint_Menas'),
  _key(3, 16): _c('بداية صوم الميلاد المجيد', 'يستمر حتى ٢٨ كيهك', Kind.fast, 'Nativity_of_Jesus'),
  _key(3, 17): _c('نياحة القديس يوحنا ذهبي الفم', 'رئيس أساقفة القسطنطينية', Kind.saint, 'John_Chrysostom'),
  _key(3, 22): _c('استشهاد القديسين قزمان ودميان', 'وإخوتهما وأمهم', Kind.saint, 'Saints_Cosmas_and_Damian'),
  _key(3, 25): _c('استشهاد القديس أبي سيفين', 'فيلوباتير مرقوريوس', Kind.saint, 'Mercurius'),
  // كيهك
  _key(4, 3): _c('دخول السيدة العذراء الهيكل', 'تذكار تقدمة العذراء', Kind.feast, 'Presentation_of_Mary'),
  _key(4, 22): _c('تذكار الملاك غبريال المبشر', 'رئيس الملائكة', Kind.saint, 'Gabriel'),
  _key(4, 29): _c('عيد الميلاد المجيد', 'ميلاد ربنا يسوع المسيح بالجسد', Kind.feast, 'Nativity_of_Jesus'),
  // طوبه
  _key(5, 3): _c('تذكار أطفال بيت لحم', 'الذين قتلهم هيرودس', Kind.saint, 'Massacre_of_the_Innocents'),
  _key(5, 4): _c('نياحة القديس يوحنا الإنجيلي', 'التلميذ الذي كان يسوع يحبه', Kind.saint, 'John_the_Apostle'),
  _key(5, 6): _c('عيد الختان المجيد', 'من الأعياد السيدية الصغرى', Kind.feast, 'Circumcision_of_Jesus'),
  _key(5, 11): _c('عيد الغطاس المجيد', 'معمودية السيد المسيح في الأردن', Kind.feast, 'Baptism_of_Jesus'),
  _key(5, 13): _c('عيد عرس قانا الجليل', 'أولى معجزات السيد المسيح', Kind.feast, 'Marriage_at_Cana'),
  _key(5, 21): _c('نياحة السيدة العذراء مريم', 'والدة الإله', Kind.feast, 'Dormition_of_the_Mother_of_God'),
  _key(5, 22): _c('نياحة القديس الأنبا أنطونيوس', 'أب جميع الرهبان', Kind.saint, 'Anthony_the_Great'),
  // أمشير
  _key(6, 8): _c('دخول السيد المسيح الهيكل', 'حمله سمعان الشيخ على ذراعيه', Kind.feast, 'Presentation_of_Jesus'),
  _key(6, 30): _c('نياحة البابا كيرلس السادس', 'البابا المئة والسادس عشر', Kind.saint, 'Pope_Cyril_VI_of_Alexandria'),
  // برمهات
  _key(7, 8): _c('نياحة البابا شنوده الثالث', 'البابا المئة والسابع عشر', Kind.saint, 'Pope_Shenouda_III_of_Alexandria'),
  _key(7, 10): _c('تذكار الصليب المجيد', 'العيد الثاني للصليب', Kind.feast, 'True_Cross'),
  _key(7, 27): _c('نياحة القديس مقاريوس الكبير', 'أب برية شيهيت', Kind.saint, 'Macarius_of_Egypt'),
  _key(7, 29): _c('عيد البشارة المجيد', 'بشارة الملاك غبريال للعذراء', Kind.feast, 'Annunciation'),
  // برموده
  _key(8, 23): _c('استشهاد القديس مار جرجس', 'أمير الشهداء', Kind.saint, 'Saint_George_and_the_Dragon'),
  _key(8, 30): _c('استشهاد القديس مار مرقس الرسول', 'كاروز الديار المصرية', Kind.saint, 'Mark_the_Evangelist'),
  // بشنس
  _key(9, 7): _c('نياحة القديس أثناسيوس الرسولي', 'البابا العشرون وحامي الإيمان', Kind.saint, 'Athanasius_of_Alexandria'),
  _key(9, 24): _c('دخول السيد المسيح أرض مصر', '"مبارك شعبي مصر"', Kind.feast, 'Flight_into_Egypt'),
  // بؤونه
  _key(10, 12): _c('عيد رئيس الملائكة ميخائيل', 'تذكار تكريس كنيسته', Kind.feast, 'Michael_(archangel)'),
  _key(10, 24): _c('نياحة القديس موسى الأسود', 'القوي', Kind.saint, 'Moses_the_Black'),
  _key(10, 30): _c('ميلاد القديس يوحنا المعمدان', 'أعظم مواليد النساء', Kind.feast, 'Nativity_of_St_John_the_Baptist'),
  // أبيب
  _key(11, 3): _c('نياحة القديس كيرلس عمود الدين', 'البابا الرابع والعشرون', Kind.saint, 'Cyril_of_Alexandria'),
  _key(11, 5): _c('استشهاد القديسين بطرس وبولس', 'الرسولين العظيمين', Kind.feast, 'Saints_Peter_and_Paul'),
  _key(11, 7): _c('نياحة القديس الأنبا شنوده', 'رئيس المتوحدين', Kind.saint, 'Shenoute'),
  _key(11, 8): _c('نياحة القديس الأنبا بيشوي', 'الرجل الكامل حبيب مخلصنا', Kind.saint, 'Monastery_of_Saint_Pishoy'),
  // مسرى
  _key(12, 1): _c('بداية صوم السيدة العذراء', 'يستمر حتى ١٥ مسرى', Kind.fast, 'Theotokos'),
  _key(12, 13): _c('عيد التجلي المجيد', 'على جبل طابور', Kind.feast, 'Transfiguration_of_Jesus'),
  _key(12, 16): _c('صعود جسد السيدة العذراء', 'عيد العذراء', Kind.feast, 'Assumption_of_Mary'),
  // النسيء
  _key(13, 3): _c('تذكار الملاك رافائيل', 'رئيس الملائكة', Kind.saint, 'Raphael_(archangel)'),
};

/// الأعياد المتحركة بالأيام نسبة إلى عيد القيامة.
final Map<int, Commemoration> _movable = {
  -69: _c('بداية صوم يونان', 'صوم نينوى ثلاثة أيام', Kind.fast, 'Jonah'),
  -55: _c('بداية الصوم الكبير', 'الصوم المقدس', Kind.fast, 'Temptation_of_Christ'),
  -7: _c('أحد الشعانين', 'دخول المسيح أورشليم', Kind.feast, 'Triumphal_entry_into_Jerusalem'),
  -3: _c('خميس العهد', 'تأسيس سر الإفخارستيا', Kind.feast, 'Last_Supper'),
  -2: _c('الجمعة العظيمة', 'صلب ربنا يسوع المسيح', Kind.feast, 'Crucifixion_of_Jesus'),
  0: _c('عيد القيامة المجيد', 'خريستوس آنستي .. آليثوس آنستي', Kind.feast, 'Resurrection_of_Jesus'),
  39: _c('عيد الصعود المجيد', 'صعود السيد المسيح إلى السماء', Kind.feast, 'Ascension_of_Jesus'),
  49: _c('عيد العنصرة', 'حلول الروح القدس', Kind.feast, 'Pentecost'),
  50: _c('بداية صوم الرسل', 'يستمر حتى ٤ أبيب', Kind.fast, 'Twelve_Apostles'),
};

class Synaxarium {
  /// العيد أو بداية الصوم في هذا اليوم إن وُجد (للنتيجة).
  static Commemoration? feastOrFast(DateTime date) {
    final m = _movable[daysBetween(copticEaster(date.year), date)];
    if (m != null) return m;
    final c = CopticDate.fromGregorian(date);
    final f = _fixed[_key(c.month, c.day)];
    return f != null && f.kind != Kind.saint ? f : null;
  }

  static Commemoration forDate(DateTime date) {
    final special = feastOrFast(date);
    if (special != null) return special;
    final c = CopticDate.fromGregorian(date);
    final f = _fixed[_key(c.month, c.day)];
    if (f != null) return f;
    // تذكارات شهرية ثابتة
    switch (c.day) {
      case 12:
        return _c('التذكار الشهري لرئيس الملائكة ميخائيل', 'شفيع الكنيسة', Kind.saint, 'Michael_(archangel)', true);
      case 21:
        return _c('التذكار الشهري للسيدة العذراء', 'والدة الإله القديسة مريم', Kind.saint, 'Theotokos', true);
      case 29:
        return _c('التذكار الشهري للأعياد السيدية', 'البشارة والميلاد والقيامة', Kind.feast, 'Annunciation', true);
    }
    return _c('سنكسار ${ar(c.day)} ${c.monthName}', 'بركة صلوات القديسين تكون معنا', Kind.saint, null, true);
  }
}

enum Season { ordinary, fast, feast }

Season seasonOf(DateTime date) {
  final offset = daysBetween(copticEaster(date.year), date);
  final c = CopticDate.fromGregorian(date);
  final md = c.month * 100 + c.day;
  if (Synaxarium.feastOrFast(date)?.kind == Kind.feast) return Season.feast;
  if (offset >= 0 && offset <= 49) return Season.feast; // الخماسين
  bool inRange(int v, int a, int b) => v >= a && v <= b;
  final fasting = inRange(offset, -69, -67) || // يونان
      inRange(offset, -55, -1) || // الصوم الكبير
      (offset >= 50 && inRange(md, 901, 1104)) || // الرسل حتى ٤ أبيب
      inRange(md, 316, 330) ||
      inRange(md, 401, 428) || // الميلاد ١٦ هاتور – ٢٨ كيهك
      inRange(md, 1201, 1215); // العذراء
  return fasting ? Season.fast : Season.ordinary;
}
