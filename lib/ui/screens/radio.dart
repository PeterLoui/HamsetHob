import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../audio/radio_player.dart';
import '../../core/coptic.dart';
import '../../data/sermons.dart';
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
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600 && _page < _totalPages) _load(reset: false);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
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
        ScreenHeader('الإذاعة', subtitle: 'مكتبة عظات قداسة البابا شنوده الثالث', onBack: widget.onBack),
        _NowPlaying(onStartRadio: () => player.startRadio(_category)),
        const SizedBox(height: 14),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sermonCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = sermonCategories[i];
              return GlassChip(
                label: cat.name,
                selected: cat.id == _category,
                selectedColor: c.accent,
                onTap: () {
                  _category = cat.id;
                  _load(reset: true);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        GlassSearchBar(
          placeholder: 'ابحث في العظات… (مثال: التوبة)',
          height: 48,
          textStyle: TextStyle(color: c.text, fontSize: 15),
          placeholderStyle: TextStyle(color: c.textFaint, fontSize: 15),
          onChanged: (q) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 450), () {
              _query = q;
              _load(reset: true);
            });
          },
        ),
        const SizedBox(height: 12),
        if (_failed && _sermons.isEmpty) Text('تعذّر تحميل العظات، تأكد من الاتصال بالإنترنت', style: TextStyle(color: c.textSoft)),
        if (!_loading && !_failed && _sermons.isEmpty) Text('لا توجد عظات مطابقة', style: TextStyle(color: c.textSoft)),
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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.accent.withValues(alpha: .22)),
              child: Center(child: AppIconView(AppIcon.radio, size: 34, color: c.accent)),
            ),
            const SizedBox(height: 12),
            Text(now?.title ?? 'اختر عظة أو ابدأ البث المتواصل',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
            Text(
              now == null ? 'عظات عشوائية متتالية من المكتبة' : (player.radioOn ? 'بث متواصل • ${now.category}' : now.category),
              style: TextStyle(fontSize: 12, color: c.textSoft),
            ),
            if (now != null) ...[
              const SizedBox(height: 10),
              GlassSlider(
                value: dur == 0 ? 0 : (player.position.inMilliseconds / dur).clamp(0, 1).toDouble(),
                onChanged: (v) => player.seekTo(Duration(milliseconds: (v * dur).round())),
                activeColor: c.accent,
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
            Pill(player.radioOn ? 'إيقاف البث المتواصل' : '▶  بث متواصل عشوائي',
                onTap: player.radioOn ? player.stopRadio : onStartRadio),
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
      listenable: player,
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
              decoration: BoxDecoration(shape: BoxShape.circle, color: current ? c.accent : c.chip),
              child: Center(
                child: player.loadingId == sermon.id
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : AppIconView(current && player.isPlaying ? AppIcon.pause : AppIcon.play,
                        size: 18, color: current ? const Color(0xFF2A1446) : c.text),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sermon.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
                Text(categoryName(sermon.categoryId), style: TextStyle(fontSize: 11, color: c.accent)),
                if (sermon.summary.isNotEmpty)
                  Text(sermon.summary,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, height: 1.5, color: c.textSoft)),
              ]),
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
        if (now == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassPanel(
            ownLayer: true,
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
                  Text(player.radioOn ? 'بث متواصل • ${now.category}' : now.category,
                      maxLines: 1, style: TextStyle(fontSize: 11, color: c.textSoft)),
                ]),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: AppIconView(AppIcon.radio, size: 20, color: c.accent)),
            ]),
          ),
        );
      },
    );
  }
}
