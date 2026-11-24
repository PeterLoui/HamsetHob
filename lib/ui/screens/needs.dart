import 'package:flutter/material.dart';

import '../../data/bible.dart';
import '../../data/needs.dart';
import '../glass.dart';
import '../theme.dart';

/// «أنا محتاج…»: اختار حالتك، ويطلعلك مسار جاهز: آيات وصلاة وعظات وسؤال للتأمل.
class NeedsScreen extends StatelessWidget {
  const NeedsScreen({super.key, required this.onBack, required this.onOpen});
  final VoidCallback onBack;
  final ValueChanged<Need> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(24, pad.top, 24, pad.bottom + 40),
      children: [
        ScreenHeader('أنا محتاج…', subtitle: 'اختار حالتك، وهنطلّعلك كلمة وصلاة وعظة تساعدك', onBack: onBack),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final n in needs)
              GlassPanel(
                onTap: () => onOpen(n),
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Icon(n.icon, color: c.navGlow, size: 26),
                  Text(n.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text('المحتوى ده قايمة اتكتبت بإيد بشر (مش ذكاء اصطناعي). وأي حالة صعبة، كلّم أب الاعتراف أو الكاهن.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 11, height: 1.7, color: c.textFaint)),
      ],
    );
  }
}

/// مسار حالة واحدة: كلمة (آيات)، وصلاة، وعظات، وسؤال للتأمل.
class NeedScreen extends StatelessWidget {
  const NeedScreen({
    super.key,
    required this.need,
    required this.onBack,
    required this.onVerse,
    required this.onPrayer,
    required this.onSermons,
    this.loadVerses,
  });
  final Need need;
  final VoidCallback onBack;
  final ValueChanged<VerseRef> onVerse;
  final ValueChanged<String> onPrayer;
  final ValueChanged<String> onSermons;
  final Future<List<Verse>> Function(int book, int chapter)? loadVerses;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 8),
          child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.accent)),
        );
    return ListView(
      padding: EdgeInsets.fromLTRB(24, pad.top, 24, pad.bottom + 40),
      children: [
        ScreenHeader(need.label, subtitle: need.intro, onBack: onBack),
        label('كلمة ليك'),
        for (final r in need.verses) _VerseCard(ref: r, onTap: () => onVerse(r), load: loadVerses),
        label('صلّي'),
        GlassPanel(
          onTap: () => onPrayer(need.prayerId),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(Icons.self_improvement, color: c.navGlow),
            const SizedBox(width: 12),
            Expanded(child: Text(need.prayerWhy, style: TextStyle(fontSize: 14, height: 1.6, color: c.text))),
            Icon(Icons.chevron_left, color: c.textFaint),
          ]),
        ),
        label('اسمع'),
        GlassPanel(
          onTap: () => onSermons(need.sermonQuery),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(Icons.headphones_outlined, color: c.navGlow),
            const SizedBox(width: 12),
            Expanded(child: Text('عظات للبابا شنوده عن «${need.sermonQuery}»', style: TextStyle(fontSize: 14, color: c.text))),
            Icon(Icons.chevron_left, color: c.textFaint),
          ]),
        ),
        label('سؤال للتأمل'),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: c.navGlow, width: 3))),
          child: Text(need.reflection, style: TextStyle(fontSize: 15, height: 1.8, color: c.textSoft)),
        ),
      ],
    );
  }
}

class _VerseCard extends StatelessWidget {
  const _VerseCard({required this.ref, required this.onTap, this.load});
  final VerseRef ref;
  final VoidCallback onTap;
  final Future<List<Verse>> Function(int book, int chapter)? load;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: FutureBuilder<List<Verse>>(
          future: (load ?? BibleRepository.instance.chapter)(ref.book, ref.chapter),
          builder: (context, snap) {
            final text = snap.data?.where((v) => v.number == ref.verse).firstOrNull?.text;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (text != null)
                Text('«$text»', style: context.scripture(size: 19))
              else
                Text(snap.hasError ? 'تعذّر تحميل الآية، اتأكد من النت' : '…', style: TextStyle(color: c.textFaint)),
              const SizedBox(height: 6),
              Text('${ref.label}  ‹', style: TextStyle(fontSize: 13, color: c.accent)),
            ]);
          },
        ),
      ),
    );
  }
}
