import '../models/moves.dart';
import 'poses.dart';
import 'skeleton.dart';

/// 콤보 하나를 자세 키프레임으로 펼친다 (동작별 키는 [moveAnim]).
/// 스텝으로 나간 거리는 다음 동작에 누적된다.
/// [holds]가 있으면 i번째 동작 앞에서 그만큼 자세를 멈췄다가 이어 친다 (끊어 부른 콜).
class PoseTimeline {
  PoseTimeline(this.moves, {double tempo = 1.0, List<double>? holds}) {
    var t = 0.0;
    var base = 0.0;
    _keys.add((0, guardPose));
    for (var i = 0; i < moves.length; i++) {
      final m = moves[i];
      final hold = holds == null ? 0.0 : holds[i];
      if (hold > 0) {
        t += hold;
        _keys.add((t, _keys.last.$2));
      }
      final anim = moveAnim(m);
      final d = animSeconds(m) * tempo;
      _starts.add(t);
      _bases.add(base);
      for (final (f, pose) in anim.keys) {
        _keys.add((t + d * f, pose.translated(base)));
      }
      t += d;
      base += anim.advance;
    }
    _end = t;
    _keys.add((t + 0.35, _keys.last.$2));
    _keys.add((t + 0.8, guardPose.translated(base)));
  }

  final List<Move> moves;
  final List<(double, Pose)> _keys = [];
  final List<double> _starts = [];
  final List<double> _bases = [];
  late final double _end;

  double get duration => _keys.last.$1;

  Pose poseAt(double t) => samplePoses(_keys, t);

  Skeleton at(double t) => poseAt(t).build();

  /// [i]번째 동작이 시작되는 발 위치 (앞뒤 누적 이동).
  double baseOf(int i) => _bases[i];

  /// [t] 시점에 수행 중인 동작 index. 시작 전이나 끝난 뒤는 -1.
  int stepAt(double t) {
    if (t < 0 || t >= _end) return -1;
    for (var i = _starts.length - 1; i >= 0; i--) {
      if (t >= _starts[i]) return i;
    }
    return -1;
  }
}
