import 'dart:math';

import 'package:boxing_coach/engine/combo_generator.dart';
import 'package:boxing_coach/engine/pacer.dart';
import 'package:boxing_coach/models/moves.dart';
import 'package:boxing_coach/models/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final profile = Level.intermediate.profile;
  final oneTwoHook = Combo([Moves.jab, Moves.cross, Moves.leadHook]);

  bool onGrid(double t, double unit) => ((t / unit) - (t / unit).round()).abs() < 1e-6;

  test('콜은 박자 위에 떨어지고, 가끔 반 박자 당기거나 끈다', () {
    final pacer = Pacer(profile, random: Random(1));
    final beat = profile.beat;
    var onBeat = 0, offBeat = 0;
    var now = 0.37; // 콜을 다 읽은 시각은 박자와 상관없다
    for (var i = 0; i < 2000; i++) {
      final next = pacer.nextCallAt(now, oneTwoHook);
      expect(onGrid(next, beat / 2), isTrue);
      onGrid(next, beat) ? onBeat++ : offBeat++;
      // 동작을 칠 시간은 준다.
      final exec = oneTwoHook.duration * profile.tempo;
      expect(next, greaterThanOrEqualTo(now + exec * 0.8));
      now = next + 0.83;
    }
    final ratio = offBeat / (onBeat + offBeat);
    expect(ratio, greaterThan(profile.offbeatChance * 0.5));
    expect(ratio, lessThan(profile.offbeatChance * 1.5));
  });
}
