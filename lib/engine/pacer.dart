import 'dart:math';

import '../models/settings.dart';
import 'combo_generator.dart';

/// 콜 타이밍을 정한다.
///
/// 같은 콤보를 [TrainingSettings.comboRepeats]번 연달아 부르고, 한 세트가 끝나면 랜덤한 시간 동안 콜이 없다.
/// 반복 콜은 동작을 마친 다음 박자에 바로 떨어져 리듬이 일정하고,
/// 세트 사이 휴지는 길이가 매번 달라 그동안 움직이다가 갑자기 나오는 콜에 반응하게 만든다.
/// 콜은 일정한 박자([LevelProfile.beat]) 위에 떨어지고, 휴지 뒤의 콜은 가끔 반 박자 당기거나 끈다.
/// 시각은 모두 라운드 시작부터 잰 박자 시계(초) 기준이다.
class Pacer {
  Pacer(this.profile, {Random? random}) : _rnd = random ?? Random();

  final LevelProfile profile;
  final Random _rnd;

  double get beat => profile.beat;

  double _exec(Combo combo) => combo.duration * profile.tempo;

  /// 콜을 다 읽은 [now]에서 같은 콤보를 다시 부를 시각. 동작을 마친 뒤 한 박자쯤.
  double repeatAt(double now, Combo combo) {
    final exec = _exec(combo);
    var t = _snap(now + exec + beat, beat);
    while (t < now + exec) {
      t += beat;
    }
    return t;
  }

  /// 콤보 세트를 마친 [now]에서 다음 콤보를 부를 시각. 그 사이는 주먹 없이 움직이는 시간.
  /// [rush]는 라운드 막판: 휴지가 짧아진다.
  double nextCallAt(double now, Combo combo, {bool rush = false}) {
    final exec = _exec(combo);
    var t = _snap(now + exec + _gap(rush), beat);
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

  /// 휴지(초). 대개 [LevelProfile.gapMin]~[LevelProfile.gapMax] 사이에서 고르게 뽑고, 가끔 쉴 틈 없이 바로 부른다.
  double _gap(bool rush) {
    final quick = rush ? profile.quickChance * 2 : profile.quickChance;
    if (_rnd.nextDouble() < quick) return beat;
    final g = profile.gapMin + _rnd.nextDouble() * (profile.gapMax - profile.gapMin);
    return max(beat, rush ? g * 0.5 : g);
  }

  double _snap(double t, double unit) => (t / unit).round() * unit;
}
