import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../audio/audio_levels.dart';
import '../../core/coptic.dart';
import '../../data/bible.dart';
import '../../data/reminders.dart';
import '../../data/store.dart';
import '../../data/updater.dart';
import '../../native/native_bridge.dart';
import '../accent_picker.dart';
import '../../core/synaxarium.dart';
import '../../data/saint_images.dart';
import '../glass.dart';
import '../theme.dart';
import '../update_dialog.dart';
import 'home.dart' show VerseActions;

/// المزيد: المفضلة والإعدادات وتحميل الكتاب المقدس.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key, required this.onOpenFavorites, required this.onOpenReadingPlans, required this.onSettingsChanged});
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenReadingPlans;
  final VoidCallback onSettingsChanged;

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final settings = AppSettings.instance;
  bool? _offline;
  double? _progress;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    BibleRepository.instance.isOffline().then((v) {
      if (mounted) setState(() => _offline = v);
    });
  }

  Future<void> _download() async {
    setState(() {
      _progress = 0;
      _downloadError = null;
    });
    try {
      await BibleRepository.instance.downloadOffline((p) {
        if (mounted) setState(() => _progress = p);
      });
      _offline = await BibleRepository.instance.isOffline();
    } catch (e) {
      _downloadError = 'تعذّر التحميل، حاول مرة أخرى';
    }
    if (mounted) setState(() => _progress = null);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.morningMinutes ~/ 60, minute: settings.morningMinutes % 60),
    );
    if (t == null) return;
    settings.morningMinutes = t.hour * 60 + t.minute;
    NativeBridge.scheduleMorning(settings.morningEnabled, settings.morningMinutes);
    setState(() {});
  }

  static String _fmt(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    return '${ar(h % 12 == 0 ? 12 : h % 12)}:${ar(m.toString().padLeft(2, '0'))} ${h < 12 ? 'صباحاً' : 'مساءً'}';
  }

  /// يختار وقت جديد ويرجّعه، أو null لو المستخدم لغى.
  Future<int?> _pickMinutes(int current) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60));
    return t == null ? null : t.hour * 60 + t.minute;
  }

  /// صف التحديث: فحص يدوي، أو النسخة الجديدة لو لقيناها.
  Widget _updateItem() {
    final up = Updater.instance;
    return ListenableBuilder(
      listenable: up,
      builder: (context, _) {
        final u = up.available;
        if (up.checking) return _item('جارٍ فحص التحديثات…', 'لحظة', () {});
        if (u != null) {
          return _item('نسخة جديدة ${ar(u.version)}', 'اضغط للتحديث', () => showUpdateDialog(context, u));
        }
        return _item(
          up.failed ? 'تعذّر فحص التحديثات' : 'فحص التحديثات الآن',
          up.failed
              ? 'تأكد من الاتصال بالإنترنت، واضغط للمحاولة تاني'
              : up.installed > 0
                  ? 'النسخة الحالية ${ar('2.1.${up.installed}')}'
                  : 'غير متاح على الجهاز ده',
          () async {
            final found = await up.check(force: true);
            if (!context.mounted) return;
            if (found != null) {
              showUpdateDialog(context, found);
            } else if (!up.failed) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أنت على آخر نسخة')));
            }
          },
        );
      },
    );
  }

  Widget _hourRow(PrayerHour h) {
    final c = context.colors;
    final on = settings.hourOn(h.id);
    final at = settings.hourAt(h.id, h.defaultMinutes);
    return InkWell(
      onTap: on
          ? () async {
              final m = await _pickMinutes(at);
              if (m == null) return;
              settings.setHourAt(h.id, m);
              Reminders.sync();
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
              Text(on ? '${_fmt(at)} • اضغط لتغيير الوقت' : 'متوقف', style: TextStyle(fontSize: 12, color: c.textSoft)),
            ]),
          ),
          AppSwitch(
            value: on,
            label: 'تذكير ${h.name}',
            onChanged: (v) {
              settings.setHourOn(h.id, v);
              Reminders.sync();
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final time = _fmt(settings.morningMinutes);

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => ListView(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, 24),
        children: [
          const ScreenHeader('المزيد'),
          _group(null, [
            _item('المفضلة', '${ar(Favorites.instance.items.length)} آية محفوظة', widget.onOpenFavorites),
            _item('خطط قراءة الكتاب', 'اقرأ الكتاب بترتيب وتابع تقدّمك', widget.onOpenReadingPlans),
          ]),
          _label('المظهر'),
          AppSegmented(
            labels: [for (final t in ThemeChoice.values) t.label],
            selectedIndex: settings.theme.index,
            onSelected: (i) {
              settings.theme = ThemeChoice.values[i];
              widget.onSettingsChanged();
            },
          ),
          const SizedBox(height: 12),
          AccentPicker(onChanged: widget.onSettingsChanged),
          const SizedBox(height: 10),
          _toggle('ضوء متزامن مع الإيقاع', 'الضوء اللي بيظهر والصوت شغال يتحرك مع الصوت نفسه. أندرويد بيطلب إذن الميكروفون، والتطبيق مابيسجّلش حاجة', settings.syncLight, (v) async {
            if (!v) {
              settings.syncLight = false;
              return;
            }
            final ok = await AudioLevels.enableSync();
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('من غير الإذن الضوء هيفضل يتنفس بإيقاع هادي لوحده')));
            }
          }),
          _toggle('خط أميري للآيات', 'خط عربي جميل للنصوص المقدسة', settings.scriptureFont, (v) => settings.scriptureFont = v),
          const SizedBox(height: 10),
          _readingSize(),
          _toggle('القبطي المعرّب', 'يظهر في مربع منفصل تحت العربي في الخولاجي والتسبحة', settings.showCoptic, (v) => settings.showCoptic = v),
          _label('الصوت في الخلفية'),
          _group(null, [
            _item('التشغيل التلقائي', 'في شاومي وHyperOS: فعّله عشان الإذاعة ماتقفش بعد ما تخرج', () => NativeBridge.openBackgroundSettings('autostart')),
            _item('توفير البطارية', 'اختار «بدون قيود» للتطبيق', () => NativeBridge.openBackgroundSettings('battery')),
            _item('حقوق صور التذكار', 'المصوّرون والتراخيص (ويكيميديا كومنز)', _showCredits),
            _item('فحص صورة تذكار اليوم', 'يجرّب تحميل الصورة من ويكيميديا ويقولك السبب لو فشلت', _checkImage),
            _item('فحص أزرار شاشة القفل والإشعارات', 'يتأكد من الإذن والبطارية وقناة الإذاعة', _checkMedia),
          ]),
          _label('الإشعارات'),
          _toggle('رسالة الصباح', 'إشعار يومي برسالة اليوم', settings.morningEnabled, (v) {
            settings.morningEnabled = v;
            NativeBridge.scheduleMorning(v, settings.morningMinutes);
          }),
          if (settings.morningEnabled) _group(null, [_item('وقت الإشعار', time, _pickTime)]),
          _toggle('شاشة القفل', 'التاريخ القبطي ورسالة اليوم في إشعار هادئ', settings.lockNotification, (v) {
            settings.lockNotification = v;
            widget.onSettingsChanged();
          }),
          _label('التحديثات'),
          _toggle('تحديث تلقائي من GitHub', 'يفحص النسخ الجديدة ويعلّمك بيها. التركيب بيتم بموافقتك', settings.autoUpdate, (v) {
            settings.autoUpdate = v;
            NativeBridge.setUpdateOptions(v, settings.betaUpdates);
          }),
          if (settings.autoUpdate)
            _toggle('تضمين النسخ التجريبية', 'نسخ من فروع التطوير قبل ما تتدمج في الرئيسية', settings.betaUpdates, (v) {
              settings.betaUpdates = v;
              NativeBridge.setUpdateOptions(settings.autoUpdate, v);
              Updater.instance.check(force: true);
            }),
          _group(null, [_updateItem()]),
          _label('تذكير الصلاة'),
          for (final h in prayerHours) _hourRow(h),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Text('الضغط على الإشعار بيفتح الصلاة. التذكير ممكن يتأخر دقايق قليلة لتوفير البطارية.',
                style: TextStyle(fontSize: 11, height: 1.5, color: c.textFaint)),
          ),
          _label('الأعياد والأصوام'),
          _toggle('تنبيه قبلها بيوم', 'إشعار مساء اليوم السابق للأعياد وبدايات الأصوام', settings.feastReminders, (v) {
            settings.feastReminders = v;
            Reminders.sync();
          }),
          if (settings.feastReminders)
            _group(null, [
              _item('وقت التنبيه', _fmt(settings.feastAt), () async {
                final m = await _pickMinutes(settings.feastAt);
                if (m == null) return;
                settings.feastAt = m;
                Reminders.sync();
              }),
            ]),
          _label('الكتاب المقدس بدون إنترنت'),
          _group(null, [
            if (_progress != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('جارٍ التحميل… ${ar((_progress! * 100).round())}٪', style: TextStyle(color: c.text)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _progress, color: c.live, backgroundColor: c.chip),
                ]),
              )
            else if (_offline == true)
              _item('الكتاب محمّل على الجهاز ✓', 'اضغط لحذفه وتوفير المساحة', () async {
                await BibleRepository.instance.deleteOffline();
                setState(() => _offline = false);
              })
            else
              _item(_downloadError ?? 'تحميل الكتاب كاملاً', 'حوالي ٢٫٤ ميجا • يتيح القراءة والبحث بدون إنترنت', _download),
          ]),
          const SizedBox(height: 16),
          Text(
            'النصوص: ترجمة فاندايك (bolls.life) • القطمارس والسنكسار: katameros.app • العظات: popeshenouda.org.eg • الصور: ويكيبيديا',
            style: TextStyle(fontSize: 11, height: 1.6, color: c.textFaint),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
        child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: context.colors.textFaint)),
      );

  /// حجم خط القراءة في كل الشاشات (الكتاب، الأجبية، القداس، التسبحة، السنكسار).
  Widget _readingSize() {
    final c = context.colors;
    final s = AppSettings.instance.readingScale;
    void set(double v) => setState(() => AppSettings.instance.readingScale = (v * 20).round() / 20);
    return _group(null, [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 12, 4),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('حجم خط القراءة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
              Text('يسري على كل شاشات القراءة', style: TextStyle(fontSize: 12, color: c.textSoft)),
            ]),
          ),
          AppIconButton(icon: Text('أ-', style: TextStyle(fontSize: 15, color: c.text)), label: 'تصغير الخط', onTap: () => set(s - .1)),
          SizedBox(width: 56, child: Text('${ar((s * 100).round())}٪', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.textSoft))),
          AppIconButton(icon: Text('أ+', style: TextStyle(fontSize: 19, color: c.text)), label: 'تكبير الخط', onTap: () => set(s + .1)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
        child: Text('مثال: الله محبة، ومن يثبت في المحبة يثبت في الله', style: context.scripture(size: 18)),
      ),
    ]);
  }

  Widget _group(String? title, List<Widget> children) => GlassPanel(
        radius: 26,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: children),
      );

  /// حقوق الصور المضمّنة: اسم الملف على ويكيميديا كومنز، والمصوّر أو الرسّام، والرخصة.
  Future<void> _showCredits() async {
    final c = context.colors;
    List<dynamic> items = const [];
    try {
      items = jsonDecode(await rootBundle.loadString('assets/saints/credits.json')) as List;
    } catch (_) {/* القائمة فاضية */}
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حقوق صور التذكار'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(shrinkWrap: true, children: [
            Text('الصور من ويكيميديا كومنز، وأغلبها ملك عام. اللي له رخصة بيذكر صاحبها هنا.', style: TextStyle(fontSize: 12, height: 1.6, color: c.textSoft)),
            for (final e in items)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e['file'] as String, textDirection: TextDirection.ltr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text)),
                  Text('${e['artist']} — ${e['license']}', textDirection: TextDirection.ltr, style: TextStyle(fontSize: 11, color: c.textSoft)),
                ]),
              ),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تمام'))],
      ),
    );
  }

  /// يجرّب تحميل صورة تذكار النهارده بنفس الطريقة وبنفس اسم التطبيق، ويعرض النتيجة (كود الرد، الحجم، أو سبب الفشل).
  Future<void> _checkImage() async {
    final com = Synaxarium.forDate(DateTime.now());
    final url = com.wiki == null ? null : SaintImages.verified[com.wiki];
    final c = context.colors;
    String report;
    if (url == null) {
      report = 'تذكار النهارده (${com.title}) مالوش صورة مؤكدة في الجدول، فبيظهر الصليب.';
    } else {
      final sw = Stopwatch()..start();
      final log = <String>[];
      // فحص الشبكة نفسها: هل ويكيميديا بتتفتح من الجهاز أصلاً؟
      try {
        final ips = await InternetAddress.lookup('upload.wikimedia.org').timeout(const Duration(seconds: 10));
        log.add('DNS: ${ips.map((e) => e.address).take(2).join(', ')}');
      } catch (e) {
        log.add('DNS فشل: $e');
      }
      try {
        final r = await http.get(Uri.parse('https://en.wikipedia.org/static/images/project-logos/enwiki.png'), headers: SaintImages.imageHeaders).timeout(const Duration(seconds: 15));
        log.add('شعار ويكيبيديا: ${r.statusCode}');
      } catch (e) {
        log.add('شعار ويكيبيديا فشل: $e');
      }
      final bytes = await SaintImages.instance.loadBytes(url, log: log, fresh: true);
      var decoded = 'لم تتحمّل';
      if (bytes != null) {
        try {
          final codec = await ui.instantiateImageCodec(bytes);
          final f = (await codec.getNextFrame()).image;
          decoded = 'تمام: ${f.width}×${f.height} بكسل، ${(bytes.length / 1024).round()} ك.ب';
        } catch (e) {
          decoded = 'الملف مش صورة صالحة ($e)';
        }
      }
      report = '${log.isEmpty ? 'من الملف المحفوظ على الجهاز' : log.join('\n')}\n\nالنتيجة: $decoded\nالزمن: ${sw.elapsedMilliseconds} م.ث';
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('فحص صورة التذكار'),
        content: SelectableText('${com.title}\n${url ?? ''}\n\n$report', style: TextStyle(fontSize: 13, height: 1.6, color: c.text)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تمام'))],
      ),
    );
  }

  /// يفحص إن أزرار تشغيل الإذاعة والعظات ممكن تظهر في شاشة القفل وشريط الإشعارات، ويقول إيه اللي ناقص.
  Future<void> _checkMedia() async {
    final m = await NativeBridge.mediaStatus();
    if (!mounted) return;
    final c = context.colors;
    Widget row(bool ok, String text, {VoidCallback? fix, String fixLabel = 'إصلاح'}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(ok ? Icons.check_circle : Icons.error_outline, size: 20, color: ok ? Colors.green : c.saint),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(fontSize: 14, height: 1.5, color: c.text))),
            if (!ok && fix != null) TextButton(onPressed: fix, child: Text(fixLabel)),
          ]),
        );
    final notif = m?['notifications'] == true;
    final channel = (m?['channel'] as int?) ?? -1;
    final battery = m?['battery'] == true;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('فحص أزرار التشغيل'),
        content: m == null
            ? const Text('الفحص متاح على أندرويد بس')
            : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                row(notif, notif ? 'الإشعارات مفعّلة للتطبيق' : 'الإشعارات مقفولة: من غيرها مفيش أزرار', fix: NativeBridge.openNotificationSettings, fixLabel: 'فتح'),
                row(channel != 0, channel == -1 ? 'قناة الإذاعة هتتعمل أول ما تشغّل صوت' : (channel == 0 ? 'قناة «الإذاعة» مقفولة في إعدادات الإشعارات' : 'قناة «الإذاعة» شغالة'),
                    fix: NativeBridge.openNotificationSettings, fixLabel: 'فتح'),
                row(battery, battery ? 'توفير البطارية مش بيقيّد التطبيق' : 'توفير البطارية ممكن يقفل الصوت بعد ما تخرج', fix: () => NativeBridge.openBackgroundSettings('battery'), fixLabel: 'فتح'),
                const SizedBox(height: 8),
                Text('الجهاز: ${m['maker']} • أندرويد ${m['sdk']}', style: TextStyle(fontSize: 12, color: c.textFaint)),
                const SizedBox(height: 6),
                Text('في شاومي وHyperOS: فعّل «التشغيل التلقائي» وثبّت التطبيق في قائمة التطبيقات الأخيرة (قفل)، لأن السحب منها بيقفل التطبيق والإشعار.',
                    style: TextStyle(fontSize: 12, height: 1.6, color: c.textSoft)),
              ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تمام'))],
      ),
    );
  }

  Widget _item(String title, String subtitle, VoidCallback onTap) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: c.textSoft)),
            ]),
          ),
          Icon(Icons.chevron_left, color: c.textSoft),
        ]),
      ),
    );
  }

  /// مفتاح زجاجي — خارج أي بطاقة زجاجية كما توصي الحزمة.
  Widget _toggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: c.textSoft)),
          ]),
        ),
        AppSwitch(value: value, onChanged: onChanged, label: title),
      ]),
    );
  }
}

/// الآيات المحفوظة.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.onOpenChapter, required this.onBack});
  final ValueChanged<VerseRef> onOpenChapter;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: Favorites.instance,
      builder: (context, _) {
        final items = Favorites.instance.items;
        return ListView(
          padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, MediaQuery.paddingOf(context).bottom + 32),
          children: [
            ScreenHeader('المفضلة', subtitle: 'الآيات التي حفظتها', onBack: onBack),
            if (items.isEmpty)
              Text('لم تحفظ آيات بعد. اضغط ♡ بجوار رسالة اليوم أو على أي آية في الإصحاح.',
                  style: TextStyle(height: 1.6, color: c.textSoft)),
            for (final f in items) ...[
              GlassPanel(
                radius: 24,
                padding: const EdgeInsets.all(18),
                onTap: () => onOpenChapter(f.ref),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('«${f.text}»', style: context.scripture(size: 18)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: Text(f.ref.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent))),
                    VerseActions(ref: f.ref, text: f.text, showCopy: true),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}
