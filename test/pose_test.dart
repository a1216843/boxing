import 'dart:math' as math;

import 'package:boxing_coach/models/moves.dart';
import 'package:boxing_coach/pose/mocap.dart';
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
        expect(len(J.leadHip, J.leadKnee), closeTo(0.43, 0.005), reason: m.id);
        expect(len(J.rearKnee, J.rearFoot), closeTo(0.40, 0.005), reason: m.id);
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
    for (final m in [Moves.leadHook, Moves.rearHook, Moves.leadBody]) {
      final glove = motionGuides(m).firstWhere((g) => g.kind == GuideKind.glove).points;
      final a = glove.first, b = glove.last;
      final chord = b - a;
      // 시작-끝 직선에서 가장 멀리 벗어난 거리.
      final bulge = glove
          .map((p) => ((p - a) - chord * ((p - a).dot(chord) / chord.dot(chord))).length)
          .reduce((x, y) => x > y ? x : y);
      // 실제 선수(BoxingVI) 훅 궤적 휨(벗어난 폭 / 직선 거리)은 중앙값 0.10~0.16. 모션캡처 클립은 0.09 안팎.
      expect(bulge / chord.length, greaterThan(0.06), reason: m.id);
    }
  });

  test('훅: 팔꿈치를 들고 팔을 굽힌 채 바깥에서 원호를 그려 들어간다 (주먹을 내밀고 팔꿈치만 돌리지 않는다)', () {
    for (final m in [Moves.leadHook, Moves.rearHook, Moves.leadBody, Moves.jumpHook, Moves.checkHook]) {
      final tl = PoseTimeline([m]);
      final lead = m.leadHand!;
      final (sh, el, ha) =
          lead ? (J.leadShoulder, J.leadElbow, J.leadHand) : (J.rearShoulder, J.rearElbow, J.rearHand);
      final impact = animSeconds(m) * moveAnim(m).impact;
      final path = [for (var i = 0; i <= 40; i++) tl.at(impact * i / 40)];
      final a = path.first[ha], b = path.last[ha], chord = b - a;
      final bulge = path
          .map((s) => ((s[ha] - a) - chord * ((s[ha] - a).dot(chord) / chord.dot(chord))).length)
          .reduce((x, y) => x > y ? x : y);
      expect(bulge, greaterThan(0.1), reason: '${m.id} 원호 폭');
      // 가는 길 후반: 팔은 굽힌 채(잽은 0.53까지 뻗는다), 팔꿈치는 주먹 높이 언저리.
      for (final s in path.skip(20)) {
        expect((s[ha] - s[sh]).length, lessThan(0.42), reason: '${m.id} 팔 굽힘');
      }
      if (m.id != 'leadBody') {
        expect((path.last[el].y - path.last[ha].y).abs(), lessThan(0.08), reason: '${m.id} 팔꿈치 높이');
      }
    }
  });

  test('점프 훅: 두 발이 함께 떠서 골반이 올라갔다가 착지하며 맞힌다', () {
    final tl = PoseTimeline([Moves.jumpHook]);
    final impact = animSeconds(Moves.jumpHook) * moveAnim(Moves.jumpHook).impact;
    final guardY = guardPose.build()[J.pelvis].y;
    var air = 0.0, rise = 0.0;
    for (var i = 0; i <= 60; i++) {
      final s = tl.at(impact * i / 60);
      air = math.max(air, math.min(s[J.leadToe].y, s[J.rearToe].y));
      rise = math.max(rise, s[J.pelvis].y - guardY);
    }
    expect(air, greaterThan(0.1));
    expect(rise, greaterThan(0.05));
    final land = tl.at(impact);
    expect(math.max(land[J.leadToe].y, land[J.rearToe].y), lessThan(0.03));
  });

  test('칠 때는 몸이 먼저, 거둘 때는 팔이 먼저 움직인다', () {
    final anim = moveAnim(Moves.cross);
    final keys = [(0.0, guardPose), ...anim.keys];
    final peak = strikePose(Moves.cross);
    // 가드→임팩트 진행도 (0~1).
    double body(Pose p) => (p.hipYaw - guardPose.hipYaw) / (peak.hipYaw - guardPose.hipYaw);
    double arm(Pose p) => (p.rear.hand - guardPose.rear.hand).length / (peak.rear.hand - guardPose.rear.hand).length;
    final going = samplePoses(keys, anim.impact * 0.3);
    expect(body(going), greaterThan(arm(going) + 0.05));
    final last = anim.keys[anim.keys.length - 2].$1;
    final back = samplePoses(keys, last + (1 - last) * 0.3);
    expect(1 - arm(back), greaterThan(1 - body(back) + 0.05));
  });

  test('슬립은 머리가 앞뒤가 아니라 옆으로 빠진다', () {
    final g = guardPose.build();
    for (final m in [Moves.slipLead, Moves.slipRear]) {
      final d = strikePose(m).build()[J.head] - g[J.head];
      // 코치 시범 실측: 옆 0.66~0.72, 앞뒤 −0.15~0 (몸통 길이 0.52 단위).
      expect(d.x.abs(), greaterThan(0.28), reason: m.id);
      expect(d.x.abs(), greaterThan(d.z.abs() * 4), reason: m.id);
    }
  });

  test('골반 회전 링은 회전이 큰 펀치에만', () {
    bool hasHip(Move m) => motionGuides(m).any((g) => g.kind == GuideKind.hip);
    expect(hasHip(Moves.leadHook), isTrue);
    expect(hasHip(Moves.cross), isTrue);
    expect(hasHip(Moves.slipLead), isFalse);
  });

  test('실제 사람의 펀치 곡선: 몸이 주먹보다 먼저 움직인다', () {
    for (final m in [Moves.jab, Moves.cross, Moves.leadHook]) {
      final p = motionProfile(m)!;
      // 출발→임팩트 중간에 어깨 회전은 주먹보다 더 진행돼 있다 (CMU 모션캡처 중앙값).
      expect(p.shoulderAt(true, 0.5), greaterThan(p.handAt(true, 0.5)), reason: m.id);
      expect(p.handAt(true, 0), closeTo(0, 1e-9));
      expect(p.handAt(true, 1), closeTo(1, 1e-9));
      expect(p.handAt(false, 1), closeTo(0, 1e-9));
    }
  });

  test('곡선으로 재생해도 출발·임팩트·끝 자세는 정석 키 자세 그대로', () {
    for (final m in [Moves.jab, Moves.cross, Moves.leadHook, Moves.rearUpper]) {
      final anim = moveAnim(m);
      final keys = [(0.0, guardPose), ...anim.keys];
      final move = WarpedMove(keys, anim.impact, motionProfile(m)!, leadArm: m.leadHand!);
      // [flat]: 주먹·발·골반의 수평 위치만 비교한다 (임팩트 순간엔 실제 곡선대로 골반이 조금 내려가 무릎이 더 굽는다).
      void same(Pose a, Pose b, String at, {bool flat = false}) {
        final x = a.build(), y = b.build();
        final joints = flat ? [J.pelvis, J.leadHand, J.rearHand, J.leadToe, J.rearToe] : J.values;
        for (final j in joints) {
          final d = x[j] - y[j];
          expect((flat ? V3(d.x, 0, d.z) : d).length, lessThan(0.01), reason: '${m.id} $at $j');
        }
      }

      same(move.at(0), guardPose, 'start');
      same(move.at(anim.impact), samplePoses(keys, anim.impact), 'impact', flat: true);
      same(move.at(1), keys.last.$2, 'end');
    }
  });

  test('콤보에서 스텝 거리가 누적된다', () {
    final tl = PoseTimeline([Moves.backStep, Moves.backStep, Moves.slipLead]);
    expect(tl.baseOf(1), closeTo(-0.28, 1e-9));
    expect(tl.baseOf(2), closeTo(-0.56, 1e-9));
    final mid = tl.at(animSeconds(Moves.backStep) * 2);
    expect(mid[J.leadToe].z - guardPose.build()[J.leadToe].z, closeTo(-0.56, 0.01));
  });

  test('콤보가 끝나면 걸음 없이 출발점에 돌아온다', () {
    for (final moves in [
      [Moves.jabBody, Moves.rearBody, Moves.leadHook],
      [Moves.jab, Moves.backStep, Moves.backStep],
      [Moves.weaveLead, Moves.jab, Moves.weaveRear, Moves.weaveRear],
    ]) {
      final tl = PoseTimeline(moves);
      final guard = guardPose.build();
      final end = tl.at(tl.duration);
      for (final j in J.values) {
        expect((end[j] - guard[j]).length, lessThan(1e-9), reason: '$moves $j');
      }
      // 돌아오는 동안 발을 들지 않는다.
      for (var i = 0; i <= 200; i++) {
        final s = tl.at(tl.actionEnd + 0.4 + (tl.duration - tl.actionEnd - 0.4) * i / 200);
        expect(s[J.leadToe].y < 0.005 && s[J.rearToe].y < 0.005, isTrue, reason: '$moves $i');
      }
    }
  });

  test('위빙은 빠지는 쪽으로 발을 옮겨 각도를 잡는다', () {
    final guard = guardPose.build();
    for (final (m, side) in [(Moves.weaveLead, -1.0), (Moves.weaveRear, 1.0)]) {
      final anim = moveAnim(m);
      final end = anim.keys.last.$2.build();
      for (final toe in [J.leadToe, J.rearToe]) {
        expect((end[toe].x - guard[toe].x) * side, greaterThan(0.08), reason: '${m.id} $toe');
        expect(end[toe].z - guard[toe].z, greaterThan(0), reason: '${m.id} $toe');
      }
      // 빠지는 쪽 발이 먼저 나간다.
      final first = anim.keys.first.$2.build();
      final (moved, stays) = side < 0 ? (J.leadToe, J.rearToe) : (J.rearToe, J.leadToe);
      expect((first[moved].x - guard[moved].x).abs(), greaterThan(0.08), reason: m.id);
      expect((first[stays].x - guard[stays].x).abs(), lessThan(1e-9), reason: m.id);
      expect(anim.side * side, greaterThan(0));
    }
  });

  test('더킹·위빙한 자세에서 일어서지 않고 그대로 다음 펀치로 이어진다', () {
    final guardY = guardPose.build()[J.pelvis].y;
    for (final d in [Moves.duckLead, Moves.duckRear, Moves.weaveLead, Moves.weaveRear]) {
      final tl = PoseTimeline([d, Moves.leadHook]);
      final start = animSeconds(d), impact = start + animSeconds(Moves.leadHook) * moveAnim(Moves.leadHook).impact;
      final low = guardY - tl.at(start)[J.pelvis].y;
      // 출발해서 임팩트까지 내내 낮춘 높이의 대부분을 유지한다 (가드 높이로 돌아갔다가 치지 않는다).
      for (var i = 0; i <= 20; i++) {
        final y = tl.at(start + (impact - start) * i / 20)[J.pelvis].y;
        expect(guardY - y, greaterThan(low * 0.6), reason: '${d.id} $i');
      }
    }
    // 가드에서 그냥 친 훅은 낮추지 않는다 (임팩트 때 몸이 살짝 가라앉는 실제 곡선 정도만).
    final alone = PoseTimeline([Moves.leadHook]);
    final hit = alone.at(animSeconds(Moves.leadHook) * moveAnim(Moves.leadHook).impact);
    expect(guardY - hit[J.pelvis].y, lessThan(0.06));
  });

  test('위빙은 바닥에서 멈추지 않고 U자로 지나간다', () {
    for (final m in [Moves.weaveLead, Moves.weaveRear]) {
      final anim = moveAnim(m);
      final keys = [(0.0, guardPose), ...anim.keys];
      V3 head(double f) => samplePoses(keys, f).build()[J.head];
      double speed(double f) => (head(f + 0.005) - head(f - 0.005)).length / 0.01;
      final top = [for (var i = 1; i < 84; i++) speed(i / 100)].reduce((a, b) => a > b ? a : b);
      // 키마다 멈추면 바닥에서 속도가 0이 되어 ㄷ자로 꺾인다. U자 바닥에선 위아래 속도만 0이고 옆으로는 계속 간다.
      expect(speed(anim.keys.first.$1), greaterThan(top * 0.3), reason: m.id);
    }
  });

  test('체크 훅·점프 훅·백스텝이 든 콤보도 끊기지 않고, 끝나면 걸음 없이 출발점에 돌아온다', () {
    final guard = guardPose.build();
    for (final moves in [
      [Moves.cross, Moves.checkHook, Moves.cross],
      [Moves.duckLead, Moves.jumpHook, Moves.overhand],
      [Moves.jab, Moves.jumpHook, Moves.cross, Moves.leadHook, Moves.backStep],
      [Moves.backStep, Moves.jab, Moves.cross],
    ]) {
      final tl = PoseTimeline(moves);
      final end = tl.at(tl.duration);
      for (final j in J.values) {
        expect((end[j] - guard[j]).length, lessThan(1e-6), reason: '$moves $j');
      }
      // 몸통·다리는 한 프레임(1/240초)에 2.5cm 넘게 움직이지 않는다 (팔은 훅 팔꿈치가 넘어가는 순간이 있어 뺀다).
      const dt = 1 / 240;
      const body = [J.head, J.neck, J.pelvis, J.leadHip, J.rearHip, J.leadKnee, J.rearKnee, J.leadToe, J.rearToe];
      var prev = tl.at(0);
      for (var t = dt; t <= tl.duration; t += dt) {
        final s = tl.at(t);
        for (final j in body) {
          expect((s[j] - prev[j]).length, lessThan(0.025), reason: '$moves $j @$t');
        }
        prev = s;
      }
      for (var i = 0; i <= 100; i++) {
        final s = tl.at(tl.actionEnd + 0.4 + (tl.duration - tl.actionEnd - 0.4) * i / 100);
        expect(s[J.leadToe].y < 0.005 && s[J.rearToe].y < 0.005, isTrue, reason: '$moves $i');
      }
    }
  });

  test('백스텝: 두 발이 함께 떠서 한 번에 뒤로 뛴다 (한 발씩 걷지 않는다)', () {
    final anim = moveAnim(Moves.backStep);
    final keys = [(0.0, guardPose), ...anim.keys];
    final g = guardPose.build();
    var air = 0.0;
    for (var i = 0; i <= 100; i++) {
      final s = samplePoses(keys, i / 100).build();
      air = math.max(air, math.min(s[J.leadToe].y, s[J.rearToe].y));
      // 두 발이 같이 움직인다: 어느 순간에도 두 발의 뒤로 간 거리 차이가 작다.
      final lead = g[J.leadToe].z - s[J.leadToe].z, rear = g[J.rearToe].z - s[J.rearToe].z;
      expect((lead - rear).abs(), lessThan(0.05), reason: '$i');
    }
    expect(air, greaterThan(0.03));
  });

  test('점프 훅은 두 발이 함께 떠서 앞으로 들어간다', () {
    final anim = moveAnim(Moves.jumpHook);
    final keys = [(0.0, guardPose), ...anim.keys];
    final air = samplePoses(keys, anim.impact * 0.5).build();
    expect(air[J.leadToe].y, greaterThan(0.03));
    expect(air[J.rearToe].y, greaterThan(0.03));
    expect(anim.advance, greaterThan(0.2));
  });

  test('타임라인 단계', () {
    final tl = PoseTimeline([Moves.jab, Moves.cross, Moves.slipRear]);
    expect(tl.stepAt(0.1), 0);
    expect(tl.stepAt(animSeconds(Moves.jab) + 0.01), 1);
    expect(tl.stepAt(animSeconds(Moves.jab) + animSeconds(Moves.cross) + 0.01), 2);
    expect(tl.stepAt(tl.duration), -1);
    // 끝나면 출발점의 가드로 돌아온다.
    final end = tl.at(tl.duration);
    final guard = guardPose.build();
    expect((end[J.leadHand] - guard[J.leadHand]).length, lessThan(1e-9));
  });
}
