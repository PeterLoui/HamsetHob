import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'audio/radio_player.dart';
import 'data/books.dart';
import 'data/sermon_downloads.dart';
import 'data/store.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // لو جزء من الشاشة فشل في الرسم: سطر هادي بدل الشاشة الرمادي أو الأحمر، وباقي التطبيق يكمل
  ErrorWidget.builder = (details) => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('تعذّر عرض الجزء ده', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 13, color: Color(0xFF8C8477))),
        ),
      );
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.hamsethob.radio',
    androidNotificationChannelName: 'الإذاعة',
    androidNotificationChannelDescription: 'زرار التشغيل والإيقاف على شاشة القفل وفي شريط الإشعارات',
    // أيقونة الإشعار لازم تكون رسمة أحادية اللون: أيقونة التطبيق (adaptive) مش صالحة كأيقونة إشعار
    androidNotificationIcon: 'drawable/ic_stat_cross',
    // الإشعار يفضل ظاهر وأنت موقّف مؤقتاً، عشان زرار التشغيل يفضل في شاشة القفل وشريط الإشعارات
    // (لو الخدمة خرجت من الواجهة وقت الإيقاف النظام ممكن يقفلها ويشيل الإشعار)
    androidStopForegroundOnPause: false,
    androidNotificationOngoing: false,
    fastForwardInterval: const Duration(seconds: 30),
    rewindInterval: const Duration(seconds: 30),
  );
  await AppSettings.load();
  await Favorites.load();
  await BibleMarks.load();
  await ReadingProgress.load();
  await SermonDownloads.load();
  await RadioPlayer.instance.restoreLast();
  await BooksRepository.instance.load();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const HamsetApp());
}

class HamsetApp extends StatefulWidget {
  const HamsetApp({super.key});

  @override
  State<HamsetApp> createState() => _HamsetAppState();
}

class _HamsetAppState extends State<HamsetApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final dark = switch (settings.theme) {
      ThemeChoice.light => false,
      ThemeChoice.dark => true,
      ThemeChoice.system => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
    };
    final colors = AppColors.of(dark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: MaterialApp(
        title: 'همسة حب',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar', 'EG'),
        supportedLocales: const [Locale('ar', 'EG')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(colors),
        home: Shell(onThemeChanged: () => setState(() {})),
      ),
    );
  }
}
