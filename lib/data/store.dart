import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bible.dart';

enum ThemeChoice {
  system('تلقائي'),
  light('فاتح'),
  dark('داكن');

  const ThemeChoice(this.label);
  final String label;
}

/// إعدادات التطبيق، تُحفظ فور تغييرها.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);
  final SharedPreferences _prefs;
  static late AppSettings instance;

  static Future<void> load() async => instance = AppSettings._(await SharedPreferences.getInstance());

  ThemeChoice get theme => ThemeChoice.values.byName(_prefs.getString('theme') ?? 'system');
  set theme(ThemeChoice v) => _set(() => _prefs.setString('theme', v.name));

  bool get seasonalColors => _prefs.getBool('seasonal') ?? true;
  set seasonalColors(bool v) => _set(() => _prefs.setBool('seasonal', v));

  bool get scriptureFont => _prefs.getBool('amiri') ?? true;
  set scriptureFont(bool v) => _set(() => _prefs.setBool('amiri', v));

  bool get lockNotification => _prefs.getBool('lock_notif') ?? true;
  set lockNotification(bool v) => _set(() => _prefs.setBool('lock_notif', v));

  bool get morningEnabled => _prefs.getBool('morning') ?? false;
  set morningEnabled(bool v) => _set(() => _prefs.setBool('morning', v));

  int get morningMinutes => _prefs.getInt('morning_at') ?? 7 * 60;
  set morningMinutes(int v) => _set(() => _prefs.setInt('morning_at', v));

  void _set(Future<bool> Function() write) {
    write();
    notifyListeners();
  }
}

class Favorite {
  const Favorite(this.ref, this.text);
  final VerseRef ref;
  final String text;
}

/// الآيات المحفوظة، الأحدث أولاً.
class Favorites extends ChangeNotifier {
  Favorites._(this._prefs) {
    final raw = jsonDecode(_prefs.getString('favorites') ?? '[]') as List;
    items.addAll(raw.map((o) => Favorite(VerseRef(o['b'] as int, o['c'] as int, o['v'] as int), o['t'] as String)));
  }
  final SharedPreferences _prefs;
  final items = <Favorite>[];
  static late Favorites instance;

  static Future<void> load() async => instance = Favorites._(await SharedPreferences.getInstance());

  bool contains(VerseRef ref) => items.any((f) => f.ref == ref);

  void toggle(VerseRef ref, String text) {
    if (contains(ref)) {
      items.removeWhere((f) => f.ref == ref);
    } else {
      items.insert(0, Favorite(ref, text));
    }
    _prefs.setString(
      'favorites',
      jsonEncode([for (final f in items) {'b': f.ref.book, 'c': f.ref.chapter, 'v': f.ref.verse, 't': f.text}]),
    );
    notifyListeners();
  }
}
