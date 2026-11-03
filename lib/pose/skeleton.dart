import 'dart:math' as math;

class V3 {
  const V3(this.x, this.y, this.z);

  static const zero = V3(0, 0, 0);

  final double x, y, z;

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);

  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  double get length => math.sqrt(dot(this));

  V3 get normalized {
    final l = length;
    return l < 1e-9 ? this : this * (1 / l);
  }

  /// y축 회전. 양수면 -x 쪽(리드 쪽)이 앞(+z)으로 나온다.
  V3 rotY(double degrees) {
    final r = degrees * math.pi / 180;
    final c = math.cos(r), s = math.sin(r);
    return V3(x * c + z * s, y, -x * s + z * c);
  }

  static V3 lerp(V3 a, V3 b, double t) => a + (b - a) * t;
}

/// 관절. lead/rear는 앞손·앞발 / 뒷손·뒷발.
enum J {
  head,
  neck,
  pelvis,
  leadShoulder,
  rearShoulder,
  leadElbow,
  rearElbow,
  leadHand,
  rearHand,
  leadHip,
  rearHip,
  leadKnee,
  rearKnee,
  leadFoot, // 발목
  rearFoot,
  leadToe, // 앞꿈치
  rearToe,
}

/// 관절 좌표 묶음 (오소독스 기준, 미터 단위).
/// x: 화면 오른쪽(= 거울 속 내 오른쪽), y: 위, z: 화면 밖(정면).
/// 거울에 비친 모습이라 그대로 그리면 사우스포로 보인다. 오소독스는 그릴 때 좌우를 뒤집는다.
class Skeleton {
  const Skeleton(this.joints, {this.leadGlow = 0, this.rearGlow = 0, this.facing = const V3(0, 0, 1)});

  final List<V3> joints;

  /// 얼굴이 향한 방향.
  final V3 facing;

  /// 펀치를 뻗은 손 강조 (0~1).
  final double leadGlow;
  final double rearGlow;

  V3 operator [](J j) => joints[j.index];

  /// 통째로 [d]만큼 옮긴 뼈대.
  Skeleton shifted(V3 d) => Skeleton([for (final p in joints) p + d], leadGlow: leadGlow, rearGlow: rearGlow, facing: facing);

  /// 관절마다 [d]를 [w]배 더한 뼈대. 팔·다리는 방향만 따르고 길이는 [lengths]로 되돌린다.
  Skeleton offset(List<V3> d, double w, Lengths lengths) {
    final j = [for (var i = 0; i < joints.length; i++) joints[i] + d[i] * w];
    void limb(J a, J b, J c, double l1, double l2) {
      final mid = j[a.index] + (j[b.index] - j[a.index]).normalized * l1;
      j[c.index] = mid + (j[c.index] - mid).normalized * l2;
      j[b.index] = mid;
    }

    limb(J.leadShoulder, J.leadElbow, J.leadHand, lengths.upperArm, lengths.foreArm);
    limb(J.rearShoulder, J.rearElbow, J.rearHand, lengths.upperArm, lengths.foreArm);
    limb(J.leadHip, J.leadKnee, J.leadFoot, lengths.thigh, lengths.shin);
    limb(J.rearHip, J.rearKnee, J.rearFoot, lengths.thigh, lengths.shin);
    return Skeleton(j, leadGlow: leadGlow, rearGlow: rearGlow, facing: facing);
  }

  static Skeleton lerp(Skeleton a, Skeleton b, double t) => Skeleton(
        [for (var i = 0; i < a.joints.length; i++) V3.lerp(a.joints[i], b.joints[i], t)],
        leadGlow: a.leadGlow + (b.leadGlow - a.leadGlow) * t,
        rearGlow: a.rearGlow + (b.rearGlow - a.rearGlow) * t,
        facing: V3.lerp(a.facing, b.facing, t).normalized,
      );
}

/// 팔·다리 마디 길이.
class Lengths {
  const Lengths({required this.upperArm, required this.foreArm, required this.thigh, required this.shin});

  final double upperArm, foreArm, thigh, shin;
}

/// 두 마디 IK: 시작점 [a]에서 끝점 [c]로 가는 팔/다리의 중간 관절 위치.
/// [pole] 방향으로 꺾인다. 닿지 않으면 [c]를 끌어당긴다.
(V3 joint, V3 end) solveIk(V3 a, V3 c, double l1, double l2, V3 pole) {
  var d = c - a;
  var len = d.length;
  final reach = l1 + l2 - 0.002;
  if (len > reach) {
    c = a + d.normalized * reach;
    d = c - a;
    len = reach;
  }
  final dir = d.normalized;
  final along = (l1 * l1 - l2 * l2 + len * len) / (2 * len);
  final h = math.sqrt(math.max(0, l1 * l1 - along * along));
  var bend = pole - dir * pole.dot(dir);
  if (bend.length < 1e-6) bend = const V3(0, -1, 0);
  return (a + dir * along + bend.normalized * h, c);
}

/// 바닥 평면(x, z)의 강체 변환 (회전·이동). 체크 훅·점프 훅으로 돈 방향을 콤보 뒤 동작에 이어 준다.
/// 월드 = M · (x, z) + o.
class Frame {
  const Frame._(this.a, this.b, this.c, this.d, this.ox, this.oz);

  static const identity = Frame._(1, 0, 0, 1, 0, 0);

  final double a, b, c, d, ox, oz;

  /// [V3.rotY]와 같은 방향으로 [deg]도, [about]을 축으로.
  factory Frame.rotation(double deg, V3 about) {
    final r = deg * math.pi / 180;
    final co = math.cos(r), si = math.sin(r);
    return Frame._(co, si, -si, co, about.x - (co * about.x + si * about.z), about.z - (-si * about.x + co * about.z));
  }

  factory Frame.translation(double dx, double dz) => Frame._(1, 0, 0, 1, dx, dz);

  bool get isIdentity => a == 1 && b == 0 && c == 0 && d == 1 && ox == 0 && oz == 0;

  /// 회전 각도(도).
  double get angle => math.atan2(b, a) * 180 / math.pi;

  V3 apply(V3 p) => V3(a * p.x + b * p.z + ox, p.y, c * p.x + d * p.z + oz);

  V3 applyDir(V3 v) => V3(a * v.x + b * v.z, v.y, c * v.x + d * v.z);

  /// 먼저 [inner], 다음 이 변환.
  Frame then(Frame inner) => Frame._(
        a * inner.a + b * inner.c,
        a * inner.b + b * inner.d,
        c * inner.a + d * inner.c,
        c * inner.b + d * inner.d,
        a * inner.ox + b * inner.oz + ox,
        c * inner.ox + d * inner.oz + oz,
      );

  Frame get inverse {
    final det = a * d - b * c;
    final ia = d / det, ib = -b / det, ic = -c / det, id = a / det;
    return Frame._(ia, ib, ic, id, -(ia * ox + ib * oz), -(ic * ox + id * oz));
  }

  /// 회전 [deg]도(원점 축) 뒤 ([dx], [dz]) 이동.
  factory Frame.rigid(double deg, double dx, double dz) {
    final r = deg * math.pi / 180;
    final co = math.cos(r), si = math.sin(r);
    return Frame._(co, si, -si, co, dx, dz);
  }

  /// 두 변환 사이를 각도·이동으로 보간한다 (각도는 가까운 쪽으로).
  static Frame lerpRigid(Frame a, Frame b, double u) {
    var d = b.angle - a.angle;
    while (d > 180) {
      d -= 360;
    }
    while (d < -180) {
      d += 360;
    }
    return Frame.rigid(a.angle + d * u, a.ox + (b.ox - a.ox) * u, a.oz + (b.oz - a.oz) * u);
  }

  /// 변환을 [u](0~1)만큼 없앤 변환: 회전 각도와 이동을 같은 비율로 줄인다.
  Frame fadedOut(double u) {
    final r = angle * (1 - u) * math.pi / 180;
    final co = math.cos(r), si = math.sin(r);
    return Frame._(co, si, -si, co, ox * (1 - u), oz * (1 - u));
  }
}

extension SkeletonFrame on Skeleton {
  /// [f]로 옮긴 뼈대.
  Skeleton transformed(Frame f) {
    if (f.isIdentity) return this;
    return Skeleton([for (final p in joints) f.apply(p)],
        leadGlow: leadGlow, rearGlow: rearGlow, facing: f.applyDir(facing));
  }
}
