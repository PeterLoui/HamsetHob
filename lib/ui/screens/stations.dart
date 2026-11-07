import 'package:flutter/material.dart';

import '../../audio/radio_player.dart';
import '../../data/prayers.dart';
import '../glass.dart';
import '../icons.dart';
import '../theme.dart';
import 'home.dart' show PlayButton;

/// إذاعات مسيحية بث مباشر: تبويب لكل محطة.
class StationsScreen extends StatefulWidget {
  const StationsScreen({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  State<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends State<StationsScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = MediaQuery.paddingOf(context);
    final side = c.classic ? 24.0 : 16.0;
    final player = RadioPlayer.instance;
    final st = stations[_selected];

    return ListView(
      padding: EdgeInsets.fromLTRB(side, pad.top, side, pad.bottom + 32),
      children: [
        ScreenHeader('إذاعات', subtitle: 'إذاعات مسيحية بث مباشر', onBack: widget.onBack),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: stations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => AppChip(
              label: stations[i].name,
              selected: i == _selected,
              onTap: () => setState(() => _selected = i),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          radius: 16,
          child: ListenableBuilder(
            listenable: player,
            builder: (context, _) {
              final current = player.live && player.stationId == st.id;
              return Column(children: [
                AppIconView(AppIcon.radio, size: 40, color: c.textSoft),
                const SizedBox(height: 12),
                Text(st.name, textAlign: TextAlign.center, style: context.heading(size: 22)),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (current && player.isPlaying) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: c.isDark ? c.accent : c.text),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    current ? (player.isPlaying ? 'يُذاع الآن' : 'متوقف مؤقتاً') : 'بث مباشر',
                    style: TextStyle(fontSize: 12, color: c.textFaint),
                  ),
                ]),
                const SizedBox(height: 16),
                if (current)
                  const PlayButton(size: 62)
                else
                  RoundAction(
                    size: 62,
                    color: c.live,
                    tooltip: 'تشغيل ${st.name}',
                    onTap: () => player.playStation(st),
                    icon: AppIconView(AppIcon.play, size: 30, color: c.onLive),
                  ),
                if (player.error != null && (current || player.loadingId == null)) ...[
                  const SizedBox(height: 12),
                  Text(player.error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.textSoft)),
                ],
              ]);
            },
          ),
        ),
        const SizedBox(height: 16),
        Text('إذاعات تانية هتتضاف قريباً', style: TextStyle(fontSize: 12, color: c.textFaint)),
      ],
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
    final side = c.classic ? 24.0 : 16.0;
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
