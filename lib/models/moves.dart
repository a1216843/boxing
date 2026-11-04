/// 복싱 동작과 자세(체중) 전이 규칙.
///
/// 동작은 스탠스와 무관하게 리드(앞손)/리어(뒷손) 기준으로 정의하고,
/// 읽어줄 문구를 만들 때만 스탠스에 맞춰 레프트/라이트로 바꾼다.
/// 오소독스 기준: 리드 = 왼쪽, 리어 = 오른쪽.
library;

enum Stance {
  orthodox('오소독스'),
  southpaw('사우스포');

  const Stance(this.label);
  final String label;
}

enum CallStyle {
  number('숫자 (원투쓰리)'),
  name('이름 (원투 레프트훅)');

  const CallStyle(this.label);
  final String label;
}

/// 동작을 마친 뒤 체중이 어느 쪽 발에 실려 있는지.
enum Weight { lead, center, rear }

enum MoveType { jab, straight, hook, uppercut, overhand, body, slip, duck, weave, pull, step }

const _defenseTypes = {
  MoveType.slip,
  MoveType.duck,
  MoveType.weave,
  MoveType.pull,
  MoveType.step,
};

/// 리드 손으로 치는 펀치.
const _leadPunches = {'jab', 'jabBody', 'leadHook', 'leadUpper', 'leadBody', 'jumpHook', 'checkHook'};

class Move {
  const Move({
    required this.id,
    required this.type,
    required this.nameCall,
    this.numberCall,
    required this.duration,
    required this.compat,
    required this.result,
    this.lowAfter = false,
    this.freq = 1.0,
    this.special = false,
  });

  final String id;
  final MoveType type;

  /// 이름 콜. {L} = 리드 쪽, {R} = 리어 쪽으로 치환된다.
  final String nameCall;

  /// 숫자 콜. 없으면 이름 콜을 쓴다.
  final String? numberCall;

  /// 동작 수행에 걸리는 대략적인 시간(초).
  final double duration;

  /// 현재 체중 위치에서 이 동작이 얼마나 자연스러운지 (0 = 자세상 불가능).
  final Map<Weight, double> compat;

  /// 동작 후 체중 위치.
  final Weight result;

  /// 동작 후 자세가 낮아지는지 (더킹, 위빙, 바디샷).
  final bool lowAfter;

  /// 기본 출현 빈도.
  final double freq;

  /// 상급 기술 (점프 훅, 체크 훅, 오버핸드 훅). 상급에서만 나온다.
  final bool special;

  bool get isDefense => _defenseTypes.contains(type);
  bool get isPunch => !isDefense;

  /// 자세 높이를 바꾸는 동작 (바디샷, 더킹, 위빙). 레벨 체인지.
  bool get changesLevel => lowAfter;

  /// 펀치를 치는 손이 리드 손인지. 방어 동작은 null.
  bool? get leadHand => isPunch ? _leadPunches.contains(id) : null;

  String call(Stance stance, CallStyle style) {
    final template = (style == CallStyle.number ? numberCall : null) ?? nameCall;
    final lead = stance == Stance.orthodox ? '레프트' : '라이트';
    final rear = stance == Stance.orthodox ? '라이트' : '레프트';
    return template.replaceAll('{L}', lead).replaceAll('{R}', rear);
  }
}

abstract final class Moves {
  // ── 펀치 ──
  // 리드 손 펀치는 체중을 뒤로, 리어 손 펀치는 체중을 앞으로 옮긴다.
  // 그래서 체중이 앞에 실려 있으면 리드 손이, 뒤에 실려 있으면 리어 손이 자연스럽다.
  static const jab = Move(
    id: 'jab',
    type: MoveType.jab,
    nameCall: '잽',
    numberCall: '원',
    duration: 0.35,
    compat: {Weight.lead: 0.6, Weight.center: 1.0, Weight.rear: 0.9},
    result: Weight.center,
    freq: 1.3,
  );
  static const cross = Move(
    id: 'cross',
    type: MoveType.straight,
    nameCall: '투',
    duration: 0.45,
    compat: {Weight.lead: 0.15, Weight.center: 1.0, Weight.rear: 1.0},
    result: Weight.lead,
    freq: 1.3,
  );
  static const leadHook = Move(
    id: 'leadHook',
    type: MoveType.hook,
    nameCall: '{L} 훅',
    numberCall: '쓰리',
    duration: 0.5,
    compat: {Weight.lead: 1.0, Weight.center: 0.6, Weight.rear: 0.1},
    result: Weight.rear,
  );
  static const rearHook = Move(
    id: 'rearHook',
    type: MoveType.hook,
    nameCall: '{R} 훅',
    numberCall: '포',
    duration: 0.55,
    compat: {Weight.lead: 0.0, Weight.center: 0.35, Weight.rear: 1.0},
    result: Weight.lead,
    freq: 0.6,
  );
  static const leadUpper = Move(
    id: 'leadUpper',
    type: MoveType.uppercut,
    nameCall: '{L} 어퍼',
    numberCall: '파이브',
    duration: 0.5,
    compat: {Weight.lead: 1.0, Weight.center: 0.4, Weight.rear: 0.1},
    result: Weight.rear,
    freq: 0.8,
  );
  static const rearUpper = Move(
    id: 'rearUpper',
    type: MoveType.uppercut,
    nameCall: '{R} 어퍼',
    numberCall: '식스',
    duration: 0.55,
    compat: {Weight.lead: 0.0, Weight.center: 0.5, Weight.rear: 1.0},
    result: Weight.lead,
    freq: 0.8,
  );
  static const leadBody = Move(
    id: 'leadBody',
    type: MoveType.body,
    nameCall: '{L} 바디',
    numberCall: '바디 쓰리',
    duration: 0.55,
    compat: {Weight.lead: 1.0, Weight.center: 0.6, Weight.rear: 0.1},
    result: Weight.rear,
    lowAfter: true,
  );
  static const rearBody = Move(
    id: 'rearBody',
    type: MoveType.body,
    nameCall: '{R} 바디',
    numberCall: '바디 투',
    duration: 0.55,
    compat: {Weight.lead: 0.1, Weight.center: 1.0, Weight.rear: 1.0},
    result: Weight.lead,
    lowAfter: true,
  );
  static const jabBody = Move(
    id: 'jabBody',
    type: MoveType.body,
    nameCall: '바디 잽',
    numberCall: '바디 원',
    duration: 0.4,
    compat: {Weight.lead: 0.5, Weight.center: 1.0, Weight.rear: 0.8},
    result: Weight.center,
    lowAfter: true,
    freq: 0.5,
  );

  // ── 방어 ──
  // 리드 쪽으로 빠지면 체중이 앞발에, 리어 쪽으로 빠지면 뒷발에 실린다.
  static const slipLead = Move(
    id: 'slipLead',
    type: MoveType.slip,
    nameCall: '{L} 슬립',
    duration: 0.45,
    compat: {Weight.lead: 0.2, Weight.center: 1.0, Weight.rear: 0.8},
    result: Weight.lead,
  );
  static const slipRear = Move(
    id: 'slipRear',
    type: MoveType.slip,
    nameCall: '{R} 슬립',
    duration: 0.45,
    compat: {Weight.lead: 0.8, Weight.center: 1.0, Weight.rear: 0.2},
    result: Weight.rear,
  );
  // 더킹: 무릎을 굽혀 낮추면서 한쪽으로 빠진다. 슬립과 체중 이동은 같고 자세가 낮아진다.
  static const duckLead = Move(
    id: 'duckLead',
    type: MoveType.duck,
    nameCall: '{L} 더킹',
    duration: 0.5,
    compat: {Weight.lead: 0.2, Weight.center: 1.0, Weight.rear: 0.8},
    result: Weight.lead,
    lowAfter: true,
    freq: 0.8,
  );
  static const duckRear = Move(
    id: 'duckRear',
    type: MoveType.duck,
    nameCall: '{R} 더킹',
    duration: 0.5,
    compat: {Weight.lead: 0.8, Weight.center: 1.0, Weight.rear: 0.2},
    result: Weight.rear,
    lowAfter: true,
    freq: 0.8,
  );
  static const weaveLead = Move(
    id: 'weaveLead',
    type: MoveType.weave,
    nameCall: '{L} 위빙',
    duration: 0.7,
    compat: {Weight.lead: 0.2, Weight.center: 0.9, Weight.rear: 1.0},
    result: Weight.lead,
    lowAfter: true,
    freq: 0.7,
  );
  static const weaveRear = Move(
    id: 'weaveRear',
    type: MoveType.weave,
    nameCall: '{R} 위빙',
    duration: 0.7,
    compat: {Weight.lead: 1.0, Weight.center: 0.9, Weight.rear: 0.2},
    result: Weight.rear,
    lowAfter: true,
    freq: 0.7,
  );
  static const pullBack = Move(
    id: 'pullBack',
    type: MoveType.pull,
    nameCall: '스웨이',
    duration: 0.5,
    compat: {Weight.lead: 0.8, Weight.center: 1.0, Weight.rear: 0.2},
    result: Weight.rear,
    freq: 0.6,
  );
  static const backStep = Move(
    id: 'backStep',
    type: MoveType.step,
    nameCall: '백스텝',
    duration: 0.6,
    compat: {Weight.lead: 0.7, Weight.center: 0.7, Weight.rear: 0.7},
    result: Weight.center,
    freq: 0.4,
  );


  // ── 상급 기술 ──
  // 점프 훅: 두 발로 바닥을 차고 뛰어 들어가며 리드 훅. 착지와 동시에 맞힌다.
  // 웅크렸다(더킹) 튀어 오르거나 잽으로 거리를 잰 뒤에 나온다.
  static const jumpHook = Move(
    id: 'jumpHook',
    type: MoveType.hook,
    nameCall: '점프 훅',
    duration: 0.7,
    compat: {Weight.lead: 0.4, Weight.center: 1.0, Weight.rear: 0.9},
    result: Weight.rear,
    freq: 0.7,
    special: true,
  );
  // 체크 훅: 들어오는 상대에게 리드 훅을 치며 앞발을 축으로 몸을 돌려(뒷발이 뒤로 돌아 나감) 옆으로 빠진다.
  // 체중이 앞발에 실려 있어야 앞발로 돈다.
  static const checkHook = Move(
    id: 'checkHook',
    type: MoveType.hook,
    nameCall: '체크 훅',
    duration: 0.75,
    compat: {Weight.lead: 1.0, Weight.center: 0.7, Weight.rear: 0.1},
    result: Weight.center,
    freq: 0.8,
    special: true,
  );
  // 오버핸드 훅: 리어 손을 위에서 아래로 넘겨 치는 큰 펀치. 리드 쪽으로 머리를 숙이며 체중을 앞으로 싣는다.
  static const overhand = Move(
    id: 'overhand',
    type: MoveType.overhand,
    nameCall: '오버핸드 훅',
    duration: 0.6,
    compat: {Weight.lead: 0.1, Weight.center: 0.8, Weight.rear: 1.0},
    result: Weight.lead,
    freq: 0.8,
    special: true,
  );
  static const all = [
    jab, cross, leadHook, rearHook, leadUpper, rearUpper,
    leadBody, rearBody, jabBody,
    slipLead, slipRear, duckLead, duckRear, weaveLead, weaveRear, pullBack, backStep,
    jumpHook, checkHook, overhand,
  ];

  /// 상급 기술 id.
  static final specialIds = {for (final m in all) if (m.special) m.id};
}


/// 실전에서 자주 쓰는 연결에 주는 가중치 ('이전>다음').
/// 1보다 크면 더 자주, 체중상 다소 어색해도 정석인 연결(바디→헤드 더블 훅 등)을 살려준다.
const Map<String, double> pairBonus = {
  'jab>cross': 2.2,
  'cross>leadHook': 2.0,
  'cross>leadUpper': 1.3,
  'cross>leadBody': 1.3,
  'leadHook>cross': 1.8,
  'leadHook>rearUpper': 1.4,
  'leadBody>leadHook': 6.0,
  'leadUpper>leadHook': 4.0,
  'rearUpper>leadHook': 1.8,
  'rearBody>leadHook': 1.5,
  'slipLead>leadHook': 1.5,
  'slipLead>leadUpper': 1.5,
  'slipRear>cross': 1.5,
  'slipRear>rearUpper': 1.6,
  'duckLead>leadUpper': 1.6,
  'duckLead>leadHook': 1.5,
  'duckRear>rearUpper': 1.6,
  'duckRear>cross': 1.3,
  'weaveLead>leadHook': 1.5,
  'weaveRear>cross': 1.5,
  'pullBack>cross': 3.0,
  'backStep>jab': 2.0,
  // 상급 기술
  'jab>jumpHook': 1.4,
  'duckLead>jumpHook': 2.0,
  'duckRear>jumpHook': 1.6,
  'jumpHook>cross': 1.8,
  'cross>checkHook': 2.0,
  'rearUpper>checkHook': 1.5,
  'slipLead>checkHook': 1.5,
  'jab>overhand': 1.6,
  'slipRear>overhand': 2.0,
  'weaveRear>overhand': 1.8,
  'duckRear>overhand': 1.5,
  'overhand>leadHook': 2.0,
};
