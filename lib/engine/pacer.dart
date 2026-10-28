import 'dart:math';

import '../models/settings.dart';
import 'combo_generator.dart';

/// 콜 타이밍을 정한다.
///
/// 콜은 라운드 내내 일정한 박자([LevelProfile.beat]) 위에 떨어져서 몸이 리듬을 탄다.
/// 그 위에서 가끔 반 박자 당기거나 끌고, 쉴 틈 없이 몰아치거나 길게 끌어서 다음 콜을 예측할 수 없게 만든다.
/// 시각은 모두 라운드 시작부터 잰 박자 시계(초) 기준이다.
class Pacer {
  Pacer(this.profile, {Random? random}) : _rnd = random ?? Random();

  final LevelProfile profile;
  final Random _rnd;
  int _burst = 0;

  double get beat => profile.beat;

  /// 콜을 다 읽은 [now]에서 다음 콜을 시작할 시각.
  /// [rush]는 라운드 막판: 간격이 짧아지고 길게 끄는 휴지는 없다.
  double nextCallAt(double now, Combo combo, {bool rush = false}) {
    final exec = combo.duration * profile.tempo;
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
}
