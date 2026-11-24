import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/prayers.dart' show Station, stations;
import '../native/native_bridge.dart';
import '../data/sermon_downloads.dart';
import '../data/sermons.dart';

class NowPlaying {
  const NowPlaying(this.id, this.title, this.category);
  final int id;
  final String title;
  final String category;
}

/// مشغّل الإذاعة: عظة واحدة أو بث متواصل لعظات عشوائية، يعمل في الخلفية
/// مع أزرار التحكم في الإشعار وشاشة القفل.
///
/// لو البث انقطع (النت فصل، الشاشة اتقفلت والشبكة نامت، المحطة وقعت) المشغّل بيرجّع الصوت لوحده:
/// محاولات بانتظار بيزيد (٢، ٤، ٨… لحد ٣٠ ثانية)، والعظة بترجع من نفس المكان.
/// ولو البث فضل «بيحمّل» أكتر من ٢٥ ثانية بيتعاد الاتصال.
class RadioPlayer extends ChangeNotifier {
  RadioPlayer._() {
    _player.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace _) => _recover());
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        position = Duration.zero;
        _persist(force: true); // العظة خلصت: المرة الجاية من الأول
        if (sleepAtEnd) {
          // مؤقت النوم «آخر العظة»: العظة خلصت، فمانكملش للي بعدها
          sleepAtEnd = false;
          radioOn = false;
          _intent = false;
        } else if (radioOn) {
          _playRandom();
        }
      }
      final active = s.playing && s.processingState != ProcessingState.idle && s.processingState != ProcessingState.completed;
      if (active && s.processingState == ProcessingState.ready) {
        // رجع يشتغل: نصفّر المحاولات
        if (_attempts > 0 || error != null) {
          _attempts = 0;
          error = null;
        }
        _bufferingSince = null;
      }
      // المستخدم وقّف من الإشعار أو سماعة البلوتوث (كان شغال ووقف وهو جاهز): مانرجّعش الصوت لوحدنا.
      // التحميل نفسه بيعدّي على «جاهز ومش شغال» قبل التشغيل، فده مش إيقاف.
      if (_wasPlaying && !s.playing && s.processingState == ProcessingState.ready) _intent = false;
      // وقف مؤقت: نحفظ المكان فوراً (آخر مكان يرجّع منه لو التطبيق اتقفل)
      if (_wasPlaying && !s.playing) _persist(force: true);
      if (s.playing && !_wasPlaying) refreshNotificationState();
      _wasPlaying = s.playing;
      if (s.processingState == ProcessingState.buffering) {
        _bufferingSince ??= DateTime.now();
      } else {
        _bufferingSince = null;
      }
      _updateLock(active);
      _syncOwn();
      notifyListeners();
    });
    NativeBridge.onMediaAction = _onMediaAction;
    // مراقب: بث واقف على التحميل كتير = اتصال ميت، نعيده
    Timer.periodic(const Duration(seconds: 5), (_) {
      if (_own && _player.playing) _pushOwn(); // المكان والعنوان في إشعار التحكم الاحتياطي
      final since = _bufferingSince;
      if (_intent && since != null && DateTime.now().difference(since) > const Duration(seconds: 25)) {
        _bufferingSince = null;
        _recover(immediate: true);
      }
    });
    _player.positionStream.listen((p) {
      position = p;
      _persist();
      notifyListeners();
    });
    _player.androidAudioSessionIdStream.listen((_) => notifyListeners());
    addListener(_syncWidget);
    // اسم اللي بيتذاع دلوقتي على المحطة (ICY): ٦ من الـ ٨ محطات بيبعتوه
    _player.icyMetadataStream.listen((m) {
      final t = cleanStreamTitle(m?.info?.title, nowPlaying?.title);
      if (t != streamTitle) {
        streamTitle = t;
        notifyListeners();
      }
    });
    _player.durationStream.listen((d) {
      duration = d ?? Duration.zero;
      notifyListeners();
    });
  }
  static final instance = RadioPlayer._();

  // ─── ويدجت الإذاعة ───
  String _widgetState = '';

  /// بيبعت للويدجت اللي شغال لما يتغير بس (مش مع كل تحديث للمكان).
  void _syncWidget() {
    final now = nowPlaying;
    final title = now?.title ?? '';
    final sub = subtitle;
    final playing = isPlaying;
    final state = '$title|$sub|$playing';
    if (state == _widgetState) return;
    _widgetState = state;
    NativeBridge.updateRadioWidget(title, sub, playing);
  }

  /// زرار التشغيل في الويدجت: يكمّل اللي كان شغال، أو آخر محطة، أو البث المتواصل.
  Future<void> resumeLast() async {
    if (isPlaying) return;
    if (hasPending) {
      toggle();
      return;
    }
    if (_source != null) {
      toggle();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('last_station');
    final st = stations.where((s) => s.id == id);
    if (st.isNotEmpty) {
      await playStation(st.first);
    } else {
      await startRadio();
    }
  }

  // بافر أكبر من الافتراضي عشان البث يعدّي انقطاعات النت القصيرة والشاشة مقفولة
  final _player = AudioPlayer(
    audioLoadConfiguration: AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: Duration(seconds: 30),
        maxBufferDuration: Duration(seconds: 120),
        bufferForPlaybackDuration: Duration(seconds: 3),
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 6),
        prioritizeTimeOverSizeThresholds: true,
      ),
    ),
  );
  bool _locked = false;

  /// المستخدم عايز الصوت شغال (بدأه ومش وقّفه)، فلو وقف من غير ما يطلب نرجّعه.
  bool _intent = false;
  bool _wasPlaying = false;
  AudioSource? _source;
  int _attempts = 0;
  bool _retrying = false;
  DateTime? _bufferingSince;

  /// قفل المعالج والواي فاي: طول ما فيه صوت، وكمان وإحنا بنحاول نرجّعه.
  void _updateLock(bool active) {
    final want = active || _retrying;
    if (want == _locked) return;
    _locked = want;
    NativeBridge.setPlaybackLock(want);
    if (active) _askBatteryOnce();
  }

  Future<void> _load(AudioSource source, {Duration? at}) async {
    _source = source;
    await _player.setAudioSource(source, initialPosition: at);
    _intent = true;
    unawaited(_player.play());
  }

  /// يرجّع الصوت بعد انقطاع: انتظار بيزيد مع كل محاولة، ومن نفس المكان للعظات.
  Future<void> _recover({bool immediate = false}) async {
    final src = _source;
    if (!_intent || src == null || _retrying) return;
    if (_attempts >= 12) {
      _intent = false;
      error = 'الاتصال مقطوع، شغّل تاني لما النت يرجع';
      _updateLock(false);
      notifyListeners();
      return;
    }
    _retrying = true;
    _updateLock(false);
    final at = live ? null : position;
    final wait = immediate ? Duration.zero : Duration(seconds: math.min(30, 2 << _attempts));
    _attempts++;
    error = 'انقطع الاتصال، بنرجّع الصوت…';
    notifyListeners();
    await Future<void>.delayed(wait);
    _retrying = false;
    if (!_intent || !identical(src, _source)) {
      _updateLock(false);
      return;
    }
    try {
      await _player.setAudioSource(src, initialPosition: at);
      _intent = true;
      unawaited(_player.play());
    } catch (_) {
      unawaited(_recover());
    }
  }

  /// أول مرة الصوت يشتغل: نطلب استثناء البطارية عشان النظام مايوقفش الصوت في الخلفية.
  Future<void> _askBatteryOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('asked_battery') ?? false) return;
    await prefs.setBool('asked_battery', true);
    await NativeBridge.requestBatteryExemption();
  }
  final _repo = SermonRepository.instance;

  NowPlaying? nowPlaying;
  int? loadingId;
  String? error;
  bool radioOn = false;

  /// بث مباشر لمحطة إذاعة (من غير مدة ولا تقديم ورجوع).
  bool live = false;
  String? stationId;
  int radioCategory = 0;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  bool get isPlaying => _player.playing;

  // ─── إشعار التحكم الاحتياطي ───
  // إشعار audio_service ماظهرش في بعض الأجهزة (حتى والصوت شغال). فلو بعد ٤ ثواني من التشغيل ماظهرش إشعار تحكم،
  // بنطلب من أندرويد إشعارنا الخاص بجلسة وسائط (أزرار على شاشة القفل وشريط الإشعارات وسماعات البلوتوث).
  bool _own = false;
  Timer? _ownCheck;

  void _syncOwn() {
    final now = nowPlaying;
    if (now == null) {
      if (_own) {
        _own = false;
        NativeBridge.mediaHide();
      }
      _ownCheck?.cancel();
      _ownCheck = null;
      return;
    }
    if (_own) {
      _pushOwn();
      return;
    }
    if (_player.playing && _ownCheck == null) {
      _ownCheck = Timer(const Duration(seconds: 4), () async {
        _ownCheck = null;
        if (!_player.playing || nowPlaying == null || _own) return;
        if (!await NativeBridge.hasMediaNotification()) {
          _own = true;
          _pushOwn();
        }
      });
    }
  }

  void _pushOwn() {
    final now = nowPlaying;
    if (now == null) return;
    NativeBridge.mediaUpdate(
      title: now.title,
      subtitle: subtitle,
      playing: _player.playing,
      live: live,
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
    );
  }

  void _onMediaAction(String action) {
    switch (action) {
      case 'toggle':
        toggle();
      case 'back30':
        seekBy(-30);
      case 'fwd30':
        seekBy(30);
      case 'next':
        next();
      case 'stop':
        _intent = false;
        _player.pause();
        _own = false;
        NativeBridge.mediaHide();
    }
  }

  /// اسم اللي بيتذاع دلوقتي على المحطة لو بتبعته (ترنيمة، عظة، لحن)، وإلا null.
  String? streamTitle;

  /// السطر اللي تحت الاسم: اللي بيتذاع على المحطة، أو قسم العظة.
  String get subtitle {
    final now = nowPlaying;
    if (now == null) return '';
    if (live) return streamTitle ?? 'بث مباشر';
    return radioOn ? 'بث متواصل · ${now.category}' : now.category;
  }

  /// تنضيف عنوان المحطة: من غير أكواد زي [JI6]، والشرطة السفلية مسافة، ومن غير اسم المحطة نفسه.
  static String? cleanStreamTitle(String? raw, String? stationName) {
    if (raw == null) return null;
    var t = raw.replaceAll(RegExp(r'\[[^\]]*\]'), ' ').replaceAll('_', ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceAll(RegExp(r'^[-–·|:\s]+|[-–·|:\s]+$'), '').trim();
    if (t.length < 2 || t == stationName) return null;
    return t;
  }

  // ─── آخر حاجة اتسمعت ───

  Sermon? _sermon;
  Station? _station;

  /// آخر عظة أو محطة (محفوظة من تشغيل قبل كده) لسه ماتحمّلتش: بتتحمّل أول ما المستخدم يدوس تشغيل.
  Sermon? _pendingSermon;
  Station? _pendingStation;
  Duration _pendingAt = Duration.zero;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  bool get hasPending => _pendingSermon != null || _pendingStation != null;

  /// يحفظ اللي شغال ومكانه كل ٥ ثواني (ولما يقف، أو لما التطبيق يروح للخلفية بـ [force]).
  void _persist({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastSave) < const Duration(seconds: 5)) return;
    final s = _sermon, st = _station;
    if (s == null && st == null) return;
    _lastSave = now;
    final data = <String, Object?>{
      if (s != null) ...{
        'kind': 'sermon',
        'id': s.id,
        't': s.title,
        's': s.summary,
        'l': s.link,
        'c': s.categoryId,
        'pos': position.inMilliseconds,
        'dur': duration.inMilliseconds,
      } else ...{
        'kind': 'station',
        'station': st!.id,
      },
      'radio': radioOn,
      'rcat': radioCategory,
    };
    SharedPreferences.getInstance().then((p) => p.setString('last_play', jsonEncode(data)));
  }

  /// يحفظ فوراً (التطبيق رايح للخلفية أو بيتقفل).
  void saveNow() => _persist(force: true);

  /// يرجّع آخر عظة أو محطة اتسمعت، واقفة على نفس المكان، من غير ما يشغّل حاجة أو يحتاج نت.
  Future<void> restoreLast() async {
    if (nowPlaying != null) return;
    try {
      final raw = (await SharedPreferences.getInstance()).getString('last_play');
      if (raw == null) return;
      final o = jsonDecode(raw) as Map<String, dynamic>;
      radioOn = o['radio'] as bool? ?? false;
      radioCategory = o['rcat'] as int? ?? 0;
      if (o['kind'] == 'station') {
        final st = stations.where((s) => s.id == o['station']).firstOrNull;
        if (st == null) return;
        _pendingStation = st;
        live = true;
        stationId = st.id;
        nowPlaying = NowPlaying(-1, st.name, 'بث مباشر');
      } else {
        final s = Sermon(o['id'] as int, o['t'] as String, o['s'] as String? ?? '', o['l'] as String, o['c'] as int? ?? 0);
        var at = Duration(milliseconds: o['pos'] as int? ?? 0);
        final dur = Duration(milliseconds: o['dur'] as int? ?? 0);
        // اللي قرب يخلص (آخر ١٠ ثواني) يبدأ من الأول
        if (dur > Duration.zero && at >= dur - const Duration(seconds: 10)) at = Duration.zero;
        _pendingSermon = s;
        _pendingAt = at;
        live = false;
        position = at;
        duration = dur;
        nowPlaying = NowPlaying(s.id, s.title, categoryName(s.categoryId));
      }
      notifyListeners();
    } catch (_) {
      // بيانات تالفة: نبدأ من غير استكمال
    }
  }

  Future<void> _resumePending() async {
    final s = _pendingSermon, st = _pendingStation, at = _pendingAt;
    if (s != null) {
      await _start(s, at: at > Duration.zero ? at : null);
    } else if (st != null) {
      await playStation(st);
    }
  }

  // ─── إشعار أزرار التحكم ───

  /// الإشعارات مقفولة من إعدادات النظام: أزرار التشغيل والإيقاف مش هتظهر في شاشة القفل ولا شريط الإشعارات.
  bool notificationsOff = false;

  Future<void> refreshNotificationState() async {
    final off = !(await NativeBridge.notificationsEnabled());
    if (off != notificationsOff) {
      notificationsOff = off;
      notifyListeners();
    }
  }

  // ─── مؤقت النوم ───
  Timer? _sleep;

  /// وقت الإيقاف لو المؤقت شغال بمدة.
  DateTime? sleepAt;

  /// الإيقاف في آخر العظة الحالية (للعظات بس، مش البث المباشر).
  bool sleepAtEnd = false;

  bool get sleepOn => sleepAt != null || sleepAtEnd;

  /// المدة الباقية على الإيقاف، لو المؤقت شغال بمدة.
  Duration? get sleepLeft {
    final at = sleepAt;
    if (at == null) return null;
    final left = at.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// يشغّل مؤقت النوم بمدة، أو يلغيه لو [d] = null.
  void setSleep(Duration? d) {
    _sleep?.cancel();
    sleepAtEnd = false;
    sleepAt = d == null ? null : DateTime.now().add(d);
    if (d != null) _sleep = Timer(d, _sleepNow);
    notifyListeners();
  }

  void setSleepAtEnd() {
    _sleep?.cancel();
    sleepAt = null;
    sleepAtEnd = true;
    notifyListeners();
  }

  /// الصوت بيخفت في ٨ ثواني وبعدين يقف، بدل ما يتقطع فجأة.
  Future<void> _sleepNow() async {
    sleepAt = null;
    for (var v = 1.0; v > 0.05 && _player.playing; v -= .1) {
      await _player.setVolume(v);
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    _intent = false;
    radioOn = false;
    await _player.pause();
    await _player.setVolume(1);
    notifyListeners();
  }

  /// جلسة الصوت في أندرويد، للضوء المتزامن مع الإيقاع.
  int? get audioSessionId => _player.androidAudioSessionId;
  bool get isBuffering =>
      _player.processingState == ProcessingState.loading || _player.processingState == ProcessingState.buffering;

  /// تشغيل محطة إذاعة مسيحية بث مباشر.
  Future<void> playStation(Station st) async {
    SharedPreferences.getInstance().then((p) => p.setString('last_station', st.id));
    _pendingSermon = null;
    _pendingStation = null;
    streamTitle = null;
    radioOn = false;
    live = true;
    stationId = st.id;
    loadingId = -1;
    error = null;
    notifyListeners();
    _attempts = 0;
    try {
      await _load(AudioSource.uri(
        Uri.parse(st.url),
        tag: MediaItem(id: 'station_${st.id}', title: st.name, artist: 'بث مباشر', album: 'إذاعات'),
      ));
      nowPlaying = NowPlaying(-1, st.name, 'بث مباشر');
      _station = st;
      _sermon = null;
      _persist(force: true);
    } catch (_) {
      _intent = false;
      _pendingStation = st; // زرار التشغيل يعيد المحاولة
      error = 'تعذّر تشغيل الإذاعة، تأكد من الاتصال بالإنترنت';
    }
    loadingId = null;
    notifyListeners();
  }

  Future<void> play(Sermon s) async {
    SharedPreferences.getInstance().then((p) => p.remove('last_station'));
    radioOn = false;
    await _start(s);
  }

  /// البث المتواصل: عظات عشوائية متتالية من القسم المختار.
  Future<void> startRadio([int category = 0]) async {
    SharedPreferences.getInstance().then((p) => p.remove('last_station'));
    radioOn = true;
    radioCategory = category;
    await _playRandom();
  }

  void stopRadio() {
    radioOn = false;
    notifyListeners();
  }

  Future<void> _playRandom() async {
    try {
      await _start(await _repo.random(radioCategory));
    } catch (_) {
      // من غير نت: البث المتواصل بيدوّر على العظات المحمّلة
      final saved = SermonDownloads.instance.sermons;
      if (saved.isNotEmpty) return _start(saved[math.Random().nextInt(saved.length)]);
      error = 'تعذّر الاتصال بمكتبة العظات';
      notifyListeners();
    }
  }

  Future<void> _start(Sermon s, {Duration? at}) async {
    _pendingSermon = null;
    _pendingStation = null;
    live = false;
    streamTitle = null;
    stationId = null;
    loadingId = s.id;
    error = null;
    notifyListeners();
    _attempts = 0;
    try {
      // العظة المحمّلة بتشتغل من الملف، من غير نت
      final local = SermonDownloads.instance.pathOf(s.id);
      final uri = local != null ? Uri.file(local) : Uri.parse(await _repo.audioUrl(s));
      await _load(AudioSource.uri(
        uri,
        tag: MediaItem(
          id: '${s.id}',
          title: s.title,
          artist: 'قداسة البابا شنوده الثالث',
          album: categoryName(s.categoryId),
          artUri: Uri.parse(SermonRepository.artwork),
        ),
      ), at: at);
      nowPlaying = NowPlaying(s.id, s.title, categoryName(s.categoryId));
      _sermon = s;
      _station = null;
      _persist(force: true);
    } catch (e) {
      _intent = false;
      if (at != null) {
        // فشل الاستكمال (مافيش نت مثلاً): العظة والمكان يفضلوا، وزرار التشغيل يعيد المحاولة
        _pendingSermon = s;
        _pendingAt = at;
      }
      error = e is StateError ? e.message : 'تعذّر تشغيل العظة';
    }
    loadingId = null;
    notifyListeners();
  }

  void toggle() {
    // آخر حاجة اتسمعت (اتسجّلت قبل ما التطبيق يتقفل) لسه ماتحمّلتش: أول ضغطة بتحمّلها وتكمّل من مكانها
    if (hasPending) {
      _intent = true;
      _attempts = 0;
      unawaited(_resumePending());
      return;
    }
    if (_player.playing) {
      _intent = false;
      _player.pause();
    } else {
      _intent = true;
      _attempts = 0;
      // لو كان واقف بسبب انقطاع، نعيد تحميل المصدر بدل ما نشغّل حاجة ميتة
      if (_player.processingState == ProcessingState.idle && _source != null) {
        _recover(immediate: true);
      } else {
        _player.play();
      }
    }
  }
  void seekBy(int seconds) {
    final target = position + Duration(seconds: seconds);
    seekTo(target < Duration.zero ? Duration.zero : target);
  }

  void seekTo(Duration d) {
    if (_pendingSermon != null) {
      _pendingAt = d;
      position = d;
      notifyListeners();
      return;
    }
    _player.seek(d);
  }
  void next() => _playRandom();
}
