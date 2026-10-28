import 'package:boxing_coach/models/moves.dart';
import 'package:boxing_coach/pose/poses.dart';
import 'package:boxing_coach/pose/skeleton.dart';
import 'package:boxing_coach/pose/timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('보간 중에도 팔·다리 길이가 유지된다 (IK)', () {
    for (final m in Moves.all) {
      final tl = PoseTimeline([m]);
      for (var i = 0; i <= 20; i++) {
        final s = tl.at(tl.duration * i / 20);
        double len(J a, J b) => (s[a] - s[b]).length;
        expect(len(J.leadShoulder, J.leadElbow), closeTo(0.3, 0.005), reason: m.id);
        expect(len(J.leadElbow, J.leadHand), closeTo(0.3, 0.005), reason: m.id);
        expect(len(J.rearShoulder, J.rearElbow), closeTo(0.3, 0.005), reason: m.id);
        expect(len(J.rearElbow, J.rearHand), closeTo(0.3, 0.005), reason: m.id);
        expect(len(J.leadHip, J.leadKnee), closeTo(0.48, 0.005), reason: m.id);
        expect(len(J.rearKnee, J.rearFoot), closeTo(0.48, 0.005), reason: m.id);
      }
    }
  });

  test('펀치 손만 강조된다', () {
    expect(strikePose(Moves.jab).build().leadGlow, 1);
    expect(strikePose(Moves.jab).build().rearGlow, 0);
    expect(strikePose(Moves.rearUpper).build().rearGlow, 1);
    expect(strikePose(Moves.slipLead).build().leadGlow, 0);
  });

  test('훅 주먹은 직선이 아니라 원호를 그린다', () {
    final glove = motionGuides(Moves.leadHook).firstWhere((g) => g.kind == GuideKind.glove).points;
    final a = glove.first, b = glove.last;
    final chord = b - a;
    // 시작-끝 직선에서 가장 멀리 벗어난 거리.
    final bulge = glove
        .map((p) => ((p - a) - chord * ((p - a).dot(chord) / chord.dot(chord))).length)
        .reduce((x, y) => x > y ? x : y);
    expect(bulge, greaterThan(0.08));
  });

  test('골반 회전 링은 회전이 큰 펀치에만', () {
    bool hasHip(Move m) => motionGuides(m).any((g) => g.kind == GuideKind.hip);
    expect(hasHip(Moves.leadHook), isTrue);
    expect(hasHip(Moves.cross), isTrue);
    expect(hasHip(Moves.jab), isFalse);
    expect(hasHip(Moves.slipLead), isFalse);
  });

  test('잽은 앞발을 내딛고 뒷발을 끌어와 스탠스를 회복한다', () {
    final tl = PoseTimeline([Moves.jab]);
    final start = tl.at(0), end = tl.at(tl.duration);
    final impact = tl.at(animSeconds(Moves.jab) * moveAnim(Moves.jab).impact);
    // 임팩트 때 앞발은 이미 나가 있고 뒷발은 아직 그 자리.
    expect(impact[J.leadToe].z - start[J.leadToe].z, closeTo(0.07, 0.01));
    expect(impact[J.rearToe].z - start[J.rearToe].z, closeTo(0, 0.01));
    // 끝나면 두 발 모두 앞으로, 스탠스 간격은 그대로.
    expect(end[J.rearToe].z - start[J.rearToe].z, closeTo(0.07, 0.01));
    expect(end[J.leadToe].z - end[J.rearToe].z, closeTo(start[J.leadToe].z - start[J.rearToe].z, 0.01));
    // 옮기는 도중에는 발이 바닥에서 뜬다.
    final mid = tl.at(animSeconds(Moves.jab) * 0.22);
    expect(mid[J.leadToe].y, greaterThan(0.005));
  });

  test('콤보에서 스텝 거리가 누적된다', () {
    final tl = PoseTimeline([Moves.jab, Moves.jab, Moves.backStep]);
    expect(tl.baseOf(1), closeTo(0.07, 1e-9));
    expect(tl.baseOf(2), closeTo(0.14, 1e-9));
    final end = tl.at(tl.duration);
    expect(end[J.leadToe].z - guardPose.build()[J.leadToe].z, closeTo(0.14 - 0.28, 0.01));
  });

  test('타임라인 단계', () {
    final tl = PoseTimeline([Moves.jab, Moves.cross, Moves.slipRear]);
    expect(tl.stepAt(0.1), 0);
    expect(tl.stepAt(animSeconds(Moves.jab) + 0.01), 1);
    expect(tl.stepAt(animSeconds(Moves.jab) + animSeconds(Moves.cross) + 0.01), 2);
    expect(tl.stepAt(tl.duration), -1);
    // 끝나면 (앞으로 나간 자리에서) 가드로 돌아온다.
    final end = tl.at(tl.duration);
    final guard = guardPose.translated(0.07 + 0.03).build();
    expect((end[J.leadHand] - guard[J.leadHand]).length, lessThan(1e-9));
  });
}
