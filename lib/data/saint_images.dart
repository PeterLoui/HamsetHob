import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/coptic.dart';
import 'net.dart';

/// صورة تذكار اليوم، بالترتيب:
/// ١. الجدول المتراجع [verified] للأعياد والقديسين المشهورين (ويكيميديا كومنز)، بمفتاح اليوم أو بكلمة في العنوان.
/// ٢. صور صفحة سنكسار اليوم نفسه على موقع الأنبا تكلا (st-takla.org)، بشرط إن وصف الصورة فيه اسم صاحب التذكار.
/// ٣. بحث ويكيبيديا العربية باسم القديس، ومابتتقبلش نتيجة إلا لو عنوانها فيه أول كلمتين من الاسم.
/// لو مافيش صورة في أي مصدر الواجهة بتعرض الصليب القبطي.
class SaintImages {
  SaintImages._();
  static final instance = SaintImages._();

  static const _taklaMonths = [
    'Toot', 'Babah', 'Hatoor', 'Keyahk', 'Topah', 'Amsheer', 'Baramhat',
    'Bermodah', 'Bashans', 'Bawoonah', 'Abeeb', 'Mesraa', 'Nasea',
  ];
  static const _taklaBase = 'https://st-takla.org/Full-Free-Coptic-Books/Synaxarium-or-Synaxarion';

  /// كلمات مش جزء من اسم القديس.
  static const _titles = {
    'نياحه', 'استشهاد', 'تذكار', 'عيد', 'القديس', 'القديسه', 'القديسين', 'القديسان', 'البابا', 'الانبا', 'انبا',
    'مار', 'ماري', 'العظيم', 'الجليل', 'الشهيد', 'الشهيده', 'الشهداء', 'رئيس', 'الملائكه', 'الملاك', 'السيده', 'ابي', 'ابو', 'ابينا', 'البطريرك',
    'الكبير', 'الرسول', 'الرسولين', 'الانجيلي', 'بطاركه', 'الكرازه', 'المرقسيه', 'اسقف', 'الاسقف', 'اسقفي',
    'التذكار', 'الشهري', 'سنكسار', 'اليوم', 'دخول', 'بدايه', 'صوم', 'المجيد', 'ظهور', 'نقل', 'جسد', 'راس',
    'تكريس', 'كنيسه', 'الاب', 'الراهب', 'القمص', 'القس', 'الامير', 'الي', 'من', 'في', 'علي', 'اهل', 'بلده',
    'والده', 'اخته', 'اخيه', 'امه', 'بجبل', 'مدينه',
  };

  static const _missTtl = Duration(days: 7);
  static const _retryAfterFailure = Duration(minutes: 1);

  final _memo = <String, Future<String?>>{};
  final _taklaMemo = <int, Future<List<(String, String)>>>{};

  /// نفس الطلب بيرجّع نفس الـ Future، فالصورة ماتتحمّلش من جديد مع كل إعادة رسم.
  /// [wikiTitle] مفتاح الجدول المتراجع، [name] عنوان التذكار، [date] اليوم الميلادي.
  Future<String?> imageUrl(String? wikiTitle, String name, DateTime date) {
    final fixed = wikiTitle == null ? null : verified[wikiTitle];
    if (fixed != null) return _memo.putIfAbsent('v|$wikiTitle', () => Future.value(fixed));
    final c = CopticDate.fromGregorian(date);
    final key = '${c.month}-${c.day}|${normalizeArabic(name)}';
    return _memo.putIfAbsent(key, () => _lookup(key, c, name));
  }

  Future<String?> _lookup(String key, CopticDate c, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'saint_img2_$key';
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      if (cached.startsWith('http')) return cached;
      // «مافيش صورة» بتتجرّب تاني بعد أسبوع، يمكن اتضافت
      final at = DateTime.fromMillisecondsSinceEpoch(int.tryParse(cached) ?? 0);
      if (DateTime.now().difference(at) < _missTtl) return null;
    }
    var failed = false;
    String? url = _alias(name);
    if (url != null) return url;
    try {
      url = _pickTakla(await _taklaMemo.putIfAbsent(c.month * 100 + c.day, () => _stTaklaDay(c)), name);
    } catch (_) {
      failed = true;
      _taklaMemo.remove(c.month * 100 + c.day);
    }
    if (url == null) {
      try {
        url = await _wikipedia(name);
      } catch (_) {
        failed = true;
      }
    }
    if (url != null) {
      await prefs.setString(cacheKey, url);
    } else if (!failed) {
      await prefs.setString(cacheKey, '${DateTime.now().millisecondsSinceEpoch}');
    } else {
      // الشبكة وقعت: مانحفظش «مافيش صورة»، ونجرّب تاني بعد شوية
      Future.delayed(_retryAfterFailure, () => _memo.remove(key));
    }
    return url;
  }

  /// صور معرض الموقع جوه صفحة سنكسار اليوم ده، كل صورة ومعاها وصفها العربي.
  Future<List<(String, String)>> _stTaklaDay(CopticDate c) async {
    String two(int n) => n.toString().padLeft(2, '0');
    final month = _taklaMonths[c.month - 1];
    final page = '$_taklaBase/${two(c.month)}-$month/${two(c.day)}-$month.html';
    final r = await getRaw(page);
    if (r.statusCode == 404) return const [];
    if (r.statusCode >= 400) throw HttpStatusError(r.statusCode);
    final html = _decode(r.bodyBytes);
    final out = <(String, String)>[];
    for (final m in RegExp('<img[^>]+>', caseSensitive: false).allMatches(html)) {
      final tag = m[0]!;
      final src = RegExp('src="([^"]*Gallery/var/(?:resizes|albums)/[^"]+)"', caseSensitive: false).firstMatch(tag)?[1];
      if (src == null || src.contains('/Words/')) continue; // صور أسماء مكتوبة مش أيقونات
      final alt = RegExp('alt="([^"]*)"', caseSensitive: false, dotAll: true).firstMatch(tag)?[1] ?? '';
      out.add((Uri.parse(page).resolve(src).toString(), alt));
    }
    return out;
  }

  /// صفحات الموقع بترميز windows-1256. بنجرّب UTF-8 الأول لو اتغيّر في يوم.
  static String _decode(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      final b = StringBuffer();
      for (final x in bytes) {
        b.writeCharCode(switch (x) {
          < 0x80 => x,
          >= 0xC1 && <= 0xD6 => 0x0621 + x - 0xC1,
          >= 0xD8 && <= 0xDB => 0x0637 + x - 0xD8,
          >= 0xDD && <= 0xDF => 0x0641 + x - 0xDD,
          0xE1 => 0x0644,
          >= 0xE3 && <= 0xE6 => 0x0645 + x - 0xE3,
          0xEC || 0xED => 0x0649 + x - 0xEC,
          _ => 0x20,
        });
      }
      return b.toString();
    }
  }

  /// هيكل الكلمة من غير حروف المد والهمزات، عشان «لنجينوس» تطابق «لونجينوس» و«تيموثاوس» تطابق «تيموثاؤس».
  static String _skeleton(String w) => normalizeArabic(w).replaceAll(RegExp('[اويءؤئ]'), '');

  /// الصورة اللي وصفها فيه اسم صاحب التذكار المعروض. صفحة اليوم فيها كذا تذكار،
  /// فمانعرضش صورة قديس تاني من نفس اليوم تحت اسم ده.
  static String? _pickTakla(List<(String, String)> images, String name) {
    final keys = nameKeys(name);
    if (keys.isEmpty) return null;
    final want = _skeleton(keys.first);
    if (want.length < 3) return null;
    for (final (url, alt) in images) {
      final words = normalizeArabic(alt).split(RegExp(r'[^ء-ي]+')).map(_skeleton);
      if (words.any((w) => w == want)) return url;
    }
    return null;
  }

  /// قديسين وأعياد مشهورين ليهم صورة متراجعة في [verified]، بيتعرفوا من كلمة في عنوان التذكار
  /// (تكريس كنيسة، نقل جسد، تذكار شهري…). الترتيب مهم: الأكثر تحديداً الأول.
  static const _aliases = <(List<String>, String)>[
    (['مينا', 'العجايبي'], 'Saint_Menas'),
    (['جرجس', 'الروماني'], 'Saint_George_and_the_Dragon'),
    (['ابي', 'سيفين'], 'Mercurius'),
    (['مرقوريوس'], 'Mercurius'),
    (['يوحنا', 'المعمدان'], 'John_the_Baptist'),
    (['يوحنا', 'ذهبي'], 'John_Chrysostom'),
    (['مرقس', 'الرسول'], 'Mark_the_Evangelist'),
    (['انطونيوس', 'اب'], 'Anthony_the_Great'),
    (['اثناسيوس', 'الرسولي'], 'Athanasius_of_Alexandria'),
    (['كيرلس', 'السادس'], 'Pope_Cyril_VI_of_Alexandria'),
    (['شنوده', 'الثالث'], 'Pope_Shenouda_III_of_Alexandria'),
    (['موسي', 'الاسود'], 'Moses_the_Black'),
    (['قزمان', 'دميان'], 'Saints_Cosmas_and_Damian'),
    (['بطرس', 'بولس'], 'Saints_Peter_and_Paul'),
    (['الملائكه', 'ميخائيل'], 'Michael_(archangel)'),
    (['الملاك', 'ميخائيل'], 'Michael_(archangel)'),
    (['جبرائيل'], 'Gabriel'),
    (['غبريال', 'الملاك'], 'Gabriel'),
    (['غبريال', 'الملائكه'], 'Gabriel'),
    (['روفائيل'], 'Raphael_(archangel)'),
    (['الاعياد', 'السيديه'], 'Annunciation'),
    (['رافائيل'], 'Raphael_(archangel)'),
  ];

  static String? _alias(String name) {
    final words = normalizeArabic(name).split(RegExp(r'[^ء-ي]+')).toSet();
    for (final (need, wiki) in _aliases) {
      if (need.every(words.contains)) return verified[wiki];
    }
    // كنايس ومعجزات السيدة العذراء، بس مش تذكار والديها (حنة ويواقيم)
    if (words.contains('العذراء') && !words.contains('حنه') && !words.contains('يواقيم') && !words.contains('العذاري')) {
      return verified['Theotokos'];
    }
    return null;
  }

  /// كلمات الاسم بعد شيل الألقاب («نياحة القديس…»).
  static List<String> nameKeys(String name) => normalizeArabic(name)
      .split(RegExp(r'[\s،,()\-–]+'))
      .map((w) => w.startsWith('و') && w.length > 4 ? w.substring(1) : w)
      .where((w) => w.length >= 3 && !_titles.contains(w))
      .toList();

  Future<String?> _wikipedia(String name) async {
    final keys = nameKeys(name).take(3).toList();
    // اسم من كلمة واحدة («تيموثاوس») ممكن يطلع شخص تاني خالص، فمابندوّرش بيه
    if (keys.length < 2) return null;
    final j = await getJson('https://ar.wikipedia.org/w/api.php?action=query&generator=search'
        '&gsrsearch=${Uri.encodeQueryComponent(keys.join(' '))}&gsrlimit=6'
        '&prop=pageimages&piprop=thumbnail&pithumbsize=800&format=json') as Map;
    final pages = ((j['query'] as Map?)?['pages'] as Map?)?.values.cast<Map>().toList() ?? [];
    pages.sort((a, b) => (a['index'] as int? ?? 0).compareTo(b['index'] as int? ?? 0));
    final must = keys.take(2);
    for (final p in pages) {
      final title = normalizeArabic(p['title'] as String? ?? '');
      final thumb = p['thumbnail'] as Map?;
      if (thumb != null && must.every(title.contains)) return thumb['source'] as String?;
    }
    return null;
  }

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
