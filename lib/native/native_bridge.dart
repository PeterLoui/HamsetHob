import 'package:flutter/services.dart';

import '../data/bible.dart';

/// قناة الاتصال بكود أندرويد الأصلي: الويدجتس وإشعار شاشة القفل وإشعار الصباح.
class NativeBridge {
  static const _channel = MethodChannel('hamset/native');

  /// يحدّث الويدجتس وإشعار القفل. glassPng: صورة سطح الزجاج المرسومة بالحزمة.
  static Future<void> updateWidgets({
    required String copticLabel,
    required String copticDay,
    required String copticMonth,
    required DailyVerse verse,
    required bool lockNotification,
  }) =>
      _call('updateWidgets', {
        'copticLabel': copticLabel,
        'copticDay': copticDay,
        'copticMonth': copticMonth,
        'text': verse.text,
        'ref': verse.ref.label,
        'book': verse.ref.book,
        'chapter': verse.ref.chapter,
        'verse': verse.ref.verse,
        'lockNotification': lockNotification,
      });

  /// يحفظ صورة سطح الزجاج للويدجت (PNG) ليستخدمها الويدجت خلفيةً.
  static Future<void> setWidgetGlass(String kind, Uint8List png) =>
      _call('setWidgetGlass', {'kind': kind, 'png': png});

  static Future<void> scheduleMorning(bool enabled, int minutes) =>
      _call('scheduleMorning', {'enabled': enabled, 'minutes': minutes});

  /// الآية التي فُتح بها التطبيق من الويدجت أو الإشعار، إن وُجدت.
  static Future<VerseRef?> takeLaunchRef() async {
    final m = await _channel.invokeMapMethod<String, int>('takeLaunchRef');
    if (m == null || (m['book'] ?? 0) == 0) return null;
    return VerseRef(m['book']!, m['chapter'] ?? 1, m['verse'] ?? 1);
  }

  static void onLaunchRef(void Function(VerseRef) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openRef') {
        final m = (call.arguments as Map).cast<String, int>();
        handler(VerseRef(m['book']!, m['chapter'] ?? 1, m['verse'] ?? 1));
      }
    });
  }

  static Future<void> _call(String method, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod(method, args);
    } on MissingPluginException {
      // خارج أندرويد
    } on PlatformException {
      // لا نوقف الواجهة بسبب الويدجت
    }
  }
}
