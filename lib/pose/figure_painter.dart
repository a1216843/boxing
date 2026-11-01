import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'poses.dart';
import 'skeleton.dart';

/// 스켈레톤을 입체 인형으로 그린다.
///
/// 원근 카메라가 [focus](두 발 사이 바닥)를 바라보며 따라가고, 바닥 격자가 월드에 고정돼 있어
/// 스텝으로 이동하면 격자가 흘러간다. 기본 시점은 상대 쪽에서 리드 쪽으로 30° 돌아 약간 위에서 본 3/4.
/// 더 옆에서 보면 슬립·위빙의 좌우 이동이 앞뒤 이동처럼 보인다.
///
/// [ghost]: 출발 자세를 반투명하게 겹쳐 그린다.
/// [guides]: 움직임 화살표 — 방어 이동(노랑), 주먹 궤적(빨강), 골반 회전(청록).
class FigurePainter extends CustomPainter {
  FigurePainter(
    this.skeleton, {
    this.mirror = false,
    this.ghost,
    this.guides = const [],
    this.focus = const V3(0.05, 0, 0.14),
    this.color = Colors.white,
    this.accent = const Color(0xFFFF5252),
    this.viewYaw = -30,
    this.elevation = 16,
    this.zoom = 1.0,
    this.floor = true,
  });

  final Skeleton skeleton;

  /// 사우스포: 좌우 반전.
  final bool mirror;
  final Skeleton? ghost;
  final List<Guide> guides;

  /// 카메라가 바라보는 바닥 지점.
  final V3 focus;
  final Color color;
  final Color accent;

  /// 카메라 수평 회전(도)과 내려다보는 각도(도).
  final double viewYaw;
  final double elevation;

  /// 영역 대비 인형 크기. 1보다 작으면 둘레 여백이 늘어난다.
  final double zoom;
  final bool floor;

  static const _centerY = 0.86;

  static const _camDist = 3.6;
  static const _bodyColor = Color(0xFFFFC107);
  static const _hipColor = Color(0xFF4DD0E1);

  /// 빛은 화면 왼쪽 위에서.
  static const _light = Offset(-0.45, -0.9);

  late double _k;
  late Size _size;
  late double _cosY, _sinY, _cosE, _sinE;

  /// 월드 → (화면 좌표, 원근 배율, 깊이). 깊이가 클수록 카메라에 가깝다.
  (Offset, double, double) _proj(V3 p) {
    final w = p - focus;
    final x = w.x * _cosY + w.z * _sinY;
    final z0 = -w.x * _sinY + w.z * _cosY;
    final y0 = w.y - _centerY;
    final y = y0 * _cosE - z0 * _sinE;
    final z = y0 * _sinE + z0 * _cosE;
    final s = _camDist / (_camDist - z);
    final sx = (mirror ? -x : x) * s;
    return (Offset(_size.width / 2 + sx * _k, _size.height / 2 - y * s * _k), s, z);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _size = size;
    _k = math.min(size.width / 1.9, size.height / 2.5) * zoom;
    final yaw = viewYaw * math.pi / 180, el = elevation * math.pi / 180;
    _cosY = math.cos(yaw);
    _sinY = math.sin(yaw);
    _cosE = math.cos(el);
    _sinE = math.sin(el);

    if (floor) _drawFloor(canvas);
    _drawShadows(canvas, skeleton);

    // 골반 링은 바닥에 깔리므로 인형보다 먼저.
    for (final g in guides.where((g) => g.kind == GuideKind.hip)) {
      _drawArrow(canvas, g.points, _hipColor, 0.04);
    }

    final g = ghost;
    if (g != null) _drawFigure(canvas, g, ghost: true);
    _drawFigure(canvas, skeleton);

    for (final g in guides) {
      switch (g.kind) {
        case GuideKind.body:
          _drawArrow(canvas, g.points, _bodyColor, 0.035);
        case GuideKind.glove:
          _drawArrow(canvas, g.points, accent.withAlpha(210), 0.028);
        case GuideKind.hip:
          break;
      }
    }
  }

  /// 월드에 고정된 바닥 격자. 가운데서 멀수록 흐려진다.
  void _drawFloor(Canvas canvas) {
    const step = 0.3, reach = 1.8;
    final paint = Paint()..strokeWidth = 1;
    double snap(double v) => (v / step).round() * step;
    final cx = snap(focus.x), cz = snap(focus.z);
    void line(V3 a, V3 b, double fade) {
      final alpha = (60 * (1 - fade)).clamp(0, 60).round();
      if (alpha <= 0) return;
      canvas.drawLine(_proj(a).$1, _proj(b).$1, paint..color = color.withAlpha(alpha));
    }

    // 흐림은 카메라 중심에서의 실제 거리로 정해, 격자 기준점이 바뀌어도 선 밝기가 튀지 않게 한다.
    for (var i = -6; i <= 6; i++) {
      final x = cx + i * step, z = cz + i * step;
      line(V3(x, 0, focus.z - reach), V3(x, 0, focus.z + reach), (x - focus.x).abs() / reach);
      line(V3(focus.x - reach, 0, z), V3(focus.x + reach, 0, z), (z - focus.z).abs() / reach);
    }
  }

  void _drawShadows(Canvas canvas, Skeleton sk) {
    final paint = Paint()..color = Colors.black.withAlpha(80);
    void blob(V3 at, double w, double d) {
      final (c, s, _) = _proj(V3(at.x, 0, at.z));
      canvas.drawOval(Rect.fromCenter(center: c, width: w * _k * s, height: d * _k * s), paint);
    }

    blob(sk[J.pelvis], 0.55, 0.16);
    for (final (a, b) in [(J.leadFoot, J.leadToe), (J.rearFoot, J.rearToe)]) {
      blob(V3.lerp(sk[a], sk[b], 0.5), 0.26, 0.09);
    }
  }

  /// 마네킹: 끝으로 갈수록 가늘어지는 팔다리, 가슴·허리·골반 볼륨의 몸통, 턱이 있는 머리, 글러브와 신발.
  /// 덩어리마다 화면 깊이로 정렬해 앞에 있는 것을 나중에 그리고, 원통·구처럼 빛 쪽이 밝게 음영을 준다.
  void _drawFigure(Canvas canvas, Skeleton sk, {bool ghost = false}) {
    final items = <(double, VoidCallback)>[];
    final base = ghost ? color.withAlpha(40) : color;
    final dark = ghost ? color.withAlpha(25) : Color.lerp(color, Colors.black, 0.6)!;
    final lightDir = _light / _light.distance;

    // 깊이 음영: 멀수록 어둡게. [lit]만큼 더 밝게/어둡게.
    Color shade(Color tint, double z, [double lit = 0]) => ghost
        ? base
        : Color.lerp(Color.lerp(tint, Colors.black, 0.6)!, tint, ((z + 0.6) / 1.1 + lit).clamp(0.0, 1.0))!;

    // 원통 음영: 축에 수직인 방향으로 빛 쪽 가장자리 → 반대쪽 가장자리.
    Paint cylinder(Offset center, Offset normal, double r, Color c) {
      final paint = Paint();
      if (ghost) return paint..color = base;
      final n = normal.dx * lightDir.dx + normal.dy * lightDir.dy >= 0 ? normal : -normal;
      return paint
        ..shader = LinearGradient(
          colors: [
            Color.lerp(c, Colors.white, 0.3)!,
            Color.lerp(c, Colors.white, 0.08)!,
            Color.lerp(c, Colors.black, 0.28)!,
            Color.lerp(c, Colors.black, 0.18)!,
          ],
          stops: const [0, 0.35, 0.85, 1],
        ).createShader(Rect.fromPoints(center + n * r, center - n * r));
    }

    // 굵기가 변하는 캡슐 (두 원과 바깥 접선으로 이은 실루엣).
    void capsule(V3 a, V3 b, double ra, double rb, Color tint, {double lit = 0, double zBias = 0}) {
      final (pa, sa, za) = _proj(a);
      final (pb, sb, zb) = _proj(b);
      final z = (za + zb) / 2 + zBias;
      final r1 = ra * _k * sa, r2 = rb * _k * sb;
      items.add((
        z,
        () {
          final d = pb - pa;
          final len = d.distance;
          final c = shade(tint, z, lit);
          if (len <= (r1 - r2).abs() + 0.5) {
            final big = r1 >= r2 ? (pa, r1) : (pb, r2);
            canvas.drawCircle(big.$1, big.$2, cylinder(big.$1, const Offset(1, 0), big.$2, c));
            return;
          }
          final u = d / len;
          final n = Offset(-u.dy, u.dx);
          final phi = math.asin(((r1 - r2) / len).clamp(-1.0, 1.0));
          final base0 = math.atan2(n.dy, n.dx);
          final path = Path();
          // pa 쪽 반원(뒤쪽) → pb 쪽 반원(앞쪽).
          const steps = 10;
          for (var i = 0; i <= steps; i++) {
            final ang = base0 - phi + (math.pi + 2 * phi) * i / steps;
            final p = pa + Offset(math.cos(ang), math.sin(ang)) * r1;
            i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
          }
          for (var i = 0; i <= steps; i++) {
            final ang = base0 + math.pi + phi + (math.pi - 2 * phi) * i / steps;
            final p = pb + Offset(math.cos(ang), math.sin(ang)) * r2;
            path.lineTo(p.dx, p.dy);
          }
          path.close();
          canvas.drawPath(path, cylinder((pa + pb) / 2, n, (r1 + r2) / 2, c));
        },
      ));
    }

    // 구 (머리 등): 빛 쪽이 밝은 방사형 그라디언트.
    void ball(V3 at, double radius, Color tint, {double zBias = 0.02}) {
      final (p, s, z) = _proj(at);
      final r = radius * _k * s;
      items.add((
        z + zBias,
        () {
          final paint = Paint();
          if (ghost) {
            paint.color = base;
          } else {
            final c = shade(tint, z);
            paint.shader = RadialGradient(
              center: Alignment(lightDir.dx * 0.5, lightDir.dy * 0.5),
              radius: 1.1,
              colors: [Color.lerp(c, Colors.white, 0.45)!, c, Color.lerp(c, Colors.black, 0.5)!],
              stops: const [0, 0.5, 1],
            ).createShader(Rect.fromCircle(center: p, radius: r));
          }
          canvas.drawCircle(p, r, paint);
        },
      ));
    }

    // 몸통: 높이별 타원 단면(가슴은 어깨선, 골반은 골반선 방향)을 이어 볼록 껍질로 그린다.
    // 위(가슴~허리)와 아래(허리~골반) 두 덩어리라 허리가 잘록하고 비틀림이 보인다.
    final pelvis = sk[J.pelvis], neck = sk[J.neck];
    final up = (neck - pelvis).normalized;
    V3 flat(V3 v) => (v - up * v.dot(up)).normalized;
    final shLat = flat(sk[J.rearShoulder] - sk[J.leadShoulder]);
    final hipLat = flat(sk[J.rearHip] - sk[J.leadHip]);
    List<V3> ring(V3 center, V3 lat, double w, double d) {
      final fwd = V3(up.y * lat.z - up.z * lat.y, up.z * lat.x - up.x * lat.z, up.x * lat.y - up.y * lat.x);
      return [
        for (var i = 0; i < 16; i++)
          center + lat * (w * math.cos(i * math.pi / 8)) + fwd * (d * math.sin(i * math.pi / 8)),
      ];
    }

    final waistLat = (shLat + hipLat).normalized;
    final shoulderMid = (sk[J.leadShoulder] + sk[J.rearShoulder]) * 0.5;
    final hipMid = (sk[J.leadHip] + sk[J.rearHip]) * 0.5;
    final chest = [
      ...ring(shoulderMid + up * 0.035, shLat, 0.15, 0.08),
      ...ring(shoulderMid - up * 0.1, shLat, 0.185, 0.11),
      ...ring(V3.lerp(hipMid, shoulderMid, 0.38), waistLat, 0.135, 0.095),
    ];
    final hips = [
      ...ring(V3.lerp(hipMid, shoulderMid, 0.38), waistLat, 0.135, 0.095),
      ...ring(hipMid + up * 0.02, hipLat, 0.165, 0.105),
      ...ring(hipMid - up * 0.07, hipLat, 0.12, 0.09),
    ];
    void hull(List<V3> pts3, Color tint, double lit, V3 lat) {
      final proj = pts3.map(_proj).toList();
      final z = proj.fold(0.0, (s, p) => s + p.$3) / proj.length;
      final pts = _convexHull([for (final p in proj) p.$1]);
      final center = pts.fold(Offset.zero, (s, p) => s + p) / pts.length.toDouble();
      final (la, _, _) = _proj(hipMid);
      final (lb, _, _) = _proj(hipMid + lat);
      var n = lb - la;
      n = n.distance < 1e-6 ? const Offset(1, 0) : n / n.distance;
      final r = pts.fold(0.0, (m, p) => math.max(m, (p - center).distance));
      items.add((
        z,
        () => canvas.drawPath(Path()..addPolygon(pts, true), cylinder(center, n, r, shade(tint, z, lit))),
      ));
    }

    final shorts = ghost ? color : Color.lerp(color, const Color(0xFF263238), 0.55)!;
    hull(chest, color, 0.08, shLat);
    hull(hips, shorts, 0, hipLat);

    // 목·머리: 머리는 뒤통수 공 + 앞아래 턱 공으로 얼굴 방향이 보이게.
    final head = sk[J.head];
    final face = sk.facing;
    capsule(neck - up * 0.02, head - up * 0.02, 0.05, 0.045, color, lit: -0.1);
    ball(head - face * 0.01, 0.1, color, zBias: 0.03);
    ball(head + face * 0.045 - up * 0.04, 0.072, color, zBias: 0.035);
    if (!ghost) {
      // 눈높이 띠: 얼굴이 향한 쪽에 짧은 선. 뒤를 보면 머리에 가려진다.
      final (p, s, z) = _proj(head + face * 0.095 + up * 0.005);
      items.add((
        z + 0.04,
        () => canvas.drawCircle(p, 0.026 * _k * s, Paint()..color = Color.lerp(dark, accent, 0.25)!),
      ));
    }

    // 팔: 위팔·아래팔은 끝으로 갈수록 가늘게, 주먹은 손목 방향으로 길쭉한 글러브.
    for (final (sh, el, ha, glow) in [
      (J.leadShoulder, J.leadElbow, J.leadHand, sk.leadGlow),
      (J.rearShoulder, J.rearElbow, J.rearHand, sk.rearGlow),
    ]) {
      ball(sk[sh], 0.06, color, zBias: 0);
      capsule(sk[sh], sk[el], 0.056, 0.042, color);
      ball(sk[el], 0.042, color, zBias: 0);
      capsule(sk[el], sk[ha], 0.042, 0.034, color);
      final dir = (sk[ha] - sk[el]).normalized;
      final glove = Color.lerp(const Color(0xFFB0BEC5), accent, ghost ? 0 : 0.25 + 0.75 * glow)!;
      capsule(sk[ha] - dir * 0.03, sk[ha] + dir * 0.035, 0.06, 0.072, glove, zBias: 0.01);
    }

    // 다리: 허벅지·정강이는 끝으로 갈수록 가늘게, 발은 신발 모양.
    for (final (hp, kn, an, toe) in [
      (J.leadHip, J.leadKnee, J.leadFoot, J.leadToe),
      (J.rearHip, J.rearKnee, J.rearFoot, J.rearToe),
    ]) {
      capsule(sk[hp], sk[kn], 0.078, 0.055, shorts == color ? color : Color.lerp(color, shorts, 0.35)!);
      ball(sk[kn], 0.056, color, zBias: 0);
      capsule(sk[kn], sk[an], 0.055, 0.038, color);
      final shoe = Color.lerp(color, const Color(0xFF37474F), 0.5)!;
      capsule(sk[an] - const V3(0, 0.02, 0), sk[toe] + const V3(0, 0.025, 0), 0.042, 0.035, shoe);
    }

    items.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, draw) in items) {
      draw();
    }
  }

  /// 2D 볼록 껍질 (monotone chain).
  static List<Offset> _convexHull(List<Offset> pts) {
    final p = [...pts]..sort((a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));
    if (p.length < 3) return p;
    double cross(Offset o, Offset a, Offset b) => (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    final lower = <Offset>[];
    for (final q in p) {
      while (lower.length >= 2 && cross(lower[lower.length - 2], lower.last, q) <= 0) {
        lower.removeLast();
      }
      lower.add(q);
    }
    final upper = <Offset>[];
    for (final q in p.reversed) {
      while (upper.length >= 2 && cross(upper[upper.length - 2], upper.last, q) <= 0) {
        upper.removeLast();
      }
      upper.add(q);
    }
    return [...lower..removeLast(), ...upper..removeLast()];
  }

  void _drawArrow(Canvas canvas, List<V3> world, Color color, double width) {
    final pts = <Offset>[];
    for (final w in world) {
      final (p, _, _) = _proj(w);
      if (pts.isEmpty || (p - pts.last).distance > 1) pts.add(p);
    }
    if (pts.length < 2) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * _k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(Path()..addPolygon(pts, false), paint);

    // 화살촉: 끝에서 조금 앞 점을 기준으로 방향을 잡는다.
    final tip = pts.last;
    final dir = tip - pts[math.max(0, pts.length - 4)];
    if (dir.distance < 1e-3) return;
    final len = 0.1 * _k;
    for (final side in [-1, 1]) {
      final a = dir.direction + math.pi + side * 0.5;
      canvas.drawLine(tip, tip + Offset(math.cos(a), math.sin(a)) * len, paint);
    }
  }

  @override
  bool shouldRepaint(FigurePainter old) =>
      old.skeleton != skeleton ||
      old.mirror != mirror ||
      old.ghost != ghost ||
      old.guides != guides ||
      old.focus != focus ||
      old.viewYaw != viewYaw ||
      old.color != color;
}
