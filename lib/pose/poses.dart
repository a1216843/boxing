import 'dart:math' as math;

import '../models/moves.dart';
import 'skeleton.dart';

/// 팔 상태. *Load는 훅·어퍼를 치기 직전 준비 자세 (궤적을 원호로 만든다).
enum Arm { guard, straight, bodyStraight, hook, hookLoad, uppercut, uppercutLoad, bodyHook, bodyHookLoad }

/// 주먹 목표와 팔꿈치 방향. 몸통 기준 좌표 (x 옆, y 위, z 몸통 정면) → 몸통이 돌면 같이 돈다.
class ArmTarget {
  const ArmTarget(this.hand, this.pole, this.glow);

  final V3 hand;
  final V3 pole;

  /// 펀치 손 강조 (0~1).
  final double glow;

  static ArmTarget lerp(ArmTarget a, ArmTarget b, double t) =>
      ArmTarget(V3.lerp(a.hand, b.hand, t), V3.lerp(a.pole, b.pole, t), a.glow + (b.glow - a.glow) * t);
}

/// 몸통 기준 어깨 위치. [side] 리드 -1, 리어 +1.
V3 _shoulderLocal(double side) => V3(side * 0.19, -0.05, 0);

ArmTarget _arm(Arm arm, double side, double yaw) {
  // 스트레이트는 정면 중심선을 향해 뻗으므로 월드 기준으로 계산한 뒤 몸통 좌표로 되돌린다.
  ArmTarget straight(double height) {
    final shoulder = _shoulderLocal(side).rotY(yaw);
    final hand = shoulder + (V3(0, height, 0.9) - shoulder).normalized * 0.5;
    return ArmTarget(hand.rotY(-yaw), V3(side, -0.6, 0), 1);
  }

  return switch (arm) {
    // 앞손은 광대 앞, 뒷손은 턱 옆. 팔꿈치는 아래로 내려 갈비뼈를 덮는다.
    Arm.guard => side < 0
        ? const ArmTarget(V3(-0.09, 0.08, 0.24), V3(-0.3, -1, -0.4), 0)
        : const ArmTarget(V3(0.1, 0.05, 0.15), V3(0.3, -1, -0.4), 0),
    Arm.straight => straight(0.26),
    Arm.bodyStraight => straight(-0.42),
    // 훅: 팔꿈치를 어깨 높이로 들고, 주먹이 바깥에서 중심선으로 수평 호를 그린다.
    Arm.hookLoad => ArmTarget(V3(side * 0.3, 0.06, 0.22), V3(side, 0.25, -0.3), 0.6),
    Arm.hook => ArmTarget(V3(-side * 0.02, 0.1, 0.38), V3(side, 0.35, -0.2), 1),
    // 어퍼: 주먹을 가슴 높이로 살짝 떨어뜨렸다가 상대 턱 높이로 올려친다.
    Arm.uppercutLoad => ArmTarget(V3(side * 0.12, -0.18, 0.2), V3(side * 0.4, -0.8, -0.5), 0.6),
    Arm.uppercut => ArmTarget(V3(side * 0.06, 0.24, 0.3), V3(side * 0.2, -1, 0.2), 1),
    Arm.bodyHookLoad => ArmTarget(V3(side * 0.32, -0.3, 0.18), V3(side, -0.2, -0.3), 0.6),
    Arm.bodyHook => ArmTarget(V3(-side * 0.02, -0.4, 0.34), V3(side, -0.3, -0.2), 1),
  };
}

/// 자세를 몇 개의 숫자로 표현한다. 숫자끼리 보간한 뒤 [build]로 관절을 다시 계산하므로
/// 몸통이 도는 만큼 주먹도 원호를 그리고, 팔·다리 길이는 항상 유지된다.
///
/// 발 위치는 바닥에 찍힌 앞뒤 위치로 들고 있고, 골반은 두 발 사이를 기준으로 놓인다.
class Pose {
  Pose({
    Arm lead = Arm.guard,
    Arm rear = Arm.guard,
    this.yaw = 30,
    double? hipYaw,
    this.shiftX = 0,
    this.shiftZ = 0,
    this.drop = 0,
    this.roll = 0,
    this.pitch = 0,
    this.leadFootZ = 0,
    this.rearFootZ = 0,
    this.leadLift = 0,
    this.rearLift = 0,
    this.leadPivot = 0,
    this.rearPivot = 0,
    this.leadHeel = 0,
    this.rearHeel = 0,
  })  : hipYaw = hipYaw ?? yaw * 0.6,
        lead = _arm(lead, -1, yaw),
        rear = _arm(rear, 1, yaw);

  Pose._raw({
    required this.lead,
    required this.rear,
    required this.yaw,
    required this.hipYaw,
    required this.shiftX,
    required this.shiftZ,
    required this.drop,
    required this.roll,
    required this.pitch,
    required this.leadFootZ,
    required this.rearFootZ,
    required this.leadLift,
    required this.rearLift,
    required this.leadPivot,
    required this.rearPivot,
    required this.leadHeel,
    required this.rearHeel,
  });

  final ArmTarget lead;
  final ArmTarget rear;

  /// 어깨 회전(도). 양수 = 리드 어깨가 앞으로. 가드 30.
  final double yaw;

  /// 골반 회전(도). 펀치에서는 골반이 먼저 돌고 어깨가 따라간다.
  final double hipYaw;

  /// 두 발 사이 기준 골반 이동. x 음수 = 리드 쪽, z 양수 = 앞 (체중 이동).
  final double shiftX;
  final double shiftZ;

  /// 무릎을 굽혀 낮춘 정도.
  final double drop;

  /// 상체 옆 기울기(도). 음수 = 리드 쪽.
  final double roll;

  /// 상체 앞 숙임(도). 음수 = 뒤로 젖힘.
  final double pitch;

  /// 발이 놓인 앞뒤 위치 (기본 스탠스 기준). 스텝이면 바뀐다.
  final double leadFootZ;
  final double rearFootZ;

  /// 발을 든 높이. 보간 중 발이 옮겨지면 자동으로 들렸다 내려간다.
  final double leadLift;
  final double rearLift;

  /// 앞꿈치 축으로 발을 돌린 각도(도). 뒤꿈치가 바깥으로 나간다.
  final double leadPivot;
  final double rearPivot;

  /// 뒤꿈치를 든 정도 (0~1).
  final double leadHeel;
  final double rearHeel;

  /// 두 발 사이 바닥 지점. 카메라가 따라가는 기준.
  V3 get base => V3(0.05, 0, 0.14 + (leadFootZ + rearFootZ) / 2);

  Pose _with({double? leadFootZ, double? rearFootZ}) => Pose._raw(
        lead: lead,
        rear: rear,
        yaw: yaw,
        hipYaw: hipYaw,
        shiftX: shiftX,
        shiftZ: shiftZ,
        drop: drop,
        roll: roll,
        pitch: pitch,
        leadFootZ: leadFootZ ?? this.leadFootZ,
        rearFootZ: rearFootZ ?? this.rearFootZ,
        leadLift: leadLift,
        rearLift: rearLift,
        leadPivot: leadPivot,
        rearPivot: rearPivot,
        leadHeel: leadHeel,
        rearHeel: rearHeel,
      );

  /// 발까지 통째로 앞뒤로 옮긴 자세.
  Pose translated(double dz) =>
      dz == 0 ? this : _with(leadFootZ: leadFootZ + dz, rearFootZ: rearFootZ + dz);

  /// 두 발 위치를 정한 자세.
  Pose feet(double lead, double rear) => _with(leadFootZ: lead, rearFootZ: rear);

  static Pose lerp(Pose a, Pose b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    // 바닥에서 미끄러지지 않도록, 옮겨지는 발은 포물선으로 들렸다가 내려놓는다.
    double swing(double from, double to) =>
        math.min(0.06, (to - from).abs() * 0.4) * math.sin(math.pi * t);
    return Pose._raw(
      lead: ArmTarget.lerp(a.lead, b.lead, t),
      rear: ArmTarget.lerp(a.rear, b.rear, t),
      yaw: l(a.yaw, b.yaw),
      hipYaw: l(a.hipYaw, b.hipYaw),
      shiftX: l(a.shiftX, b.shiftX),
      shiftZ: l(a.shiftZ, b.shiftZ),
      drop: l(a.drop, b.drop),
      roll: l(a.roll, b.roll),
      pitch: l(a.pitch, b.pitch),
      leadFootZ: l(a.leadFootZ, b.leadFootZ),
      rearFootZ: l(a.rearFootZ, b.rearFootZ),
      leadLift: l(a.leadLift, b.leadLift) + swing(a.leadFootZ, b.leadFootZ),
      rearLift: l(a.rearLift, b.rearLift) + swing(a.rearFootZ, b.rearFootZ),
      leadPivot: l(a.leadPivot, b.leadPivot),
      rearPivot: l(a.rearPivot, b.rearPivot),
      leadHeel: l(a.leadHeel, b.leadHeel),
      rearHeel: l(a.rearHeel, b.rearHeel),
    );
  }

  static const _upperArm = 0.3;
  static const _foreArm = 0.3;
  static const _thigh = 0.48;
  static const _shin = 0.48;
  static const _foot = 0.19;

  Skeleton build() {
    final j = List<V3>.filled(J.values.length, V3.zero);
    void set(J k, V3 v) => j[k.index] = v;

    final pelvis = V3(0.02 + shiftX, 0.93 - drop, (leadFootZ + rearFootZ) / 2 + shiftZ);
    final leadHip = pelvis + const V3(-0.12, 0, 0).rotY(hipYaw);
    final rearHip = pelvis + const V3(0.12, 0, 0).rotY(hipYaw);

    // 몸통 좌표축: 척추(up), 몸통 정면(fwd), 옆(lat).
    final r = roll * math.pi / 180, p = pitch * math.pi / 180;
    final up = V3(math.sin(r), math.cos(r) * math.cos(p), math.cos(r) * math.sin(p));
    final f0 = const V3(0, 0, 1).rotY(yaw);
    final fwd = (f0 - up * f0.dot(up)).normalized;
    final l0 = const V3(1, 0, 0).rotY(yaw);
    final lat = (l0 - up * l0.dot(up) - fwd * l0.dot(fwd)).normalized;
    final neck = pelvis + up * 0.52;
    V3 local(V3 v) => neck + lat * v.x + up * v.y + fwd * v.z;
    V3 dir(V3 v) => lat * v.x + up * v.y + fwd * v.z;

    final head = local(const V3(0, 0.17, 0.02));
    final leadShoulder = local(_shoulderLocal(-1));
    final rearShoulder = local(_shoulderLocal(1));
    final (leadElbow, leadHand) =
        solveIk(leadShoulder, local(lead.hand), _upperArm, _foreArm, dir(lead.pole));
    final (rearElbow, rearHand) =
        solveIk(rearShoulder, local(rear.hand), _upperArm, _foreArm, dir(rear.pole));

    // 발: 앞꿈치(toe) 기준. 피벗하면 그 축으로 돌고, 뒤꿈치를 들면 발목이 올라간다.
    // 리드 발끝은 약간 안쪽(+x), 리어 발끝은 50° 바깥(+x)을 향한다. 피벗하면 뒤꿈치가 바깥으로.
    final leadToe = V3(-0.14, leadLift, 0.38 + leadFootZ);
    final rearToe = V3(0.24, rearLift, -0.1 + rearFootZ);
    V3 ankle(V3 toe, double angle, double heel) {
      final lift = heel * 35 * math.pi / 180;
      final back = const V3(0, 0, -1).rotY(angle) * (_foot * math.cos(lift));
      return toe + back + V3(0, _foot * math.sin(lift) + 0.05, 0);
    }

    final leadAnkle = ankle(leadToe, 15 + leadPivot, leadHeel);
    final rearAnkle = ankle(rearToe, 50 - rearPivot, rearHeel);
    final (leadKnee, la) = solveIk(leadHip, leadAnkle, _thigh, _shin, const V3(-0.3, 0, 1));
    final (rearKnee, ra) = solveIk(rearHip, rearAnkle, _thigh, _shin, const V3(0.3, 0, 1));

    set(J.head, head);
    set(J.neck, neck);
    set(J.pelvis, pelvis);
    set(J.leadShoulder, leadShoulder);
    set(J.rearShoulder, rearShoulder);
    set(J.leadElbow, leadElbow);
    set(J.rearElbow, rearElbow);
    set(J.leadHand, leadHand);
    set(J.rearHand, rearHand);
    set(J.leadHip, leadHip);
    set(J.rearHip, rearHip);
    set(J.leadKnee, leadKnee);
    set(J.rearKnee, rearKnee);
    set(J.leadFoot, la);
    set(J.rearFoot, ra);
    set(J.leadToe, leadToe);
    set(J.rearToe, rearToe);
    return Skeleton(j, leadGlow: lead.glow, rearGlow: rear.glow, facing: fwd);
  }
}

final guardPose = Pose();

/// 펀치를 거둔 뒤 체중 위치에 따른 가드 자세.
Pose restPose(Weight w, bool low) => Pose(
      yaw: switch (w) { Weight.lead => 20, Weight.center => 30, Weight.rear => 40 },
      shiftX: switch (w) { Weight.lead => -0.03, Weight.center => 0, Weight.rear => 0.03 },
      shiftZ: switch (w) { Weight.lead => 0.04, Weight.center => 0, Weight.rear => -0.04 },
      drop: low ? 0.12 : 0,
    );

/// 동작의 정점(임팩트) 자세. 발 위치(feet)는 동작 시작 지점 기준.
Pose strikePose(Move m) => switch (m.id) {
      // 스텝 잽: 앞발을 밀어 넣으며 뻗는다. 주먹이 닿을 때 앞발이 착지.
      'jab' => Pose(lead: Arm.straight, yaw: 45, hipYaw: 25, shiftZ: 0.04).feet(0.07, 0),
      // 크로스: 앞발을 조금 밀어 넣고, 뒷발을 돌리며 뒤꿈치를 든다. 골반 → 어깨 순으로 회전.
      'cross' => Pose(
          rear: Arm.straight, yaw: -20, hipYaw: -5, shiftX: -0.03, shiftZ: 0.06, pitch: 5,
          rearPivot: 15, rearHeel: 0.5).feet(0.03, 0),
      // 리드 훅: 앞발 앞꿈치를 축으로 돌고 골반·어깨를 리어 쪽으로 크게 돌린다.
      'leadHook' => Pose(
          lead: Arm.hook, yaw: 75, hipYaw: 50, shiftX: 0.03, leadPivot: 15, leadHeel: 0.3),
      'rearHook' => Pose(
          rear: Arm.hook, yaw: -50, hipYaw: -30, shiftX: -0.04, shiftZ: 0.04,
          rearPivot: 15, rearHeel: 0.4),
      'leadUpper' => Pose(lead: Arm.uppercut, yaw: 50, hipYaw: 35, leadPivot: 10),
      'rearUpper' => Pose(
          rear: Arm.uppercut, yaw: -20, hipYaw: -5, shiftZ: 0.04,
          rearPivot: 12, rearHeel: 0.3),
      'leadBody' => Pose(
          lead: Arm.bodyHook, yaw: 65, hipYaw: 45, drop: 0.2, roll: -12, leadPivot: 30).feet(0.06, 0),
      // 바디 스트레이트: 자세를 낮추며 앞발을 깊게 내딛는다.
      'rearBody' => Pose(
          rear: Arm.bodyStraight, yaw: -20, hipYaw: -5, drop: 0.2, pitch: 10,
          rearPivot: 35, rearHeel: 0.7).feet(0.14, 0),
      'jabBody' => Pose(lead: Arm.bodyStraight, yaw: 45, hipYaw: 25, drop: 0.2, pitch: 8).feet(0.2, 0),
      // 슬립: 골반은 거의 그대로, 허리를 옆으로 꺾어 머리만 중심선 밖으로. 어깨선이 크게 기운다.
      'slipLead' => Pose(yaw: 40, roll: -33, shiftX: -0.03, drop: 0.08),
      'slipRear' => Pose(yaw: 15, roll: 33, shiftX: 0.03, drop: 0.08),
      // 더킹: 무릎을 깊게 굽히고 상체를 숙이며 한쪽으로. 끝자세가 가장 낮다.
      'duckLead' => Pose(drop: 0.32, pitch: 28, roll: -8, shiftX: -0.05),
      'duckRear' => Pose(drop: 0.32, pitch: 28, roll: 8, shiftX: 0.05),
      // 위빙: 반대쪽에서 출발해 낮은 지점을 지나 옆에서 다시 올라온 자세 (U자).
      'weaveLead' => Pose(drop: 0.12, pitch: 8, roll: -16, shiftX: -0.08, yaw: 40),
      'weaveRear' => Pose(drop: 0.12, pitch: 8, roll: 16, shiftX: 0.08, yaw: 20),
      // 풀백: 어깨선은 수평 그대로, 상체를 뒷발 위로 젖힌다.
      'pullBack' => Pose(yaw: 35, pitch: -28, shiftZ: -0.1, shiftX: 0.02),
      'backStep' => Pose(shiftZ: -0.03).feet(-0.28, -0.28),
      _ => guardPose,
    };

/// 훅·어퍼 직전 준비 자세: 어깨를 반대로 살짝 감아 회전 거리를 만든다.
Pose? _loadPose(Move m) => switch (m.id) {
      'leadHook' => Pose(lead: Arm.hookLoad, yaw: 20, hipYaw: 12, shiftX: -0.02),
      'rearHook' => Pose(rear: Arm.hookLoad, yaw: 40, hipYaw: 25, shiftX: 0.02),
      'leadUpper' => Pose(lead: Arm.uppercutLoad, yaw: 25, hipYaw: 15, drop: 0.03, roll: -6),
      'rearUpper' => Pose(rear: Arm.uppercutLoad, yaw: 40, hipYaw: 25, drop: 0.03, roll: 6),
      'leadBody' => Pose(lead: Arm.bodyHookLoad, yaw: 25, hipYaw: 15, drop: 0.16, roll: -8),
      _ => null,
    };

/// 펀치 동작 시간(초)과 임팩트 시점(동작 대비 비율).
///
/// BoxingVI(실제 선수 2D 포즈, 4,743개 펀치 클립, 30fps)의 중앙값에 맞췄다.
/// 바디샷은 데이터에 없어 같은 손의 머리 펀치보다 조금 길게 잡았다.
/// [Move.duration]은 콜 간격 계산용(초급자 여유 포함)이라 이것과 별개다.
double animSeconds(Move m) => switch (m.id) {
      'jab' => 0.27,
      'cross' => 0.30,
      'leadHook' => 0.33,
      'rearHook' => 0.33,
      'leadUpper' => 0.27,
      'rearUpper' => 0.30,
      'jabBody' => 0.32,
      'rearBody' => 0.36,
      'leadBody' => 0.38,
      _ => m.duration,
    };

double _impactAt(Move m) => switch (m.id) {
      'jab' => 0.43,
      'cross' => 0.40,
      'leadHook' || 'rearHook' || 'leadBody' => 0.44,
      'leadUpper' || 'rearUpper' => 0.48,
      _ => 0.45,
    };

/// 동작 하나의 애니메이션: 키프레임 (동작 시간 대비 비율, 자세), 임팩트 시점, 전진 거리.
/// 발 위치는 동작 시작 지점 기준이고, 콤보에서는 앞 동작들의 [advance]만큼 옮겨 쓴다.
class MoveAnim {
  const MoveAnim(this.keys, this.impact, this.advance);

  final List<(double, Pose)> keys;
  final double impact;
  final double advance;
}

/// 펀치: (준비 →) 임팩트 → 잠깐 머묾 → 다른 발을 끌어와 스탠스 회복 + 체중이 옮겨간 가드.
/// 방어: 빠진 자세로 가서 유지 (다음 펀치가 그 자리에서 나간다). 위빙은 U자, 백스텝은 뒷발 먼저.
MoveAnim moveAnim(Move m) {
  final peak = strikePose(m);
  if (m.isPunch) {
    final advance = math.max(peak.leadFootZ, peak.rearFootZ);
    final rest = restPose(m.result, m.lowAfter).translated(advance);
    final load = _loadPose(m);
    final impact = _impactAt(m);
    if (load == null) {
      return MoveAnim([(impact, peak), (impact + 0.12, peak), (1.0, rest)], impact, advance);
    }
    return MoveAnim(
        [(impact * 0.42, load), (impact, peak), (impact + 0.11, peak), (1.0, rest)], impact, advance);
  }
  if (m.type == MoveType.weave) {
    final side = m.result == Weight.lead ? -1.0 : 1.0;
    return MoveAnim([
      (0.2, Pose(drop: 0.1, roll: -side * 12, shiftX: -side * 0.04)),
      (0.5, Pose(drop: 0.32, pitch: 25, roll: side * 4, shiftX: side * 0.02)),
      (0.85, peak),
      (1.0, peak),
    ], 0.85, 0);
  }
  if (m.type == MoveType.step) {
    return MoveAnim([
      (0.5, Pose(shiftZ: -0.08).feet(0, peak.rearFootZ)),
      (0.9, peak),
      (1.0, peak),
    ], 0.9, peak.leadFootZ);
  }
  return MoveAnim([(0.8, peak), (1.0, peak)], 0.8, 0);
}

/// 키프레임 사이를 자세 숫자로 부드럽게 보간한다.
Pose samplePoses(List<(double, Pose)> keys, double t) {
  if (t <= keys.first.$1) return keys.first.$2;
  for (var i = 1; i < keys.length; i++) {
    final (t1, p1) = keys[i];
    if (t <= t1) {
      final (t0, p0) = keys[i - 1];
      final u = t1 <= t0 ? 1.0 : (t - t0) / (t1 - t0);
      return Pose.lerp(p0, p1, u * u * (3 - 2 * u));
    }
  }
  return keys.last.$2;
}

enum GuideKind {
  /// 방어: 머리(백스텝은 발) 이동.
  body,

  /// 펀치: 주먹 궤적.
  glove,

  /// 펀치: 골반 회전 방향 (바닥 링).
  hip,
}

class Guide {
  const Guide(this.kind, this.points);

  final GuideKind kind;
  final List<V3> points;

  Guide translated(double dz) =>
      dz == 0 ? this : Guide(kind, [for (final p in points) p + V3(0, 0, dz)]);
}

/// 동작의 움직임을 보여주는 화살표들 (가드에서 출발해 임팩트/도착까지).
List<Guide> motionGuides(Move m) {
  final anim = moveAnim(m);
  final keys = [(0.0, guardPose), ...anim.keys];
  List<V3> track(V3 Function(Skeleton s) at) => [
        for (var i = 0; i <= 24; i++) at(samplePoses(keys, anim.impact * i / 24).build()),
      ];

  if (m.isDefense) {
    final step = m.type == MoveType.step;
    final points = track(
        (s) => step ? s[J.leadToe] + const V3(0, 0.02, 0.12) : s[J.head] + const V3(0, 0.24, 0));
    return [Guide(GuideKind.body, _chaikin(points, 3))];
  }

  final leadHand = m.leadHand!;
  final hand = leadHand ? J.leadHand : J.rearHand;
  final guides = [Guide(GuideKind.glove, track((s) => s[hand]))];

  // 골반이 크게 도는 펀치만 바닥 링으로 회전 방향 표시. 치는 손 쪽 골반이 앞으로 도는 모습.
  // 실제 회전각은 30~40°라 화살표가 짧아 보이므로 2배로 과장해 그린다.
  final peak = strikePose(m);
  final from = guardPose.hipYaw, to = peak.hipYaw;
  if ((to - from).abs() >= 15) {
    final pelvis = peak.build()[J.pelvis];
    final ground = V3(pelvis.x, 0.02, pelvis.z);
    final mid = (from + to) / 2, half = to - from;
    guides.add(Guide(GuideKind.hip, [
      for (var i = 0; i <= 24; i++)
        ground + V3(leadHand ? -0.5 : 0.5, 0, 0).rotY(mid - half + 2 * half * i / 24),
    ]));
  }
  return guides;
}

/// 꺾인 점열의 모서리를 깎아 매끄럽게 (Chaikin).
List<V3> _chaikin(List<V3> p, int iterations) {
  var pts = p;
  for (var n = 0; n < iterations; n++) {
    if (pts.length < 3) return pts;
    pts = [
      pts.first,
      for (var i = 0; i < pts.length - 1; i++) ...[
        pts[i] * 0.75 + pts[i + 1] * 0.25,
        pts[i] * 0.25 + pts[i + 1] * 0.75,
      ],
      pts.last,
    ];
  }
  return pts;
}
