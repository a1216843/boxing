import '../models/moves.dart';
import 'mocap.dart';
import 'poses.dart';
import 'skeleton.dart';

/// 콤보 하나를 시간에 따른 뼈대로 펼친다.
///
/// 펀치는 정석 키 자세를 실제 사람의 움직임 곡선으로 재생하고([WarpedMove]), 방어는 자세 키프레임
/// ([moveAnim])을 곡선으로 보간한다. 조각이 바뀔 때 어긋남이 있으면 [_blend]초에 걸쳐 없앤다.
/// 스텝·위빙으로 옮겨 간 거리는 다음 동작에 누적되고, 콤보가 끝나면 출발점(0)으로 돌아온다.
class PoseTimeline {
  PoseTimeline(this.moves, {double tempo = 1.0}) {
    var t = 0.0;
    var base = 0.0, side = 0.0;
    List<(double, Pose)>? keys;
    var lastPose = guardPose; // 앞 동작의 끝 자세

    void closeKeys() {
      if (keys != null) _pieces.add(_Piece.pose(keys!));
      keys = null;
    }

    void openKeys() => keys ??= [(t, lastPose)];

    for (final m in moves) {
      _starts.add(t);
      _bases.add(base);
      final profile = motionProfile(m);
      if (profile != null) {
        // 펀치: 정석 키 자세를 실제 사람의 움직임 곡선으로 재생 (한 동작이 한 조각).
        final anim = moveAnim(m);
        closeKeys();
        final d = animSeconds(m) * tempo;
        // 더킹·위빙으로 낮추거나 옆으로 빠진 자세에서는 일어서지 않고 그 높이와 체중 그대로 친다 (거둘 때 가드로).
        final own = [
          (0.0, lastPose),
          for (final (f, pose) in anim.keys)
            (f, (f < 1 ? pose.leveledFrom(lastPose) : pose).translated(base, side)),
        ];
        final move = WarpedMove(own, anim.impact, profile, leadArm: m.leadHand!);
        final start = t;
        _pieces.add(_Piece(start, start + d, (x) => move.at((x - start) / d).build()));
        t += d;
        base += anim.advance;
        side += anim.side;
        lastPose = own.last.$2;
      } else {
        openKeys();
        final anim = moveAnim(m);
        final d = animSeconds(m) * tempo;
        for (final (f, pose) in anim.keys) {
          keys!.add((t + d * f, pose.translated(base, side)));
        }
        t += d;
        base += anim.advance;
        side += anim.side;
        lastPose = keys!.last.$2;
      }
    }
    _end = t;

    // 끝 자세에서 잠깐 머문 뒤 가드로 돌아온다. 그동안 걸음 없이 몸 전체가 출발점(0)으로 옮겨진다 ([at]).
    openKeys();
    keys!.add((t + 0.35, lastPose));
    keys!.add((t + 0.8, guardPose.translated(base, side)));
    _endBase = V3(side, 0, base);
    closeKeys();

    // 이음매: 각 조각 시작에서 앞 조각 끝 뼈대(첫 조각은 가드)와의 관절별 차이.
    final g = guardPose.build().joints, first = _pieces.first.raw(0).joints;
    _pieces.first.delta = [for (var j = 0; j < g.length; j++) g[j] - first[j]];
    for (var i = 1; i < _pieces.length; i++) {
      final prev = _pieces[i - 1];
      final a = _sample(i - 1, prev.end).joints, b = _pieces[i].raw(_pieces[i].start).joints;
      _pieces[i].delta = [for (var j = 0; j < a.length; j++) a[j] - b[j]];
    }
  }

  /// 조각 이음매를 지우는 시간(초).
  static const _blend = 0.15;

  final List<Move> moves;
  final List<_Piece> _pieces = [];
  final List<double> _starts = [];
  final List<double> _bases = [];
  late final double _end;
  late final V3 _endBase;

  double get duration => _pieces.last.end;

  /// 동작이 끝나는 시각 (뒤의 복귀 제외).
  double get actionEnd => _end;

  Skeleton _sample(int i, double t) {
    final p = _pieces[i];
    final s = p.raw(t);
    final d = p.delta;
    if (d == null) return s;
    final u = ((t - p.start) / _blend).clamp(0.0, 1.0);
    final w = 1 - u * u * (3 - 2 * u);
    return w <= 0 ? s : s.offset(d, w, Pose.lengths);
  }

  Skeleton at(double t) {
    var i = 0;
    while (i < _pieces.length - 1 && t >= _pieces[i].end) {
      i++;
    }
    final s = _sample(i, t);
    if (t <= _end + 0.35 || _endBase.length == 0) return s;
    final u = ((t - _end - 0.35) / 0.45).clamp(0.0, 1.0);
    return s.shifted(_endBase * -(u * u * (3 - 2 * u)));
  }

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

class _Piece {
  _Piece(this.start, this.end, this.raw);

  factory _Piece.pose(List<(double, Pose)> keys) =>
      _Piece(keys.first.$1, keys.last.$1, (t) => samplePoses(keys, t).build());

  final double start, end;
  final Skeleton Function(double t) raw;
  List<V3>? delta;
}
