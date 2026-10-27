import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'core/synaxarium.dart';
import 'data/store.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.hamsethob.radio',
    androidNotificationChannelName: 'الإذاعة',
    androidNotificationOngoing: true,
  );
  await LiquidGlassWidgets.initialize();
  await AppSettings.load();
  await Favorites.load();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(LiquidGlassWidgets.wrap(child: const HamsetApp()));
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
    final season = settings.seasonalColors ? seasonOf(DateTime.now()) : Season.ordinary;
    final colors = AppColors.of(dark, season);

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
