import '../models/moves.dart';

part 'mocap_data.dart';

/// 실제 사람의 펀치에서 뽑은 움직임 곡선 (CMU 모션캡처 복싱 클립, tool/mocap/export.py).
///
/// 자세(가드, 임팩트 모양)는 앱의 정석 키 자세를 쓰고, 그 사이를 어떤 속도로 가는지와 부위별 순서,
/// 몸의 오르내림만 가져온다. 피험자가 복싱 선수가 아니라 자세는 엉성하지만 움직임의 결은 사람의 것이다.
/// 같은 종류 펀치 여러 개의 시간 정규화 곡선 중앙값이라 한 사람의 버릇은 묻힌다.
class MotionProfile {
  const MotionProfile._(this.riseSeconds, this.fallSeconds,
      {required this.hand, required this.hip, required this.shoulder, required this.bob});

  /// 피험자의 출발→임팩트, 임팩트→복귀 시간 중앙값(초). 복귀가 실제 선수보다 느려 재생 시간으로는 쓰지 않는다.
  final double riseSeconds, fallSeconds;

  /// 부위별 진행도. 앞 [_riseN]+1개는 출발→임팩트(0→1), 나머지는 임팩트→복귀(1→0).
  final List<double> hand, hip, shoulder;

  /// 골반 오르내림 (앱 단위, 위 +). 출발·끝은 0.
  final List<double> bob;

  /// [rise] 구간(출발→임팩트 또는 임팩트→복귀)의 정규화 시간 [u](0~1)에서 곡선 값.
  static double _sample(List<double> c, bool rise, double u) {
    final from = rise ? 0 : _riseN, n = rise ? _riseN : c.length - 1 - _riseN;
    final x = u.clamp(0.0, 1.0) * n;
    final i = x.floor().clamp(0, n - 1);
    final a = c[from + i], b = c[from + i + 1];
    return a + (b - a) * (x - i);
  }

  double handAt(bool rise, double u) => _sample(hand, rise, u);
  double hipAt(bool rise, double u) => _sample(hip, rise, u);
  double shoulderAt(bool rise, double u) => _sample(shoulder, rise, u);
  double bobAt(bool rise, double u) => _sample(bob, rise, u);
}

/// 이 펀치를 재생할 움직임 곡선. 데이터에 없는 펀치는 팔 모양이 비슷한 종류의 곡선을 빌린다
/// (바디 스트레이트 ← 같은 손 스트레이트, 어퍼컷·바디 훅 ← 훅: 팔을 굽혀 치는 펀치). 방어·발놀림은 null.
MotionProfile? motionProfile(Move m) => switch (m.id) {
      'jab' || 'jabBody' => _profiles['jab'],
      'cross' || 'rearBody' => _profiles['cross'],
      'leadHook' || 'rearHook' || 'leadBody' || 'leadUpper' || 'rearUpper' => _profiles['hook'],
      // 상급 기술도 팔을 굽혀 치는 펀치라 훅 곡선을 빌린다.
      'jumpHook' || 'checkHook' || 'overhand' => _profiles['hook'],
      _ => null,
    };
