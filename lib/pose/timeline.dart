import '../models/moves.dart';
import 'mocap.dart';
import 'poses.dart';
import 'skeleton.dart';

/// 콤보 하나를 시간에 따른 뼈대로 펼친다.
///
/// 펀치는 정석 키 자세를 실제 사람의 움직임 곡선으로 재생하고([WarpedMove]), 방어는 자세 키프레임
/// ([moveAnim])을 곡선으로 보간한다. 조각이 바뀔 때 어긋남이 있으면 [_blend]초에 걸쳐 없앤다.
/// 스텝·위빙으로 옮겨 간 거리는 다음 동작에 누적되고, 콤보가 끝나면 출발점(0)으로 돌아온다.
///
/// 체크 훅·점프 훅으로 돈 방향은 [Frame]으로 이어 간다: 뒤 동작은 원래 좌표로 만들고 그 변환을 씌운다.
/// 콤보가 끝나면 돈 방향과 거리를 걸음 없이 되돌린다.
class PoseTimeline {
  PoseTimeline(this.moves, {double tempo = 1.0}) {
    var t = 0.0;
    var base = 0.0, side = 0.0;
    var frame = Frame.identity;
    List<(double, Pose)>? keys;
    var lastPose = guardPose; // 앞 동작의 끝 자세 (지금 좌표)

    void closeKeys() {
      if (keys != null) _pieces.add(_Piece.pose(keys!, frame));
      keys = null;
    }

    void openKeys() => keys ??= [(t, lastPose)];

    // 몸 전체가 돈 동작 뒤: 좌표를 돌리고, 끝 자세를 새 좌표로 다시 나타낸다.
    void reframe(MoveAnim anim) {
      if (anim.turn == 0) return;
      closeKeys();
      // 앞발 앞꿈치 축 (동작으로 옮겨 간 위치 기준).
      frame = frame.then(Frame.rotation(anim.turn, V3(-0.14 + side, 0, 0.38 + base)));
      lastPose = anim.after!.translated(base, side);
    }


    for (final m in moves) {
      _starts.add(t);
      _seconds.add(animSeconds(m) * tempo);
      _places.add(frame.then(Frame.translation(side, base)));
      _bases.add(base);
      final profile = motionProfile(m);
      final anim = moveAnim(m);
      if (profile != null) {
        // 펀치: 정석 키 자세를 실제 사람의 움직임 곡선으로 재생 (한 동작이 한 조각).
        closeKeys();
        final d = animSeconds(m) * tempo;
        // 더킹·위빙으로 낮추거나 옆으로 빠진 자세에서는 일어서지 않고 그 높이와 체중 그대로 친다 (거둘 때 가드로).
        final own = [
          (0.0, lastPose),
          for (final (f, pose) in anim.keys)
            (f, (f < 1 ? pose.leveledFrom(lastPose) : pose).translated(base, side)),
        ];
        final move = WarpedMove(own, anim.impact, profile, leadArm: m.leadHand!);
        final start = t, f = frame;
        _pieces.add(_Piece(start, start + d, (x) => move.at((x - start) / d).build().transformed(f)));
        t += d;
        base += anim.advance;
        side += anim.side;
        lastPose = own.last.$2;
      } else {
        openKeys();
        final d = animSeconds(m) * tempo;
        for (final (f, pose) in anim.keys) {
          keys!.add((t + d * f, pose.translated(base, side)));
        }
        t += d;
        base += anim.advance;
        side += anim.side;
        lastPose = keys!.last.$2;
      }
      reframe(anim);
      _placesAfter.add(frame.then(Frame.translation(side, base)));
    }

    _end = t;

    // 끝 자세에서 잠깐 머문 뒤 가드로 돌아온다. 그동안 걸음 없이 몸 전체가 출발점(0)으로 옮겨진다 ([at]).
    openKeys();
    keys!.add((t + 0.35, lastPose));
    keys!.add((t + 0.8, guardPose.translated(base, side)));
    _endFrame = frame;
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
  final List<Frame> _places = [];
  final List<Frame> _placesAfter = [];
  final List<double> _seconds = [];
  late final double _end;
  late final V3 _endBase;
  late final Frame _endFrame;

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
    if (t <= _end + 0.35 || (_endBase.length == 0 && _endFrame.isIdentity)) return s;
    final u = ((t - _end - 0.35) / 0.45).clamp(0.0, 1.0);
    final e = u * u * (3 - 2 * u);
    // 끝 좌표를 풀고, 앞뒤·옆 이동을 덜어 낸 뒤, 돈 방향을 같은 비율로 되돌린다.
    final undo = _endFrame.fadedOut(e).then(Frame.translation(-_endBase.x * e, -_endBase.z * e)).then(_endFrame.inverse);
    return s.transformed(undo);
  }

  /// [i]번째 동작이 시작되는 발 위치 (지금 좌표의 앞뒤 누적 이동).
  double baseOf(int i) => _bases[i];

  /// [i]번째 동작을 원래 스탠스의 가드 자리 좌표에서 화면 좌표로 옮기는 변환 (안내 화살표용).
  Frame placeOf(int i) => _places[i];

  /// [i]번째 동작을 마친 뒤의 변환 (체크 훅·점프 훅으로 돈 방향 포함).
  Frame placeAfter(int i) => _placesAfter[i];

  /// [i]번째 동작이 시작되는 시각과 걸리는 시간(초).
  double startOf(int i) => _starts[i];
  double secondsOf(int i) => _seconds[i];

  /// [i]번째 동작의 임팩트(방어는 다 빠진) 시각.
  double impactOf(int i) => _starts[i] + _seconds[i] * moveAnim(moves[i]).impact;

  /// [t] 시점에 수행 중인 동작 index. 시작 전이나 끝난 뒤는 -1.
  int stepAt(double t) {
    if (t < 0 || t >= _end) return -1;
    for (var i = _starts.length - 1; i >= 0; i--) {
      if (t >= _starts[i]) return i < moves.length ? i : -1;
    }
    return -1;
  }
}

class _Piece {
  _Piece(this.start, this.end, this.raw);

  factory _Piece.pose(List<(double, Pose)> keys, Frame frame) =>
      _Piece(keys.first.$1, keys.last.$1, (t) => samplePoses(keys, t).build().transformed(frame));

  final double start, end;
  final Skeleton Function(double t) raw;
  List<V3>? delta;
}
