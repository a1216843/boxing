import 'dart:math';

import '../models/moves.dart';
import '../models/settings.dart';
import 'combo_generator.dart';

/// 콤보 하나를 어떤 박자로 끊어 부를지.
class CallPlan {
  const CallPlan(this.combo, this.holds);

  final Combo combo;

  /// holds[i]: i번째 동작 콜 앞에서 일부러 끄는 시간(초). 0이면 앞 동작에 붙여 부른다.
  final List<double> holds;

  bool get broken => holds.any((h) => h > 0);

  /// 끊어 부를 덩어리들. (앞에서 끄는 시간, 동작들)
  List<(double, List<Move>)> get chunks {
    final out = <(double, List<Move>)>[];
    for (var i = 0; i < combo.moves.length; i++) {
      if (i == 0 || holds[i] > 0) out.add((holds[i], <Move>[]));
      out.last.$2.add(combo.moves[i]);
    }
    return out;
  }

  /// 덩어리별로 읽을 콜. 방향 생략은 콤보 전체 흐름을 보고 정한다.
  List<String> chunkCalls(Stance stance, CallStyle style, {bool direction = true}) {
    final tokens = combo.callTokens(stance, style, direction: direction);
    final out = <List<String>>[];
    for (var i = 0; i < tokens.length; i++) {
      if (i == 0 || holds[i] > 0) out.add([]);
      out.last.add(tokens[i]);
    }
    return [for (final t in out) joinCalls(t)];
  }

  /// 화면용 콜. 끊는 자리는 "…"로 표시한다 ("원투 … 훅").
  String call(Stance stance, CallStyle style, {bool direction = true}) =>
      chunkCalls(stance, style, direction: direction).join(' … ');
}

/// 콜 타이밍을 정한다.
///
/// 콜은 라운드 내내 일정한 박자([LevelProfile.beat]) 위에 떨어져서 몸이 리듬을 탄다.
/// 그 위에서 가끔 반 박자 당기거나 끌고, 콤보 중간을 끊어 늦게 부르고,
/// 쉴 틈 없이 몰아치거나 길게 끌어서 다음 콜을 예측할 수 없게 만든다.
/// 시각은 모두 라운드 시작부터 잰 박자 시계(초) 기준이다.
class Pacer {
  Pacer(this.profile, {Random? random}) : _rnd = random ?? Random();

  final LevelProfile profile;
  final Random _rnd;
  int _burst = 0;

  double get beat => profile.beat;

  /// 콤보를 한 번에 부를지, 중간을 끊어 반 박자~한 박자 늦게 이어 부를지.
  CallPlan plan(Combo combo) {
    final n = combo.moves.length;
    final holds = List<double>.filled(n, 0);
    if (n >= 2 && _rnd.nextDouble() < profile.breakChance) {
      // 마지막 한 방을 늦추는 경우가 가장 흔하다.
      final at = n == 2 || _rnd.nextDouble() < 0.6 ? n - 1 : 1 + _rnd.nextInt(n - 1);
      holds[at] = beat * (_rnd.nextDouble() < 0.6 ? 0.5 : 1.0);
    }
    return CallPlan(combo, holds);
  }

  /// 끊어 부를 때: [prev] 덩어리를 다 읽은 [now]에서 다음 덩어리를 부를 시각.
  /// 원래는 앞 동작을 치는 도중에 이어 불렀을 자리에서 [hold]만큼 늦춘다.
  double chunkAt(double now, List<Move> prev, double hold) =>
      _snap(now + _exec(prev) * 0.5, beat / 2) + hold;

  /// 콜을 다 읽은 [now]에서 다음 콜을 시작할 시각.
  /// [rush]는 라운드 막판: 간격이 짧아지고 길게 끄는 휴지는 없다.
  double nextCallAt(double now, CallPlan plan, {bool rush = false}) {
    final exec = _exec(plan.chunks.last.$2);
    var t = _snap(now + exec + _gapBeats(rush) * beat, beat);
    final offbeat = rush ? profile.offbeatChance * 1.5 : profile.offbeatChance;
    if (_rnd.nextDouble() < offbeat) {
      t += _rnd.nextBool() ? -beat / 2 : beat / 2;
    }
    // 동작을 거의 다 칠 시간은 준다.
    while (t < now + exec * 0.8) {
      t += beat;
    }
    return t;
  }

  double _gapBeats(bool rush) {
    if (_burst > 0) {
      _burst--;
      return 0;
    }
    final quick = rush ? profile.quickChance * 2 : profile.quickChance;
    final r = _rnd.nextDouble();
    if (r < quick) {
      _burst = _rnd.nextInt(3);
      return 0;
    }
    final base = ((rush ? profile.baseGap * 0.55 : profile.baseGap) / beat).roundToDouble();
    if (!rush && r < quick + profile.longChance) return base + 2 + _rnd.nextInt(3);
    final j = _rnd.nextDouble();
    final jitter = j < 0.2 ? -1 : (j > 0.8 ? 1 : 0);
    return max(1, base + jitter).toDouble();
  }

  double _snap(double t, double unit) => (t / unit).round() * unit;

  double _exec(List<Move> moves) => Combo(moves).duration * profile.tempo;
}
