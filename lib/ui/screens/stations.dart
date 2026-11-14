import 'package:flutter/material.dart';

import '../../audio/radio_player.dart';
import '../../data/prayers.dart';
import '../fluid_light.dart';
import '../glass.dart';
import '../icons.dart';
import '../theme.dart';

/// إذاعات مسيحية بث مباشر: كارت لكل محطة تحت بعض، وزرار تشغيل سريع على الشمال.
class StationsScreen extends StatelessWidget {
  const StationsScreen({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    const side = 24.0;
    return ListenableBuilder(
      listenable: RadioPlayer.instance,
      builder: (context, _) => ListView.separated(
        padding: EdgeInsets.fromLTRB(side, pad.top, side, pad.bottom + 32),
        itemCount: stations.length + 1,
        separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 0 : 10),
        itemBuilder: (context, i) => i == 0
            ? ScreenHeader('إذاعات', subtitle: 'إذاعات مسيحية بث مباشر', onBack: onBack)
            : _StationCard(station: stations[i - 1]),
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard({required this.station});
  final Station station;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final player = RadioPlayer.instance;
    final current = player.live && player.stationId == station.id;
    final playing = current && player.isPlaying;
    final loading = current && (player.loadingId != null || player.isBuffering);

    void tap() => current ? player.toggle() : player.playStation(station);

    return GlassPanel(
      radius: 14,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      onTap: tap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          AppIconView(AppIcon.antenna, size: 22, color: playing ? c.live : c.textFaint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(station.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.text)),
              const SizedBox(height: 2),
              Row(children: [
                if (playing) ...[
                  Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: c.live)),
                  const SizedBox(width: 6),
                ],
                Text(
                  loading ? 'جارٍ التحميل' : playing ? 'يُذاع الآن' : current ? 'متوقف مؤقتاً' : 'بث مباشر',
                  style: TextStyle(fontSize: 12, color: c.textFaint),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          // زرار التشغيل السريع: على الشمال (آخر الصف في الاتجاه العربي)
          FluidLight(
            spread: 16,
            when: () => current,
            child: RoundAction(
            size: 44,
            color: playing || current ? c.live : c.chip,
            tooltip: playing ? 'إيقاف ${station.name}' : 'تشغيل ${station.name}',
            onTap: tap,
            icon: loading
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: current ? c.onLive : c.text))
                : AppIconView(playing ? AppIcon.pause : AppIcon.play, size: 20, color: current ? c.onLive : c.text),
          ),
          ),
        ]),
        if (current && player.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(player.error!, style: TextStyle(fontSize: 12, color: c.textSoft)),
          ),
      ]),
    );
  }
}

/// الكتب: لسه.
class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    const side = 24.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(side, pad.top, side, pad.bottom + 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ScreenHeader('الكتب', onBack: onBack),
        const Spacer(),
        Center(child: AppIconView(AppIcon.books, size: 48, color: c.textFaint)),
        const SizedBox(height: 12),
        Text('سيضاف قريباً', textAlign: TextAlign.center, style: context.heading(size: 22)),
        const Spacer(flex: 2),
      ]),
    );
  }
}
