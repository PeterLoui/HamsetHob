import '../core/synaxarium.dart';
import '../native/native_bridge.dart';
import 'store.dart';

/// ساعة من الأجبية ليها تذكير: [prayerId] هو رقم الصلاة في assets/agpeya.json (بيفتحها الإشعار).
class PrayerHour {
  const PrayerHour(this.id, this.name, this.prayerId, this.defaultMinutes);
  final String id;
  final String name;
  final String prayerId;
  final int defaultMinutes;
}

const prayerHours = [
  PrayerHour('prime', 'صلاة باكر', 'Prime', 6 * 60),
  PrayerHour('terce', 'الساعة الثالثة', 'Terce', 9 * 60),
  PrayerHour('sext', 'الساعة السادسة', 'Sext', 12 * 60),
  PrayerHour('none', 'الساعة التاسعة', 'None', 15 * 60),
  PrayerHour('vespers', 'الغروب', 'Vespers', 18 * 60),
  PrayerHour('compline', 'النوم', 'Compline', 21 * 60),
  PrayerHour('midnight', 'نصف الليل', 'Midnight_1', 0),
];

/// تذكيرات الصلاة ومساء اليوم السابق للأعياد والأصوام.
///
/// الحساب هنا، والجدولة في أندرويد (AlarmManager)، فالتذكير بيجي والتطبيق مقفول وبعد إعادة تشغيل الموبايل.
/// بنبعت القايمة كلها كل مرة، وأندرويد بيلغي القديم ويجدول الجديد.
class Reminders {
  Reminders._();

  /// كام يوم قدّام نحسب فيها الأعياد والأصوام.
  static const horizonDays = 60;

  static const _prayerBase = 100;
  static const _feastBase = 1000;

  /// قايمة التذكيرات حسب الإعدادات. كل عنصر: id، العنوان، النص، وإما minutes (يومي) أو at (مرة واحدة بالميلي ثانية).
  static List<Map<String, Object?>> build(AppSettings s, DateTime now) {
    final out = <Map<String, Object?>>[];
    for (var i = 0; i < prayerHours.length; i++) {
      final h = prayerHours[i];
      if (!s.hourOn(h.id)) continue;
      out.add({
        'id': _prayerBase + i,
        'title': 'حان وقت ${h.name}',
        'body': 'اضغط لفتح الصلاة',
        'minutes': s.hourAt(h.id, h.defaultMinutes),
        'prayer': h.prayerId,
      });
    }
    if (s.wirdReminder) {
      out.add({
        'id': 90,
        'title': 'وردك اليوم',
        'body': 'شمعات النهارده مستنياك، خطوة خطوة',
        'minutes': s.wirdAt,
      });
    }
    if (s.feastReminders) {
      final at = s.feastAt;
      for (var d = 1; d <= horizonDays; d++) {
        final day = DateTime(now.year, now.month, now.day + d);
        final c = Synaxarium.feastOrFast(day);
        if (c == null) continue;
        // مساء اليوم اللي قبله
        final when = DateTime(day.year, day.month, day.day - 1, at ~/ 60, at % 60);
        if (!when.isAfter(now)) continue;
        out.add({
          'id': _feastBase + d,
          'title': 'غداً: ${c.title}',
          'body': c.detail,
          'at': when.millisecondsSinceEpoch,
        });
      }
    }
    return out;
  }

  static Future<void> sync() => NativeBridge.scheduleReminders(build(AppSettings.instance, DateTime.now()));
}
