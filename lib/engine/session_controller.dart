import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/settings.dart';
import 'combo_generator.dart';
import 'pacer.dart';
import 'speaker.dart';

enum SessionPhase { ready, work, rest, finished }

/// 라운드 타이머와 콤보 콜 루프.
class SessionController extends ChangeNotifier {
  SessionController(this.settings, this._speaker)
      : _generator = ComboGenerator(settings),
        _pacer = Pacer(settings.level.profile);

  final TrainingSettings settings;
  final Speaker _speaker;
  final ComboGenerator _generator;
  final Pacer _pacer;

  SessionPhase phase = SessionPhase.ready;
  int round = 1;
  Duration remaining = Duration.zero;
  String? display;

  /// 화면에 띄운 콤보와 끊어 부르는 박자. 카운트다운·휴식 문구일 때는 null.
  CallPlan? plan;

  Combo? get combo => plan?.combo;

  /// 콜을 다 읽은 순간마다 올린다. 자세 애니메이션 재생 신호.
  int actionId = 0;

  /// 같은 콤보가 연달아 나와도 화면 애니메이션이 다시 돌도록 매번 올린다.
  int displayId = 0;
  bool paused = false;

  static const _tick = Duration(milliseconds: 100);

  /// 남은 시간이 이보다 적으면 새 콜을 하지 않는다.
  static const _minCallWindow = Duration(milliseconds: 1500);
  static const _rushWindow = Duration(seconds: 10);

  int _token = 0;
  bool _disposed = false;
  bool _warned = false;
  Timer? _clock;
  final Stopwatch _watch = Stopwatch();

  /// 라운드 시작부터의 박자 시계. 일시정지 동안 멈춘다.
  final Stopwatch _beatClock = Stopwatch();

  double get _beatNow => _beatClock.elapsedMicroseconds / 1e6;

  bool get _timed => phase == SessionPhase.work || phase == SessionPhase.rest;

  void start() {
    final token = ++_token;
    _clock?.cancel();
    _watch
      ..reset()
      ..start();
    _clock = Timer.periodic(_tick, (_) => _onTick());
    _run(token);
  }

  void togglePause() {
    paused = !paused;
    if (paused) {
      _beatClock.stop();
      _speaker.interrupt();
    } else if (phase == SessionPhase.work) {
      _beatClock.start();
    }
    notifyListeners();
  }

  void stop() {
    _token++;
    _clock?.cancel();
    _speaker.interrupt();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _disposed = true;
    super.dispose();
  }

  bool _alive(int token) => token == _token;

  void _enter(SessionPhase p, Duration length) {
    phase = p;
    remaining = length;
    _warned = false;
    notifyListeners();
  }

  void _show(String text, [CallPlan? shown]) {
    display = text;
    plan = shown;
    displayId++;
    notifyListeners();
  }

  void _onTick() {
    final dt = _watch.elapsed;
    _watch
      ..reset()
      ..start();
    if (paused || !_timed || remaining <= Duration.zero) return;
    remaining -= dt;
    if (remaining < Duration.zero) remaining = Duration.zero;
    if (!_warned && remaining <= _rushWindow) {
      _warned = true;
      _speaker.say(phase == SessionPhase.work ? '10초' : '10초 후 시작');
    }
    notifyListeners();
  }

  Future<void> _run(int token) async {
    await _speaker.setRate(settings.speechRate);
    for (var r = 1; r <= settings.rounds; r++) {
      if (!_alive(token)) return;
      round = r;
      _enter(SessionPhase.ready, Duration.zero);
      final last = r == settings.rounds && r > 1;
      await _speaker.say(last ? '마지막 라운드' : '라운드 $r');
      for (final n in ['3', '2', '1']) {
        if (!_alive(token)) return;
        _show(n);
        _speaker.say(n);
        if (!await _sleep(const Duration(milliseconds: 900), token)) return;
      }

      _enter(SessionPhase.work, Duration(seconds: settings.roundSeconds));
      _show('시작');
      _beatClock
        ..reset()
        ..start();
      await _speaker.say('시작');
      if (!await _workLoop(token)) return;
      _beatClock.stop();
      await _speaker.interrupt();
      if (r == settings.rounds) break;

      _enter(SessionPhase.rest, Duration(seconds: settings.restSeconds));
      _show('휴식');
      await _speaker.say('스톱. ${settings.restSeconds}초 휴식');
      if (!await _sleepUntilPhaseEnds(token)) return;
    }
    if (!_alive(token)) return;
    _clock?.cancel();
    _enter(SessionPhase.finished, Duration.zero);
    _show('끝');
    await _speaker.say('스톱. 수고하셨습니다');
  }

  Future<bool> _workLoop(int token) async {
    while (remaining > _minCallWindow) {
      if (!await _waitWhilePaused(token)) return false;
      if (remaining <= _minCallWindow) break;
      final plan = _pacer.plan(_generator.next());
      final chunks = plan.chunks;
      final calls = plan.chunkCalls(settings.stance, settings.callStyle,
          direction: settings.callDirection);
      _show(calls.join(' … '), plan);
      for (var i = 0; i < chunks.length; i++) {
        final (hold, _) = chunks[i];
        if (i > 0) {
          final at = _pacer.chunkAt(_beatNow, chunks[i - 1].$2, hold);
          if (!await _sleepUntilBeat(at, token)) return false;
        }
        await _speaker.say(calls[i]);
        if (!_alive(token)) return false;
      }
      actionId++;
      notifyListeners();
      final rush = remaining <= _rushWindow;
      final next = _pacer.nextCallAt(_beatNow, plan, rush: rush);
      if (!await _sleepUntilBeat(next, token)) return false;
    }
    return _sleepUntilPhaseEnds(token);
  }

  /// 일시정지 동안은 시간이 흐르지 않는다. 라운드 시간이 끝나면 바로 깬다.
  Future<bool> _sleep(Duration d, int token) async {
    var left = d;
    while (left > Duration.zero) {
      if (!_alive(token)) return false;
      if (_timed && remaining <= Duration.zero) break;
      await Future<void>.delayed(_tick);
      if (!paused) left -= _tick;
    }
    return _alive(token);
  }

  /// 박자 시계가 [at]초가 될 때까지. 일시정지 동안은 시계가 멈춰 있다.
  Future<bool> _sleepUntilBeat(double at, int token) async {
    while (_alive(token)) {
      if (_timed && remaining <= Duration.zero) break;
      final left = at - _beatNow;
      if (left <= 0) break;
      // 반 박자 차이가 들리도록 마지막은 남은 만큼만 잔다.
      final ms = (left * 1000).ceil();
      await Future<void>.delayed(
          ms < _tick.inMilliseconds ? Duration(milliseconds: ms) : _tick);
    }
    return _alive(token);
  }

  Future<bool> _sleepUntilPhaseEnds(int token) async {
    while (_alive(token) && remaining > Duration.zero) {
      await Future<void>.delayed(_tick);
    }
    return _alive(token);
  }

  Future<bool> _waitWhilePaused(int token) async {
    while (_alive(token) && paused) {
      await Future<void>.delayed(_tick);
    }
    return _alive(token);
  }
}
