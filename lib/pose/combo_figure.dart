import 'package:flutter/material.dart';

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
    with SingleTickerProviderStateMixin {
  static const _defaultYaw = -50.0;

  late final AnimationController _ctrl =
      AnimationController(vsync: this, value: 1);
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
      _load();
      _ctrl.value = 1; // 재생 전까지는 가드 자세
    }
    if (old.playId != widget.playId) _play();
  }

  void _load() {
    _timeline = PoseTimeline(widget.moves, tempo: widget.tempo);
    final peaks = [for (final m in widget.moves) strikePose(m)];
    _peaks = [for (final p in peaks) p.build()];
    _peakFocus = [for (final p in peaks) p.base];
    _tileGuides = [for (final m in widget.moves) motionGuides(m)];
    _guides = [
      for (var i = 0; i < widget.moves.length; i++)
        [for (final g in _tileGuides[i]) g.translated(_timeline.baseOf(i))],
    ];
    _ctrl.duration =
        Duration(milliseconds: (_timeline.duration * 1000).round());
  }

  void _play() => _ctrl.forward(from: 0);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mirror = widget.stance == Stance.southpaw;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value * _timeline.duration;
        final step = _ctrl.isAnimating ? _timeline.stepAt(t) : -1;
        final pose = _timeline.poseAt(t);
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
                      pose.build(),
                      mirror: mirror,
                      guides: step >= 0 ? _guides[step] : const [],
                      focus: pose.base,
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
