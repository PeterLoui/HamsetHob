import 'package:flutter/painting.dart';

/// صور التذكارات والأعياد: جدول ثابت اتراجع واحدة واحدة (نوفمبر ٢٠٢٦).
/// كل صورة من ويكيميديا كومنز (Wikimedia Commons)، والأولوية للأيقونات القبطية والشرقية.
/// مافيش بحث تلقائي: لو التذكار مالوش صورة متراجعة مايظهرش صورة، أحسن من صورة غلط.
class SaintImages {
  SaintImages._();
  static final instance = SaintImages._();

  /// الصورة حسب عنوان صفحة ويكيبيديا المكتوب في synaxarium.dart.
  Future<String?> imageUrl(String? wikiTitle, String name) async => wikiTitle == null ? null : verified[wikiTitle];

  static const verified = <String, String>{
  // عيد النيروز · Nayrouz icon.jpg
  'Nayrouz': 'https://upload.wikimedia.org/wikipedia/commons/a/a7/Nayrouz_icon.jpg',
  // استشهاد يوحنا المعمدان · John baptist coptic.jpg
  'John_the_Baptist': 'https://upload.wikimedia.org/wikipedia/commons/f/f1/John_baptist_coptic.jpg',
  // عيد الصليب · Konstantin & Helena.jpg
  'True_Cross': 'https://upload.wikimedia.org/wikipedia/commons/9/9a/Konstantin_%26_Helena.jpg',
  // متى الإنجيلي · Matthew the Evangelist - icon.jpeg
  'Matthew_the_Apostle': 'https://upload.wikimedia.org/wikipedia/commons/b/b1/Matthew_the_Evangelist_-_icon.jpeg',
  // يحنس القصير · Saint John the Dwarf. Coptic icon.jpg
  'John_the_Dwarf': 'https://upload.wikimedia.org/wikipedia/commons/f/f3/Saint_John_the_Dwarf._Coptic_icon.jpg',
  // لوقا الإنجيلي · Saint Luke the Evangelist - icon.jpeg
  'Luke_the_Evangelist': 'https://upload.wikimedia.org/wikipedia/commons/e/e6/Saint_Luke_the_Evangelist_-_icon.jpeg',
  // مجمع نيقية · First Council of Nicaea Michael Damaskinos.png
  'First_Council_of_Nicaea': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/3/33/First_Council_of_Nicaea_Michael_Damaskinos.png/1280px-First_Council_of_Nicaea_Michael_Damaskinos.png',
  // رئيس الملائكة ميخائيل · Coptic Icon of the Archangel Michael.jpg
  'Michael_(archangel)': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/f/f0/Coptic_Icon_of_the_Archangel_Michael.jpg/1280px-Coptic_Icon_of_the_Archangel_Michael.jpg',
  // مار مينا العجايبي · Saint Menas Icon in Saint Mary Church in Kumanichevo.jpg
  'Saint_Menas': 'https://upload.wikimedia.org/wikipedia/commons/6/6f/Saint_Menas_Icon_in_Saint_Mary_Church_in_Kumanichevo.jpg',
  // الميلاد المجيد · Nativity (15th c., Annunciation Cathedral in Moscow).jpg
  'Nativity_of_Jesus': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/c/c1/Nativity_%2815th_c.%2C_Annunciation_Cathedral_in_Moscow%29.jpg/1280px-Nativity_%2815th_c.%2C_Annunciation_Cathedral_in_Moscow%29.jpg',
  // يوحنا ذهبي الفم · Semen Spiridonov Kholmogorets. John Chrysostom. 1670-1680th.jpg
  'John_Chrysostom': 'https://upload.wikimedia.org/wikipedia/commons/1/12/Semen_Spiridonov_Kholmogorets._John_Chrysostom._1670-1680th.jpg',
  // قزمان ودميان · Saints Cosmas and Damian icon, Syria (1778).jpg
  'Saints_Cosmas_and_Damian': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/9/9e/Saints_Cosmas_and_Damian_icon%2C_Syria_%281778%29.jpg/1280px-Saints_Cosmas_and_Damian_icon%2C_Syria_%281778%29.jpg',
  // أبو سيفين · Saint Mercurius killing Iulian.jpg
  'Mercurius': 'https://upload.wikimedia.org/wikipedia/commons/6/63/Saint_Mercurius_killing_Iulian.jpg',
  // دخول العذراء الهيكل · Presentation of Mary, II Half of XIV Century, St Mary Perivleptos Church, Ohrid Icon Gallery.jpg
  'Presentation_of_Mary': 'https://upload.wikimedia.org/wikipedia/commons/9/98/Presentation_of_Mary%2C_II_Half_of_XIV_Century%2C_St_Mary_Perivleptos_Church%2C_Ohrid_Icon_Gallery.jpg',
  // الملاك غبريال · Archangel Gabriel Icon in Blue and Red.png
  'Gabriel': 'https://upload.wikimedia.org/wikipedia/commons/6/62/Archangel_Gabriel_Icon_in_Blue_and_Red.png',
  // أطفال بيت لحم · Massacre of the Innocents (Ionian, 17th c., Byzantine museum).jpg
  'Massacre_of_the_Innocents': 'https://upload.wikimedia.org/wikipedia/commons/b/bd/Massacre_of_the_Innocents_%28Ionian%2C_17th_c.%2C_Byzantine_museum%29.jpg',
  // يوحنا الإنجيلي · Holy Apostle and Evangelist John the Theologian. Icon. Greece, 16th century.jpg
  'John_the_Apostle': 'https://upload.wikimedia.org/wikipedia/commons/b/bc/Holy_Apostle_and_Evangelist_John_the_Theologian._Icon._Greece%2C_16th_century.jpg',
  // الختان · Icon of the circumcision of Christ.jpg
  'Circumcision_of_Jesus': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/b/bc/Icon_of_the_circumcision_of_Christ.jpg/1280px-Icon_of_the_circumcision_of_Christ.jpg',
  // الغطاس (أيقونة قبطية) · Baptism (coptic icon).jpg
  'Baptism_of_Jesus': 'https://upload.wikimedia.org/wikipedia/commons/5/5f/Baptism_%28coptic_icon%29.jpg',
  // نياحة العذراء (أيقونة قبطية) · Coptic icon of the Dormition of Virgin Mary.jpg
  'Dormition_of_the_Mother_of_God': 'https://upload.wikimedia.org/wikipedia/commons/c/c1/Coptic_icon_of_the_Dormition_of_Virgin_Mary.jpg',
  // الأنبا أنطونيوس (أيقونة قبطية) · Anthony the Great (coptic icon, 19-20 c., priv. coll).jpg
  'Anthony_the_Great': 'https://upload.wikimedia.org/wikipedia/commons/2/28/Anthony_the_Great_%28coptic_icon%2C_19-20_c.%2C_priv._coll%29.jpg',
  // دخول المسيح الهيكل · Presentation of Christ in the Temple (10335749684).jpg
  'Presentation_of_Jesus': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/5/53/Presentation_of_Christ_in_the_Temple_%2810335749684%29.jpg/1280px-Presentation_of_Christ_in_the_Temple_%2810335749684%29.jpg',
  // البابا كيرلس السادس · Cyril VI of Alexandria.jpg
  'Pope_Cyril_VI_of_Alexandria': 'https://upload.wikimedia.org/wikipedia/commons/a/a3/Cyril_VI_of_Alexandria.jpg',
  // البابا شنوده الثالث · Pope Shenouda III of Alexandria by Chuck Kennedy (Official White House Photostream).jpg
  'Pope_Shenouda_III_of_Alexandria': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/1/10/Pope_Shenouda_III_of_Alexandria_by_Chuck_Kennedy_%28Official_White_House_Photostream%29.jpg/1280px-Pope_Shenouda_III_of_Alexandria_by_Chuck_Kennedy_%28Official_White_House_Photostream%29.jpg',
  // مقاريوس الكبير · Icon of Saint Macarius the Great.jpg
  'Macarius_of_Egypt': 'https://upload.wikimedia.org/wikipedia/commons/6/65/Icon_of_Saint_Macarius_the_Great.jpg',
  // البشارة · The Annunciation, Gladzor.jpg
  'Annunciation': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/9/9a/The_Annunciation%2C_Gladzor.jpg/1280px-The_Annunciation%2C_Gladzor.jpg',
  // مار جرجس · Icon of Saint George and the youth of Mytilene.jpg
  'Saint_George_and_the_Dragon': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/7/73/Icon_of_Saint_George_and_the_youth_of_Mytilene.jpg/1280px-Icon_of_Saint_George_and_the_youth_of_Mytilene.jpg',
  // مار مرقس الرسول · 087 Mark the Evangelist Icon from Saint Paraskevi Church in Langadas.jpg
  'Mark_the_Evangelist': 'https://upload.wikimedia.org/wikipedia/commons/3/3d/087_Mark_the_Evangelist_Icon_from_Saint_Paraskevi_Church_in_Langadas.jpg',
  // أثناسيوس الرسولي · Saint-Athanasius-of-Alexandria-icon-Sozopol-Bulgaria-17century.jpg
  'Athanasius_of_Alexandria': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/3/30/Saint-Athanasius-of-Alexandria-icon-Sozopol-Bulgaria-17century.jpg/1280px-Saint-Athanasius-of-Alexandria-icon-Sozopol-Bulgaria-17century.jpg',
  // دخول المسيح مصر (أيقونة قبطية) · Flight into Egypt (coptic icon).jpg
  'Flight_into_Egypt': 'https://upload.wikimedia.org/wikipedia/commons/c/c0/Flight_into_Egypt_%28coptic_icon%29.jpg',
  // موسى الأسود · St Moses the Black.jpg
  'Moses_the_Black': 'https://upload.wikimedia.org/wikipedia/commons/3/3b/St_Moses_the_Black.jpg',
  // ميلاد يوحنا المعمدان · 052 Nativity of Saint John the Baptist Icon from Saint Paraskevi Church in Langadas.jpg
  'Nativity_of_St_John_the_Baptist': 'https://upload.wikimedia.org/wikipedia/commons/c/c5/052_Nativity_of_Saint_John_the_Baptist_Icon_from_Saint_Paraskevi_Church_in_Langadas.jpg',
  // كيرلس عمود الدين · Chora-Kirche 2013-03-21zh (cropped).jpg
  'Cyril_of_Alexandria': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/4/46/Chora-Kirche_2013-03-21zh_%28cropped%29.jpg/1280px-Chora-Kirche_2013-03-21zh_%28cropped%29.jpg',
  // بطرس وبولس · The Holy Apostles Peter and Paul. Novgorod School of Icon Painting, 12th-13th centuries. Belozersk.jpg
  'Saints_Peter_and_Paul': 'https://upload.wikimedia.org/wikipedia/commons/e/ec/The_Holy_Apostles_Peter_and_Paul._Novgorod_School_of_Icon_Painting%2C_12th-13th_centuries._Belozersk.jpg',
  // الأنبا شنوده رئيس المتوحدين · Shenoute of Atripe.jpg
  'Shenoute': 'https://upload.wikimedia.org/wikipedia/commons/e/ee/Shenoute_of_Atripe.jpg',
  // الأنبا بيشوي (بائيسيوس الكبير) · Saint Paisiy the Great.jpg
  'Monastery_of_Saint_Pishoy': 'https://upload.wikimedia.org/wikipedia/commons/7/7e/Saint_Paisiy_the_Great.jpg',
  // السيدة العذراء · Ethiopia Madonna and Child.jpg
  'Theotokos': 'https://upload.wikimedia.org/wikipedia/commons/9/92/Ethiopia_Madonna_and_Child.jpg',
  // التجلي · Transfiguration by Feofan Grek from Spaso-Preobrazhensky Cathedral in Pereslavl-Zalessky (15th c, Tretyakov gallery).jpeg
  'Transfiguration_of_Jesus': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/d/da/Transfiguration_by_Feofan_Grek_from_Spaso-Preobrazhensky_Cathedral_in_Pereslavl-Zalessky_%2815th_c%2C_Tretyakov_gallery%29.jpeg/1280px-Transfiguration_by_Feofan_Grek_from_Spaso-Preobrazhensky_Cathedral_in_Pereslavl-Zalessky_%2815th_c%2C_Tretyakov_gallery%29.jpeg',
  // صعود جسد العذراء · The Dormition and Assumption of the Virgin (Moskos).jpg
  'Assumption_of_Mary': 'https://upload.wikimedia.org/wikipedia/commons/1/16/The_Dormition_and_Assumption_of_the_Virgin_%28Moskos%29.jpg',
  // الملاك رافائيل · Georgios Kortezas The Archangels Michael, Gabriel and Raphael.png
  'Raphael_(archangel)': 'https://upload.wikimedia.org/wikipedia/commons/a/a7/Georgios_Kortezas_The_Archangels_Michael%2C_Gabriel_and_Raphael.png',
  // صوم يونان · Jonah.jpg
  'Jonah': 'https://upload.wikimedia.org/wikipedia/commons/2/27/Jonah.jpg',
  // الصوم الكبير · Temptation icon.jpg
  'Temptation_of_Christ': 'https://upload.wikimedia.org/wikipedia/commons/f/f6/Temptation_icon.jpg',
  // أحد الشعانين · Entry into Jerusalem (Afon icon).jpg
  'Triumphal_entry_into_Jerusalem': 'https://upload.wikimedia.org/wikipedia/commons/a/af/Entry_into_Jerusalem_%28Afon_icon%29.jpg',
  // خميس العهد · Icon last supper.jpg
  'Last_Supper': 'https://upload.wikimedia.org/wikipedia/commons/0/03/Icon_last_supper.jpg',
  // الجمعة العظيمة · Double-side icon with Crucifixion and Hodegetria (14th century, Byzantine museum)-.jpg
  'Crucifixion_of_Jesus': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/7/70/Double-side_icon_with_Crucifixion_and_Hodegetria_%2814th_century%2C_Byzantine_museum%29-.jpg/1280px-Double-side_icon_with_Crucifixion_and_Hodegetria_%2814th_century%2C_Byzantine_museum%29-.jpg',
  // عيد القيامة · Harrowing of hell (Pskov, 14th c.).jpg
  'Resurrection_of_Jesus': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/6/68/Harrowing_of_hell_%28Pskov%2C_14th_c.%29.jpg/1280px-Harrowing_of_hell_%28Pskov%2C_14th_c.%29.jpg',
  // الصعود · Ascension of Jesus icon, Lattakia (1667).jpg
  'Ascension_of_Jesus': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/e/e4/Ascension_of_Jesus_icon%2C_Lattakia_%281667%29.jpg/1280px-Ascension_of_Jesus_icon%2C_Lattakia_%281667%29.jpg',
  // العنصرة · Pentecost icon.jpg
  'Pentecost': 'https://upload.wikimedia.org/wikipedia/commons/d/db/Pentecost_icon.jpg',
  // صوم الرسل · Synaxis of the Twelve Apostles by Constantinople master (early 14th c., Pushkin museum).jpg
  'Twelve_Apostles': 'https://upload.wikimedia.org/wikipedia/commons/8/81/Synaxis_of_the_Twelve_Apostles_by_Constantinople_master_%28early_14th_c.%2C_Pushkin_museum%29.jpg',
  };

  /// لكل صورة: نسبة الارتفاع للعرض، ومكان وش القديس الأساسي من فوق (كسر من ارتفاع الصورة).
  /// اتقاست بالعين على كل صورة، عشان القص يتوسّط على الوش بدل ما يقطعه.
  static const framing = <String, (double, double)>{
    'Nayrouz': (1.448, 0.23),
    'John_the_Baptist': (1.090, 0.2),
    'True_Cross': (0.779, 0.15),
    'Matthew_the_Apostle': (1.333, 0.25),
    'John_the_Dwarf': (1.606, 0.25),
    'Luke_the_Evangelist': (1.169, 0.25),
    'First_Council_of_Nicaea': (1.276, 0.3),
    'Michael_(archangel)': (1.451, 0.15),
    'Saint_Menas': (1.541, 0.15),
    'Nativity_of_Jesus': (1.327, 0.4),
    'John_Chrysostom': (2.334, 0.25),
    'Saints_Cosmas_and_Damian': (1.250, 0.12),
    'Mercurius': (1.278, 0.25),
    'Presentation_of_Mary': (1.304, 0.35),
    'Gabriel': (1.427, 0.3),
    'Massacre_of_the_Innocents': (0.648, 0.4),
    'John_the_Apostle': (1.371, 0.2),
    'Circumcision_of_Jesus': (0.498, 0.4),
    'Baptism_of_Jesus': (1.444, 0.42),
    'Dormition_of_the_Mother_of_God': (1.421, 0.12),
    'Anthony_the_Great': (1.412, 0.2),
    'Presentation_of_Jesus': (1.061, 0.35),
    'Pope_Cyril_VI_of_Alexandria': (1.598, 0.3),
    'Pope_Shenouda_III_of_Alexandria': (1.500, 0.35),
    'Macarius_of_Egypt': (1.210, 0.3),
    'Annunciation': (1.302, 0.38),
    'Saint_George_and_the_Dragon': (1.307, 0.27),
    'Mark_the_Evangelist': (1.255, 0.25),
    'Athanasius_of_Alexandria': (1.392, 0.3),
    'Flight_into_Egypt': (1.353, 0.18),
    'Moses_the_Black': (1.849, 0.1),
    'Nativity_of_St_John_the_Baptist': (1.381, 0.35),
    'Cyril_of_Alexandria': (1.334, 0.2),
    'Saints_Peter_and_Paul': (1.538, 0.12),
    'Shenoute': (1.624, 0.2),
    'Monastery_of_Saint_Pishoy': (1.124, 0.32),
    'Theotokos': (1.108, 0.25),
    'Transfiguration_of_Jesus': (1.388, 0.2),
    'Assumption_of_Mary': (1.988, 0.1),
    'Raphael_(archangel)': (0.853, 0.25),
    'Jonah': (1.245, 0.25),
    'Temptation_of_Christ': (1.203, 0.45),
    'Triumphal_entry_into_Jerusalem': (1.347, 0.3),
    'Last_Supper': (1.375, 0.3),
    'Crucifixion_of_Jesus': (1.279, 0.2),
    'Resurrection_of_Jesus': (1.249, 0.42),
    'Ascension_of_Jesus': (1.276, 0.2),
    'Pentecost': (1.214, 0.25),
    'Twelve_Apostles': (1.160, 0.3),
  };

  /// المحاذاة اللي بتخلي الوش ظاهر جوه صندوق بالمقاس ده مع BoxFit.cover.
  /// [faceAt] مكان الوش المطلوب من فوق الصندوق (٠٫٤ يعني فوق النص شوية).
  static Alignment focus(String? wikiTitle, double boxW, double boxH, {double faceAt = .4}) {
    final f = wikiTitle == null ? null : framing[wikiTitle];
    if (f == null || boxW <= 0 || boxH <= 0) return const Alignment(0, -.6);
    final (aspect, faceY) = f;
    final shownH = boxW * aspect; // الصورة بعرض الصندوق
    if (shownH <= boxH) return Alignment.center; // صورة عريضة: بتتقص من الجناب مش من فوق وتحت
    final overflow = shownH - boxH;
    final top = (faceY * shownH - faceAt * boxH).clamp(0.0, overflow);
    return Alignment(0, top / overflow * 2 - 1);
  }
}
