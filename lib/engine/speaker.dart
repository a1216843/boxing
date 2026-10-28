import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'web/speech_unlock_stub.dart'
    if (dart.library.js_interop) 'web/speech_unlock_web.dart' as web_speech;

/// TTS를 한 줄로 세워 읽는다. 겹쳐 말하지 않고, [interrupt]로 대기 중인 말까지 끊는다.
class Speaker {
  final FlutterTts _tts = FlutterTts();
  Future<void> _queue = Future.value();
  Completer<void> _cut = Completer<void>();
  int _generation = 0;
  bool _ready = false;

  static const _maxUtterance = Duration(seconds: 6);

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    await _tts.awaitSpeakCompletion(true);
    // 웹은 iOS Safari에서도 defaultTargetPlatform이 iOS라 따로 거른다.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // 음악을 틀어놓고 운동해도 콜이 들리도록: 음악과 섞되 콜 동안 음악 볼륨을 낮춘다.
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }
    await _tts.setLanguage('ko-KR');
    await _tts.setPitch(1.0);
  }

  /// [rate]는 모바일 기준 (0.5 = 보통). 웹 음성은 1.0이 보통이라 두 배로 바꾼다.
  Future<void> setRate(double rate) async {
    if (kIsWeb) {
      // 브라우저는 음성 목록을 늦게 불러와서, 시작할 때 고른 한국어 음성이 비어 있을 수 있다.
      await _tts.setLanguage('ko-KR');
      return _tts.setSpeechRate(rate * 2);
    }
    await _tts.setSpeechRate(rate);
  }

  /// 웹(iOS Safari)에서 첫 음성을 열어둔다. 버튼 탭 핸들러 안에서 바로 불러야 한다.
  void unlock() {
    if (kIsWeb) web_speech.unlockSpeech();
  }

  Future<void> say(String text) {
    final generation = _generation;
    final next = _queue.then((_) async {
      if (generation != _generation) return;
      try {
        await Future.any<void>([
          _tts.speak(text).then((_) {}),
          _cut.future,
        ]).timeout(_maxUtterance);
      } catch (_) {}
    });
    _queue = next;
    return next;
  }

  Future<void> interrupt() async {
    _generation++;
    if (!_cut.isCompleted) _cut.complete();
    _cut = Completer<void>();
    await _tts.stop();
  }
}
