import 'dart:math' as math;

import '../models/moves.dart';
import 'mocap.dart';
import 'skeleton.dart';

/// 팔 상태.
enum Arm { guard, straight, bodyStraight, hook, uppercut, bodyHook, overhand }

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
/// 가드에서는 어깨를 살짝 올려 턱을 감싼다. 어깨너비는 코치 영상 실측(몸통 길이의 0.57~0.67배)에 맞춘다.
V3 _shoulderLocal(double side) => V3(side * 0.17, -0.02, 0);

/// 몸통 기준 머리 위치. 턱을 당겨 낮고 약간 앞으로.
/// 실제 선수(BoxingVI)는 코가 어깨선보다 몸통 길이의 0.1~0.25배 위에 있다. 목을 세우면 0.45배.
const _headLocal = V3(0, 0.09, 0.05);

/// 펀치를 끝까지 뻗었을 때 어깨가 앞·위로 나오는 양 (견갑골 내밀기). 치는 손 강조 값만큼 적용한다.
V3 _protract(double side) => V3(-side * 0.02, 0.025, 0.06);

ArmTarget _arm(Arm arm, double side, double yaw) {
  // 스트레이트는 정면 중심선을 향해 뻗으므로 월드 기준으로 계산한 뒤 몸통 좌표로 되돌린다.
  ArmTarget straight(double height) {
    final shoulder = (_shoulderLocal(side) + _protract(side)).rotY(yaw);
    final hand = shoulder + (V3(0, height, 0.9) - shoulder).normalized * 0.53;
    return ArmTarget(hand.rotY(-yaw), V3(side, -0.6, 0), 1);
  }

  // 굽혀 치는 펀치도 상대가 있는 정면을 노린다: 목표와 팔꿈치 방향을 정면 기준으로 잡아 몸통 좌표로 되돌린다.
  // (몸통 기준으로 잡으면 훅에서 몸통이 75° 돌아 있어 주먹이 상대 쪽이 아니라 옆으로 간다.)
  ArmTarget aimed(V3 target, V3 pole) => ArmTarget(target.rotY(-yaw), pole.rotY(-yaw), 1);

  return switch (arm) {
    // 앞손은 턱 앞, 뒷손은 턱 옆. 팔꿈치는 아래로 내려 갈비뼈를 덮는다.
    // 실제 선수(BoxingVI) 가드 손목은 코보다 몸통 길이의 0.43배 아래. 주먹(글러브 중심)은 그보다 조금 위.
    Arm.guard => side < 0
        ? const ArmTarget(V3(-0.09, -0.03, 0.34), V3(-0.3, -0.8, 0.4), 0)
        : const ArmTarget(V3(0.1, -0.05, 0.26), V3(0.3, -0.8, 0.4), 0),
    // 스트레이트는 가드에서 거의 수평으로 뻗는다 (실제 주먹 상승: 잽 0.09, 크로스 0.06 몸통 길이).
    Arm.straight => straight(side < 0 ? 0.08 : 0.14),
    // 바디 스트레이트: 다리로 자세를 낮추고 팔은 거의 수평으로 뻗는다 (실제 바닥 기준 7~16° 아래).
    // 목표는 몸통 기준이라, 상체를 더 숙이는 바디 크로스는 그만큼 위로 잡는다.
    Arm.bodyStraight => straight(side < 0 ? 0.0 : 0.2),
    // 훅: 팔꿈치를 어깨 높이로 들고, 주먹이 중심선으로 짧은 수평 호를 그린다.
    // 옆으로 크게 빼면 궤적이 실제보다 3배 휜다.
    // 팔꿈치는 바깥으로 들고, 주먹은 정면 중심선의 턱 높이에 닿는다.
    Arm.hook => aimed(const V3(0.02, 0.04, 0.5), V3(side, 0.25, 0)),
    // 어퍼: 주먹을 가슴 높이로 살짝 떨어뜨렸다가 턱 높이로 올려친다.
    Arm.uppercut => aimed(V3(side * 0.03, 0.14, 0.42), V3(side * 0.3, -1, -0.1)),
    Arm.bodyHook => aimed(const V3(0.02, -0.12, 0.46), V3(side, -0.2, 0)),
    // 오버핸드: 팔꿈치를 바깥 위로 들고 주먹이 위에서 비스듬히 내려꽂힌다. 팔은 다 펴지 않는다.
    Arm.overhand => aimed(const V3(0.14, 0.26, 0.56), V3(side, 0.4, -0.2)),
  };
}

/// 다음 자세로 옮겨갈 때 부위별 출발 순서.
///
/// BoxingVI(펀치 4,743개)에서 부위별로 움직이기 시작한 시각을 비교한 결과:
/// 칠 때는 모든 펀치에서 발·골반·어깨가 손목보다 15~40ms 먼저 움직이고 (골반과 어깨는 거의 동시),
/// 거둘 때는 손목이 몸보다 15~35ms 먼저 돌아온다.
enum Order {
  together,

  /// 몸이 먼저 돌고 팔이 뒤따라 뻗는다 (펀치를 칠 때).
  bodyFirst,

  /// 팔이 먼저 돌아오고 몸이 뒤따른다 (펀치를 거둘 때).
  armsFirst,
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
    this.leadFootX = 0,
    this.rearFootX = 0,
    this.leadLift = 0,
    this.rearLift = 0,
    this.leadPivot = 0,
    this.rearPivot = 0,
    this.leadHeel = 0,
    this.rearHeel = 0,
    this.order = Order.together,
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
    required this.leadFootX,
    required this.rearFootX,
    required this.leadLift,
    required this.rearLift,
    required this.leadPivot,
    required this.rearPivot,
    required this.leadHeel,
    required this.rearHeel,
    required this.order,
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

  /// 발이 놓인 옆 위치 (기본 스탠스 기준, 음수 = 리드 쪽). 옆으로 각도를 잡으면 바뀐다.
  final double leadFootX;
  final double rearFootX;

  /// 발을 든 높이. 보간 중 발이 옮겨지면 자동으로 들렸다 내려간다.
  final double leadLift;
  final double rearLift;

  /// 앞꿈치 축으로 발을 돌린 각도(도). 뒤꿈치가 바깥으로 나간다.
  final double leadPivot;
  final double rearPivot;

  /// 뒤꿈치를 든 정도 (0~1).
  final double leadHeel;
  final double rearHeel;

  /// 이 자세로 옮겨갈 때 어느 부위가 먼저 움직이는지.
  final Order order;

  /// 두 발 사이 바닥 지점. 카메라가 따라가는 기준.
  V3 get base => V3(0.05 + (leadFootX + rearFootX) / 2, 0, 0.14 + (leadFootZ + rearFootZ) / 2);

  Pose _with(
          {double? leadFootZ,
          double? rearFootZ,
          double? leadFootX,
          double? rearFootX,
          double? shiftX,
          double? drop,
          double? pitch,
          double? leadLift,
          double? rearLift,
          Order? order}) =>
      Pose._raw(
        lead: lead,
        rear: rear,
        yaw: yaw,
        hipYaw: hipYaw,
        shiftX: shiftX ?? this.shiftX,
        shiftZ: shiftZ,
        drop: drop ?? this.drop,
        roll: roll,
        pitch: pitch ?? this.pitch,
        leadFootZ: leadFootZ ?? this.leadFootZ,
        rearFootZ: rearFootZ ?? this.rearFootZ,
        leadFootX: leadFootX ?? this.leadFootX,
        rearFootX: rearFootX ?? this.rearFootX,
        leadLift: leadLift ?? this.leadLift,
        rearLift: rearLift ?? this.rearLift,
        leadPivot: leadPivot,
        rearPivot: rearPivot,
        leadHeel: leadHeel,
        rearHeel: rearHeel,
        order: order ?? this.order,
      );

  /// 두 발을 [lead]·[rear]만큼 든 자세 (점프).
  Pose lifted(double lead, double rear) => _with(leadLift: lead, rearLift: rear);

  /// 무릎을 [drop]만큼 굽힌 자세.
  Pose dropped(double drop) => _with(drop: drop);

  /// 앞발 앞꿈치를 축으로 몸 전체를 [deg]도 돌린 자세 (체크 훅·점프 훅). 양수 = 리드 훅이 도는 쪽 (뒷발이 뒤로 돌아 나감).
  /// 발·골반·몸통 회전이 함께 돌고, 팔은 몸통 좌표라 저절로 따라간다.
  Pose turned(double deg) {
    final pivot = V3(-0.14 + leadFootX, 0, 0.38 + leadFootZ);
    V3 rot(V3 p) => pivot + (p - pivot).rotY(deg);
    final rearToe = rot(V3(0.24 + rearFootX, 0, -0.1 + rearFootZ));
    final pelvis = rot(V3(0.02 + (leadFootX + rearFootX) / 2 + shiftX, 0, (leadFootZ + rearFootZ) / 2 + shiftZ));
    final rfx = rearToe.x - 0.24, rfz = rearToe.z + 0.1;
    final lean = V3(roll, 0, pitch).rotY(deg);
    return Pose._raw(
      lead: lead,
      rear: rear,
      yaw: yaw + deg,
      hipYaw: hipYaw + deg,
      shiftX: pelvis.x - 0.02 - (leadFootX + rfx) / 2,
      shiftZ: pelvis.z - (leadFootZ + rfz) / 2,
      drop: drop,
      roll: lean.x,
      pitch: lean.z,
      leadFootZ: leadFootZ,
      rearFootZ: rfz,
      leadFootX: leadFootX,
      rearFootX: rfx,
      leadLift: leadLift,
      rearLift: rearLift,
      leadPivot: leadPivot + deg,
      rearPivot: rearPivot - deg,
      leadHeel: leadHeel,
      rearHeel: rearHeel,
      order: order,
    );
  }


  /// 발까지 통째로 앞뒤로([dz]), 옆으로([dx]) 옮긴 자세.
  Pose translated(double dz, [double dx = 0]) => dz == 0 && dx == 0
      ? this
      : _with(leadFootZ: leadFootZ + dz, rearFootZ: rearFootZ + dz, leadFootX: leadFootX + dx, rearFootX: rearFootX + dx);

  /// 두 발 위치를 정한 자세 (앞뒤, 옆은 [leadX]·[rearX]를 줄 때만).
  Pose feet(double lead, double rear, {double? leadX, double? rearX}) =>
      _with(leadFootZ: lead, rearFootZ: rear, leadFootX: leadX, rearFootX: rearX);

  /// [from](더킹·위빙 등으로 낮추거나 옆으로 빠진 자세)의 높이와 체중을 이어받은 자세.
  /// 일어서지 않고 그 자리에서 다음 펀치를 친다: 무릎 높이는 대부분, 숙임은 조금, 옆 체중은 절반 남긴다.
  /// 골반을 올리는 자세(점프, [drop] < 0)는 그대로 둔다.
  Pose leveledFrom(Pose from) => _with(
        drop: drop < 0 ? drop : math.max(drop, from.drop * 0.75),
        pitch: math.max(pitch, from.pitch * 0.4),
        shiftX: shiftX + from.shiftX * 0.5,
      );

  /// 한쪽 팔을 정면 기준(목 원점, 몸통 회전 전) 주먹 위치 [hand]와 팔꿈치 방향 [pole]로 둔 자세.
  /// 이 자세의 몸통 회전으로 몸통 좌표로 되돌려 넣는다.
  Pose aimedArm(bool leadArm, V3 hand, V3 pole, double glow) {
    final a = ArmTarget(hand.rotY(-yaw), pole.rotY(-yaw), glow);
    return Pose._raw(
      lead: leadArm ? a : lead,
      rear: leadArm ? rear : a,
      yaw: yaw,
      hipYaw: hipYaw,
      shiftX: shiftX,
      shiftZ: shiftZ,
      drop: drop,
      roll: roll,
      pitch: pitch,
      leadFootZ: leadFootZ,
      rearFootZ: rearFootZ,
      leadFootX: leadFootX,
      rearFootX: rearFootX,
      leadLift: leadLift,
      rearLift: rearLift,
      leadPivot: leadPivot,
      rearPivot: rearPivot,
      leadHeel: leadHeel,
      rearHeel: rearHeel,
      order: order,
    );
  }

  /// 이 자세로 옮겨가는 순서를 정한 자세.
  Pose ordered(Order order) => _with(order: order);

  /// 한쪽 주먹 목표만 [d]만큼 옮긴 자세 (몸통 좌표).
  Pose handShifted(bool leadArm, V3 d) {
    ArmTarget shift(ArmTarget a) => ArmTarget(a.hand + d, a.pole, a.glow);
    return Pose._raw(
      lead: leadArm ? shift(lead) : lead,
      rear: leadArm ? rear : shift(rear),
      yaw: yaw,
      hipYaw: hipYaw,
      shiftX: shiftX,
      shiftZ: shiftZ,
      drop: drop,
      roll: roll,
      pitch: pitch,
      leadFootZ: leadFootZ,
      rearFootZ: rearFootZ,
      leadFootX: leadFootX,
      rearFootX: rearFootX,
      leadLift: leadLift,
      rearLift: rearLift,
      leadPivot: leadPivot,
      rearPivot: rearPivot,
      leadHeel: leadHeel,
      rearHeel: rearHeel,
      order: order,
    );
  }

  static Pose lerp(Pose a, Pose b, double t) => blend(a, b, legs: t, torso: t, arms: t);

  /// 부위별 진행도를 따로 줘서 보간한다. [legs]는 발·골반, [torso]는 상체 기울기·어깨 회전, [arms]는 팔.
  static Pose blend(Pose a, Pose b, {required double legs, required double torso, required double arms}) {
    double l(double x, double y, double t) => x + (y - x) * t;
    // 바닥에서 미끄러지지 않도록, 옮겨지는 발은 포물선으로 들렸다가 내려놓는다.
    double swing(double from, double to, double fromX, double toX) =>
        math.min(0.06, math.sqrt(math.pow(to - from, 2) + math.pow(toX - fromX, 2)) * 0.4) * math.sin(math.pi * legs);
    return Pose._raw(
      lead: ArmTarget.lerp(a.lead, b.lead, arms),
      rear: ArmTarget.lerp(a.rear, b.rear, arms),
      yaw: l(a.yaw, b.yaw, torso),
      hipYaw: l(a.hipYaw, b.hipYaw, legs),
      shiftX: l(a.shiftX, b.shiftX, legs),
      shiftZ: l(a.shiftZ, b.shiftZ, legs),
      drop: l(a.drop, b.drop, legs),
      roll: l(a.roll, b.roll, torso),
      pitch: l(a.pitch, b.pitch, torso),
      leadFootZ: l(a.leadFootZ, b.leadFootZ, legs),
      rearFootZ: l(a.rearFootZ, b.rearFootZ, legs),
      leadFootX: l(a.leadFootX, b.leadFootX, legs),
      rearFootX: l(a.rearFootX, b.rearFootX, legs),
      leadLift: l(a.leadLift, b.leadLift, legs) + swing(a.leadFootZ, b.leadFootZ, a.leadFootX, b.leadFootX),
      rearLift: l(a.rearLift, b.rearLift, legs) + swing(a.rearFootZ, b.rearFootZ, a.rearFootX, b.rearFootX),
      leadPivot: l(a.leadPivot, b.leadPivot, legs),
      rearPivot: l(a.rearPivot, b.rearPivot, legs),
      leadHeel: l(a.leadHeel, b.leadHeel, legs),
      rearHeel: l(a.rearHeel, b.rearHeel, legs),
      order: b.order,
    );
  }

  /// 앞뒤 키까지 네 자세를 부위별 가중치로 섞는다 (각 가중치 합은 1). [samplePoses]의 곡선 보간용.
  /// 발 위치·들기·피벗은 곡선 대신 [feet] 진행도로 두 키 사이만 옮긴다. 딛은 발이 미끄러지지 않게.
  static Pose _spline(List<Pose> p, List<double> legs, List<double> torso, List<double> arms, double feet) {
    double s(double Function(Pose) f, List<double> w) => f(p[0]) * w[0] + f(p[1]) * w[1] + f(p[2]) * w[2] + f(p[3]) * w[3];
    V3 v(V3 Function(Pose) f, List<double> w) => f(p[0]) * w[0] + f(p[1]) * w[1] + f(p[2]) * w[2] + f(p[3]) * w[3];
    ArmTarget arm(ArmTarget Function(Pose) f) =>
        ArmTarget(v((q) => f(q).hand, arms), v((q) => f(q).pole, arms), s((q) => f(q).glow, arms).clamp(0.0, 1.0));
    final a = p[1], b = p[2];
    double l(double x, double y) => x + (y - x) * feet;
    double swing(double from, double to, double fromX, double toX) =>
        math.min(0.06, math.sqrt(math.pow(to - from, 2) + math.pow(toX - fromX, 2)) * 0.4) * math.sin(math.pi * feet);
    return Pose._raw(
      lead: arm((q) => q.lead),
      rear: arm((q) => q.rear),
      yaw: s((q) => q.yaw, torso),
      hipYaw: s((q) => q.hipYaw, legs),
      shiftX: s((q) => q.shiftX, legs),
      shiftZ: s((q) => q.shiftZ, legs),
      drop: s((q) => q.drop, legs),
      roll: s((q) => q.roll, torso),
      pitch: s((q) => q.pitch, torso),
      leadFootZ: l(a.leadFootZ, b.leadFootZ),
      rearFootZ: l(a.rearFootZ, b.rearFootZ),
      leadFootX: l(a.leadFootX, b.leadFootX),
      rearFootX: l(a.rearFootX, b.rearFootX),
      leadLift: l(a.leadLift, b.leadLift) + swing(a.leadFootZ, b.leadFootZ, a.leadFootX, b.leadFootX),
      rearLift: l(a.rearLift, b.rearLift) + swing(a.rearFootZ, b.rearFootZ, a.rearFootX, b.rearFootX),
      leadPivot: l(a.leadPivot, b.leadPivot),
      rearPivot: l(a.rearPivot, b.rearPivot),
      leadHeel: l(a.leadHeel, b.leadHeel),
      rearHeel: l(a.rearHeel, b.rearHeel),
      order: b.order,
    );
  }

  /// 부위별로 다른 자세에서 값을 가져와 합친다. [bob]만큼 골반을 올린다.
  static Pose mix({required Pose legs, required Pose torso, required Pose arms, double bob = 0}) => Pose._raw(
        lead: arms.lead,
        rear: arms.rear,
        yaw: torso.yaw,
        hipYaw: legs.hipYaw,
        shiftX: legs.shiftX,
        shiftZ: legs.shiftZ,
        drop: legs.drop - bob,
        roll: torso.roll,
        pitch: torso.pitch,
        leadFootZ: legs.leadFootZ,
        rearFootZ: legs.rearFootZ,
        leadFootX: legs.leadFootX,
        rearFootX: legs.rearFootX,
        leadLift: legs.leadLift,
        rearLift: legs.rearLift,
        leadPivot: legs.leadPivot,
        rearPivot: legs.rearPivot,
        leadHeel: legs.leadHeel,
        rearHeel: legs.rearHeel,
        order: arms.order,
      );

  /// 두 자세가 사실상 같은지 (머무는 키 판별).
  static bool _same(Pose a, Pose b) =>
      (a.yaw - b.yaw).abs() + (a.hipYaw - b.hipYaw).abs() + (a.roll - b.roll).abs() + (a.pitch - b.pitch).abs() < 0.5 &&
      (a.shiftX - b.shiftX).abs() + (a.shiftZ - b.shiftZ).abs() + (a.drop - b.drop).abs() +
              (a.leadFootZ - b.leadFootZ).abs() + (a.rearFootZ - b.rearFootZ).abs() +
              (a.leadFootX - b.leadFootX).abs() + (a.rearFootX - b.rearFootX).abs() +
              (a.lead.hand - b.lead.hand).length + (a.rear.hand - b.rear.hand).length <
          0.005;

  static const lengths = Lengths(upperArm: _upperArm, foreArm: _foreArm, thigh: _thigh, shin: _shin);

  static const _upperArm = 0.3;
  static const _foreArm = 0.3;
  // 다리 비율은 코치 시범 영상 8개(MediaPipe)에서 잰 값: 다리 길이 = 몸통의 1.52~1.62배, 허벅지 0.78~0.88배.
  static const _thigh = 0.43;
  static const _shin = 0.40;
  static const _foot = 0.17;

  Skeleton build() {
    final j = List<V3>.filled(J.values.length, V3.zero);
    void set(J k, V3 v) => j[k.index] = v;

    final pelvis = V3(0.02 + (leadFootX + rearFootX) / 2 + shiftX, _pelvisHeight - drop, (leadFootZ + rearFootZ) / 2 + shiftZ);
    final leadHip = pelvis + const V3(-0.12, 0, 0).rotY(hipYaw);
    final rearHip = pelvis + const V3(0.12, 0, 0).rotY(hipYaw);

    // 몸통 좌표축: 척추(up), 몸통 정면(fwd), 옆(lat).
    (V3, V3) axes(double rollDeg, double pitchDeg, double yawDeg) {
      final r = rollDeg * math.pi / 180, p = pitchDeg * math.pi / 180;
      final up = V3(math.sin(r), math.cos(r) * math.cos(p), math.cos(r) * math.sin(p));
      final f0 = const V3(0, 0, 1).rotY(yawDeg);
      return (up, (f0 - up * f0.dot(up)).normalized);
    }

    final (up, fwd) = axes(roll, pitch, yaw);
    final l0 = const V3(1, 0, 0).rotY(yaw);
    final lat = (l0 - up * l0.dot(up) - fwd * l0.dot(fwd)).normalized;
    final neck = pelvis + up * 0.52;
    V3 local(V3 v) => neck + lat * v.x + up * v.y + fwd * v.z;
    V3 dir(V3 v) => lat * v.x + up * v.y + fwd * v.z;

    // 머리는 몸통을 그대로 따라가지 않고 시선을 상대에 두도록 되돌린다.
    // 코치 시범 영상에서 잰 비율: 옆 기울기 0.1~0.4, 앞 숙임 0.12(더킹)~0.4(슬립·스웨이), 회전 약 0.75.
    final (headUp, headFwd) = axes(roll * 0.3, pitch * 0.25, yaw * 0.75);
    final head = neck + headUp * _headLocal.y + headFwd * _headLocal.z;
    // 펀치를 뻗으면 견갑골이 앞으로 밀려 어깨가 앞으로 나오고 살짝 올라가 턱을 가린다.
    V3 shoulder(double side, ArmTarget arm) => local(_shoulderLocal(side) + _protract(side) * arm.glow);
    final leadShoulder = shoulder(-1, lead);
    final rearShoulder = shoulder(1, rear);
    final (leadElbow, leadHand) =
        solveIk(leadShoulder, local(lead.hand), _upperArm, _foreArm, dir(lead.pole));
    final (rearElbow, rearHand) =
        solveIk(rearShoulder, local(rear.hand), _upperArm, _foreArm, dir(rear.pole));

    // 발: 앞꿈치(toe) 기준. 피벗하면 그 축으로 돌고, 뒤꿈치를 들면 발목이 올라간다.
    // 리드 발끝은 약간 안쪽(+x), 리어 발끝은 50° 바깥(+x)을 향한다. 피벗하면 뒤꿈치가 바깥으로.
    final leadToe = V3(-0.14 + leadFootX, leadLift, 0.38 + leadFootZ);
    final rearToe = V3(0.24 + rearFootX, rearLift, -0.1 + rearFootZ);
    V3 ankle(V3 toe, double angle, double heel) {
      final lift = heel * 35 * math.pi / 180;
      final back = const V3(0, 0, -1).rotY(angle) * (_foot * math.cos(lift));
      return toe + back + V3(0, _foot * math.sin(lift) + 0.05, 0);
    }

    final leadAnkle = ankle(leadToe, 15 + leadPivot, leadHeel);
    final rearAnkle = ankle(rearToe, 50 - rearPivot, rearHeel);
    // 무릎은 발끝 방향을 향한다 (발을 돌리면 무릎도 따라 돈다). 살짝 바깥으로 벌린다.
    V3 kneeDir(V3 toe, V3 ankle, double out) {
      final d = toe - ankle;
      return V3(d.x, 0, d.z).normalized + V3(out, 0, 0);
    }

    final (leadKnee, la) = solveIk(leadHip, leadAnkle, _thigh, _shin, kneeDir(leadToe, leadAnkle, -0.15));
    final (rearKnee, ra) = solveIk(rearHip, rearAnkle, _thigh, _shin, kneeDir(rearToe, rearAnkle, 0.15));

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
    return Skeleton(j, leadGlow: lead.glow, rearGlow: rear.glow, facing: headFwd);
  }
}

/// 가드에서 골반 높이. 실제 가드 무릎 각도(146~159°)가 나오는 높이.
const _pelvisHeight = 0.83;

final guardPose = Pose();

/// 가드에서 리듬을 타는 움직임을 [amount](0~1)만큼 얹는다. [t]는 초.
/// 앞꿈치로 가볍게 오르내리고(올라갈 때 뒤꿈치가 들림), 느리게 좌우로 체중을 옮긴다.
/// 바운스는 CMU 모션캡처에서 펀치 사이 구간 51곳을 잰 값(tool/mocap/bounce.py): 2.4Hz(사분위 2.1~2.6),
/// 크기(봉우리-골 절반) 0.033~0.052. 피험자가 깡충거리는 편이라 크기는 사분위 하단을 쓴다.
/// 손은 몸보다 조금 늦게 따라와 관성이 보이게 한다.
Pose withRhythm(Pose p, double t, double amount) {
  if (amount <= 0) return p;
  final phase = 2 * math.pi * 2.4 * t;
  final bob = (1 - math.cos(phase)) / 2; // 0 = 위, 1 = 아래
  final lag = (1 - math.cos(phase - 0.9)) / 2;
  final sway = math.sin(2 * math.pi * 0.45 * t);
  final a = amount;
  ArmTarget hand(ArmTarget h, double side) => ArmTarget(
      h.hand + V3(side * 0.004 * sway, (bob - lag) * 0.012, 0.006 * math.sin(phase * 0.5 + side)) * a, h.pole, h.glow);
  return Pose._raw(
    lead: hand(p.lead, -1),
    rear: hand(p.rear, 1),
    yaw: p.yaw + 2.5 * sway * a,
    hipYaw: p.hipYaw + 1.5 * sway * a,
    shiftX: p.shiftX + 0.012 * sway * a,
    shiftZ: p.shiftZ,
    drop: p.drop + 0.066 * bob * a,
    roll: p.roll - 1.5 * sway * a,
    pitch: p.pitch + 1.0 * bob * a,
    leadFootZ: p.leadFootZ,
    rearFootZ: p.rearFootZ,
    leadFootX: p.leadFootX,
    rearFootX: p.rearFootX,
    leadLift: p.leadLift,
    rearLift: p.rearLift,
    leadPivot: p.leadPivot,
    rearPivot: p.rearPivot,
    leadHeel: p.leadHeel + 0.25 * (1 - bob) * a,
    rearHeel: p.rearHeel + 0.4 * (1 - bob) * a,
    order: p.order,
  );
}

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
      // 리드 바디 훅: 무릎을 굽히고 앞으로 숙여 앞발에 체중을 싣는다. 앞발은 고정하고 뒤꿈치를 들어 돌리며,
      // 골반이 어깨만큼 돌아 정면과 나란해진다 (코치 시범: 어깨 51°·골반 43° 회전, tool/video_pose).
      'leadBody' => Pose(
          lead: Arm.bodyHook, yaw: 75, hipYaw: 60, drop: 0.15, pitch: 15, roll: -8, shiftZ: 0.04,
          leadPivot: 5, rearPivot: 20, rearHeel: 0.6).feet(0.06, 0),
      // 바디 스트레이트는 코치 시범 영상에서 쟀다 (tool/video_pose).
      // 바디 크로스: 앞무릎을 깊게 굽힌 런지. 뒷다리는 펴고 뒤꿈치를 들며, 상체는 뒷다리와 일직선으로 숙인다.
      'rearBody' => Pose(
          rear: Arm.bodyStraight, yaw: -20, hipYaw: -5, drop: 0.14, pitch: 25, roll: -5, shiftZ: 0.22,
          rearPivot: 35, rearHeel: 0.8).feet(0.36, 0),
      // 바디 잽: 앞발을 깊게 내딛고 무릎을 굽혀 몸 전체를 낮춘다. 상체는 조금만 숙인다.
      'jabBody' => Pose(lead: Arm.bodyStraight, yaw: 45, hipYaw: 25, drop: 0.2, pitch: 12, shiftZ: 0.24).feet(0.45, 0),
      // 방어 자세는 코치 시범 영상(MediaPipe 3D 포즈)에서 가드 대비 변화량을 재서 맞췄다 (tool/video_pose).
      // 슬립: 상체를 옆으로 24° 기울이고 어깨·골반을 30°쯤 함께 돌린다. 거의 낮추지 않는다.
      // 리드 쪽 슬립은 뒷어깨가 앞으로(크로스 친 모양), 리어 쪽 슬립은 앞어깨가 앞으로 나온다.
      // 머리는 거의 옆으로만 움직인다 (실측: 옆 0.66~0.72, 앞뒤 −0.15~0 몸통 길이). 골반도 같은 쪽 무릎 위로 옮긴다.
      'slipLead' => Pose(yaw: 0, hipYaw: -5, roll: -24, pitch: 10, shiftX: -0.07, shiftZ: -0.03, drop: 0.045),
      'slipRear' => Pose(yaw: 60, hipYaw: 42, roll: 25, pitch: 2, shiftX: 0.06, shiftZ: -0.04, drop: 0.02),
      // 더킹: 무릎을 굽혀 0.15쯤 낮추고 상체를 35° 숙인다. 엉덩이는 뒤로 빠진다.
      'duckLead' => Pose(drop: 0.15, pitch: 35, roll: -8, shiftX: -0.03, shiftZ: -0.05),
      'duckRear' => Pose(drop: 0.15, pitch: 35, roll: 8, shiftX: 0.03, shiftZ: -0.05),
      // 위빙: 반대쪽에서 출발해 낮은 지점을 지나 옆에서 다시 올라온 자세 (U자).
      // 올라온 자세는 그쪽 슬립처럼 어깨가 돌아 있다.
      'weaveLead' => Pose(drop: 0.07, pitch: 15, roll: -22, shiftX: -0.06, yaw: 0, hipYaw: 2),
      'weaveRear' => Pose(drop: 0.07, pitch: 10, roll: 22, shiftX: 0.06, yaw: 60, hipYaw: 40),
      // 스웨이: 어깨선은 수평 그대로, 상체를 뒷발 위로 젖힌다. 높이는 그대로.
      'pullBack' => Pose(yaw: 35, hipYaw: 25, pitch: -20, shiftZ: -0.05, shiftX: 0.02),
      'backStep' => Pose(shiftZ: -0.03).feet(-0.28, -0.28),
      // 점프 훅: 두 발로 뛰어 리드 쪽 앞 대각선(오소독스끼리면 상대 뒷손 쪽)으로 들어가 각을 잡고,
      // 착지하며 상대 쪽으로 몸을 돌려 리드 훅. 상대는 원래 자리에 있으니 주먹은 원래 정면 쪽으로 간다.
      'jumpHook' => Pose(
              lead: Arm.hook, yaw: 75, hipYaw: 50, shiftX: 0.03, drop: 0.02, pitch: 4, leadPivot: 15, leadHeel: 0.3)
          .feet(_jumpAdvance, _jumpAdvance, leadX: _jumpSide, rearX: _jumpSide)
          .handShifted(true, const V3(0, 0.08, 0))
          .turned(_jumpTurn),
      // 체크 훅: 리드 훅을 맞히는 순간 이미 앞발을 축으로 돌기 시작한다 (끝까지 돌면 [_pivotTurn]).
      'checkHook' => Pose(
          lead: Arm.hook, yaw: 75, hipYaw: 50, shiftX: 0.02, leadPivot: 15, leadHeel: 0.3).turned(_pivotTurn * 0.2),
      // 오버핸드: 리드 쪽으로 머리를 숙여 상대 잽 위로 넘겨 친다. 크로스보다 낮게, 더 기울인다.
      'overhand' => Pose(
          rear: Arm.overhand, yaw: -25, hipYaw: -10, shiftX: -0.06, shiftZ: 0.07, drop: 0.06,
          pitch: 14, roll: -14, rearPivot: 20, rearHeel: 0.6).feet(0.04, 0),
      _ => guardPose,
    };

/// 동작의 정점 뼈대 (단계 그림용).
Skeleton peakSkeleton(Move m) => strikePose(m).build();

/// 카메라가 바라볼 바닥 지점. 앞뒤로는 두 발 사이를 따라가고, 옆으로는 가드 자리에 둔다
/// (위빙으로 옆으로 각도를 잡는 발놀림이 화면에서 보이도록).
V3 focusOf(Skeleton s) => V3(0.05, 0, (s[J.leadToe].z + s[J.rearToe].z) / 2);

/// 어퍼·오버핸드가 가는 도중 주먹이 지나가는 쪽 (치는 손 기준 몸통 좌표 오프셋).
/// 치기 전에 뒤로 감는 준비 동작은 실제 선수에게 거의 없다. 손목이 20% 움직이는 시점이 실제 27~58ms인데
/// 준비 동작을 넣으면 70~97ms로 늦어진다. 대신 가는 도중 어퍼는 앞으로 나가며 올라가, 오버핸드는 바깥 위로 돌아 휜다.
/// 훅은 [_hookVia]로 따로 그린다.
V3? _arc(Move m) => switch (m.id) {
      'leadUpper' || 'rearUpper' => const V3(0, -0.02, 0.1),
      'overhand' => const V3(0.08, 0.1, -0.04),
      _ => null,
    };

/// 훅 계열 (리드·리어 훅, 리드 바디 훅, 점프 훅, 체크 훅).
bool _isHook(Move m) => m.type == MoveType.hook || m.id == 'leadBody';

/// 훅이 바깥으로 휘는 폭 (정면 기준). 주먹이 바깥으로 크게 돌아 반원을 그리며 들어간다.
const _hookBulge = 0.26;

/// 훅 도중 자세. [s] = 0(가드) ~ 1(임팩트).
///
/// 팔꿈치를 먼저 어깨 높이로 들어 팔을 90°쯤 굽힌 채 고정하고, 몸통이 돌면서 주먹이 치는 쪽 바깥에서
/// 안으로 원호를 그리며 정면 목표에 닿는다. 주먹을 먼저 내밀고 팔꿈치만 돌리면 훅이 아니라 휘두른 잽처럼 보인다.
Pose Function(double s) _hookVia(Move m, Pose peak) {
  final lead = m.leadHand!;
  final side = lead ? -1.0 : 1.0;
  ArmTarget arm(Pose p) => lead ? p.lead : p.rear;
  // 정면 기준 (몸통 회전을 풀어 놓은) 주먹 위치·팔꿈치 방향.
  final from = arm(guardPose).hand.rotY(guardPose.yaw), to = arm(peak).hand.rotY(peak.yaw);
  final poleFrom = arm(guardPose).pole.rotY(guardPose.yaw), poleTo = arm(peak).pole.rotY(peak.yaw);
  return (s) {
    final bend = math.sin(math.pi * s);
    // 앞부분에서 조금 뒤로 빠졌다가 바깥을 돌아 들어오도록, 앞뒤로도 살짝 휜다 (반원).
    final hand = V3.lerp(from, to, s) + V3(side * _hookBulge * bend, 0.03 * bend, -0.12 * bend * (1 - s));
    // 팔꿈치는 주먹보다 먼저 올라간다 (가는 길의 앞쪽 40%에서 거의 다 든다).
    final pole = V3.lerp(poleFrom, poleTo, math.min(1.0, s * 2.2));
    return Pose.lerp(guardPose, peak, s).aimedArm(lead, hand, pole, s);
  };
}

/// 펀치 동작 시간(초)과 임팩트 시점(동작 대비 비율).
///
/// BoxingVI(실제 선수 2D 포즈, 4,743개 펀치 클립, 30fps)의 중앙값에 맞췄다.
/// 바디샷은 데이터에 없어 같은 손의 머리 펀치보다 조금 길게 잡았다.
/// [Move.duration]은 콜 간격 계산용(초급자 여유 포함)이라 이것과 별개다.
/// 보고 따라 할 수 있도록 펀치는 [_punchSlow]배 느리게 보여 준다 (콜 간격 [Move.duration] 0.45~0.55초와 비슷).
double animSeconds(Move m) => switch (m.id) {
      'jab' => 0.27 * _punchSlow,
      'cross' => 0.30 * _punchSlow,
      'leadHook' => 0.33 * _punchSlow,
      'rearHook' => 0.33 * _punchSlow,
      'leadUpper' => 0.27 * _punchSlow,
      'rearUpper' => 0.30 * _punchSlow,
      'jabBody' => 0.32 * _punchSlow,
      'rearBody' => 0.36 * _punchSlow,
      'leadBody' => 0.38 * _punchSlow,
      // 상급 기술은 측정 자료가 없어 비슷한 펀치에 발놀림 시간을 더했다.
      'jumpHook' => 0.45 * _punchSlow,
      'checkHook' => 0.45 * _punchSlow,
      'overhand' => 0.36 * _punchSlow,
      // 방어 시간은 코치 튜토리얼에서 쟀는데, 같은 튜토리얼의 펀치(20%→최대 200~300ms)가 실제 펀치
      // (CMU 모션캡처 83~108ms)보다 2배 넘게 느렸다. 튜토리얼 값(슬립 0.30~0.35초 등)을 0.6배로 줄였다.
      'slipLead' || 'slipRear' => 0.27,
      'duckLead' || 'duckRear' => 0.3,
      'pullBack' => 0.36,
      'weaveLead' || 'weaveRear' => 0.5,
      'backStep' => 0.36,
      _ => m.duration,
    };

const _punchSlow = 1.6;

double _impactAt(Move m) => switch (m.id) {
      'jab' => 0.43,
      'cross' => 0.40,
      'leadHook' || 'rearHook' || 'leadBody' => 0.44,
      'leadUpper' || 'rearUpper' => 0.48,
      'jumpHook' => 0.52,
      'checkHook' => 0.36,
      'overhand' => 0.46,
      _ => 0.45,
    };

/// 위빙에서 옆으로 옮기는 발 거리 (발 길이의 3/4쯤).
const _weaveStep = 0.12;

/// 체크 훅에서 몸을 돌리는 각도.
const _pivotTurn = 60.0;

/// 점프 훅으로 뛰어 들어가는 앞·옆 거리(옆은 리드 쪽 = 음수)와 착지하며 상대 쪽으로 도는 각도.
const _jumpAdvance = 0.45;
const _jumpSide = -0.22;
const _jumpTurn = 25.0;


/// 동작 하나의 애니메이션: 키프레임 (동작 시간 대비 비율, 자세), 임팩트 시점, 전진 거리.
/// 발 위치는 동작 시작 지점 기준이고, 콤보에서는 앞 동작들의 [advance]만큼 옮겨 쓴다.
class MoveAnim {
  const MoveAnim(this.keys, this.impact, this.advance, {this.side = 0, this.turn = 0, this.after});

  final List<(double, Pose)> keys;
  final double impact;
  final double advance;

  /// 옆으로 옮겨 간 거리 (음수 = 리드 쪽).
  final double side;

  /// 앞발을 축으로 몸 전체가 돈 각도 (체크 훅, 점프 훅). 이후 동작은 돈 방향을 정면으로 친다.
  final double turn;

  /// [turn]이 있을 때 바뀐 좌표에서 본 끝 자세 ([advance]·[side] 적용 전).
  final Pose? after;
}

/// 펀치: (휘는 중간 지점 →) 임팩트 → 잠깐 머묾 → 다른 발을 끌어와 스탠스 회복 + 체중이 옮겨간 가드.
/// 방어: 빠진 자세로 가서 유지 (다음 펀치가 그 자리에서 나간다). 위빙은 바닥을 지나는 U자, 백스텝은 뒷발 먼저.
MoveAnim moveAnim(Move m) {
  final peak = strikePose(m);
  if (m.id == 'jumpHook') {
    // 두 발로 바닥을 차고 뛰어 들어가, 착지하며 맞힌다. (웅크리는 준비 키는 넣지 않는다: 골반이 돌지 않고
    // 내려가기만 하는 구간은 실제 움직임 곡선([WarpedMove])이 건너뛰어 순간이동처럼 보인다.)
    final impact = _impactAt(m);
    final rest = restPose(m.result, m.lowAfter);
    final via = _hookVia(m, peak);
    return MoveAnim([
      // 두 발이 함께 떠서 골반이 올라갔다가, 임팩트와 함께 착지한다.
      (impact * 0.35, via(0.35).dropped(-0.07).lifted(0.1, 0.1).ordered(Order.bodyFirst)),
      (impact * 0.7, via(0.7).dropped(-0.1).lifted(0.16, 0.16).ordered(Order.bodyFirst)),
      (impact, peak.ordered(Order.bodyFirst)),
      (impact + 0.06, peak),
      (1.0, rest.translated(_jumpAdvance, _jumpSide).turned(_jumpTurn).ordered(Order.armsFirst)),
    ], impact, _jumpAdvance, side: _jumpSide, turn: _jumpTurn, after: rest);
  }
  if (m.id == 'checkHook') {
    // 훅을 맞히며 앞발로 돌기 시작해, 거두면서 끝까지 돌아 옆으로 빠진다.
    final impact = _impactAt(m);
    final via = _hookVia(m, peak);
    final rest = restPose(m.result, m.lowAfter);
    return MoveAnim([
      (impact * 0.35, via(0.35).ordered(Order.bodyFirst)),
      (impact * 0.7, via(0.7).ordered(Order.bodyFirst)),
      (impact, peak.ordered(Order.bodyFirst)),
      (impact + 0.06, peak),
      (1.0, rest.turned(_pivotTurn).ordered(Order.armsFirst)),
    ], impact, 0, turn: _pivotTurn, after: rest);
  }
  if (m.isPunch) {
    final advance = math.max(peak.leadFootZ, peak.rearFootZ);
    final strike = peak.ordered(Order.bodyFirst);
    final rest = restPose(m.result, m.lowAfter).translated(advance).ordered(Order.armsFirst);
    final impact = _impactAt(m);
    if (_isHook(m)) {
      final via = _hookVia(m, peak);
      return MoveAnim([
        (impact * 0.35, via(0.35).ordered(Order.bodyFirst)),
        (impact * 0.7, via(0.7).ordered(Order.bodyFirst)),
        (impact, strike),
        (impact + 0.06, strike),
        (1.0, rest),
      ], impact, advance);
    }
    final arc = _arc(m);
    if (arc == null) {
      return MoveAnim([(impact, strike), (impact + 0.12, strike), (1.0, rest)], impact, advance);
    }
    final via = Pose.lerp(guardPose, peak, 0.5).handShifted(m.leadHand!, arc).ordered(Order.bodyFirst);
    return MoveAnim(
        [(impact * 0.5, via), (impact, strike), (impact + 0.06, strike), (1.0, rest)], impact, advance);
  }
  if (m.type == MoveType.weave) {
    final side = m.result == Weight.lead ? -1.0 : 1.0;
    // U자: 먼저 거의 수직으로 내려가고, 낮은 높이를 유지한 채 옆으로 건너간 뒤, 반대편에서 올라온다.
    // 바닥이 한 점이면 내려가자마자 올라와 V자가 된다. 두 바닥 키에서 멈추지 않고 곡선으로 지나간다.
    // 발도 빠지는 쪽으로 대각선 앞으로 조금 옮겨 각도를 잡는다: 그쪽 발이 내려가며 먼저 나가고,
    // 다른 발은 올라오며 따라와 스탠스를 되찾는다.
    final dx = side * _weaveStep, dz = _weaveStep * 0.3;
    Pose first(Pose p) => side < 0 ? p.feet(dz, 0, leadX: dx, rearX: 0) : p.feet(0, dz, leadX: 0, rearX: dx);
    Pose both(Pose p) => p.feet(dz, dz, leadX: dx, rearX: dx);
    return MoveAnim([
      (0.3, first(Pose(drop: 0.15, pitch: 32, roll: -side * 2, shiftZ: -0.05))),
      (0.6, first(Pose(drop: 0.15, pitch: 30, roll: side * 14, shiftX: side * 0.045, shiftZ: -0.04))),
      (0.85, both(peak)),
      (1.0, both(peak)),
    ], 0.85, dz, side: dx);
  }
  if (m.type == MoveType.step) {
    // 백스텝: 앞발로 바닥을 차서 두 발이 함께 뒤로 한 번에 미끄러지듯 뛴다 (한 발씩 걷지 않는다).
    // 차기 직전 체중을 앞발에 살짝 싣고, 뒷발로 받아 착지한다.
    return MoveAnim([
      (0.2, Pose(shiftZ: 0.03, drop: 0.03, leadHeel: 0.3)),
      (0.75, peak.ordered(Order.together)),
      (1.0, peak),
    ], 0.75, peak.leadFootZ);
  }
  return MoveAnim([(0.8, peak), (1.0, peak)], 0.8, 0);
}

/// 펀치 키 자세를 실제 사람의 움직임 곡선([MotionProfile])에 맞춰 재생한다.
///
/// 자세는 키 자세 그대로 두고 시간만 바꾼다. 부위(골반·다리 / 상체 / 팔)마다, 실제 사람이 그 순간까지
/// 움직인 비율(진행도)만큼 키 자세에서도 움직인 시각을 찾아 그 시각의 값을 쓴다. 그래서 몸이 먼저 돌고
/// 주먹이 뒤따라 빨라지는 순서와 가속·감속은 실제 사람의 것이 되고, 자세는 정석으로 남는다.
/// 골반 오르내림도 실제 곡선을 더한다.
class WarpedMove {
  WarpedMove(List<(double, Pose)> keys, this.impact, this.profile, {required this.leadArm}) {
    const n = 48;
    for (final rise in [true, false]) {
      final ts = [for (var i = 0; i <= n; i++) rise ? impact * i / n : impact + (1 - impact) * i / n];
      final poses = [for (final t in ts) samplePoses(keys, t)];
      final ref = rise ? poses.first : poses.last;
      final peak = rise ? poses.last : poses.first;
      List<double> progress(double Function(Pose p) v, {double min = 0}) {
        final span = (v(peak) - v(ref)).abs();
        if (span <= min) return const [];
        return [for (final p in poses) (v(p) - v(ref)).abs() / span];
      }

      // 주먹 진행도는 지나온 길이로 잰다. 직선 거리로 재면 훅처럼 휘어 가는 주먹은 도중에 출발점에서
      // 목표보다 멀어져 진행도가 1을 넘었다 줄어들고, 시간이 건너뛰어 순간이동처럼 보인다.
      ArmTarget arm(Pose p) => leadArm ? p.lead : p.rear;
      final steps = [for (var i = 1; i < poses.length; i++) (arm(poses[i]).hand - arm(poses[i - 1]).hand).length];
      final total = math.max(1e-9, steps.fold(0.0, (a, b) => a + b));
      var acc = 0.0;
      final along = [0.0, for (final d in steps) acc += d];
      // 출발→임팩트는 출발점에서, 임팩트→복귀는 복귀 자세(끝)에서 잰다.
      final hand = [for (final a in along) rise ? a / total : 1 - a / total];
      // 다리(골반·발) 진행도: 골반 회전만 보면 점프처럼 발이 뜨고 옮겨 가는 동안 골반이 거의 안 도는 동작은
      // 이륙이 한순간에 몰린다. 골반 회전·발 위치·발 높이·몸 높이가 움직인 길이를 함께 잰다.
      List<double> legs() {
        List<double> v(Pose p) => [p.hipYaw / 60, p.leadFootZ, p.rearFootZ, p.leadFootX, p.rearFootX, p.drop, p.leadLift, p.rearLift];
        var acc = 0.0;
        final along = [0.0];
        for (var i = 1; i < poses.length; i++) {
          final a = v(poses[i - 1]), b = v(poses[i]);
          var d = 0.0;
          for (var k = 0; k < a.length; k++) {
            d += (b[k] - a[k]) * (b[k] - a[k]);
          }
          along.add(acc += math.sqrt(d));
        }
        if (acc < 0.05) return const [];
        return [for (final x in along) rise ? x / acc : 1 - x / acc];
      }

      final hip = legs(), torso = progress((p) => p.yaw, min: 3);
      final tables = [hand, hip.isEmpty ? hand : hip, torso.isEmpty ? hand : torso];
      (rise ? _rise : _fall).addAll([for (final g in tables) (ts, g, poses)]);
    }
  }

  final double impact;
  final MotionProfile profile;
  final bool leadArm;
  final List<(List<double>, List<double>, List<Pose>)> _rise = [], _fall = [];

  /// 진행도 [q]에 해당하는 키 자세. 출발→임팩트는 처음으로 q에 닿는 시각, 임팩트→복귀는 처음으로 q 아래로 내려가는 시각.
  static Pose _find((List<double>, List<double>, List<Pose>) table, double q, bool rise) {
    final (_, g, poses) = table;
    var best = rise ? 0.0 : 1.0;
    for (var i = 1; i < g.length; i++) {
      best = rise ? math.max(best, g[i]) : math.min(best, g[i]);
      final hit = rise ? best >= q : best <= q;
      if (hit) {
        final a = g[i - 1], b = g[i];
        final f = (b - a).abs() < 1e-9 ? 1.0 : ((q - a) / (b - a)).clamp(0.0, 1.0);
        return Pose.lerp(poses[i - 1], poses[i], f);
      }
    }
    return poses.last;
  }

  /// 동작 시간 대비 비율 [u](0~1)의 자세.
  Pose at(double u) {
    final rise = u < impact;
    final v = rise ? u / impact : (u - impact) / (1 - impact);
    final t = rise ? _rise : _fall;
    final arms = _find(t[0], profile.handAt(rise, v), rise);
    final torso = _find(t[2], profile.shoulderAt(rise, v), rise);
    final mixed = Pose.mix(arms: arms, legs: _find(t[1], profile.hipAt(rise, v), rise), torso: torso, bob: profile.bobAt(rise, v));
    // 칠 때 치는 팔은 키 자세에서 정한 정면 기준 길을 그대로 간다: 몸통이 팔보다 먼저 돌아도 주먹이 끌려가지 않게
    // (끌려가면 훅의 원호가 펴진다). 몸통 좌표로 다시 넣을 때 두 자세의 몸통 회전 차이만큼 되돌린다.
    // 거둘 때는 팔이 몸통을 따라 가드로 돌아온다.
    if (!rise) return mixed;
    final arm = leadArm ? arms.lead : arms.rear;
    final d = arms.yaw - torso.yaw;
    return mixed.aimedArm(leadArm, arm.hand.rotY(d + mixed.yaw), arm.pole.rotY(d + mixed.yaw), arm.glow);
  }
}

/// 키프레임 사이를 자세 숫자로 부드럽게 보간한다.
///
/// 머무는 키(앞이나 뒤 키와 같은 자세, 처음·끝)에서는 멈추고, 지나가는 키(위빙 바닥, 훅이 휘는 지점 등)에서는
/// 멈추지 않고 곡선으로 통과한다 (Catmull-Rom). 키마다 멈추면 위빙이 U자가 아니라 ㄷ자로 꺾인다.
/// 도착하는 자세의 [Pose.order]에 따라 늦게 출발하는 부위는 늦게 출발해 같은 시각에 도착한다.
Pose samplePoses(List<(double, Pose)> keys, double t) {
  if (t <= keys.first.$1) return keys.first.$2;
  final n = keys.length;
  bool stops(int i) =>
      i == 0 || i == n - 1 || Pose._same(keys[i].$2, keys[i - 1].$2) || Pose._same(keys[i].$2, keys[i + 1].$2);
  for (var i = 1; i < n; i++) {
    final (t1, p1) = keys[i];
    if (t <= t1) {
      final (t0, p0) = keys[i - 1];
      if (t1 <= t0) return p1;
      final u = (t - t0) / (t1 - t0);
      final prev = i >= 2 ? keys[i - 2] : keys[i - 1];
      final next = i + 1 < n ? keys[i + 1] : keys[i];
      final stop0 = stops(i - 1), stop1 = stops(i);

      // [from, to] 구간에서 움직이는 부위의 네 자세 가중치 (3차 Hermite, 기울기는 앞뒤 키로).
      List<double> w(double from, [double to = 1]) {
        final v = ((u - from) / (to - from)).clamp(0.0, 1.0);
        final v2 = v * v, v3 = v2 * v;
        final h00 = 2 * v3 - 3 * v2 + 1, h10 = v3 - 2 * v2 + v, h01 = -2 * v3 + 3 * v2, h11 = v3 - v2;
        final d = (t1 - t0) * (to - from);
        final c0 = stop0 ? 0.0 : d / (t1 - prev.$1);
        final c1 = stop1 ? 0.0 : d / (next.$1 - t0);
        return [-h10 * c0, h00 - h11 * c1, h01 + h10 * c0, h11 * c1];
      }

      double ease(double from, [double to = 1]) {
        final v = ((u - from) / (to - from)).clamp(0.0, 1.0);
        return v * v * (3 - 2 * v);
      }

      final ps = [prev.$2, p0, p1, next.$2];
      return switch (p1.order) {
        Order.together => Pose._spline(ps, w(0), w(0), w(0), ease(0)),
        Order.bodyFirst => Pose._spline(ps, w(0, 0.7), w(0.02, 0.72), w(0.05), ease(0, 0.7)),
        Order.armsFirst => Pose._spline(ps, w(0.2), w(0.2), w(0, 0.85), ease(0.2)),
      };
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

  Guide mapped(V3 Function(V3) f) => Guide(kind, [for (final p in points) f(p)]);
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
