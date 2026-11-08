import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../audio/radio_player.dart';
import '../../core/coptic.dart';
import '../../core/synaxarium.dart';
import '../../data/bible.dart';
import '../../data/katameros.dart';
import '../../data/meditations.dart';
import '../../data/saint_images.dart';
import '../../data/store.dart';
import '../../share/verse_image.dart';
import '../glass.dart';
import '../icons.dart';
import '../theme.dart';
import 'meditation.dart';
import 'prayers.dart' show QuickTiles;

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.today,
    required this.onOpenChapter,
    required this.onOpenSynaxarium,
    required this.onOpenReadings,
    required this.onOpenFavorites,
    required this.onOpenRadio,
    required this.onOpenMeditation,
    required this.onOpenPrayers,
    required this.onOpenStations,
    required this.onOpenBooks,
    required this.onVerseLoaded,
  });

  final DateTime today;
  final ValueChanged<VerseRef> onOpenChapter;
  final VoidCallback onOpenSynaxarium, onOpenReadings, onOpenFavorites, onOpenRadio;
  final ValueChanged<Meditation> onOpenMeditation;
  final VoidCallback onOpenPrayers, onOpenStations, onOpenBooks;
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
        null, // اسم قديس من السنكسار الكامل: مالوش صورة متراجعة، فمانعرضش صورة التذكار الشهري معاه
      );
    }
    return local;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (c.classic) return _bookPage(context);
    final greeting = DateTime.now().hour < 12 ? 'صباح الخير' : 'مساء الخير';
    return ListView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 8, 16, 24),
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.classic ? weekdayName(widget.today) : '$greeting  •  ${weekdayName(widget.today)}',
                  style: TextStyle(fontSize: 14, color: c.textFaint)),
              Text('همسة حب', style: c.classic ? context.heading(size: 26) : TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: c.text)),
            ]),
          ),
          RoundAction(
            icon: Icon(c.classic ? Icons.favorite_border : Icons.favorite, color: c.classic ? c.textSoft : c.saint, size: 22),
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
        const SizedBox(height: 16),
        MeditationCard(today: widget.today, onOpen: widget.onOpenMeditation),
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
        QuickTiles(onPrayers: widget.onOpenPrayers, onSermons: widget.onOpenRadio, onStations: widget.onOpenStations, onBooks: widget.onOpenBooks),
        const SizedBox(height: 16),
        _RadioCard(onOpen: widget.onOpenRadio),
      ],
    );
  }

  /// مخطوطة/سهرانية: الرئيسية صفحة كتاب. من غير كروت إلا كارت «يُذاع الآن»،
  /// والأحمر (أو العسلي) للتاريخ القبطي وأرقام الآيات بس.
  Widget _bookPage(BuildContext context) {
    final c = context.colors;
    final today = widget.today;
    final coptic = CopticDate.fromGregorian(today);
    final com = _commemoration;
    final v = _verse;
    final gospel = _readings?.liturgyGospel;

    return ListView(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 8, 24, 24),
      children: [
        Row(children: [
          Expanded(child: Text('همسة حب', style: context.heading(size: 20))),
          RoundAction(
            icon: Icon(Icons.favorite_border, color: c.textFaint, size: 22),
            onTap: widget.onOpenFavorites,
            tooltip: 'المفضلة',
            size: 44,
          ),
        ]),
        const SizedBox(height: 12),
        // صورة قديس اليوم أو العيد ورا التاريخ والتذكار: من الشمال، بشفافية ٣٠٪، وبتتلاشى لنص الصفحة
        _SaintBackdrop(
          wiki: com.wiki,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${weekdayName(today)} ${ar(today.day)} ${gregorianMonths[today.month - 1]}', style: context.heading(size: 28)),
              const SizedBox(height: 2),
              Text('${ar(coptic.day)} ${coptic.monthName} ${ar(coptic.year)} للشهداء',
                  style: TextStyle(fontSize: 15, color: c.accent, fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(height: 8),
              InkWell(
                onTap: widget.onOpenSynaxarium,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    CopticCross(size: 12, color: c.textFaint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(com.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.text)),
                        Text(com.detail, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: c.textFaint)),
                      ]),
                    ),
                    Icon(Icons.chevron_left, color: c.textFaint, size: 18),
                  ]),
                ),
              ),
          ]),
        ),
        const _Ornament(),
        Text('رسالة اليوم', style: TextStyle(fontSize: 13, color: c.textFaint)),
        const SizedBox(height: 4),
        if (v != null) ...[
          GestureDetector(
            onTap: () => widget.onOpenChapter(v.ref),
            child: Text(v.text, style: context.scripture(size: 23).copyWith(height: 1.75)),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Text(v.ref.label, style: TextStyle(fontSize: 14, color: c.accent)),
            const Spacer(),
            InkWell(
              onTap: () => widget.onOpenChapter(v.ref),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Text('النص كاملاً', style: TextStyle(fontSize: 13, color: c.textSoft)),
              ),
            ),
            VerseActions(ref: v.ref, text: v.text),
            RoundAction(
              icon: Icon(Icons.refresh, color: c.textFaint, size: 20),
              onTap: () => _loadVerse(forceNew: true),
              tooltip: 'رسالة أخرى',
            ),
          ]),
        ] else if (_verseFailed)
          Row(children: [
            Expanded(
              child: Text('تعذّر تحميل الرسالة، تأكد من الاتصال بالإنترنت ثم اضغط زر التحديث',
                  style: TextStyle(color: c.textSoft)),
            ),
            RoundAction(
              icon: Icon(Icons.refresh, color: c.textFaint, size: 20),
              onTap: () => _loadVerse(forceNew: true),
              tooltip: 'رسالة أخرى',
            ),
          ])
        else
          const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        const SizedBox(height: 20),
        MeditationCard(today: today, onOpen: widget.onOpenMeditation),
        const SizedBox(height: 16),
        if (gospel != null)
          _PageRow(
            icon: AppIcon.readings,
            title: 'إنجيل القداس اليوم',
            subtitle: '${gospel.book} ${ar(gospel.ref)}',
            onTap: widget.onOpenReadings,
            last: true,
          ),
        const SizedBox(height: 16),
        QuickTiles(onPrayers: widget.onOpenPrayers, onSermons: widget.onOpenRadio, onStations: widget.onOpenStations, onBooks: widget.onOpenBooks),
        const SizedBox(height: 16),
        _NowPlayingCard(onOpen: widget.onOpenRadio),
      ],
    );
  }
}

/// صورة التذكار ورا رأس الصفحة: بتبدأ من شمال الشاشة بشفافية ٣٠٪ وبتتلاشى تدريجياً لحد نص الصفحة يمين،
/// ومن تحت كمان، فمافيش حافة واضحة. الصور من جدول متراجع (SaintImages)، ولو مافيش صورة الرأس بيفضل زي ما هو.
class _SaintBackdrop extends StatelessWidget {
  const _SaintBackdrop({required this.wiki, required this.child});
  final String? wiki;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: SaintImages.instance.imageUrl(wiki, ''),
      builder: (context, snap) {
        final url = snap.data;
        if (url == null) return child;
        return LayoutBuilder(builder: (context, box) {
          // الصورة بتغطي من حافة الشاشة لحد ٦٢٪ من عرضها، والقص بيتوسّط على وش القديس (SaintImages.framing)
          final w = (box.maxWidth + 24) * .62;
          return Stack(clipBehavior: Clip.none, children: [
          Positioned(
            top: -12,
            bottom: -8,
            left: -24, // لحد حافة الشاشة (هامش الصفحة ٢٤)
            width: w,
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, img) => ShaderMask(
                  // من الشمال، وبتتلاشى لحد نص الصفحة يمين
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.black, Colors.black, Colors.transparent],
                    stops: [0, .4, 1],
                  ).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: ShaderMask(
                    // ومن فوق وتحت عشان مايبقاش فيه خط
                    shaderCallback: (r) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                      stops: [0, .08, .78, 1],
                    ).createShader(r),
                    blendMode: BlendMode.dstIn,
                    child: Opacity(
                      opacity: .3,
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        alignment: SaintImages.focus(wiki, img.maxWidth, img.maxHeight),
                        fadeInDuration: const Duration(milliseconds: 300),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ]);
        });
      },
    );
  }
}

/// صليب قبطي صغير: كل ذراع ينتهي بثلاث كرات.
class CopticCross extends StatelessWidget {
  const CopticCross({super.key, this.size = 12, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _CopticCrossPainter(color)));
}

class _CopticCrossPainter extends CustomPainter {
  _CopticCrossPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    canvas.scale(size.width / 100, size.height / 100);
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.translate(50, 50);
      canvas.rotate(i * 1.5707963267948966);
      canvas.translate(-50, -50);
      canvas.drawRRect(RRect.fromLTRBR(44, 20, 56, 52, const Radius.circular(2)), p);
      canvas.drawCircle(const Offset(50, 15), 6.5, p);
      canvas.drawCircle(const Offset(41.5, 21.5), 5.5, p);
      canvas.drawCircle(const Offset(58.5, 21.5), 5.5, p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CopticCrossPainter old) => old.color != color;
}

/// فاصل الصفحة: خط رفيع وفي نصه صليب صغير.
class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(children: [
        Expanded(child: Divider(color: c.hairline)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: CopticCross(size: 10, color: c.textFaint)),
        Expanded(child: Divider(color: c.hairline)),
      ]),
    );
  }
}

/// صف في الصفحة: أيقونة وعنوان ووصف، وفوقه خط رفيع.
class _PageRow extends StatelessWidget {
  const _PageRow({required this.icon, required this.title, required this.subtitle, required this.onTap, this.last = false});
  final AppIcon icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: c.hairline),
            bottom: last ? BorderSide(color: c.hairline) : BorderSide.none,
          ),
        ),
        child: Row(children: [
          AppIconView(icon, size: 20, color: c.textFaint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.text)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: c.textFaint)),
            ]),
          ),
          Icon(Icons.chevron_left, color: c.textFaint, size: 18),
        ]),
      ),
    );
  }
}

/// الكارت الوحيد في الصفحة: «يُذاع الآن»، أو الإذاعة لو مافيش حاجة شغالة.
class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final player = RadioPlayer.instance;
    return GlassPanel(
      radius: 14,
      padding: const EdgeInsets.all(16),
      onTap: onOpen,
      child: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          final now = player.nowPlaying;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (now != null)
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      if (player.isPlaying) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: c.isDark ? c.accent : c.text),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(player.isPlaying ? 'يُذاع الآن' : 'متوقف مؤقتاً', style: TextStyle(fontSize: 12, color: c.textFaint)),
                    ]),
                    const SizedBox(height: 2),
                    Text(now.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.text)),
                    Text(now.category, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: c.textFaint)),
                  ]),
                ),
                const SizedBox(width: 12),
                const PlayButton(size: 44),
              ])
            else ...[
              Text('المكتبة السمعية البابا شنودة الثالث', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.text)),
              Text('بث متواصل أو اختار عظة من المكتبة', style: TextStyle(fontSize: 12, color: c.textFaint)),
              const SizedBox(height: 12),
              Row(children: [
                Pill('بث متواصل', filled: true, onTap: () => player.startRadio()),
                const SizedBox(width: 8),
                Pill('تصفح العظات', onTap: onOpen),
              ]),
            ],
            if (player.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(player.error!, style: TextStyle(fontSize: 12, color: c.textSoft)),
              ),
          ]);
        },
      ),
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
    final shadow = c.classic ? const <Shadow>[] : [Shadow(color: c.isDark ? const Color(0x66000000) : const Color(0x55FFFFFF), blurRadius: 8)];
    // مخطوطة/سهرانية: التاريخ القبطي بلون التصميم المميز (أحمر الروبريك أو العسلي)
    TextStyle big({bool coptic = false}) => c.classic
        ? context.heading(size: 40, color: coptic ? c.accent : c.text).copyWith(height: 1.1)
        : TextStyle(fontSize: 40, height: 1.1, fontWeight: FontWeight.w700, color: c.text, shadows: shadow);
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
              child: LayoutBuilder(
                builder: (context, box) => CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  alignment: SaintImages.focus(commemoration.wiki, box.maxWidth, box.maxHeight),
                  errorWidget: (_, __, ___) => const _CrossArt(),
                ),
              ),
            );
          },
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: c.classic
                  ? [c.card.withValues(alpha: .7), c.card.withValues(alpha: .45), c.card.withValues(alpha: .9)]
                  : c.isDark
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
                Text(ar(coptic.day), style: big(coptic: true)),
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
                    decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(c.classic ? 6 : 99)),
                    child: Text(commemoration.kind.label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: c.classic ? FontWeight.w500 : FontWeight.w700,
                            color: c.kindColor(commemoration.kind))),
                  ),
                  const SizedBox(height: 6),
                  Text(commemoration.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: c.classic
                          ? context.heading(size: 20)
                          : TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text, shadows: shadow)),
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
  Widget build(BuildContext context) {
    final c = context.colors;
    // مخطوطة/سهرانية: صليب خفيف من غير توهج ذهبي وراه
    return CustomPaint(painter: _CrossPainter(c.text.withValues(alpha: c.classic ? .12 : .33), glow: !c.classic));
  }
}

class _CrossPainter extends CustomPainter {
  _CrossPainter(this.color, {this.glow = true});
  final Color color;
  final bool glow;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .42);
    final arm = size.height * .22;
    final w = arm * .34;
    if (glow) {
      canvas.drawCircle(
        center,
        arm * 2.2,
        Paint()..shader = RadialGradient(colors: const [Color(0x55F3C77A), Color(0x00F3C77A)]).createShader(Rect.fromCircle(center: center, radius: arm * 2.2)),
      );
    }
    final s = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: w, height: arm * 2), const Radius.circular(3)), s);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: arm * 2, height: w), const Radius.circular(3)), s);
    canvas.drawCircle(center, arm * .62, s);
  }

  @override
  bool shouldRepaint(covariant _CrossPainter old) => old.color != color || old.glow != glow;
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
          if (!c.classic) ...[
            Text('✦', style: TextStyle(color: c.accent, fontSize: 16)),
            const SizedBox(width: 8),
          ],
          Expanded(
              child: Text('رسالة اليوم',
                  style: c.classic
                      ? TextStyle(fontSize: 13, color: c.textFaint)
                      : TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.text))),
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
            icon: Icon(saved ? Icons.favorite : Icons.favorite_border, color: saved ? c.saint : (c.classic ? c.textFaint : c.text), size: 19),
            onTap: () => Favorites.instance.toggle(ref, text),
            tooltip: 'حفظ في المفضلة',
          ),
          const SizedBox(width: 8),
          RoundAction(
            icon: Icon(Icons.ios_share, color: c.classic ? c.textFaint : c.text, size: 18),
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
                child: Center(child: PopeIcon(size: 30, color: c.accent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('المكتبة السمعية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.text)),
                  Text('البابا شنودة الثالث', style: TextStyle(fontSize: 12, color: c.textSoft)),
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
                Pill(c.classic ? 'بث متواصل' : '▶  بث متواصل', onTap: () => player.startRadio()),
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
        color: c.live,
        tooltip: player.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
        onTap: player.toggle,
        icon: player.isBuffering || player.loadingId != null
            ? SizedBox(width: size * .45, height: size * .45, child: CircularProgressIndicator(strokeWidth: 2, color: c.onLive))
            : AppIconView(player.isPlaying ? AppIcon.pause : AppIcon.play, size: size * .5, color: c.onLive),
      ),
    );
  }
}
