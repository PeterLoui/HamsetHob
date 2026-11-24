import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/coptic.dart';
import 'reminders.dart';

/// بنود ورد اليوم الأربعة.
enum WirdItem { prayer, chapter, sermon, quiz }

/// ورد اليوم: أي بنود اتخلّصت النهارده. بيتصفّر لوحده مع بداية كل يوم، ومفيش عدّ للأيام اللي فاتت.
class WirdStore extends ChangeNotifier {
  WirdStore._(this._prefs) {
    _roll();
  }
  final SharedPreferences _prefs;
  static WirdStore? instance;

  static Future<WirdStore> load() async => instance ??= WirdStore._(await SharedPreferences.getInstance());

  Set<String> _done = {};
  String _day = '';

  static String dayKey(DateTime d) => dateOnly(d).toIso8601String().substring(0, 10);

  void _roll() {
    final today = dayKey(DateTime.now());
    if (_day == today) return;
    _day = today;
    _done = _prefs.getString('wird_day') == today ? {...?_prefs.getStringList('wird_done')} : {};
  }

  bool isDone(WirdItem i) {
    _roll();
    return _done.contains(i.name);
  }

  int get count {
    _roll();
    return _done.length;
  }

  bool get complete => count == WirdItem.values.length;

  Future<void> _save() async {
    await _prefs.setString('wird_day', _day);
    await _prefs.setStringList('wird_done', _done.toList());
    notifyListeners();
  }

  Future<void> mark(WirdItem i) async {
    _roll();
    if (_done.add(i.name)) await _save();
  }

  Future<void> toggle(WirdItem i) async {
    _roll();
    if (!_done.remove(i.name)) _done.add(i.name);
    await _save();
  }

  /// تعليم من أي مكان في التطبيق من غير ما نقلق لو الورد لسه ماتحمّلش.
  static void markIf(WirdItem i) => instance?.mark(i);

  /// ساعة الأجبية المناسبة للوقت: باكر الصبح، والغروب المغرب، وهكذا.
  static PrayerHour hourFor(DateTime now) {
    final h = now.hour;
    final id = h < 3
        ? 'midnight'
        : h < 9
            ? 'prime'
            : h < 12
                ? 'terce'
                : h < 15
                    ? 'sext'
                    : h < 18
                        ? 'none'
                        : h < 21
                            ? 'vespers'
                            : 'compline';
    return prayerHours.firstWhere((p) => p.id == id);
  }
}
