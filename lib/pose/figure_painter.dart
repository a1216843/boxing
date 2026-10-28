import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'poses.dart';
import 'skeleton.dart';

/// 스켈레톤을 입체 인형으로 그린다.
///
/// 원근 카메라가 [focus](두 발 사이 바닥)를 바라보며 따라가고, 바닥 격자가 월드에 고정돼 있어
/// 스텝으로 이동하면 격자가 흘러간다. 기본 시점은 리드 쪽(화면 왼쪽)을 향해 약간 위에서 본 3/4.
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
    this.viewYaw = -50,
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

  static const _centerY = 0.95;
  static const _camDist = 3.6;
  static const _limbWidth = 0.09;
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

    for (var i = -6; i <= 6; i++) {
      final fade = i.abs() / 6;
      line(V3(cx + i * step, 0, focus.z - reach), V3(cx + i * step, 0, focus.z + reach), fade);
      line(V3(focus.x - reach, 0, cz + i * step), V3(focus.x + reach, 0, cz + i * step), fade);
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

  void _drawFigure(Canvas canvas, Skeleton sk, {bool ghost = false}) {
    final items = <(double, VoidCallback)>[];
    final base = ghost ? color.withAlpha(40) : color;
    final dark = ghost ? color.withAlpha(25) : Color.lerp(color, Colors.black, 0.55)!;

    // 깊이 음영: 멀수록 어둡게. [lit]만큼 더 밝게/어둡게.
    Color shade(double z, [double lit = 0]) =>
        ghost ? base : Color.lerp(dark, base, ((z + 0.5) / 1.0 + lit).clamp(0.0, 1.0))!;

    // 팔다리: 어두운 테두리 위에 밝은 심을 빛 쪽으로 살짝 밀어 그려 원기둥처럼 보이게.
    void limb(J a, J b, [double width = _limbWidth]) {
      final (pa, sa, za) = _proj(sk[a]);
      final (pb, sb, zb) = _proj(sk[b]);
      final z = (za + zb) / 2;
      final w = width * _k * (sa + sb) / 2;
      items.add((
        z,
        () {
          final cap = Paint()..strokeCap = StrokeCap.round;
          canvas.drawLine(pa, pb, cap..color = shade(z, -0.25)..strokeWidth = w);
          if (!ghost) {
            final off = _light * (w * 0.15);
            canvas.drawLine(pa + off, pb + off, cap..color = shade(z, 0.15)..strokeWidth = w * 0.55);
          }
        },
      ));
    }

    // 구(머리·주먹): 빛 쪽이 밝은 방사형 그라디언트.
    void ball(V3 at, double radius, Color tint) {
      final (p, s, z) = _proj(at);
      final r = radius * _k * s;
      items.add((
        z + 0.02,
        () {
          final paint = Paint();
          if (ghost) {
            paint.color = base;
          } else {
            paint.shader = RadialGradient(
              center: Alignment(_light.dx * 0.6, _light.dy * 0.6),
              colors: [Color.lerp(tint, Colors.white, 0.35)!, tint, Color.lerp(tint, Colors.black, 0.5)!],
              stops: const [0, 0.55, 1],
            ).createShader(Rect.fromCircle(center: p, radius: r));
          }
          canvas.drawCircle(p, r, paint);
        },
      ));
    }

    // 몸통: 가슴과 골반 두 덩어리로 나눠 비틀림이 보이게. 화면에 보이는 면이 앞면이면 밝게.
    final waistLead = V3.lerp(sk[J.leadHip], sk[J.leadShoulder], 0.42);
    final waistRear = V3.lerp(sk[J.rearHip], sk[J.rearShoulder], 0.42);
    void panel(List<V3> corners, double lit) {
      final pts = corners.map(_proj).toList();
      final z = pts.fold(0.0, (sum, c) => sum + c.$3) / pts.length;
      final offsets = [for (final c in pts) c.$1];
      var area = 0.0;
      for (var i = 0; i < offsets.length; i++) {
        final a = offsets[i], b = offsets[(i + 1) % offsets.length];
        area += a.dx * b.dy - b.dx * a.dy;
      }
      final front = (area > 0) != mirror;
      items.add((
        z,
        () {
          final path = Path()..addPolygon(offsets, true);
          final paint = Paint()..color = shade(z, front ? lit : lit - 0.35);
          canvas.drawPath(path, paint);
          canvas.drawPath(
            path,
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.05 * _k
              ..strokeJoin = StrokeJoin.round,
          );
        },
      ));
    }

    panel([sk[J.leadShoulder], sk[J.rearShoulder], waistRear, waistLead], 0.1);
    panel([waistLead, waistRear, sk[J.rearHip], sk[J.leadHip]], -0.05);

    limb(J.neck, J.head, 0.07);
    limb(J.leadShoulder, J.leadElbow);
    limb(J.leadElbow, J.leadHand);
    limb(J.rearShoulder, J.rearElbow);
    limb(J.rearElbow, J.rearHand);
    limb(J.leadHip, J.leadKnee, 0.11);
    limb(J.leadKnee, J.leadFoot);
    limb(J.rearHip, J.rearKnee, 0.11);
    limb(J.rearKnee, J.rearFoot);
    limb(J.leadFoot, J.leadToe, 0.07);
    limb(J.rearFoot, J.rearToe, 0.07);

    final head = sk[J.head];
    ball(head, 0.115, Color.lerp(dark, color, 0.85)!);
    // 얼굴 방향 표시: 머리 앞쪽 작은 점. 머리 뒤로 돌면 머리에 가려진다.
    if (!ghost) {
      final (p, s, z) = _proj(head + sk.facing * 0.1 + const V3(0, -0.01, 0));
      items.add((
        z + 0.03,
        () => canvas.drawCircle(p, 0.035 * _k * s, Paint()..color = Color.lerp(dark, accent, 0.35)!),
      ));
    }
    ball(sk[J.leadHand], 0.075, Color.lerp(color, accent, ghost ? 0 : sk.leadGlow)!);
    ball(sk[J.rearHand], 0.075, Color.lerp(color, accent, ghost ? 0 : sk.rearGlow)!);

    items.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, draw) in items) {
      draw();
    }
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
