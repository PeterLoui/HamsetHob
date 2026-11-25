import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../native/native_bridge.dart';
import 'net.dart';
import 'store.dart';

/// نسخة جديدة منشورة على إصدارات GitHub.
class UpdateInfo {
  const UpdateInfo({
    required this.build,
    required this.version,
    required this.notes,
    required this.apkUrl,
    required this.size,
    required this.prerelease,
    this.sha256,
  });

  /// رقم البناء (رقم التشغيل في GitHub)، وهو versionCode في التطبيق.
  final int build;

  /// زي 2.1.34
  final String version;
  final String notes;
  final String apkUrl;
  final int size;
  final bool prerelease;

  /// بصمة الملف لو GitHub بعتها.
  final String? sha256;
}

enum InstallResult { started, needsPermission, failed }

/// التحديث من GitHub: يفحص آخر إصدار، وينزّله، ويسلّمه للنظام يركّبه.
///
/// الإصدارات بتتسمى v2.1.N والرقم N هو رقم بناء التطبيق، فالمقارنة بالرقم مش بالاسم.
/// أندرويد بيرفض أي APK مش متوقّع بنفس مفتاح توقيع التطبيق المركّب، فمهما حصل في الملف
/// مفيش نسخة غريبة هتتركّب فوق التطبيق. وبنطابق البصمة كمان لو GitHub بعتها.
class Updater extends ChangeNotifier {
  Updater._();
  static final instance = Updater._();

  static const repo = 'PeterLoui/HamsetHob';
  static const _every = Duration(minutes: 15);

  /// رقم بناء النسخة المركّبة (٠ لو مش معروف، وساعتها مفيش فحص).
  int installed = 0;

  UpdateInfo? available;
  bool checking = false;

  /// آخر فحص فشل (مثلاً مافيش نت).
  bool failed = false;
  DateTime? lastCheck;

  Future<void> init() async {
    installed = await NativeBridge.appBuild();
    final prefs = await SharedPreferences.getInstance();
    final at = prefs.getInt('upd_last');
    if (at != null) lastCheck = DateTime.fromMillisecondsSinceEpoch(at);
    final s = AppSettings.instance;
    await NativeBridge.setUpdateOptions(s.autoUpdate, s.betaUpdates);
  }

  /// أحدث إصدار أكبر من المركّب (مع تخطي المسودات، والتجريبي لو مش مفعّل)، أو null.
  static UpdateInfo? pick(List<dynamic> releases, int installed, {required bool beta}) {
    UpdateInfo? best;
    for (final r in releases) {
      if (r is! Map) continue;
      if (r['draft'] == true) continue;
      final pre = r['prerelease'] == true;
      if (pre && !beta) continue;
      final tag = r['tag_name'] as String? ?? '';
      final m = RegExp(r'^v?(\d+(?:\.\d+)*\.(\d+))$').firstMatch(tag);
      if (m == null) continue;
      final build = int.parse(m[2]!);
      if (build <= installed) continue;
      Map? apk;
      for (final a in (r['assets'] as List? ?? const []).whereType<Map>()) {
        if ((a['name'] as String? ?? '').toLowerCase().endsWith('.apk')) {
          apk = a;
          break;
        }
      }
      final url = apk?['browser_download_url'] as String?;
      if (apk == null || url == null || !url.startsWith('https://')) continue;
      final digest = apk['digest'] as String?;
      final info = UpdateInfo(
        build: build,
        version: m[1]!,
        notes: (r['body'] as String? ?? '').trim(),
        apkUrl: url,
        size: (apk['size'] as num?)?.toInt() ?? 0,
        prerelease: pre,
        sha256: digest != null && digest.startsWith('sha256:') ? digest.substring(7).toLowerCase() : null,
      );
      if (best == null || info.build > best.build) best = info;
    }
    return best;
  }

  /// يفحص GitHub. [force] بيتخطى فترة الانتظار القصيرة (١٥ دقيقة) بين الفحوصات.
  Future<UpdateInfo?> check({bool force = false}) async {
    if (installed == 0) await init();
    if (installed == 0 || checking) return available;
    final last = lastCheck;
    if (!force && last != null && DateTime.now().difference(last) < _every) return available;
    checking = true;
    failed = false;
    notifyListeners();
    try {
      final releases = await getJson('https://api.github.com/repos/$repo/releases?per_page=15') as List;
      available = pick(releases, installed, beta: AppSettings.instance.betaUpdates);
      lastCheck = DateTime.now();
      (await SharedPreferences.getInstance()).setInt('upd_last', lastCheck!.millisecondsSinceEpoch);
    } catch (_) {
      failed = true;
    }
    checking = false;
    notifyListeners();
    return available;
  }

  /// «لاحقاً» على نسخة: ما نعرضهاش تاني في فتح التطبيق، لكنها تفضل ظاهرة في الإعدادات.
  Future<bool> dismissedBuild(int build) async => (await SharedPreferences.getInstance()).getInt('upd_dismissed') == build;
  Future<void> dismiss(int build) async => (await SharedPreferences.getInstance()).setInt('upd_dismissed', build);

  /// ينزّل الـ APK ويرجّع مساره، ويحدّث [onProgress] من ٠ لـ ١. بيرمي استثناء لو التحميل فشل أو الملف مش سليم.
  Future<String> download(UpdateInfo u, ValueChanged<double> onProgress) async {
    final dir = await getTemporaryDirectory();
    for (final f in dir.listSync()) {
      // نسخ قديمة من تحديثات فاتت
      if (f is File && f.path.contains('hamset-update-') && !f.path.endsWith('${u.build}.apk')) f.deleteSync();
    }
    final file = File('${dir.path}/hamset-update-${u.build}.apk');
    if (file.existsSync() && await _valid(file, u)) {
      onProgress(1);
      return file.path;
    }
    final client = http.Client();
    final part = File('${file.path}.part');
    try {
      final res = await openStream(client, u.apkUrl);
      if (res.statusCode >= 400) throw HttpStatusError(res.statusCode);
      final total = res.contentLength ?? u.size;
      var done = 0, tick = 0;
      final sink = part.openWrite();
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          done += chunk.length;
          if (total > 0 && done - tick > 128 * 1024) {
            tick = done;
            onProgress((done / total).clamp(0.0, .99));
          }
        }
      } finally {
        await sink.close();
      }
      if (total > 0 && done != total) throw const HttpException('incomplete');
      if (!await _valid(part, u)) throw const HttpException('checksum');
      await part.rename(file.path);
      onProgress(1);
      return file.path;
    } catch (_) {
      if (part.existsSync()) part.deleteSync();
      rethrow;
    } finally {
      client.close();
    }
  }

  /// حجم وبصمة الملف (لو معروفة) مطابقين للإصدار.
  static Future<bool> _valid(File f, UpdateInfo u) async {
    if (u.size > 0 && f.lengthSync() != u.size) return false;
    final want = u.sha256;
    if (want == null) return true;
    final got = await sha256.bind(f.openRead()).first;
    return got.toString() == want;
  }

  Future<InstallResult> install(String path) async {
    final r = await NativeBridge.installApk(path);
    if (r == 'started') return InstallResult.started;
    if (r == 'needs_permission') return InstallResult.needsPermission;
    return InstallResult.failed;
  }
}
