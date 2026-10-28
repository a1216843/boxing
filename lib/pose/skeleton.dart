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
class Skeleton {
  const Skeleton(this.joints, {this.leadGlow = 0, this.rearGlow = 0, this.facing = const V3(0, 0, 1)});

  final List<V3> joints;

  /// 몸통(얼굴)이 향한 방향.
  final V3 facing;

  /// 펀치를 뻗은 손 강조 (0~1).
  final double leadGlow;
  final double rearGlow;

  V3 operator [](J j) => joints[j.index];

  static Skeleton lerp(Skeleton a, Skeleton b, double t) => Skeleton(
        [for (var i = 0; i < a.joints.length; i++) V3.lerp(a.joints[i], b.joints[i], t)],
        leadGlow: a.leadGlow + (b.leadGlow - a.leadGlow) * t,
        rearGlow: a.rearGlow + (b.rearGlow - a.rearGlow) * t,
        facing: V3.lerp(a.facing, b.facing, t).normalized,
      );
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
