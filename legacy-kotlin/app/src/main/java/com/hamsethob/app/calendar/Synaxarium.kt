package com.hamsethob.app.calendar

import java.time.LocalDate
import java.time.temporal.ChronoUnit

enum class Kind(val label: String) {
    FEAST("عيد"),
    SAINT("تذكار اليوم"),
    FAST("صوم"),
}

/**
 * @param wiki عنوان صفحة ويكيبيديا الإنجليزية، تُستخدم لجلب صورة الأيقونة.
 */
data class Commemoration(
    val title: String,
    val detail: String,
    val kind: Kind,
    val wiki: String? = null,
    /** تذكار عام بديل؛ يُستبدل باسم قديس اليوم من السنكسار الكامل إن توفر. */
    val generic: Boolean = false,
)

/**
 * السنكسار اليومي. الأعياد المتحركة تُحسب من عيد القيامة، والثابتة من جدول
 * مرتب بالشهر واليوم القبطي. لإضافة يوم جديد أضف سطراً إلى [fixed].
 */
object Synaxarium {

    private fun key(month: Int, day: Int) = month * 100 + day

    private val fixed: Map<Int, Commemoration> = mapOf(
        // توت
        key(1, 1) to Commemoration("عيد النيروز", "رأس السنة القبطية وتذكار الشهداء", Kind.FEAST, "Nayrouz"),
        key(1, 2) to Commemoration("استشهاد القديس يوحنا المعمدان", "السابق الصابغ", Kind.SAINT, "John_the_Baptist"),
        key(1, 17) to Commemoration("عيد الصليب المجيد", "ظهور الصليب على يد الملكة هيلانة", Kind.FEAST, "True_Cross"),
        key(1, 26) to Commemoration("بشارة زكريا الكاهن", "بميلاد القديس يوحنا المعمدان", Kind.SAINT, "Zechariah_(New_Testament_figure)"),
        // بابه
        key(2, 12) to Commemoration("استشهاد القديس متى الإنجيلي", "أحد الاثني عشر رسولاً", Kind.SAINT, "Matthew_the_Apostle"),
        key(2, 16) to Commemoration("نياحة البابا أغاثون", "البابا التاسع والثلاثون من باباوات الإسكندرية", Kind.SAINT, "Coptic_Orthodox_Church"),
        key(2, 20) to Commemoration("نياحة القديس يحنس القصير", "صاحب شجرة الطاعة", Kind.SAINT, "John_the_Dwarf"),
        key(2, 22) to Commemoration("استشهاد القديس لوقا الإنجيلي", "الطبيب كاتب الإنجيل وسفر الأعمال", Kind.SAINT, "Luke_the_Evangelist"),
        // هاتور
        key(3, 9) to Commemoration("تذكار مجمع نيقية المسكوني", "اجتماع الـ318 أباً", Kind.SAINT, "First_Council_of_Nicaea"),
        key(3, 12) to Commemoration("عيد رئيس الملائكة ميخائيل", "رئيس جند السماء", Kind.FEAST, "Michael_(archangel)"),
        key(3, 15) to Commemoration("استشهاد القديس مار مينا العجايبي", "صانع العجائب", Kind.SAINT, "Saint_Menas"),
        key(3, 16) to Commemoration("بداية صوم الميلاد المجيد", "يستمر حتى ٢٨ كيهك", Kind.FAST, "Nativity_of_Jesus"),
        key(3, 17) to Commemoration("نياحة القديس يوحنا ذهبي الفم", "رئيس أساقفة القسطنطينية", Kind.SAINT, "John_Chrysostom"),
        key(3, 22) to Commemoration("استشهاد القديسين قزمان ودميان", "وإخوتهما وأمهم", Kind.SAINT, "Saints_Cosmas_and_Damian"),
        key(3, 25) to Commemoration("استشهاد القديس أبي سيفين", "فيلوباتير مرقوريوس", Kind.SAINT, "Mercurius"),
        // كيهك
        key(4, 3) to Commemoration("دخول السيدة العذراء الهيكل", "تذكار تقدمة العذراء", Kind.FEAST, "Presentation_of_Mary"),
        key(4, 22) to Commemoration("تذكار الملاك غبريال المبشر", "رئيس الملائكة", Kind.SAINT, "Gabriel"),
        key(4, 29) to Commemoration("عيد الميلاد المجيد", "ميلاد ربنا يسوع المسيح بالجسد", Kind.FEAST, "Nativity_of_Jesus"),
        // طوبه
        key(5, 3) to Commemoration("تذكار أطفال بيت لحم", "الذين قتلهم هيرودس", Kind.SAINT, "Massacre_of_the_Innocents"),
        key(5, 4) to Commemoration("نياحة القديس يوحنا الإنجيلي", "التلميذ الذي كان يسوع يحبه", Kind.SAINT, "John_the_Apostle"),
        key(5, 6) to Commemoration("عيد الختان المجيد", "من الأعياد السيدية الصغرى", Kind.FEAST, "Circumcision_of_Jesus"),
        key(5, 11) to Commemoration("عيد الغطاس المجيد", "معمودية السيد المسيح في الأردن", Kind.FEAST, "Baptism_of_Jesus"),
        key(5, 13) to Commemoration("عيد عرس قانا الجليل", "أولى معجزات السيد المسيح", Kind.FEAST, "Marriage_at_Cana"),
        key(5, 21) to Commemoration("نياحة السيدة العذراء مريم", "والدة الإله", Kind.FEAST, "Dormition_of_the_Mother_of_God"),
        key(5, 22) to Commemoration("نياحة القديس الأنبا أنطونيوس", "أب جميع الرهبان", Kind.SAINT, "Anthony_the_Great"),
        // أمشير
        key(6, 8) to Commemoration("دخول السيد المسيح الهيكل", "حمله سمعان الشيخ على ذراعيه", Kind.FEAST, "Presentation_of_Jesus"),
        key(6, 30) to Commemoration("نياحة البابا كيرلس السادس", "البابا المئة والسادس عشر", Kind.SAINT, "Pope_Cyril_VI_of_Alexandria"),
        // برمهات
        key(7, 8) to Commemoration("نياحة البابا شنوده الثالث", "البابا المئة والسابع عشر", Kind.SAINT, "Pope_Shenouda_III_of_Alexandria"),
        key(7, 10) to Commemoration("تذكار الصليب المجيد", "العيد الثاني للصليب", Kind.FEAST, "True_Cross"),
        key(7, 27) to Commemoration("نياحة القديس مقاريوس الكبير", "أب برية شيهيت", Kind.SAINT, "Macarius_of_Egypt"),
        key(7, 29) to Commemoration("عيد البشارة المجيد", "بشارة الملاك غبريال للعذراء", Kind.FEAST, "Annunciation"),
        // برموده
        key(8, 23) to Commemoration("استشهاد القديس مار جرجس", "أمير الشهداء", Kind.SAINT, "Saint_George_and_the_Dragon"),
        key(8, 30) to Commemoration("استشهاد القديس مار مرقس الرسول", "كاروز الديار المصرية", Kind.SAINT, "Mark_the_Evangelist"),
        // بشنس
        key(9, 7) to Commemoration("نياحة القديس أثناسيوس الرسولي", "البابا العشرون وحامي الإيمان", Kind.SAINT, "Athanasius_of_Alexandria"),
        key(9, 24) to Commemoration("دخول السيد المسيح أرض مصر", "\"مبارك شعبي مصر\"", Kind.FEAST, "Flight_into_Egypt"),
        // بؤونه
        key(10, 12) to Commemoration("عيد رئيس الملائكة ميخائيل", "تذكار تكريس كنيسته", Kind.FEAST, "Michael_(archangel)"),
        key(10, 24) to Commemoration("نياحة القديس موسى الأسود", "القوي", Kind.SAINT, "Moses_the_Black"),
        key(10, 30) to Commemoration("ميلاد القديس يوحنا المعمدان", "أعظم مواليد النساء", Kind.FEAST, "Nativity_of_St_John_the_Baptist"),
        // أبيب
        key(11, 3) to Commemoration("نياحة القديس كيرلس عمود الدين", "البابا الرابع والعشرون", Kind.SAINT, "Cyril_of_Alexandria"),
        key(11, 5) to Commemoration("استشهاد القديسين بطرس وبولس", "الرسولين العظيمين", Kind.FEAST, "Saints_Peter_and_Paul"),
        key(11, 7) to Commemoration("نياحة القديس الأنبا شنوده", "رئيس المتوحدين", Kind.SAINT, "Shenoute"),
        key(11, 8) to Commemoration("نياحة القديس الأنبا بيشوي", "الرجل الكامل حبيب مخلصنا", Kind.SAINT, "Monastery_of_Saint_Pishoy"),
        // مسرى
        key(12, 1) to Commemoration("بداية صوم السيدة العذراء", "يستمر حتى ١٥ مسرى", Kind.FAST, "Theotokos"),
        key(12, 13) to Commemoration("عيد التجلي المجيد", "على جبل طابور", Kind.FEAST, "Transfiguration_of_Jesus"),
        key(12, 16) to Commemoration("صعود جسد السيدة العذراء", "عيد العذراء", Kind.FEAST, "Assumption_of_Mary"),
        // النسيء
        key(13, 3) to Commemoration("تذكار الملاك رافائيل", "رئيس الملائكة", Kind.SAINT, "Raphael_(archangel)"),
    )

    /** الأعياد المتحركة بالأيام نسبة إلى عيد القيامة. */
    private val movable: Map<Long, Commemoration> = mapOf(
        -69L to Commemoration("بداية صوم يونان", "صوم نينوى ثلاثة أيام", Kind.FAST, "Jonah"),
        -55L to Commemoration("بداية الصوم الكبير", "الصوم المقدس", Kind.FAST, "Temptation_of_Christ"),
        -7L to Commemoration("أحد الشعانين", "دخول المسيح أورشليم", Kind.FEAST, "Triumphal_entry_into_Jerusalem"),
        -3L to Commemoration("خميس العهد", "تأسيس سر الإفخارستيا", Kind.FEAST, "Last_Supper"),
        -2L to Commemoration("الجمعة العظيمة", "صلب ربنا يسوع المسيح", Kind.FEAST, "Crucifixion_of_Jesus"),
        0L to Commemoration("عيد القيامة المجيد", "خريستوس آنستي .. آليثوس آنستي", Kind.FEAST, "Resurrection_of_Jesus"),
        39L to Commemoration("عيد الصعود المجيد", "صعود السيد المسيح إلى السماء", Kind.FEAST, "Ascension_of_Jesus"),
        49L to Commemoration("عيد العنصرة", "حلول الروح القدس", Kind.FEAST, "Pentecost"),
        50L to Commemoration("بداية صوم الرسل", "يستمر حتى ٤ أبيب", Kind.FAST, "Twelve_Apostles"),
    )

    /** العيد أو بداية الصوم في هذا اليوم إن وُجد (يُستخدم في النتيجة). */
    fun feastOrFast(date: LocalDate): Commemoration? {
        val offset = ChronoUnit.DAYS.between(copticEaster(date.year), date)
        movable[offset]?.let { return it }
        val coptic = CopticDate.fromGregorian(date)
        return fixed[key(coptic.month, coptic.day)]?.takeIf { it.kind != Kind.SAINT }
    }

    fun forDate(date: LocalDate): Commemoration {
        feastOrFast(date)?.let { return it }

        val coptic = CopticDate.fromGregorian(date)
        fixed[key(coptic.month, coptic.day)]?.let { return it }

        // تذكارات شهرية ثابتة في الكنيسة القبطية
        return when (coptic.day) {
            12 -> Commemoration("التذكار الشهري لرئيس الملائكة ميخائيل", "شفيع الكنيسة", Kind.SAINT, "Michael_(archangel)", generic = true)
            21 -> Commemoration("التذكار الشهري للسيدة العذراء", "والدة الإله القديسة مريم", Kind.SAINT, "Theotokos", generic = true)
            29 -> Commemoration("التذكار الشهري للأعياد السيدية", "البشارة والميلاد والقيامة", Kind.FEAST, "Annunciation", generic = true)
            else -> Commemoration(
                "سنكسار ${coptic.day.arabicDigits()} ${coptic.monthName}",
                "بركة صلوات القديسين تكون معنا",
                Kind.SAINT,
                "Coptic_Orthodox_Church",
                generic = true,
            )
        }
    }
}
