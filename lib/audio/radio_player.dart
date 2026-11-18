import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/prayers.dart' show Station, stations;
import '../native/native_bridge.dart';
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
      _wasPlaying = s.playing;
      if (s.processingState == ProcessingState.buffering) {
        _bufferingSince ??= DateTime.now();
      } else {
        _bufferingSince = null;
      }
      _updateLock(active);
      notifyListeners();
    });
    // مراقب: بث واقف على التحميل كتير = اتصال ميت، نعيده
    Timer.periodic(const Duration(seconds: 5), (_) {
      final since = _bufferingSince;
      if (_intent && since != null && DateTime.now().difference(since) > const Duration(seconds: 25)) {
        _bufferingSince = null;
        _recover(immediate: true);
      }
    });
    _player.positionStream.listen((p) {
      position = p;
      notifyListeners();
    });
    _player.androidAudioSessionIdStream.listen((_) => notifyListeners());
    addListener(_syncWidget);
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
    final sub = now == null ? '' : (live ? 'بث مباشر' : (radioOn ? 'بث متواصل · ${now.category}' : now.category));
    final playing = isPlaying;
    final state = '$title|$sub|$playing';
    if (state == _widgetState) return;
    _widgetState = state;
    NativeBridge.updateRadioWidget(title, sub, playing);
  }

  /// زرار التشغيل في الويدجت: يكمّل اللي كان شغال، أو آخر محطة، أو البث المتواصل.
  Future<void> resumeLast() async {
    if (isPlaying) return;
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
    } catch (_) {
      _intent = false;
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
      error = 'تعذّر الاتصال بمكتبة العظات';
      notifyListeners();
    }
  }

  Future<void> _start(Sermon s) async {
    live = false;
    stationId = null;
    loadingId = s.id;
    error = null;
    notifyListeners();
    _attempts = 0;
    try {
      final url = await _repo.audioUrl(s);
      await _load(AudioSource.uri(
        Uri.parse(url),
        tag: MediaItem(
          id: '${s.id}',
          title: s.title,
          artist: 'قداسة البابا شنوده الثالث',
          album: categoryName(s.categoryId),
          artUri: Uri.parse(SermonRepository.artwork),
        ),
      ));
      nowPlaying = NowPlaying(s.id, s.title, categoryName(s.categoryId));
    } catch (e) {
      _intent = false;
      error = e is StateError ? e.message : 'تعذّر تشغيل العظة';
    }
    loadingId = null;
    notifyListeners();
  }

  void toggle() {
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
    _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  void seekTo(Duration d) => _player.seek(d);
  void next() => _playRandom();
}
