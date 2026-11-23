import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/coptic.dart';
import 'katameros.dart';
import 'net.dart';

class FatherSaying {
  const FatherSaying(this.father, this.text);
  final String father, text;
}

/// السنكسار اليومي وأقوال الآباء من خادم كنيسة الشهيدة دميانة (st-demiana.com).
/// السنكسار بيتحفظ لكل يوم على الجهاز، وأقوال الآباء بتتحدّث كل يوم.
class DemianaRepository {
  DemianaRepository._();
  static final instance = DemianaRepository._();
  static const _api = 'https://st-demiana.com/be/api/';

  final _memory = <String, List<SaintStory>>{};
  List<FatherSaying>? _sayings;

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// سير سنكسار اليوم (عنوان + نص). بيرمي استثناء لو الشبكة وقعت ومفيش نسخة محفوظة.
  Future<List<SaintStory>> synaxarium(DateTime date) async {
    final d = dateOnly(date);
    final key = '${d.year}-${_two(d.month)}-${_two(d.day)}';
    final hit = _memory[key];
    if (hit != null) return hit;
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('demiana_syn_$key');
    if (cached != null) return _memory[key] = _decode(cached);
    final text = await getText('${_api}katameros/by-date?date=${_two(d.day)}-${_two(d.month)}-${d.year}&tz=Africa/Cairo&raw=0&compact=0');
    final stories = parseSynaxarium(text);
    await prefs.setString('demiana_syn_$key', jsonEncode([for (final s in stories) [s.title, s.text]]));
    return _memory[key] = stories;
  }

  static List<SaintStory> _decode(String s) => [
        for (final e in jsonDecode(s) as List) SaintStory(e[0] as String, e[1] as String),
      ];

  /// يطلّع سير السنكسار من رد الخادم. العنوان والنص بالنظافة من وسوم HTML.
  static List<SaintStory> parseSynaxarium(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    if (j['ok'] == false) throw FormatException(j['message']?.toString() ?? 'bad response');
    final list = (j['normalized'] as Map?)?['synaxarium'];
    if (list is! List) throw const FormatException('no synaxarium');
    return [
      for (final e in list.whereType<Map>())
        if ((e['saint'] as String?)?.trim().isNotEmpty == true && (e['story'] as String?)?.trim().isNotEmpty == true)
          SaintStory(stripHtml(e['saint'] as String), stripHtml(e['story'] as String)),
    ];
  }

  /// كل أقوال الآباء المتاحة.
  Future<List<FatherSaying>> sayings() async {
    if (_sayings != null) return _sayings!;
    final prefs = await SharedPreferences.getInstance();
    final today = dateOnly(DateTime.now()).toIso8601String().substring(0, 10);
    var raw = prefs.getString('demiana_sayings');
    if (raw == null || prefs.getString('demiana_sayings_day') != today) {
      try {
        raw = await getText('${_api}fathers-saying');
        await prefs.setString('demiana_sayings', raw);
        await prefs.setString('demiana_sayings_day', today);
      } catch (_) {
        if (raw == null) rethrow; // مفيش نسخة قديمة نرجع لها
      }
    }
    return _sayings = parseSayings(raw);
  }

  static List<FatherSaying> parseSayings(String body) {
    final data = (jsonDecode(body) as Map<String, dynamic>)['data'];
    if (data is! List) throw const FormatException('no data');
    return [
      for (final e in data.whereType<Map>())
        if ((e['content'] as String?)?.trim().isNotEmpty == true)
          FatherSaying(((e['father'] as String?) ?? '').trim(), (e['content'] as String).trim()),
    ];
  }

  /// قول اليوم: ثابت طول اليوم (بيتغيّر بتغيّر التاريخ)، و[shift] لزر «قول آخر».
  Future<FatherSaying?> sayingFor(DateTime date, {int shift = 0}) async {
    final all = await sayings();
    if (all.isEmpty) return null;
    final day = dateOnly(date).difference(DateTime.utc(2024)).inDays;
    return all[(day + shift) % all.length];
  }
}

/// سنكسار اليوم: من st-demiana.com، ولو مش متاح من القطمارس (api.katameros.app) كاحتياطي.
Future<List<SaintStory>> synaxariumStories(DateTime date) async {
  try {
    final s = await DemianaRepository.instance.synaxarium(date);
    if (s.isNotEmpty) return s;
  } catch (_) {/* نكمّل للاحتياطي */}
  return (await KatamerosRepository.instance.day(date)).synaxarium;
}
