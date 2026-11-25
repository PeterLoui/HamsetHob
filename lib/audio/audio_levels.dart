import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/store.dart';
import '../native/native_bridge.dart';
import 'radio_player.dart';

/// مستويات الصوت الشغال للضوء المتحرك: باص ووسط وحاد من ٠ لـ ١.
///
/// لو «تزامن الضوء مع الإيقاع» مفعّل والإذن موجود، المستويات حقيقية من أندرويد (Visualizer).
/// غير كده [real] بيبقى false والضوء بيتنفس بإيقاع هادي لوحده.
class AudioLevels extends ChangeNotifier {
  AudioLevels._() {
    RadioPlayer.instance.addListener(_sync);
    AppSettings.instance.addListener(_sync);
  }
  static final instance = AudioLevels._();

  double bass = 0, mid = 0, high = 0;
  bool real = false;

  StreamSubscription<List<double>>? _sub;
  int? _session;
  bool _starting = false;

  Future<void> _sync() async {
    final p = RadioPlayer.instance;
    final want = p.isPlaying && AppSettings.instance.syncLight;
    final session = p.audioSessionId;
    if (want && session != null && session > 0) {
      if ((real && session == _session) || _starting) return;
      _starting = true;
      final ok = await NativeBridge.startLevels(session);
      _starting = false;
      if (!ok) return _stop();
      _session = session;
      real = true;
      _sub ??= NativeBridge.levels.listen((v) {
        if (v.length < 3) return;
        bass = v[0];
        mid = v[1];
        high = v[2];
        notifyListeners();
      });
    } else if (real) {
      _stop();
    }
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    _session = null;
    if (real) NativeBridge.stopLevels();
    real = false;
    bass = mid = high = 0;
    notifyListeners();
  }

  /// تفعيل التزامن الحقيقي: بيطلب الإذن الأول. بيرجع false لو المستخدم رفض.
  static Future<bool> enableSync() async {
    final ok = await NativeBridge.requestMic();
    AppSettings.instance.syncLight = ok;
    return ok;
  }
}
