import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/moves.dart';
import 'figure_painter.dart';
import 'poses.dart';
import 'skeleton.dart';
import 'timeline.dart';

/// 위: 콤보를 이어서 움직이는 큰 인형 (좌우로 끌어 시점 회전, 두 번 탭하면 원래대로).
/// 아래: 단계별 정점 자세, 지금 단계 강조.
class ComboFigure extends StatefulWidget {
  const ComboFigure({
    super.key,
    required this.moves,
    required this.stance,
    required this.callStyle,
    required this.tempo,
    required this.playId,
  });

  final List<Move> moves;
  final Stance stance;
  final CallStyle callStyle;
  final double tempo;

  /// 바뀔 때마다 처음부터 재생한다 (콜을 다 읽은 순간).
  final int playId;

  @override
  State<ComboFigure> createState() => _ComboFigureState();
}

class _ComboFigureState extends State<ComboFigure>
    with TickerProviderStateMixin {
  static const _defaultYaw = -30.0;

  late final AnimationController _ctrl =
      AnimationController(vsync: this)..addStatusListener(_onStatus);

  /// 가드 리듬용 시계(초). 콤보 재생과 상관없이 계속 흐른다.
  final ValueNotifier<double> _clock = ValueNotifier(0);
  late final Ticker _ticker = createTicker((d) => _clock.value = d.inMicroseconds / 1e6)..start();
  double _playAt = -10, _endAt = -10, _rhythmAtPlay = 1;

  /// 카메라가 바라보는 지점. 스텝을 따라 살짝 늦게 미끄러진다.
  V3 _camFocus = focusOf(_guard);

  /// 콤보는 출발점(0)의 가드에서 시작해 끝나면 다시 0으로 돌아온다. 돌아오기 전에 새 콤보가 시작되면
  /// 화면에 있던 자세와의 관절별 차이를 [_carry]초에 걸쳐 없애며 이어 간다 (순간이동 없이).
  List<V3>? _from;
  double _fromAt = 0;
  Skeleton _shown = _guard;
  static const _carry = 0.3;
  double _camAt = 0;
  late PoseTimeline _timeline;
  late List<Skeleton> _peaks;
  late List<V3> _peakFocus;

  /// 단계 그림용 (가드 위치 기준) / 큰 인형용 (콤보 안에서 앞으로 나간 만큼 옮김).
  late List<List<Guide>> _tileGuides;
  late List<List<Guide>> _guides;
  double _viewYaw = _defaultYaw;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ComboFigure old) {
    super.didUpdateWidget(old);
    if (old.moves != widget.moves || old.tempo != widget.tempo) {
      _ctrl.value = 0; // 재생 전까지는 가드 자세
      _load();
      _keepPlace();
    }
    if (old.playId != widget.playId) _play();
  }

  void _load() {
    _timeline = PoseTimeline(widget.moves, tempo: widget.tempo);
    _peaks = [for (final m in widget.moves) peakSkeleton(m)];
    _peakFocus = [for (final p in _peaks) focusOf(p)];
    _tileGuides = [for (final m in widget.moves) motionGuides(m)];
    _guides = [
      for (var i = 0; i < widget.moves.length; i++)
        [for (final g in _tileGuides[i]) g.translated(_timeline.baseOf(i))],
    ];
    _ctrl.duration =
        Duration(milliseconds: (_timeline.duration * 1000).round());
  }

  void _play() {
    _rhythmAtPlay = _rhythm(_clock.value);
    _playAt = _clock.value;
    _ctrl.value = 0;
    _keepPlace();
    _ctrl.forward(from: 0);
  }

  /// 지금 화면의 자세에서 새 타임라인 자세로 이어지도록 차이를 기억한다.
  void _keepPlace() {
    final next = _timeline.at(_ctrl.value * _timeline.duration).joints;
    _from = [for (var i = 0; i < next.length; i++) _shown.joints[i] - next[i]];
    _fromAt = _clock.value;
  }

  Skeleton _carried(Skeleton s, double now) {
    final d = _from;
    if (d == null) return s;
    final u = ((now - _fromAt) / _carry).clamp(0.0, 1.0);
    return u >= 1 ? s : s.offset(d, 1 - u * u * (3 - 2 * u), Pose.lengths);
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) _endAt = _clock.value;
  }

  /// 리듬 세기: 동작이 시작되면 0.15초 안에 빠지고, 끝나면 0.6초에 걸쳐 돌아온다.
  double _rhythm(double now) {
    if (_ctrl.isAnimating) return _rhythmAtPlay * math.max(0, 1 - (now - _playAt) / 0.15);
    final u = ((now - _endAt) / 0.6).clamp(0.0, 1.0);
    return u * u * (3 - 2 * u);
  }

  /// 가드 리듬(가볍게 오르내리고 좌우로 체중 이동)을 관절별 차이로 얹는다.
  static Skeleton _withRhythm(Skeleton s, double now, double amount) {
    if (amount <= 0) return s;
    final r = withRhythm(guardPose, now, amount).build().joints;
    return s.offset([for (var i = 0; i < r.length; i++) r[i] - _guard.joints[i]], 1, Pose.lengths);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 관절 좌표는 거울에 비친 오소독스라, 그대로 그리면 마주 보는 사람에겐 사우스포로 보인다.
    // 오소독스는 좌우를 뒤집어 실제 오소독스로 보이게 하고, 사우스포는 그대로 그린다.
    final mirror = widget.stance == Stance.orthodox;
    return AnimatedBuilder(
      animation: Listenable.merge([_ctrl, _clock]),
      builder: (context, _) {
        final t = _ctrl.value * _timeline.duration;
        final step = _ctrl.isAnimating ? _timeline.stepAt(t) : -1;
        final now = _clock.value;
        final skeleton = _carried(_withRhythm(_timeline.at(t), now, _rhythm(now)), now);
        _shown = skeleton;
        final follow = 1 - math.exp(-(now - _camAt).clamp(0.0, 0.1) * 6);
        _camFocus = V3.lerp(_camFocus, focusOf(skeleton), follow);
        _camAt = now;
        return Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) => setState(
                    () => _viewYaw += (mirror ? -1 : 1) * d.delta.dx * 0.5),
                onDoubleTap: () => setState(() => _viewYaw = _defaultYaw),
                // 바닥 격자가 영역 밖(단계 그림 위)까지 번지지 않도록.
                child: ClipRect(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: FigurePainter(
                      skeleton,
                      mirror: mirror,
                      guides: step >= 0 ? _guides[step] : const [],
                      focus: _camFocus,
                      viewYaw: _viewYaw,
                      zoom: 0.7,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.moves.length; i++)
                    Flexible(
                      child: _StepTile(
                        skeleton: _peaks[i],
                        focus: _peakFocus[i],
                        guides: _tileGuides[i],
                        defense: widget.moves[i].isDefense,
                        label: widget.moves[i]
                            .call(widget.stance, widget.callStyle),
                        active: i == step,
                        mirror: mirror,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

final _guard = guardPose.build();

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.skeleton,
    required this.focus,
    required this.guides,
    required this.defense,
    required this.label,
    required this.active,
    required this.mirror,
  });

  final Skeleton skeleton;
  final V3 focus;
  final List<Guide> guides;

  /// 방어 동작이면 출발 가드 자세를 흐리게 겹쳐 그린다.
  final bool defense;
  final String label;
  final bool active;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 90,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:
            active ? scheme.primary.withAlpha(60) : Colors.white.withAlpha(12),
        border: Border.all(
            color: active ? scheme.primary : Colors.transparent, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: FigurePainter(
                skeleton,
                mirror: mirror,
                guides: guides,
                ghost: defense ? _guard : null,
                focus: focus,
                // 바디샷처럼 깊게 내딛는 동작도 주먹이 잘리지 않게.
                zoom: 0.85,
                floor: false,
              ),
            ),
          ),
          FittedBox(
            child: Text(label,
                maxLines: 1,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
