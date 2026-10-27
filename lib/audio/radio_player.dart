import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../data/sermons.dart';

class NowPlaying {
  const NowPlaying(this.id, this.title, this.category);
  final int id;
  final String title;
  final String category;
}

/// مشغّل الإذاعة: عظة واحدة أو بث متواصل لعظات عشوائية، يعمل في الخلفية
/// مع أزرار التحكم في الإشعار وشاشة القفل.
class RadioPlayer extends ChangeNotifier {
  RadioPlayer._() {
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && radioOn) _playRandom();
      notifyListeners();
    });
    _player.positionStream.listen((p) {
      position = p;
      notifyListeners();
    });
    _player.durationStream.listen((d) {
      duration = d ?? Duration.zero;
      notifyListeners();
    });
  }
  static final instance = RadioPlayer._();

  final _player = AudioPlayer();
  final _repo = SermonRepository.instance;

  NowPlaying? nowPlaying;
  int? loadingId;
  String? error;
  bool radioOn = false;
  int radioCategory = 0;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  bool get isPlaying => _player.playing;
  bool get isBuffering =>
      _player.processingState == ProcessingState.loading || _player.processingState == ProcessingState.buffering;

  Future<void> play(Sermon s) async {
    radioOn = false;
    await _start(s);
  }

  /// البث المتواصل: عظات عشوائية متتالية من القسم المختار.
  Future<void> startRadio([int category = 0]) async {
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
    loadingId = s.id;
    error = null;
    notifyListeners();
    try {
      final url = await _repo.audioUrl(s);
      await _player.setAudioSource(AudioSource.uri(
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
      unawaited(_player.play());
    } catch (e) {
      error = e is StateError ? e.message : 'تعذّر تشغيل العظة';
    }
    loadingId = null;
    notifyListeners();
  }

  void toggle() => _player.playing ? _player.pause() : _player.play();
  void seekBy(int seconds) {
    final target = position + Duration(seconds: seconds);
    _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  void seekTo(Duration d) => _player.seek(d);
  void next() => _playRandom();
}
