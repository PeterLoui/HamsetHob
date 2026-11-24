import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/synaxarium.dart';
import '../data/net.dart';
import '../data/saint_images.dart';
import 'native_bridge.dart';

/// يبعت لويدجت التقويم القبطي تذكارات الأيام الجاية وصورة تذكار النهارده.
///
/// التذكارات من جدول السنكسار المحلي (١٤ يوم قدّام)، وتذكار النهارده بيتبدّل بالاسم الكامل
/// (قديس السنكسار) لما التطبيق يعرفه. الصورة بتتنزّل في ملف صغير، وأندرويد بيقراه.
class CalendarWidgetSync {
  CalendarWidgetSync._();

  static const horizon = 14;
  static String? _lastImageUrl;
  static String? _lastImageDay;

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// [full] تذكار النهارده بالاسم الكامل لو معروف، و[imageUrl] صورته لو لقيناها.
  static Future<void> sync(DateTime today, {Commemoration? full, String? imageUrl}) async {
    final base = DateTime(today.year, today.month, today.day);
    final days = <Map<String, Object?>>[];
    for (var i = 0; i < horizon; i++) {
      final d = DateTime(base.year, base.month, base.day + i);
      final c = i == 0 && full != null ? full : Synaxarium.forDate(d);
      days.add({'date': _iso(d), 'title': c.title, 'detail': c.detail, 'kind': c.kind.label});
    }
    String? path;
    if (imageUrl != null) {
      try {
        path = await _download(imageUrl, _iso(base));
      } catch (_) {
        path = null; // من غير صورة، الويدجت بيعرض النص بس
      }
    }
    await NativeBridge.updateCalendarWidget(days: days, imagePath: path, imageDate: path == null ? null : _iso(base));
  }

  static Future<String> _download(String url, String day) async {
    final file = File('${(await getApplicationSupportDirectory()).path}/calendar_widget.img');
    if (_lastImageUrl == url && _lastImageDay == day && file.existsSync()) return file.path;
    final bytes = await SaintImages.instance.loadBytes(url);
    if (bytes == null || bytes.isEmpty) throw HttpStatusError(0);
    await file.writeAsBytes(bytes, flush: true);
    _lastImageUrl = url;
    _lastImageDay = day;
    return file.path;
  }
}
