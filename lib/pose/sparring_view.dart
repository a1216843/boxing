import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/moves.dart';
import 'figure_painter.dart';
import 'skeleton.dart';
import 'sparring.dart';

/// 콤비네이션을 상대 인형과 함께 반복 재생한다. 좌우로 끌어 시점 회전, 두 번 탭하면 원래대로.
/// [speed]가 작을수록 느리게. [playing]이 false면 그 자리에 멈춘다.
class SparringView extends StatefulWidget {
  const SparringView({
    super.key,
    required this.timeline,
    required this.stance,
    required this.speed,
    required this.playing,
    required this.onStep,
  });

  final SparringTimeline timeline;
  final Stance stance;
  final double speed;
  final bool playing;

  /// 지금 수행 중인 동작 index가 바뀔 때 (-1 = 쉬는 중).
  final ValueChanged<int> onStep;

  @override
  State<SparringView> createState() => _SparringViewState();
}

class _SparringViewState extends State<SparringView> with SingleTickerProviderStateMixin {
  /// 옆에서 조금 앞쪽으로 본 시점: 두 사람 사이 거리와 주먹이 닿는 모습이 잘 보인다.
  static const _defaultYaw = -72.0;

  /// 한 번 끝나고 다시 시작하기 전 쉬는 시간(초).
  static const _pause = 1.0;

  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  double _t = 0;
  int _step = -1;
  double _viewYaw = _defaultYaw;
  V3? _focus;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void didUpdateWidget(SparringView old) {
    super.didUpdateWidget(old);
    if (old.timeline != widget.timeline) _t = 0;
  }

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (!widget.playing) return;
    setState(() {
      _t += dt.clamp(0.0, 0.1) * widget.speed;
      if (_t > widget.timeline.duration + _pause) _t = 0;
    });
    final step = widget.timeline.stepAt(_t);
    if (step != _step) {
      _step = step;
      widget.onStep(step);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tl = widget.timeline;
    final t = math.min(_t, tl.duration);
    final me = tl.meAt(t), opp = tl.opponentAt(t);
    final target = sparringFocus(me, opp);
    _focus = _focus == null ? target : V3.lerp(_focus!, target, 0.15);
    // 관절 좌표는 거울에 비친 오소독스라 오소독스는 좌우를 뒤집어 그린다 (콤보 그림과 같은 규칙).
    final mirror = widget.stance == Stance.orthodox;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) => setState(() => _viewYaw += (mirror ? -1 : 1) * d.delta.dx * 0.5),
      onDoubleTap: () => setState(() => _viewYaw = _defaultYaw),
      child: ClipRect(
        child: CustomPaint(
          size: Size.infinite,
          painter: FigurePainter(
            me,
            opponent: opp,
            mirror: mirror,
            focus: _focus!,
            viewYaw: _viewYaw,
            elevation: 12,
            zoom: 0.62,
          ),
        ),
      ),
    );
  }
}
