import 'dart:math';

import 'package:boxing_coach/engine/combo_generator.dart';
import 'package:boxing_coach/engine/pacer.dart';
import 'package:boxing_coach/models/moves.dart';
import 'package:boxing_coach/models/settings.dart';
import 'package:boxing_coach/pose/poses.dart';
import 'package:boxing_coach/pose/timeline.dart';
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
      final plan = pacer.plan(oneTwoHook);
      final next = pacer.nextCallAt(now, plan);
      expect(onGrid(next, beat / 2), isTrue);
      onGrid(next, beat) ? onBeat++ : offBeat++;
      // 동작을 칠 시간은 준다.
      final exec = Combo(plan.chunks.last.$2).duration * profile.tempo;
      expect(next, greaterThanOrEqualTo(now + exec * 0.8));
      now = next + 0.83;
    }
    final ratio = offBeat / (onBeat + offBeat);
    expect(ratio, greaterThan(profile.offbeatChance * 0.5));
    expect(ratio, lessThan(profile.offbeatChance * 1.5));
  });

  test('콤보를 끊어 부르면 반 박자나 한 박자 늦게 이어 부른다', () {
    final pacer = Pacer(profile, random: Random(2));
    var broken = 0;
    for (var i = 0; i < 1000; i++) {
      final plan = pacer.plan(oneTwoHook);
      expect(plan.holds.first, 0);
      if (!plan.broken) {
        expect(plan.chunks, hasLength(1));
        continue;
      }
      broken++;
      expect(plan.chunks, hasLength(2));
      final hold = plan.holds.firstWhere((h) => h > 0);
      expect([profile.beat / 2, profile.beat], contains(hold));
    }
    expect(broken / 1000, closeTo(profile.breakChance, 0.05));
    expect(Pacer(profile).plan(Combo([Moves.jab])).broken, isFalse);
  });

  test('끊은 콜 문구와 인형 동작', () {
    final plan = CallPlan(oneTwoHook, [0, 0, 0.3]);
    expect(plan.call(Stance.orthodox, CallStyle.number), '원투 … 쓰리');

    final plain = PoseTimeline(oneTwoHook.moves);
    final held = PoseTimeline(oneTwoHook.moves, holds: plan.holds);
    expect(held.duration, closeTo(plain.duration + 0.3, 1e-9));
    // 멈춘 동안은 크로스를 친 뒤 자세 그대로, 훅은 그 뒤에 시작한다.
    final crossEnd = animSeconds(Moves.jab) + animSeconds(Moves.cross);
    expect(held.stepAt(crossEnd + 0.15), 1);
    expect(held.poseAt(crossEnd + 0.05).yaw, closeTo(held.poseAt(crossEnd + 0.25).yaw, 1e-9));
    expect(held.stepAt(crossEnd + 0.31), 2);
  });
}
