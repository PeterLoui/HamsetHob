import 'dart:async';

import 'package:flutter/material.dart';

import '../../audio/radio_player.dart';
import '../../core/coptic.dart';
import '../../data/sermon_downloads.dart';
import '../../data/sermons.dart';
import '../../native/native_bridge.dart';
import '../fluid_light.dart';
import '../glass.dart';
import '../icons.dart';
import '../theme.dart';
import 'home.dart' show PlayButton;

String formatTime(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return ar(h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}');
}

/// شاشة الإذاعة: المشغّل + أقسام المكتبة + البحث.
class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final _repo = SermonRepository.instance;
  final _scroll = ScrollController();
  final _sermons = <Sermon>[];
  int _category = 0;
  String _query = '';
  int _page = 0;
  int _totalPages = 1;
  bool _loading = false;
  bool _failed = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    SermonDownloads.instance.addListener(_onDownloads);
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600 && _page < _totalPages) _load(reset: false);
    });
  }

  @override
  void dispose() {
    SermonDownloads.instance.removeListener(_onDownloads);
    _scroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// تبويب «المحمّلة»: بيشتغل من غير نت وبيتفلتر محلياً.
  static const _downloadsTab = -1;

  int _seenCount = SermonDownloads.instance.count;

  /// عظة اتحذفت (أو اتضافت) وإحنا واقفين في «المحمّلة»: القايمة تتحدّث.
  void _onDownloads() {
    final n = SermonDownloads.instance.count;
    if (n == _seenCount) return;
    _seenCount = n;
    if (_category == _downloadsTab && mounted) _showDownloads();
  }

  void _showDownloads() {
    final q = _query.trim();
    setState(() {
      _loading = false;
      _failed = false;
      _page = 1;
      _totalPages = 1;
      _sermons
        ..clear()
        ..addAll(SermonDownloads.instance.sermons.where((s) => q.isEmpty || s.title.contains(q) || s.summary.contains(q)));
    });
  }

  Future<void> _load({required bool reset}) async {
    if (_category == _downloadsTab) return _showDownloads();
    if (_loading && !reset) return;
    final category = _category, query = _query, target = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) _sermons.clear();
    });
    try {
      final p = await _repo.page(category, query, target);
      if (!mounted || category != _category || query != _query) return;
      setState(() {
        _sermons.addAll(p.items);
        _page = target;
        _totalPages = p.totalPages;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final player = RadioPlayer.instance;
    return ListView(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, MediaQuery.paddingOf(context).bottom + 32),
      children: [
        ScreenHeader('المكتبة السمعية', subtitle: 'البابا شنودة الثالث', onBack: widget.onBack),
        _NowPlaying(onStartRadio: () => player.startRadio(_category)),
        const SizedBox(height: 14),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sermonCategories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              // أول تبويب: العظات المحمّلة على الجهاز
              final cat = i == 0 ? const SermonCategory(_downloadsTab, 'المحمّلة') : sermonCategories[i - 1];
              return AppChip(
                label: cat.name,
                selected: cat.id == _category,
                onTap: () {
                  _category = cat.id;
                  _load(reset: true);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        AppSearchBar(
          placeholder: 'ابحث في العظات',
          onChanged: (q) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 450), () {
              _query = q;
              _load(reset: true);
            });
          },
        ),
        const SizedBox(height: 12),
        if (_category == _downloadsTab) _DownloadsSummary(onChanged: _showDownloads),
        if (_failed && _sermons.isEmpty)
          Text(
              SermonDownloads.instance.count > 0
                  ? 'تعذّر تحميل العظات، تأكد من الاتصال بالإنترنت، أو افتح «المحمّلة» لسماع العظات المحمّلة'
                  : 'تعذّر تحميل العظات، تأكد من الاتصال بالإنترنت',
              style: TextStyle(color: c.textSoft)),
        if (!_loading && !_failed && _sermons.isEmpty)
          Text(_category == _downloadsTab ? 'ما حمّلتش عظات لسه. اضغط على سهم التحميل جنب أي عظة.' : 'لا توجد عظات مطابقة',
              style: TextStyle(color: c.textSoft)),
        for (final s in _sermons) ...[_SermonRow(sermon: s), const SizedBox(height: 10)],
        if (_loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
      ],
    );
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.onStartRadio});
  final VoidCallback onStartRadio;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final player = RadioPlayer.instance;
    return GlassPanel(
      radius: 30,
      child: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          final now = player.nowPlaying;
          final dur = player.duration.inMilliseconds;
          return Column(children: [
            FluidLight(
              spread: 34,
              strength: 1.3,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c.live.withValues(alpha: .08)),
                child: Center(child: AppIconView(AppIcon.radio, size: 34, color: c.live)),
              ),
            ),
            const SizedBox(height: 12),
            Text(now?.title ?? 'اختر عظة أو ابدأ البث المتواصل',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
            Text(
              now == null ? 'عظات عشوائية متتالية من المكتبة' : player.subtitle,
              style: TextStyle(fontSize: 12, color: c.textSoft),
            ),
            if (now != null && !player.live) ...[
              const SizedBox(height: 10),
              AppSlider(
                value: dur == 0 ? 0 : (player.position.inMilliseconds / dur).clamp(0, 1).toDouble(),
                onChanged: (v) => player.seekTo(Duration(milliseconds: (v * dur).round())),
              ),
              Row(children: [
                Text(formatTime(player.position), style: TextStyle(fontSize: 11, color: c.textFaint)),
                const Spacer(),
                Text(formatTime(player.duration), style: TextStyle(fontSize: 11, color: c.textFaint)),
              ]),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                RoundAction(icon: AppIconView(AppIcon.back30, size: 22, color: c.text), onTap: () => player.seekBy(-30), tooltip: 'رجوع ٣٠ ثانية', size: 46),
                const SizedBox(width: 18),
                const PlayButton(size: 62),
                const SizedBox(width: 18),
                RoundAction(icon: AppIconView(AppIcon.forward30, size: 22, color: c.text), onTap: () => player.seekBy(30), tooltip: 'تقديم ٣٠ ثانية', size: 46),
                if (player.radioOn) ...[
                  const SizedBox(width: 18),
                  RoundAction(icon: AppIconView(AppIcon.next, size: 22, color: c.text), onTap: player.next, tooltip: 'العظة التالية', size: 46),
                ],
              ]),
            ],
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
              Pill(player.radioOn ? 'إيقاف البث المتواصل' : 'بث متواصل عشوائي',
                  onTap: player.radioOn ? player.stopRadio : onStartRadio),
              Pill(sleepLabel(player), filled: player.sleepOn, onTap: () => showSleepTimer(context)),
            ]),
            if (player.notificationsOff && now != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Expanded(
                    child: Text('الإشعارات مقفولة، فمش هتظهر أزرار التشغيل والإيقاف في شاشة القفل وشريط الإشعارات',
                        style: TextStyle(fontSize: 12, height: 1.5, color: c.textSoft)),
                  ),
                  TextButton(
                    onPressed: NativeBridge.openNotificationSettings,
                    child: Text('فتح الإعدادات', style: TextStyle(color: c.live)),
                  ),
                ]),
              ),
            if (player.error != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(player.error!, style: TextStyle(fontSize: 12, color: c.saint))),
          ]);
        },
      ),
    );
  }
}

class _SermonRow extends StatelessWidget {
  const _SermonRow({required this.sermon});
  final Sermon sermon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final player = RadioPlayer.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([player, SermonDownloads.instance]),
      builder: (context, _) {
        final current = player.nowPlaying?.id == sermon.id;
        return GlassPanel(
          radius: 22,
          padding: const EdgeInsets.all(14),
          onTap: () => current ? player.toggle() : player.play(sermon),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: current ? c.live : c.chip),
              child: Center(
                child: player.loadingId == sermon.id
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : AppIconView(current && player.isPlaying ? AppIcon.pause : AppIcon.play,
                        size: 18, color: current ? c.onLive : c.text),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sermon.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
                Text(categoryName(sermon.categoryId), style: TextStyle(fontSize: 11, color: c.textFaint)),
                if (sermon.summary.isNotEmpty)
                  Text(sermon.summary,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, height: 1.5, color: c.textSoft)),
              ]),
            ),
            _DownloadButton(sermon: sermon),
          ]),
        );
      },
    );
  }
}

/// زرار التحميل في صف العظة: سهم، شريط تقدّم بيتلغي بالضغط، أو علامة «محمّلة» بتتمسح بالضغط.
class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.sermon});
  final Sermon sermon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = SermonDownloads.instance;
    final id = sermon.id;
    if (d.has(id)) {
      return RoundAction(
        size: 40,
        tooltip: 'محمّلة على الجهاز، اضغط للحذف',
        icon: Icon(Icons.download_done_rounded, size: 20, color: c.live),
        onTap: () => _confirmDelete(context, sermon),
      );
    }
    if (d.isDownloading(id)) {
      final p = d.progressOf(id) ?? 0;
      return RoundAction(
        size: 40,
        tooltip: 'إلغاء التحميل',
        icon: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, value: p > 0 ? p : null, color: c.live),
        ),
        onTap: () => d.cancel(id),
      );
    }
    return RoundAction(
      size: 40,
      tooltip: d.failed(id) ? 'فشل التحميل، حاول تاني' : 'تحميل العظة لسماعها من غير نت',
      icon: Icon(d.failed(id) ? Icons.refresh_rounded : Icons.download_rounded, size: 20, color: c.textSoft),
      onTap: () => d.download(sermon),
    );
  }
}

Future<void> _confirmDelete(BuildContext context, Sermon s) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('حذف العظة من الجهاز؟'),
      content: Text(s.title, maxLines: 3, overflow: TextOverflow.ellipsis),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
      ],
    ),
  );
  if (ok == true) await SermonDownloads.instance.delete(s.id);
}

/// في تبويب «المحمّلة»: كام عظة وحجمهم، وزرار حذف الكل.
class _DownloadsSummary extends StatelessWidget {
  const _DownloadsSummary({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = SermonDownloads.instance;
    return ListenableBuilder(
      listenable: d,
      builder: (context, _) {
        if (d.count == 0) return const SizedBox.shrink();
        final mb = (d.totalBytes / (1024 * 1024)).round();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Expanded(
              child: Text('${ar(d.count)} ${d.count == 1 ? 'عظة' : 'عظات'} • ${ar(mb)} ميجا على الجهاز',
                  style: TextStyle(fontSize: 12, color: c.textFaint)),
            ),
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('حذف كل العظات المحمّلة؟'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف الكل')),
                    ],
                  ),
                );
                if (ok == true) {
                  await d.deleteAll();
                  onChanged();
                }
              },
              child: Text('حذف الكل', style: TextStyle(color: c.textSoft)),
            ),
          ]),
        );
      },
    );
  }
}

/// مشغّل صغير فوق الشريط السفلي.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final player = RadioPlayer.instance;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final now = player.nowPlaying;
        // مفيش حاجة شغالة دلوقتي: آخر محطة أو عظة اتسجّلت بس لسه ماتشغّلتش في الجلسة دي، فنخفي المشغّل
        if (now == null || player.hasPending) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          // ضوء سائل حوالين المشغّل الصغير طول ما الصوت شغال
          child: FluidLight(
            spread: 22,
            strength: 1.4,
            child: GlassPanel(
            radius: 29,
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onTap: onOpen,
            child: Row(children: [
              const PlayButton(size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(now.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
                  Text(player.subtitle,
                      maxLines: 1, style: TextStyle(fontSize: 11, color: c.textSoft)),
                ]),
              ),
              if (player.sleepOn) Icon(Icons.bedtime_outlined, size: 18, color: c.textFaint),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: AppIconView(AppIcon.radio, size: 20, color: c.textFaint)),
            ]),
          ),
          ),
        );
      },
    );
  }
}

/// نص زرار مؤقت النوم: «مؤقت النوم»، أو الباقي («يقف بعد ٢٣ د»)، أو «يقف آخر العظة».
String sleepLabel(RadioPlayer p) {
  if (p.sleepAtEnd) return 'يقف آخر العظة';
  final left = p.sleepLeft;
  if (left == null) return 'مؤقت النوم';
  final m = (left.inSeconds / 60).ceil();
  return 'يقف بعد ${ar(m)} د';
}

/// اختيار مؤقت النوم: ١٥ / ٣٠ / ٤٥ / ٦٠ دقيقة، أو آخر العظة (للعظات بس)، أو إلغاء.
Future<void> showSleepTimer(BuildContext context) {
  final c = context.colors;
  final p = RadioPlayer.instance;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) {
      Widget option(String label, VoidCallback onTap, {bool on = false}) => InkWell(
            onTap: () {
              onTap();
              Navigator.of(context).pop();
            },
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
              child: Row(children: [
                Expanded(child: Text(label, style: TextStyle(fontSize: 16, color: c.text))),
                if (on) Icon(Icons.check, size: 20, color: c.text),
              ]),
            ),
          );
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
            child: Text('مؤقت النوم', style: context.heading(size: 20)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text('الصوت بيخفت شوية شوية وبعدين يقف', style: TextStyle(fontSize: 13, color: c.textSoft)),
          ),
          for (final m in const [15, 30, 45, 60]) option('بعد ${ar(m)} دقيقة', () => p.setSleep(Duration(minutes: m))),
          if (!p.live) option('آخر العظة', p.setSleepAtEnd, on: p.sleepAtEnd),
          if (p.sleepOn) option('إلغاء المؤقت', () => p.setSleep(null)),
        ]),
      );
    },
  );
}
