import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../audio/radio_player.dart';
import '../../core/coptic.dart';
import '../../core/synaxarium.dart';
import '../../data/bible.dart';
import '../../data/katameros.dart';
import '../../data/saint_images.dart';
import '../../data/store.dart';
import '../../share/verse_image.dart';
import '../glass.dart';
import '../icons.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.today,
    required this.onOpenChapter,
    required this.onOpenSynaxarium,
    required this.onOpenReadings,
    required this.onOpenFavorites,
    required this.onOpenRadio,
    required this.onVerseLoaded,
  });

  final DateTime today;
  final ValueChanged<VerseRef> onOpenChapter;
  final VoidCallback onOpenSynaxarium, onOpenReadings, onOpenFavorites, onOpenRadio;
  final ValueChanged<DailyVerse> onVerseLoaded;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DayReadings? _readings;
  DailyVerse? _verse;
  bool _verseFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    if (dateOnly(old.today) != dateOnly(widget.today)) _load();
  }

  Future<void> _load() async {
    KatamerosRepository.instance.day(widget.today).then((r) {
      if (mounted) setState(() => _readings = r);
    }).catchError((_) {});
    await _loadVerse();
  }

  Future<void> _loadVerse({bool forceNew = false}) async {
    setState(() => _verseFailed = false);
    try {
      final v = await BibleRepository.instance.dailyVerse(widget.today, forceNew: forceNew);
      if (!mounted) return;
      setState(() => _verse = v);
      widget.onVerseLoaded(v);
    } catch (_) {
      if (mounted) setState(() => _verseFailed = true);
    }
  }

  Commemoration get _commemoration {
    final local = Synaxarium.forDate(widget.today);
    final stories = _readings?.synaxarium ?? const [];
    if (local.generic && stories.isNotEmpty) {
      final more = stories.length - 1;
      return Commemoration(
        stories.first.title,
        more > 0 ? 'و${ar(more)} ${more == 1 ? 'تذكار آخر' : 'تذكارات أخرى'} في سنكسار اليوم' : 'سنكسار اليوم',
        Kind.saint,
        local.wiki,
      );
    }
    return local;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final greeting = DateTime.now().hour < 12 ? 'صباح الخير' : 'مساء الخير';
    return ListView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 8, 16, 24),
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$greeting  •  ${weekdayName(widget.today)}', style: TextStyle(fontSize: 14, color: c.textFaint)),
              Text('همسة حب', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: c.text)),
            ]),
          ),
          RoundAction(
            icon: Icon(Icons.favorite, color: c.saint, size: 22),
            onTap: widget.onOpenFavorites,
            tooltip: 'المفضلة',
            size: 46,
          ),
        ]),
        const SizedBox(height: 16),
        _DateCard(today: widget.today, commemoration: _commemoration, onTap: widget.onOpenSynaxarium),
        const SizedBox(height: 16),
        _MessageCard(
          verse: _verse,
          failed: _verseFailed,
          onRefresh: () => _loadVerse(forceNew: true),
          onOpenChapter: widget.onOpenChapter,
        ),
        if (_readings?.liturgyGospel case final g?) ...[
          const SizedBox(height: 16),
          GlassPanel(
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            onTap: widget.onOpenReadings,
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('إنجيل القداس اليوم', style: TextStyle(fontSize: 12, color: c.textFaint)),
                  Text('${g.book} ${ar(g.ref)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                ]),
              ),
              Text('القراءات  ‹', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.accent)),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        _RadioCard(onOpen: widget.onOpenRadio),
      ],
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({required this.today, required this.commemoration, required this.onTap});
  final DateTime today;
  final Commemoration commemoration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final coptic = CopticDate.fromGregorian(today);
    final shadow = [Shadow(color: c.isDark ? const Color(0x66000000) : const Color(0x55FFFFFF), blurRadius: 8)];
    TextStyle big() => TextStyle(fontSize: 40, height: 1.1, fontWeight: FontWeight.w700, color: c.text, shadows: shadow);
    TextStyle small() => TextStyle(fontSize: 15, color: c.textSoft, shadows: shadow);

    return GlassPanel(
      height: 212,
      radius: 32,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Stack(fit: StackFit.expand, children: [
        // صورة التذكار بشفافية قليلة خلف المحتوى، والصليب إن لم توجد صورة
        FutureBuilder<String?>(
          future: SaintImages.instance.imageUrl(commemoration.wiki, commemoration.title),
          builder: (context, snap) {
            final url = snap.data;
            if (url == null) return const _CrossArt();
            return Opacity(
              opacity: c.isDark ? .42 : .3,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const _CrossArt(),
              ),
            );
          },
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: c.isDark
                  ? const [Color(0x33140B26), Color(0x11140B26), Color(0x77140B26)]
                  : const [Color(0x66FFFFFF), Color(0x33FFFFFF), Color(0x99FFFFFF)],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Stack(children: [
            // يمين: اليوم والشهر والسنة القبطية
            Align(
              alignment: AlignmentDirectional.topStart,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(ar(coptic.day), style: big()),
                Text('${coptic.monthName} ${ar(coptic.year)} ش', style: small()),
              ]),
            ),
            // يسار: اليوم والشهر والسنة الميلادية
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                Text(ar(today.day), style: big()),
                Text('${gregorianMonths[today.month - 1]} ${ar(today.year)} م', style: small()),
              ]),
            ),
            // في المنتصف أسفل قليلاً: التذكار أو العيد
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(99)),
                    child: Text(commemoration.kind.label,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.kindColor(commemoration.kind))),
                  ),
                  const SizedBox(height: 6),
                  Text(commemoration.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text, shadows: shadow)),
                  Text(commemoration.detail,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: c.textSoft, shadows: shadow)),
                ]),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.bottomEnd,
              child: Icon(Icons.chevron_left, color: c.textSoft, size: 22),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _CrossArt extends StatelessWidget {
  const _CrossArt();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _CrossPainter(context.colors.text.withValues(alpha: .33)));
}

class _CrossPainter extends CustomPainter {
  _CrossPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .42);
    final arm = size.height * .22;
    final w = arm * .34;
    canvas.drawCircle(
      center,
      arm * 2.2,
      Paint()..shader = RadialGradient(colors: const [Color(0x55F3C77A), Color(0x00F3C77A)]).createShader(Rect.fromCircle(center: center, radius: arm * 2.2)),
    );
    final s = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: w, height: arm * 2), const Radius.circular(3)), s);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: arm * 2, height: w), const Radius.circular(3)), s);
    canvas.drawCircle(center, arm * .62, s);
  }

  @override
  bool shouldRepaint(covariant _CrossPainter old) => old.color != color;
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.verse, required this.failed, required this.onRefresh, required this.onOpenChapter});
  final DailyVerse? verse;
  final bool failed;
  final VoidCallback onRefresh;
  final ValueChanged<VerseRef> onOpenChapter;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final v = verse;
    return GlassPanel(
      settings: frostedSettings,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('✦', style: TextStyle(color: c.accent, fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text('رسالة اليوم', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.text))),
          if (v != null) VerseActions(ref: v.ref, text: v.text),
          const SizedBox(width: 8),
          RoundAction(icon: Icon(Icons.refresh, color: c.text, size: 20), onTap: onRefresh, tooltip: 'رسالة أخرى'),
        ]),
        const SizedBox(height: 12),
        if (v != null) ...[
          Text('«${v.text}»', style: context.scripture()),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Text(v.ref.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.accent))),
            Pill('النص كاملاً  ‹', onTap: () => onOpenChapter(v.ref)),
          ]),
        ] else if (failed)
          Text('تعذّر تحميل الرسالة، تأكد من الاتصال بالإنترنت ثم اضغط زر التحديث', style: TextStyle(color: c.textSoft))
        else
          const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      ]),
    );
  }
}

/// أزرار الآية: حفظ في المفضلة ومشاركة كصورة.
class VerseActions extends StatelessWidget {
  const VerseActions({super.key, required this.ref, required this.text, this.showCopy = false});
  final VerseRef ref;
  final String text;
  final bool showCopy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: Favorites.instance,
      builder: (context, _) {
        final saved = Favorites.instance.contains(ref);
        return Row(mainAxisSize: MainAxisSize.min, children: [
          RoundAction(
            icon: Icon(saved ? Icons.favorite : Icons.favorite_border, color: saved ? c.saint : c.text, size: 19),
            onTap: () => Favorites.instance.toggle(ref, text),
            tooltip: 'حفظ في المفضلة',
          ),
          const SizedBox(width: 8),
          RoundAction(
            icon: Icon(Icons.ios_share, color: c.text, size: 18),
            onTap: () => VerseImage.share(context, ref, text),
            tooltip: 'مشاركة كصورة',
          ),
          if (showCopy) ...[
            const SizedBox(width: 8),
            RoundAction(
              icon: Icon(Icons.copy, color: c.text, size: 18),
              onTap: () => VerseImage.copy(context, ref, text),
              tooltip: 'نسخ',
            ),
          ],
        ]);
      },
    );
  }
}

class _RadioCard extends StatelessWidget {
  const _RadioCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final player = RadioPlayer.instance;
    return GlassPanel(
      onTap: onOpen,
      child: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          final now = player.nowPlaying;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c.accent.withValues(alpha: .22)),
                child: Center(child: AppIconView(AppIcon.radio, color: c.accent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('الإذاعة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.text)),
                  Text('عظات قداسة البابا شنوده الثالث', style: TextStyle(fontSize: 12, color: c.textSoft)),
                ]),
              ),
              Text('المكتبة  ‹', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.accent)),
            ]),
            const SizedBox(height: 14),
            if (now != null)
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(player.isPlaying ? 'يُذاع الآن' : 'متوقف مؤقتاً', style: TextStyle(fontSize: 11, color: c.textFaint)),
                    Text(now.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                  ]),
                ),
                PlayButton(size: 44),
              ])
            else
              Row(children: [
                Pill('▶  بث متواصل', onTap: () => player.startRadio()),
                const SizedBox(width: 10),
                Pill('تصفح العظات', onTap: onOpen),
              ]),
            if (player.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(player.error!, style: TextStyle(fontSize: 12, color: c.saint)),
              ),
          ]);
        },
      ),
    );
  }
}

/// زر تشغيل/إيقاف ذهبي يتبع حالة المشغّل.
class PlayButton extends StatelessWidget {
  const PlayButton({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final player = RadioPlayer.instance;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => RoundAction(
        size: size,
        color: c.accent,
        tooltip: player.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
        onTap: player.toggle,
        icon: player.isBuffering || player.loadingId != null
            ? SizedBox(width: size * .45, height: size * .45, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : AppIconView(player.isPlaying ? AppIcon.pause : AppIcon.play, size: size * .5, color: const Color(0xFF2A1446)),
      ),
    );
  }
}
