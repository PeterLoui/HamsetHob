import 'package:flutter/material.dart';

import '../../core/coptic.dart' show ar;
import '../../data/prayers.dart';
import '../glass.dart';
import '../icons.dart';
import '../theme.dart';

EdgeInsets _pagePadding(BuildContext context) {
  final pad = MediaQuery.paddingOf(context);
  final side = context.colors.classic ? 24.0 : 16.0;
  return EdgeInsets.fromLTRB(side, pad.top, side, pad.bottom + 32);
}

/// صف في قائمة: عنوان ووصف وسهم، وفوقه خط رفيع.
class _ListRow extends StatelessWidget {
  const _ListRow({required this.title, this.subtitle, required this.onTap, this.leading});
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.text)),
              if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12, color: c.textFaint)),
            ]),
          ),
          Icon(Icons.chevron_left, color: c.textFaint, size: 18),
        ]),
      ),
    );
  }
}

Widget _groupLabel(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 6),
      child: Text(text, style: TextStyle(fontSize: 13, color: context.colors.textFaint)),
    );

/// الصلوات: تبويب الأجبية وتبويب القداس.
class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key, required this.onBack, required this.onOpenPrayer, required this.onOpenLiturgy});
  final VoidCallback onBack;
  final ValueChanged<Prayer> onOpenPrayer;
  final ValueChanged<Liturgy> onOpenLiturgy;

  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends State<PrayersScreen> {
  static int _tab = 0; // يفتكر آخر تبويب لحد ما التطبيق يتقفل
  final _agpeya = AgpeyaRepository.instance.load();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: _pagePadding(context),
      children: [
        ScreenHeader('الصلوات', onBack: widget.onBack),
        AppSegmented(labels: const ['الأجبية', 'القداس'], selectedIndex: _tab, onSelected: (i) => setState(() => _tab = i)),
        if (_tab == 0)
          FutureBuilder<Agpeya>(
            future: _agpeya,
            builder: (context, snap) {
              final a = snap.data;
              if (a == null) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _groupLabel(context, 'صلوات السواعي'),
                for (final p in a.hours) _ListRow(title: p.title, subtitle: p.subtitle, onTap: () => widget.onOpenPrayer(p)),
                _groupLabel(context, 'صلوات أخرى'),
                for (final p in a.others) _ListRow(title: p.title, onTap: () => widget.onOpenPrayer(p)),
              ]);
            },
          )
        else ...[
          _groupLabel(context, 'الخولاجي المقدس'),
          for (final l in liturgies) _ListRow(title: l.title, subtitle: l.subtitle, onTap: () => widget.onOpenLiturgy(l)),
          const SizedBox(height: 16),
          Text('نص القداسات: st-takla.org', style: TextStyle(fontSize: 11, color: c.textFaint)),
        ],
      ],
    );
  }
}

/// صلاة من الأجبية: كل مزمور أو جزء في صفحة لوحده.
/// التقليب بالسحب، أو بالزرارين تحت، أو بالشريط اللي بينهم.
class AgpeyaPrayerScreen extends StatefulWidget {
  const AgpeyaPrayerScreen({super.key, required this.prayer, required this.onBack});
  final Prayer prayer;
  final VoidCallback onBack;

  @override
  State<AgpeyaPrayerScreen> createState() => _AgpeyaPrayerScreenState();
}

class _AgpeyaPrayerScreenState extends State<AgpeyaPrayerScreen> {
  final _pages = PageController();
  int _i = 0;

  int get _count => widget.prayer.sections.length;

  void _go(int step) {
    final next = _i + step;
    if (next < 0 || next >= _count) return;
    _pages.animateToPage(next, duration: const Duration(milliseconds: 320), curve: const Cubic(0.22, 1, 0.36, 1));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    final side = c.classic ? 24.0 : 16.0;
    final p = widget.prayer;
    final many = _count > 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(side, pad.top, side, pad.bottom + 8),
      child: Column(children: [
        ScreenHeader(
          p.title,
          subtitle: many ? '${p.subtitle ?? 'الأجبية'} · ${ar(_i + 1)} من ${ar(_count)}' : (p.subtitle ?? 'الأجبية'),
          onBack: widget.onBack,
        ),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: _count,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (context, i) {
              final s = p.sections[i];
              return ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (s.title.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(s.title, style: context.heading(size: 21))),
                  Text(s.text, style: context.scripture(size: 20)),
                  if (i == _count - 1) ...[
                    const SizedBox(height: 20),
                    Text('النص: مشروع الأجبية مفتوح المصدر (abanoubha/agpeya)', style: TextStyle(fontSize: 11, color: c.textFaint)),
                  ],
                ],
              );
            },
          ),
        ),
        if (many) ...[
          const SizedBox(height: 8),
          Row(children: [
            AppIconButton(icon: Icon(Icons.chevron_right, color: _i > 0 ? c.text : c.textFaint), label: 'السابق', onTap: () => _go(-1)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AppSlider(
                  value: _i / (_count - 1),
                  onChanged: (v) => _pages.jumpToPage((v * (_count - 1)).round()),
                ),
              ),
            ),
            AppIconButton(icon: Icon(Icons.chevron_left, color: _i < _count - 1 ? c.text : c.textFaint), label: 'التالي', onTap: () => _go(1)),
          ]),
        ],
      ]),
    );
  }
}

/// فهرس القداس: كل الأجزاء بالترتيب.
class LiturgyScreen extends StatefulWidget {
  const LiturgyScreen({super.key, required this.liturgy, required this.onBack, required this.onOpenPart});
  final Liturgy liturgy;
  final VoidCallback onBack;
  final void Function(List<LiturgyPart> parts, int index) onOpenPart;

  @override
  State<LiturgyScreen> createState() => _LiturgyScreenState();
}

class _LiturgyScreenState extends State<LiturgyScreen> {
  late Future<List<LiturgyPart>> _future = LiturgyRepository.instance.parts(widget.liturgy);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FutureBuilder<List<LiturgyPart>>(
      future: _future,
      builder: (context, snap) {
        final parts = snap.data;
        return ListView(
          padding: _pagePadding(context),
          children: [
            ScreenHeader(widget.liturgy.title, subtitle: widget.liturgy.subtitle, onBack: widget.onBack),
            if (snap.hasError) ...[
              Text('تعذّر تحميل القداس، تأكد من الاتصال بالإنترنت', style: TextStyle(color: c.textSoft)),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppChip(
                  label: 'إعادة المحاولة',
                  onTap: () => setState(() => _future = LiturgyRepository.instance.parts(widget.liturgy)),
                ),
              ),
            ] else if (parts == null)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else
              for (var i = 0; i < parts.length; i++)
                _ListRow(
                  leading: SizedBox(
                    width: 28,
                    child: Text(ar(i + 1), style: TextStyle(fontSize: 13, color: c.textFaint, fontFeatures: const [FontFeature.tabularFigures()])),
                  ),
                  title: parts[i].title,
                  onTap: () => widget.onOpenPart(parts, i),
                ),
          ],
        );
      },
    );
  }
}

/// جزء من القداس، مع السابق والتالي.
class LiturgyPartScreen extends StatefulWidget {
  const LiturgyPartScreen({super.key, required this.liturgy, required this.parts, required this.index, required this.onBack});
  final Liturgy liturgy;
  final List<LiturgyPart> parts;
  final int index;
  final VoidCallback onBack;

  @override
  State<LiturgyPartScreen> createState() => _LiturgyPartScreenState();
}

class _LiturgyPartScreenState extends State<LiturgyPartScreen> {
  late int _i = widget.index;
  late Future<List<LiturgyBlock>> _future = _load();
  final _scroll = ScrollController();

  Future<List<LiturgyBlock>> _load() => LiturgyRepository.instance.part(widget.parts[_i]);

  void _go(int step) {
    final next = _i + step;
    if (next < 0 || next >= widget.parts.length) return;
    setState(() {
      _i = next;
      _future = _load();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    final side = c.classic ? 24.0 : 16.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(side, pad.top, side, pad.bottom + 8),
      child: Column(children: [
        ScreenHeader(widget.parts[_i].title, subtitle: '${widget.liturgy.title} · ${ar(_i + 1)} من ${ar(widget.parts.length)}', onBack: widget.onBack),
        Expanded(
          child: FutureBuilder<List<LiturgyBlock>>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('تعذّر تحميل هذا الجزء، تأكد من الاتصال بالإنترنت', style: TextStyle(color: c.textSoft)),
                  const SizedBox(height: 12),
                  AppChip(label: 'إعادة المحاولة', onTap: () => setState(() => _future = _load())),
                ]);
              }
              final blocks = snap.data;
              if (blocks == null) return const Center(child: CircularProgressIndicator());
              return ListView(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  for (final b in blocks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: b.rubric
                          ? Text(b.text, style: TextStyle(fontSize: 14, height: 1.7, fontWeight: FontWeight.w500, color: c.textFaint))
                          : Text(b.text, style: context.scripture(size: 19)),
                    ),
                  Text('النص: st-takla.org', style: TextStyle(fontSize: 11, color: c.textFaint)),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          AppIconButton(icon: Icon(Icons.chevron_right, color: _i > 0 ? c.text : c.textFaint), label: 'الجزء السابق', onTap: () => _go(-1)),
          AppIconButton(
              icon: Icon(Icons.chevron_left, color: _i < widget.parts.length - 1 ? c.text : c.textFaint),
              label: 'الجزء التالي',
              onTap: () => _go(1)),
        ]),
      ]),
    );
  }
}

/// مربعات الرئيسية: الصلوات، تسبحة، إذاعات، الكتب. بتتمرر يمين وشمال.
/// المكتبة السمعية للبابا شنودة ليها تبويب لوحده تحتهم (_NowPlayingCard في home.dart).
class QuickTiles extends StatelessWidget {
  const QuickTiles({super.key, required this.onPrayers, required this.onTasbeha, required this.onStations, required this.onBooks});
  final VoidCallback onPrayers, onTasbeha, onStations, onBooks;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (AppIcon.prayer, 'الصلوات', onPrayers),
      (AppIcon.tasbeha, 'تسبحة', onTasbeha),
      (AppIcon.antenna, 'إذاعات', onStations),
      (AppIcon.books, 'الكتب', onBooks),
    ];
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final (icon, label, onTap) = tiles[i];
          final c = context.colors;
          return SizedBox(
            width: 120,
            child: GlassPanel(
              radius: 14,
              padding: const EdgeInsets.all(14),
              onTap: onTap,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AppIconView(icon, size: 26, color: c.text),
                const Spacer(),
                Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.text)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
