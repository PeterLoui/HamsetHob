import 'dart:async';

import 'package:flutter/material.dart';

import '../core/coptic.dart';
import '../data/bible.dart';
import '../data/meditations.dart';
import '../data/prayers.dart';
import '../data/reminders.dart';
import '../data/updater.dart';
import '../data/store.dart';
import '../data/tasbeha.dart';
import '../native/native_bridge.dart';
import '../audio/radio_player.dart';
import 'glass.dart';
import 'icons.dart';
import 'screens/bible.dart';
import 'screens/books.dart';
import '../data/books.dart';
import 'screens/calendar.dart';
import 'screens/home.dart';
import 'screens/meditation.dart';
import 'screens/prayers.dart';
import 'screens/stations.dart';
import 'pinch_zoom.dart';
import 'update_dialog.dart';
import 'screens/more.dart';
import 'screens/radio.dart';
import 'screens/reading_plans.dart';
import 'screens/readings.dart';
import 'screens/tasbeha.dart';
import '../data/reading_plans.dart';

/// شاشات فرعية تُفتح فوق التبويبات.
sealed class SubScreen {
  const SubScreen();
}

class ChapterOverlay extends SubScreen {
  const ChapterOverlay(this.ref);
  final VerseRef ref;
}

class SynaxariumBrowseOverlay extends SubScreen {
  const SynaxariumBrowseOverlay();
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

class MeditationOverlay extends SubScreen {
  const MeditationOverlay(this.meditation);
  final Meditation meditation;
}

class PrayersOverlay extends SubScreen {
  const PrayersOverlay();
}

class AgpeyaPrayerOverlay extends SubScreen {
  const AgpeyaPrayerOverlay(this.prayer);
  final Prayer prayer;
}

class LiturgyOverlay extends SubScreen {
  const LiturgyOverlay(this.liturgy);
  final Liturgy liturgy;
}

class LiturgyPartOverlay extends SubScreen {
  const LiturgyPartOverlay(this.liturgy, this.parts, this.index);
  final Liturgy liturgy;
  final List<LiturgyPart> parts;
  final int index;
}

class StationsOverlay extends SubScreen {
  const StationsOverlay();
}

class BooksOverlay extends SubScreen {
  const BooksOverlay();
}

class BookCategoryOverlay extends SubScreen {
  const BookCategoryOverlay(this.category);
  final BookCategory category;
}

class BookOverlay extends SubScreen {
  const BookOverlay(this.book);
  final LibraryBook book;
}

class BookReaderOverlay extends SubScreen {
  const BookReaderOverlay(this.book);
  final LibraryBook book;
}

class ReadingPlansOverlay extends SubScreen {
  const ReadingPlansOverlay();
}

class ReadingPlanOverlay extends SubScreen {
  const ReadingPlanOverlay(this.plan);
  final ReadingPlan plan;
}

class TasbehaOverlay extends SubScreen {
  const TasbehaOverlay();
}

class TasbehaBookOverlay extends SubScreen {
  const TasbehaBookOverlay(this.book);
  final TasbehaBook book;
}

class TasbehaDayOverlay extends SubScreen {
  const TasbehaDayOverlay(this.book, this.day);
  final TasbehaBook book;
  final TasbehaDay day;
}

class TasbehaReaderOverlay extends SubScreen {
  const TasbehaReaderOverlay(this.book, this.day, this.index);
  final TasbehaBook book;
  final TasbehaDay day;
  final int index;
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.onThemeChanged});
  final VoidCallback onThemeChanged;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;
  final _overlays = <SubScreen>[];
  DateTime _today = DateTime.now();
  Timer? _dayTicker;
  DailyVerse? _lastVerse;

  static const _tabs = [
    NavTab(label: 'الرئيسية', icon: AppIconView(AppIcon.home)),
    NavTab(label: 'الكتاب', icon: AppIconView(AppIcon.bible)),
    NavTab(label: 'القراءات', icon: AppIconView(AppIcon.readings)),
    NavTab(label: 'النتيجة', icon: AppIconView(AppIcon.calendar)),
    NavTab(label: 'المزيد', icon: AppIconView(AppIcon.more)),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppSettings.instance.addListener(_onSettings);
    // مؤقّت واحد لنص الليل مابيشتغلش والتطبيق في الخلفية أو الموبايل نايم، فاليوم كان بيفضل زي ما هو.
    // بنقارن التاريخ كل شوية، وكمان أول ما التطبيق يرجع للواجهة.
    _dayTicker = Timer.periodic(const Duration(seconds: 20), (_) => _checkDay());
    NativeBridge.onLaunchRef((ref) => _open(ChapterOverlay(ref)));
    // زرار التشغيل في ويدجت الإذاعة
    NativeBridge.onResumeRadio = RadioPlayer.instance.resumeLast;
    NativeBridge.takeResume().then((yes) {
      if (yes) RadioPlayer.instance.resumeLast();
    });
    NativeBridge.takeLaunchRef().then((ref) {
      if (ref != null) _open(ChapterOverlay(ref));
    });
    // إشعار تذكير الصلاة بيفتح الصلاة نفسها
    NativeBridge.onOpenPrayer = _openPrayerById;
    NativeBridge.takeLaunchPrayer().then((id) {
      if (id != null) _openPrayerById(id);
    });
    final s = AppSettings.instance;
    NativeBridge.scheduleMorning(s.morningEnabled, s.morningMinutes);
    Reminders.sync();
    // تحديث من GitHub: فحص عند فتح التطبيق، وإشعار «نسخة جديدة» بيفتح نفس الشاشة
    NativeBridge.onOpenUpdate = () => _checkUpdate(force: true);
    NativeBridge.takeLaunchUpdate().then((yes) {
      if (yes) _checkUpdate(force: true);
    });
    Updater.instance.init().then((_) {
      if (s.autoUpdate) _checkUpdate();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDay();
      if (RadioPlayer.instance.isPlaying) RadioPlayer.instance.refreshNotificationState(); // ممكن يكون فعّلها من الإعدادات
    } else {
      RadioPlayer.instance.saveNow(); // مكان العظة يتحفظ لو التطبيق اتقفل
    }
  }

  bool _updateShowing = false;

  /// يفحص GitHub ويعرض شاشة التحديث لو فيه نسخة أحدث. بعد «لاحقاً» مابيعرضهاش تاني في فتح التطبيق
  /// (لكن [force]، من الإشعار أو الإعدادات، بيعرضها).
  Future<void> _checkUpdate({bool force = false}) async {
    final u = await Updater.instance.check(force: force);
    if (u == null || !mounted || _updateShowing) return;
    if (!force && await Updater.instance.dismissedBuild(u.build)) return;
    if (!mounted) return;
    _updateShowing = true;
    await showUpdateDialog(context, u);
    _updateShowing = false;
  }

  Future<void> _openPrayerById(String id) async {
    final agpeya = await AgpeyaRepository.instance.load();
    final prayer = agpeya.hours.where((p) => p.id == id).firstOrNull;
    if (prayer != null && mounted) _open(AgpeyaPrayerOverlay(prayer));
  }

  void _checkDay() {
    final now = DateTime.now();
    if (!mounted || dateOnly(now) == dateOnly(_today)) return;
    setState(() => _today = now);
    Reminders.sync(); // نافذة الأعياد القادمة بتتحرك مع اليوم
  }

  double _scale = AppSettings.instance.readingScale;

  /// حجم الخط اتغيّر (بالقرص أو من الخيارات): الشاشات بتقراه وقت الرسم، فنعيد بناء المحتوى.
  void _onSettings() {
    final s = AppSettings.instance.readingScale;
    if (s == _scale) return;
    _scale = s;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onSettings);
    WidgetsBinding.instance.removeObserver(this);
    _dayTicker?.cancel();
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
            onOpenMeditation: (m) => _open(MeditationOverlay(m)),
            onOpenPrayers: () => _open(const PrayersOverlay()),
            onOpenStations: () => _open(const StationsOverlay()),
            onOpenBooks: () => _open(const BooksOverlay()),
            onOpenTasbeha: () => _open(const TasbehaOverlay()),
            onVerseLoaded: _syncWidgets,
          ),
        1 => BibleScreen(onOpenChapter: (r) => _open(ChapterOverlay(r))),
        2 => ReadingsScreen(today: _today, onOpenSynaxarium: (d) => _open(SynaxariumOverlay(d))),
        3 => CalendarScreen(today: _today),
        _ => MoreScreen(
            onOpenFavorites: () => _open(const FavoritesOverlay()),
            onOpenReadingPlans: () => _open(const ReadingPlansOverlay()),
            onSettingsChanged: () {
              widget.onThemeChanged();
              _syncWidgets();
            },
          ),
      };

  Widget _overlayBody(SubScreen o) => switch (o) {
        ChapterOverlay(:final ref) => ChapterScreen(key: ValueKey(ref), start: ref, onBack: _back),
        SynaxariumOverlay(:final date) => SynaxariumScreen(
            start: date,
            onBack: _back,
            onBrowse: () => _open(const SynaxariumBrowseOverlay()),
          ),
        SynaxariumBrowseOverlay() => SynaxariumBrowseScreen(
            today: _today,
            onBack: _back,
            onOpenDate: (d) {
              _back();
              _open(SynaxariumOverlay(d));
            },
          ),
        FavoritesOverlay() => FavoritesScreen(onOpenChapter: (r) => _open(ChapterOverlay(r)), onBack: _back),
        RadioOverlay() => RadioScreen(onBack: _back),
        MeditationOverlay(:final meditation) => MeditationScreen(meditation: meditation, onBack: _back),
        PrayersOverlay() => PrayersScreen(
            onBack: _back,
            onOpenPrayer: (p) => _open(AgpeyaPrayerOverlay(p)),
            onOpenLiturgy: (l) => _open(LiturgyOverlay(l)),
          ),
        AgpeyaPrayerOverlay(:final prayer) => AgpeyaPrayerScreen(prayer: prayer, onBack: _back),
        LiturgyOverlay(:final liturgy) => LiturgyScreen(
            liturgy: liturgy,
            onBack: _back,
            onOpenPart: (parts, i) => _open(LiturgyPartOverlay(liturgy, parts, i)),
          ),
        LiturgyPartOverlay(:final liturgy, :final parts, :final index) =>
          LiturgyPartScreen(liturgy: liturgy, parts: parts, index: index, onBack: _back),
        StationsOverlay() => StationsScreen(onBack: _back),
        BooksOverlay() => BooksScreen(
            onBack: _back,
            onOpenCategory: (cat) => _open(BookCategoryOverlay(cat)),
            onOpenBook: (b) => _open(BookOverlay(b)),
          ),
        BookCategoryOverlay(:final category) =>
          BookCategoryScreen(category: category, onBack: _back, onOpenBook: (b) => _open(BookOverlay(b))),
        BookOverlay(:final book) => BookScreen(book: book, onBack: _back, onRead: () => _open(BookReaderOverlay(book))),
        BookReaderOverlay(:final book) => BookReaderScreen(book: book, onBack: _back),
        ReadingPlansOverlay() => ReadingPlansScreen(onBack: _back, onOpenPlan: (p) => _open(ReadingPlanOverlay(p))),
        ReadingPlanOverlay(:final plan) =>
          ReadingPlanScreen(plan: plan, onBack: _back, onOpenChapter: (ref) => _open(ChapterOverlay(ref))),
        TasbehaOverlay() => TasbehaScreen(
            onBack: _back,
            onOpenBook: (b) => _open(TasbehaBookOverlay(b)),
            onRead: (b, d, i) => _open(TasbehaReaderOverlay(b, d, i)),
          ),
        TasbehaBookOverlay(:final book) =>
          TasbehaBookScreen(book: book, onBack: _back, onOpenDay: (d) => _open(TasbehaDayOverlay(book, d))),
        TasbehaDayOverlay(:final book, :final day) => TasbehaDayScreen(
            book: book, day: day, onBack: _back, onOpenPiece: (i) => _open(TasbehaReaderOverlay(book, day, i))),
        TasbehaReaderOverlay(:final book, :final day, :final index) =>
          TasbehaReaderScreen(book: book, day: day, index: index, onBack: _back),
      };

  @override
  Widget build(BuildContext context) {
    final top = _overlays.isEmpty ? null : _overlays.last;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // مساحة الشريط السفلي: المحتوى ينتهي فوقه ولا يظهر شيء خلفه
    final barArea = bottomBarHeight(context) + safeBottom;

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
          const Positioned.fill(child: Wallpaper()),
          Positioned.fill(
            // المحتوى بيبدأ تحت منطقة التلاشي، فالتغبيش يلمس بس اللي بيطلع لفوق وأنت بتعمل سكرول
            // قرص بإصبعين يكبّر ويصغّر خط القراءة في كل الشاشات
            child: PinchZoom(
              child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: MediaQuery.paddingOf(context).copyWith(top: MediaQuery.paddingOf(context).top + StatusBarFade.fade),
              ),
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
          ),
          const Positioned(left: 0, right: 0, top: 0, child: StatusBarFade()),
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
              child: BottomNavBar(
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
