import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'radio_player.dart';

/// مستويات الصوت اللي شغال دلوقتي، مقسومة نطاقات تردد من الغليظ للرفيع (٠ لـ ١).
///
/// المصدر الحقيقي هو Visualizer بتاع أندرويد على جلسة صوت المشغّل، وده محتاج إذن الميكروفون
/// (النظام بيطلبه لأي قراءة لخرج الصوت، التطبيق مابيسجّلش حاجة). لو الإذن مرفوض أو القراءة مش متاحة
/// الخط بيتحرك بإيقاع تقريبي بدل ما يقف.
///
/// القراءة بتشتغل بس طول ما فيه خط ظاهر والصوت شغال والتطبيق في الواجهة.
class SoundLevels with WidgetsBindingObserver {
  SoundLevels._() {
    WidgetsBinding.instance.addObserver(this);
    RadioPlayer.instance.addListener(_sync);
    _events.receiveBroadcastStream().listen(_onFrame, onError: (_) {});
  }
  static final instance = SoundLevels._();

  static const bands = 16;
  static const _channel = MethodChannel('hamset/native');
  static const _events = EventChannel('hamset/levels');

  final _latest = List<double>.filled(bands, 0);
  final _out = List<double>.filled(bands, 0);
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  double _peak = .25; // أعلى مستوى قريب، عشان الخط يبان حتى لو صوت التليفون واطي
  int _users = 0;
  bool _foreground = true;
  int? _session;

  /// خط ظهر على الشاشة.
  void attach() {
    _users++;
    _sync();
  }

  void detach() {
    _users--;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _onFrame(dynamic data) {
    if (data is! List) return;
    var top = 0.0;
    for (var i = 0; i < bands && i < data.length; i++) {
      final v = (data[i] as num).toDouble();
      _latest[i] = v;
      if (v > top) top = v;
    }
    _peak = math.max(top, _peak * .995).clamp(.12, 1.0);
    _lastFrame = DateTime.now();
  }

  Future<void> _sync() async {
    final player = RadioPlayer.instance;
    final id = player.audioSessionId;
    final want = _users > 0 && _foreground && player.isPlaying && id != null;
    if (!want) {
      if (_session != null) {
        _session = null;
        _invoke('stopLevels', const {});
      }
      return;
    }
    if (_session == id) return;
    _session = id;
    final prefs = await SharedPreferences.getInstance();
    final asked = prefs.getBool('asked_levels') ?? false;
    if (!asked) await prefs.setBool('asked_levels', true);
    // الإذن بيتطلب مرة واحدة بس، أول مرة الخط يظهر والصوت شغال
    _invoke('startLevels', {'session': id, 'ask': !asked});
  }

  static Future<void> _invoke(String method, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod(method, args);
    } on MissingPluginException {
      // خارج أندرويد
    } on PlatformException {
      // الخط بيكمّل بالإيقاع التقريبي
    }
  }

  /// المستويات المطلوبة في اللحظة [t] (ثواني). القايمة بتتعاد استخدامها، ماتتخزنش.
  List<double> sample(double t) {
    final real = DateTime.now().difference(_lastFrame) < const Duration(milliseconds: 500);
    for (var i = 0; i < bands; i++) {
      _out[i] = real ? (_latest[i] / _peak).clamp(0.0, 1.0) : approx(t, i);
    }
    return _out;
  }

  /// إيقاع تقريبي شبه الكلام: مقاطع بتعلى وتوطى، والنطاقات الغليظة أقوى.
  static double approx(double t, int i) {
    final phrase = .55 + .45 * math.sin(t * 1.9 + math.sin(t * .43) * 2.2);
    final syllable = math.pow((math.sin(t * 13.2 + math.sin(t * 2.7) * 1.8) + 1) / 2, 1.6);
    final own = .5 + .5 * math.sin(t * (5.1 + i * .83) + i * 1.7);
    final tilt = 1 - i / bands * .55;
    return (phrase * (.25 + .75 * syllable) * (.45 + .55 * own) * tilt).clamp(0.0, 1.0);
  }
}
