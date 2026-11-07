import 'package:flutter/material.dart';

import '../../data/meditations.dart';
import '../glass.dart';
import '../theme.dart';

/// كارت «تأمل اليوم» في الرئيسية: العنوان وسهم يفتح التأمل كاملاً.
class MeditationCard extends StatefulWidget {
  const MeditationCard({super.key, required this.today, required this.onOpen});
  final DateTime today;
  final ValueChanged<Meditation> onOpen;

  @override
  State<MeditationCard> createState() => _MeditationCardState();
}

class _MeditationCardState extends State<MeditationCard> {
  late Future<Meditation> _future = MeditationRepository.instance.forDay(widget.today);

  @override
  void didUpdateWidget(MeditationCard old) {
    super.didUpdateWidget(old);
    if (old.today.day != widget.today.day) _future = MeditationRepository.instance.forDay(widget.today);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FutureBuilder<Meditation>(
      future: _future,
      builder: (context, snap) {
        final m = snap.data;
        // لو الموقع مش متاح ومافيش نسخة محفوظة، الكارت مايظهرش
        if (snap.hasError) return const SizedBox.shrink();
        return GlassPanel(
          radius: 16,
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          onTap: m == null ? null : () => widget.onOpen(m),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('تأمل اليوم', style: TextStyle(fontSize: 12, color: c.textFaint)),
                const SizedBox(height: 2),
                Text(m?.title ?? '…', maxLines: 2, overflow: TextOverflow.ellipsis, style: context.heading(size: 19)),
              ]),
            ),
            Semantics(
              button: true,
              label: 'اقرأ التأمل كاملاً',
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.arrow_forward, color: c.textSoft, size: 22),
              ),
            ),
          ]),
        );
      },
    );
  }
}

/// التأمل كاملاً.
class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key, required this.meditation, required this.onBack});
  final Meditation meditation;
  final VoidCallback onBack;

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  late Future<MeditationArticle> _future = MeditationRepository.instance.article(widget.meditation);

  void _retry() => setState(() => _future = MeditationRepository.instance.article(widget.meditation));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    return FutureBuilder<MeditationArticle>(
      future: _future,
      builder: (context, snap) {
        final a = snap.data;
        return ListView(
          padding: EdgeInsets.fromLTRB(c.classic ? 24 : 16, pad.top, c.classic ? 24 : 16, pad.bottom + 32),
          children: [
            ScreenHeader(a?.title ?? widget.meditation.title, subtitle: 'تأمل اليوم', onBack: widget.onBack),
            if (snap.hasError) ...[
              Text('تعذّر تحميل التأمل، تأكد من الاتصال بالإنترنت', style: TextStyle(color: c.textSoft)),
              const SizedBox(height: 12),
              Align(alignment: AlignmentDirectional.centerStart, child: AppChip(label: 'إعادة المحاولة', onTap: _retry)),
            ] else if (a == null)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else ...[
              for (final b in a.blocks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: b.verse
                      ? Container(
                          padding: const EdgeInsetsDirectional.only(start: 14),
                          decoration: BoxDecoration(
                            border: BorderDirectional(start: BorderSide(color: c.hairline, width: 2)),
                          ),
                          child: Text(b.text, style: context.scripture(size: 19, color: c.textSoft)),
                        )
                      : Text(b.text, style: TextStyle(fontSize: 16, height: 1.9, color: c.text)),
                ),
            ],
          ],
        );
      },
    );
  }
}
