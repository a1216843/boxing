import '../models/moves.dart';
import 'poses.dart';
import 'skeleton.dart';
import 'timeline.dart';

/// 콤비네이션을 마주 선 상대와 함께 펼친다 (콤비네이션 보기).
///
/// 내 인형은 미트 콜과 같은 [PoseTimeline]을 그대로 쓴다. 상대 인형은 그 동작에 맞춰 반응한다:
/// - 내가 치면 맞는다. 임팩트 순간 주먹이 오던 방향으로 머리가 젖혀지거나 돌아가고, 바디는 몸이 접힌다.
/// - 내가 피하면 그 회피가 노리는 펀치를 친다 (리어 쪽 슬립·스웨이·백스텝 ← 잽, 리드 쪽 슬립 ← 스트레이트,
///   더킹 ← 스트레이트(잽·투), 위빙 ← 날아오는 쪽 훅: 상대 뒷손 훅이면 리드 쪽, 앞손 훅이면 리어 쪽 위빙). 내 머리가 빠지는 순간 주먹이 원래 머리 자리를 지나간다.
///
/// 상대는 내 인형 좌표의 앞쪽 [_distance]에 180° 돌아 서 있고 같은 스탠스다. 거리는 동작마다 주먹이 닿도록
/// 맞추고, 그 사이는 부드럽게 옮겨 간다 (상대가 따라 들어오거나 물러나는 모습).
class SparringTimeline {
  SparringTimeline(this.moves, {double tempo = 1.0}) : me = PoseTimeline(moves, tempo: tempo) {
    _build(tempo);
  }

  /// 시작 전에 두 인형이 마주 서 있는 시간(초). 첫 동작이 회피여도 상대 펀치가 먼저 나갈 수 있게.
  static const lead = 0.6;

  final List<Move> moves;
  final PoseTimeline me;

  final List<(double, Pose)> _keys = [(0, guardPose)];
  final List<(double, Frame)> _roots = [];

  /// 단계별 상대 행동: 맞은 곳 또는 상대가 친 펀치.
  final List<(String?, Move?)> _reactions = [];

  /// [i]번째 동작에 상대가 한 일 (화면 표시용). 반응이 없으면 null.
  /// 상대는 내 설정 스탠스와 같은 스탠스로 서 있다 (화면 전체가 거울로 그려지므로).
  String? opponentCall(int i, Stance stance) {
    final (text, attack) = _reactions[i];
    if (attack == null) return text;
    final name = attack.id == 'cross' ? '스트레이트' : attack.call(stance, CallStyle.name);
    return '상대 $name';
  }

  late final double duration;

  Skeleton meAt(double t) => me.at(t - lead);

  Skeleton opponentAt(double t) => samplePoses(_keys, t).build().transformed(_rootAt(t));

  /// 상대가 선 자리와 방향 (상대 가드 좌표 → 화면 좌표).
  Frame opponentPlaceAt(double t) => _rootAt(t);

  /// [t] 시점에 수행 중인 내 동작 index (없으면 -1).
  int stepAt(double t) => me.stepAt(t - lead);

  void _build(double tempo) {
    final g = guardPose.build();
    final headZ = g[J.head].z;
    final ox = 2 * g[J.head].x;

    Frame root(Frame place, double distance) =>
        place.then(Frame.translation(ox, distance)).then(Frame.rotation(180, V3.zero));

    // 잽이 닿는 거리를 기본으로.
    double reach(Move om) => strikePose(om).build()[om.leadHand! ? J.leadHand : J.rearHand].z;
    final rest = headZ + reach(Moves.jab) + _contact;
    var distance = rest;
    _roots.add((0, root(Frame.identity, rest)));

    // 점프 훅으로 각을 잡히면 상대는 그 콤보 동안 원래 방향을 보고 있다 (나를 따라 돌아서지 않는다).
    // 체크 훅으로 내가 다시 돌면 풀린다.
    double? lock;
    Frame faced(Frame f) => lock == null ? f : Frame.rigid(lock, f.ox, f.oz);

    for (var i = 0; i < moves.length; i++) {
      final m = moves[i];
      final start = lead + me.startOf(i), sec = me.secondsOf(i);
      if (m.isPunch) {
        final t = lead + me.impactOf(i);
        final s = me.at(t - lead);
        final hand = s.leadGlow >= s.rearGlow ? J.leadHand : J.rearHand;
        final body = m.type == MoveType.body;
        final check = m.id == 'checkHook';
        if (check) lock = null;
        if (m.id == 'jumpHook') lock = _roots.last.$2.angle;
        // 상대는 내 주먹이 닿는 자리에 선다: 맞는 곳(머리·몸통, 체크 훅이면 돌진해 들어온 머리)이 주먹 바로 앞.
        // 방향은 나를 마주 보거나, 각을 잡혔으면 원래 방향 그대로.
        final rush = _rushPose.build();
        final targetLocal = check ? rush[J.head] : body ? V3.lerp(g[J.pelvis], g[J.neck], 0.6) : g[J.head];
        final reachDir = s[hand] - s[J.neck];
        final flat = V3(reachDir.x, 0, reachDir.z).normalized;
        final at = s[hand] + flat * _contact;
        final angle = lock ?? root(me.placeOf(i), distance).angle;
        final turnedTarget = Frame.rigid(angle, 0, 0).apply(targetLocal);
        final r = Frame.rigid(angle, at.x - turnedTarget.x, at.z - turnedTarget.z);
        distance = me.placeOf(i).inverse.apply(V3(r.ox, 0, r.oz)).z;
        _roots.add((t, r));
        // 주먹이 들어오던 방향 (상대 몸 기준).
        final v = r.inverse.applyDir(s[hand] - me.at(t - lead - 0.04)[hand]);
        final push = v.length < 1e-6 ? const V3(0, 0, -1) : v.normalized;
        if (check) {
          // 돌진: 체크 훅이 시작될 때 뒷발로 차고 들어오며 앞손을 뻗는다.
          _event(start - 0.15, [(t - 0.03, _rushPose)]);
          // 맞고도 들어오던 힘에 앞으로 고꾸라지며, 옆으로 돌아 빠진 내 원래 자리를 지나간다.
          // 다음 동작까지 그 방향 그대로 있다가 (아래 루트 키) 다시 나를 향해 돌아선다.
          _event(t - 0.03, [
            (t + 0.1, _stumble(push, 0.5)),
            (t + 0.35, _stumble(push, 1)),
            (t + 0.8, guardPose.feet(_stumbleStep, _stumbleStep, leadX: _stumbleSide, rearX: _stumbleSide)),
          ]);
          _roots.add((start + sec, r));
        } else {
          _event(t - 0.03, [
            (t + 0.07, _hitPose(push, body: body, upper: m.type == MoveType.uppercut)),
            (t + 0.16, _hitPose(push, body: body, upper: m.type == MoveType.uppercut)),
            (t + 0.5, guardPose),
          ]);
        }
        _reactions.add((check ? '돌진하다 맞음' : body ? '바디 맞음' : '맞음', null));
      } else if (m.isDefense) {
        final om = _attackFor(m);
        // 머리가 가장 깊이 빠진 순간에 상대 주먹이 지나간다.
        final t = start + sec * _evadeAt(m);
        final anim = moveAnim(om);
        final os = animSeconds(om) * tempo;
        final ts = t - anim.impact * os;
        // 상대 주먹이 내 원래 머리 자리에 닿는 거리. 훅은 얼굴 조금 앞을 쓸고 지나가게 한 뼘 멀리.
        distance = headZ + reach(om) + (om.type == MoveType.hook ? 0.2 : 0.03);
        final r = faced(root(me.placeOf(i), distance));
        _roots.add((t, r));
        // 상대는 피하기 시작할 때 내 머리가 있던 곳을 노린다 (앞 회피로 옆에 빠져 있으면 그쪽으로).
        // 더킹엔 머리 높이로 곧게 뻗는 스트레이트를 보여 준다 (낮춘 머리 위로 지나가게 조금 높게).
        final head = r.inverse.apply(me.at(start - lead)[J.head]);
        final fistX = strikePose(om).build()[om.leadHand! ? J.leadHand : J.rearHand].x;
        final aim = V3((head.x - fistX).clamp(-0.3, 0.3), m.type == MoveType.duck ? 0.11 : 0, 0);
        _event(ts, [
          for (final (f, pose) in anim.keys)
            (ts + f * os, f >= 1 ? guardPose : pose.handShifted(om.leadHand!, aim.rotY(-pose.yaw))),
        ]);
        _reactions.add((null, om));
      } else {
        _reactions.add((null, null));
      }
    }

    final end = lead + me.duration;
    _roots.add((lead + me.actionEnd, _roots.last.$2));
    _roots.add((end, root(Frame.identity, rest)));
    duration = end + 0.2;
    if (_keys.last.$1 < duration) _keys.add((duration, guardPose));
  }

  /// 상대 키에 [keys]를 이어 붙인다. [from] 이후의 남은 키(앞 반응의 회복 등)는 끊고, 그 순간의 자세에서 출발한다.
  void _event(double from, List<(double, Pose)> keys) {
    final now = samplePoses(_keys, from);
    _keys.removeWhere((k) => k.$1 >= from);
    _keys.add((from, now));
    for (final k in keys) {
      if (k.$1 > _keys.last.$1 + 1e-6) _keys.add(k);
    }
  }

  Frame _rootAt(double t) {
    if (t <= _roots.first.$1) return _roots.first.$2;
    for (var i = 1; i < _roots.length; i++) {
      final (t1, f1) = _roots[i];
      if (t <= t1) {
        final (t0, f0) = _roots[i - 1];
        if (t1 - t0 < 1e-9) return f1;
        final u = (t - t0) / (t1 - t0);
        return Frame.lerpRigid(f0, f1, u * u * (3 - 2 * u));
      }
    }
    return _roots.last.$2;
  }

  /// 체크 훅에 돌진해 들어오는 자세: 뒷발로 차고 크게 내딛으며 상체를 숙이고 앞손을 뻗는다.
  static final _rushPose =
      Pose(lead: Arm.straight, yaw: 45, hipYaw: 25, pitch: 12, shiftZ: 0.08, rearHeel: 0.8).feet(0.28, 0.12);

  /// 체크 훅을 맞고 고꾸라지며 내딛는 거리. 옆으로 빠진 나를 지나치도록 자기 리드 쪽(내가 빠진 반대쪽)으로 쏠린다.
  static const _stumbleStep = 0.38;
  static const _stumbleSide = -0.2;

  /// 맞고 앞으로 고꾸라지는 자세 ([u] = 0~1 진행). 훅이 온 쪽 반대로 돌아가며 앞으로 쏠린다.
  static Pose _stumble(V3 push, double u) {
    final side = push.x.clamp(-1.0, 1.0);
    return Pose(
      yaw: 30 - 35 * side * u,
      roll: 18 * side * u,
      pitch: 12 + 10 * u,
      drop: 0.05 * u,
      shiftZ: 0.06,
    ).feet(0.28 + (_stumbleStep - 0.28) * u, 0.12 + (_stumbleStep - 0.12) * u,
        leadX: _stumbleSide * u, rearX: _stumbleSide * u);
  }

  /// 주먹이 닿는 거리 여유 (글러브 반지름 + 머리 반지름쯤).
  static const _contact = 0.12;

  /// 맞은 자세. [push]는 상대 몸 기준 주먹 방향 (+z = 상대 정면 = 나를 향함, 그러니 뒤로 밀리면 z < 0).
  static Pose _hitPose(V3 push, {required bool body, required bool upper}) {
    final side = push.x.clamp(-1.0, 1.0), back = (-push.z).clamp(0.0, 1.0);
    if (body) {
      // 바디: 몸이 접히며 앞으로 숙이고 무릎이 꺾인다. 맞은 쪽으로 살짝 기운다.
      return Pose(pitch: 22, drop: 0.08, shiftZ: -0.04, roll: 10 * side, yaw: 30 + 10 * side);
    }
    // 머리: 주먹이 오던 쪽으로 젖혀지고 돌아간다. 어퍼는 턱이 들리며 뒤로.
    return Pose(
      pitch: upper ? -24 : -16 * back - 4,
      roll: 22 * side,
      yaw: 30 - 28 * side,
      shiftX: 0.04 * side,
      shiftZ: -0.05 * back - 0.01,
      drop: 0.02,
    );
  }

  static double _evadeAt(Move defense) => switch (defense.type) {
        // 머리가 이미 내려간 뒤에 머리 자리를 지나가게 (훅은 옆에서 쓸고 들어오므로 특히 늦게).
        MoveType.duck => 0.9,
        MoveType.weave => 0.7,
        MoveType.slip => 0.7,
        _ => 0.75,
      };

  static Move _attackFor(Move defense) => switch (defense.id) {
        'slipLead' => Moves.cross,
        // 위빙은 훅이 날아오는 쪽으로 머리를 숙여 그 밑을 지나간다: 상대 뒷손 훅(내 리드 쪽에서 옴) ← 리드 쪽 위빙,
        // 상대 앞손 훅(내 리어 쪽에서 옴) ← 리어 쪽 위빙.
        'weaveLead' => Moves.rearHook,
        'weaveRear' => Moves.leadHook,
        // 더킹은 자세를 낮춰 머리 높이로 오는 스트레이트를 흘려보낸다 (빠지는 쪽은 슬립과 같은 짝).
        'duckLead' => Moves.cross,
        _ => Moves.jab, // 리어 쪽 슬립·더킹, 스웨이, 백스텝
      };
}

/// 두 인형 사이 바닥 지점 (카메라가 바라볼 곳).
V3 sparringFocus(Skeleton me, Skeleton opponent) {
  final a = me[J.pelvis], b = opponent[J.pelvis];
  return V3((a.x + b.x) / 2, 0, (a.z + b.z) / 2);
}
