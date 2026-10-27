import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/coptic.dart';
import '../data/bible.dart';
import '../data/store.dart';
import '../native/native_bridge.dart';
import '../native/widget_glass.dart';
import '../audio/radio_player.dart';
import 'glass.dart';
import 'icons.dart';
import 'screens/bible.dart';
import 'screens/calendar.dart';
import 'screens/home.dart';
import 'screens/more.dart';
import 'screens/radio.dart';
import 'screens/readings.dart';

/// شاشات فرعية تُفتح فوق التبويبات.
sealed class SubScreen {
  const SubScreen();
}

class ChapterOverlay extends SubScreen {
  const ChapterOverlay(this.ref);
  final VerseRef ref;
}

class SynaxariumOverlay extends SubScreen {
  const SynaxariumOverlay(this.date);
  final DateTime date;
}

class FavoritesOverlay extends SubScreen {
  const FavoritesOverlay();
}

class RadioOverlay extends SubScreen {
  const RadioOverlay();
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.onThemeChanged});
  final VoidCallback onThemeChanged;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  final _overlays = <SubScreen>[];
  DateTime _today = DateTime.now();
  Timer? _midnight;
  DailyVerse? _lastVerse;

  static const _tabs = [
    LiquidGlassTab(label: 'الرئيسية', icon: AppIconView(AppIcon.home)),
    LiquidGlassTab(label: 'الكتاب', icon: AppIconView(AppIcon.bible)),
    LiquidGlassTab(label: 'القراءات', icon: AppIconView(AppIcon.readings)),
    LiquidGlassTab(label: 'النتيجة', icon: AppIconView(AppIcon.calendar)),
    LiquidGlassTab(label: 'المزيد', icon: AppIconView(AppIcon.more)),
  ];

  @override
  void initState() {
    super.initState();
    _scheduleMidnight();
    NativeBridge.onLaunchRef((ref) => _open(ChapterOverlay(ref)));
    NativeBridge.takeLaunchRef().then((ref) {
      if (ref != null) _open(ChapterOverlay(ref));
    });
    final s = AppSettings.instance;
    NativeBridge.scheduleMorning(s.morningEnabled, s.morningMinutes);
  }

  void _scheduleMidnight() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
    _midnight = Timer(next.difference(now), () {
      setState(() => _today = DateTime.now());
      widget.onThemeChanged(); // الموسم قد يتغير
      _scheduleMidnight();
    });
  }

  @override
  void dispose() {
    _midnight?.cancel();
    super.dispose();
  }

  void _open(SubScreen o) => setState(() => _overlays.add(o));
  void _back() => setState(() => _overlays.removeLast());

  /// تحديث الويدجتس وإشعار القفل برسالة اليوم نفسها.
  void _syncWidgets([DailyVerse? v]) {
    final verse = v ?? _lastVerse;
    if (verse == null) return;
    _lastVerse = verse;
    final c = CopticDate.fromGregorian(_today);
    NativeBridge.updateWidgets(
      copticLabel: c.label,
      copticDay: ar(c.day),
      copticMonth: '${c.monthName} ${ar(c.year)} ش',
      verse: verse,
      lockNotification: AppSettings.instance.lockNotification,
    );
  }

  Widget _tabBody() => switch (_tab) {
        0 => HomeScreen(
            today: _today,
            onOpenChapter: (r) => _open(ChapterOverlay(r)),
            onOpenSynaxarium: () => _open(SynaxariumOverlay(_today)),
            onOpenReadings: () => setState(() => _tab = 2),
            onOpenFavorites: () => _open(const FavoritesOverlay()),
            onOpenRadio: () => _open(const RadioOverlay()),
            onVerseLoaded: _syncWidgets,
          ),
        1 => BibleScreen(onOpenChapter: (r) => _open(ChapterOverlay(r))),
        2 => ReadingsScreen(today: _today, onOpenSynaxarium: (d) => _open(SynaxariumOverlay(d))),
        3 => CalendarScreen(today: _today),
        _ => MoreScreen(
            onOpenFavorites: () => _open(const FavoritesOverlay()),
            onSettingsChanged: () {
              widget.onThemeChanged();
              _syncWidgets();
            },
          ),
      };

  Widget _overlayBody(SubScreen o) => switch (o) {
        ChapterOverlay(:final ref) => ChapterScreen(key: ValueKey(ref), start: ref, onBack: _back),
        SynaxariumOverlay(:final date) => SynaxariumScreen(start: date, onBack: _back),
        FavoritesOverlay() => FavoritesScreen(onOpenChapter: (r) => _open(ChapterOverlay(r)), onBack: _back),
        RadioOverlay() => RadioScreen(onBack: _back),
      };

  @override
  Widget build(BuildContext context) {
    final top = _overlays.isEmpty ? null : _overlays.last;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // مساحة الشريط السفلي: المحتوى ينتهي فوقه ولا يظهر شيء خلفه
    final barArea = 64 + 20 + safeBottom + 8;

    return PopScope(
      canPop: _overlays.isEmpty && _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_overlays.isNotEmpty) {
          _back();
        } else {
          setState(() => _tab = 0);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          // سطح زجاج الويدجتس يُرسم هنا خلف الخلفية ثم يُلتقط صورةً
          const Positioned(left: 0, top: 0, child: WidgetGlassCapture()),
          const Positioned.fill(child: Wallpaper()),
          Positioned.fill(
            child: AdaptiveLiquidGlassLayer(
              settings: glassSettings,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: top != null
                    ? KeyedSubtree(key: ValueKey(top), child: _overlayBody(top))
                    : ListenableBuilder(
                        key: ValueKey('tab$_tab'),
                        listenable: RadioPlayer.instance,
                        builder: (context, _) {
                          final mini = RadioPlayer.instance.nowPlaying != null ? 68.0 : 0.0;
                          return Padding(
                            padding: EdgeInsets.only(bottom: barArea + mini),
                            child: ShaderMask(
                              // تلاشي الحافة السفلية للمحتوى
                              shaderCallback: (r) => const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black, Colors.black, Colors.transparent],
                                stops: [0, .95, 1],
                              ).createShader(r),
                              blendMode: BlendMode.dstIn,
                              child: _tabBody(),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
          if (top == null) ...[
            Positioned(
              left: 0,
              right: 0,
              bottom: barArea + 2,
              child: MiniPlayer(onOpen: () => _open(const RadioOverlay())),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LiquidGlassBottomNavBar(
                selectedIndex: _tab,
                tabs: _tabs,
                onTabSelected: (i) => setState(() => _tab = i),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
