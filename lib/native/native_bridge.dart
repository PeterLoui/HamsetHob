import 'package:flutter/services.dart';

import '../data/bible.dart';

/// قناة الاتصال بكود أندرويد الأصلي: الويدجتس وإشعار شاشة القفل وإشعار الصباح.
class NativeBridge {
  static const _channel = MethodChannel('hamset/native');
  static const _levels = EventChannel('hamset/levels');

  /// يحدّث الويدجتس وإشعار القفل.
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

  /// يمسك قفل الشبكة والمعالج طول ما الصوت شغال عشان البث مايقفش والشاشة مقفولة.
  static Future<void> setPlaybackLock(bool playing) => _call('setPlaybackLock', {'playing': playing});

  /// يطلب استثناء التطبيق من توفير البطارية (مرة واحدة).
  static Future<void> requestBatteryExemption() => _call('requestBatteryExemption', {});

  /// يفتح إعدادات التشغيل في الخلفية: 'autostart' (التشغيل التلقائي في شاومي) أو 'battery'.
  static Future<bool> openBackgroundSettings(String kind) => _ask('openBackgroundSettings', {'kind': kind});

  /// الشاشة تفضل منورة (أثناء قراءة التسبحة مثلاً).
  static Future<void> keepScreenOn(bool on) => _call('keepScreenOn', {'on': on});

  static Future<void> scheduleMorning(bool enabled, int minutes) =>
      _call('scheduleMorning', {'enabled': enabled, 'minutes': minutes});

  /// يجدول تذكيرات الصلاة والأعياد (بيلغي القديم). كل عنصر: id وtitle وbody وإما minutes (يومي) أو at (ميلي ثانية).
  static Future<void> scheduleReminders(List<Map<String, Object?>> list) => _call('scheduleReminders', {'list': list});

  /// الصلاة اللي اتفتح بيها التطبيق من إشعار تذكير، إن وُجدت.
  static Future<String?> takeLaunchPrayer() async {
    try {
      return await _channel.invokeMethod<String>('takeLaunchPrayer');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// إشعار تذكير اتضغط والتطبيق مفتوح.
  static void Function(String prayerId)? onOpenPrayer;

  /// الآية التي فُتح بها التطبيق من الويدجت أو الإشعار، إن وُجدت.
  static Future<VerseRef?> takeLaunchRef() async {
    final m = await _channel.invokeMapMethod<String, int>('takeLaunchRef');
    if (m == null || (m['book'] ?? 0) == 0) return null;
    return VerseRef(m['book']!, m['chapter'] ?? 1, m['verse'] ?? 1);
  }

  /// زرار التشغيل في ويدجت الإذاعة والتطبيق مفتوح.
  static void Function()? onResumeRadio;

  /// التطبيق اتفتح من زرار التشغيل في ويدجت الإذاعة؟
  static Future<bool> takeResume() => _ask('takeResume', {});

  /// حالة ويدجت الإذاعة: اللي شغال، والسطر اللي تحته، وشغال ولا واقف.
  static Future<void> updateRadioWidget(String title, String sub, bool playing) =>
      _call('updateRadioWidget', {'title': title, 'sub': sub, 'playing': playing});

  static void onLaunchRef(void Function(VerseRef) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'resumeRadio') onResumeRadio?.call();
      if (call.method == 'openPrayer') onOpenPrayer?.call(call.arguments as String);
      if (call.method == 'openRef') {
        final m = (call.arguments as Map).cast<String, int>();
        handler(VerseRef(m['book']!, m['chapter'] ?? 1, m['verse'] ?? 1));
      }
    });
  }

  /// مستويات الصوت الشغال [باص، وسط، حاد] من ٠ لـ ١، للضوء المتزامن مع الإيقاع.
  static Stream<List<double>> get levels =>
      _levels.receiveBroadcastStream().map((e) => [for (final v in e as List) (v as num).toDouble()]);

  /// يبدأ قراءة مستويات الصوت من جلسة المشغّل. false لو مافيش إذن أو الجلسة مش متاحة.
  static Future<bool> startLevels(int session) => _ask('startLevels', {'session': session});

  static Future<void> stopLevels() => _call('stopLevels', {});

  /// يطلب إذن الميكروفون (أندرويد بيطلبه للـ Visualizer، والتطبيق مابيسجّلش حاجة).
  static Future<bool> requestMic() => _ask('requestMic', {});

  static Future<bool> _ask(String method, Map<String, Object?> args) async {
    try {
      return await _channel.invokeMethod<bool>(method, args) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
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
