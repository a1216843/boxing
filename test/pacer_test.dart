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

  test('반복 콜은 동작을 마친 뒤 박자 위에 바로 떨어진다', () {
    final pacer = Pacer(profile, random: Random(2));
    final beat = profile.beat;
    final exec = oneTwoHook.duration * profile.tempo;
    for (final now in [0.0, 0.37, 5.11, 12.9]) {
      final t = pacer.repeatAt(now, oneTwoHook);
      expect(onGrid(t, beat), isTrue);
      expect(t, greaterThanOrEqualTo(now + exec));
      expect(t, lessThanOrEqualTo(now + exec + beat * 1.5 + 1e-9));
    }
  });

  test('세트 사이 휴지는 매번 다르고 대개 gapMin~gapMax 범위', () {
    final pacer = Pacer(profile, random: Random(3));
    final exec = oneTwoHook.duration * profile.tempo;
    final gaps = <double>[];
    for (var i = 0; i < 2000; i++) {
      gaps.add(pacer.nextCallAt(0, oneTwoHook) - exec);
    }
    final slack = profile.beat;
    final inRange =
        gaps.where((g) => g >= profile.gapMin - slack && g <= profile.gapMax + slack).length;
    expect(inRange / gaps.length, greaterThan(1 - profile.quickChance * 2));
    expect(gaps.toSet().length, greaterThan(4));
  });
}
