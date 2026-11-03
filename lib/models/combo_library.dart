import 'moves.dart';
import 'settings.dart';

/// 콤비네이션 보기에서 고를 수 있는 콤보. 난이도별로 실전에서 자주 쓰는 것을 골랐다.
/// 모두 그 난이도의 콤보 규칙(체중 전이, 레벨 체인지·상급 기술 제한)을 지킨다 (test/combo_library_test.dart).
class ComboExample {
  const ComboExample(this.title, this.moves, this.note);

  final String title;
  final List<Move> moves;

  /// 언제, 왜 쓰는지.
  final String note;
}

const Map<Level, List<ComboExample>> comboLibrary = {
  Level.beginner: [
    ComboExample('원투', [Moves.jab, Moves.cross], '잽으로 거리를 재고 뒷손 스트레이트. 모든 콤보의 시작.'),
    ComboExample('원투쓰리', [Moves.jab, Moves.cross, Moves.leadHook],
        '스트레이트로 앞발에 실린 체중을 리드 훅으로 되돌린다. 가장 기본 3연타.'),
    ComboExample('더블 잽 투', [Moves.jab, Moves.jab, Moves.cross], '첫 잽으로 가드를 흔들고 둘째 잽으로 거리를 좁힌다.'),
    ComboExample('원투 어퍼', [Moves.jab, Moves.cross, Moves.leadUpper],
        '스트레이트를 막으려 가드를 올린 상대의 턱 아래로 리드 어퍼.'),
    ComboExample('투 훅 투', [Moves.cross, Moves.leadHook, Moves.cross], '좌우로 체중을 번갈아 실으며 끊김 없이 친다.'),
    ComboExample('원투 바디', [Moves.jab, Moves.cross, Moves.leadBody],
        '머리에 두 번 친 뒤 시선이 올라간 상대의 옆구리로.'),
    ComboExample('슬립 카운터', [Moves.slipRear, Moves.cross], '상대 잽을 바깥으로 흘리고 바로 스트레이트로 받아친다.'),
    ComboExample('스웨이 카운터', [Moves.pullBack, Moves.cross], '상대 잽을 뒤로 젖혀 피하고, 되돌아오는 힘으로 스트레이트.'),
    ComboExample('슬립 훅', [Moves.slipLead, Moves.leadHook], '상대 스트레이트를 리드 쪽으로 피하며 실린 체중으로 리드 훅.'),
    ComboExample('치고 빠지기', [Moves.jab, Moves.cross, Moves.backStep], '원투를 치고 반격 거리 밖으로 물러난다.'),
  ],
  Level.intermediate: [
    ComboExample('바디-헤드 더블', [Moves.jab, Moves.cross, Moves.leadBody, Moves.leadHook],
        '같은 손으로 바디를 치고 가드가 내려간 머리로 훅. 아래-위 레벨 체인지의 기본.'),
    ComboExample('바디 스트레이트 훅', [Moves.jab, Moves.rearBody, Moves.leadHook],
        '잽으로 시선을 끌고 몸을 낮춰 뒷손 바디, 일어서며 리드 훅.'),
    ComboExample('바디 잽 원투', [Moves.jabBody, Moves.jab, Moves.cross], '배로 잽을 넣어 가드를 내리게 하고 머리로 원투.'),
    ComboExample('바디 훅 훅 투', [Moves.leadBody, Moves.leadHook, Moves.cross], '리드 바디-헤드 더블 훅 뒤 스트레이트로 마무리.'),
    ComboExample('슬립 어퍼 투', [Moves.slipLead, Moves.leadUpper, Moves.cross],
        '스트레이트를 피해 낮아진 자리에서 어퍼, 다시 스트레이트.'),
    ComboExample('원투 위빙 투', [Moves.jab, Moves.cross, Moves.weaveRear, Moves.cross],
        '원투 뒤 돌아오는 상대 훅을 위빙으로 흘리고 다시 스트레이트.'),
    ComboExample('훅 위빙 훅', [Moves.cross, Moves.leadHook, Moves.weaveLead, Moves.leadHook],
        '주고받는 거리에서 훅을 치고, 상대 훅을 위빙으로 피한 뒤 다시 훅.'),
    ComboExample('더킹 어퍼 훅', [Moves.duckLead, Moves.leadUpper, Moves.leadHook],
        '상대 훅 아래로 숙였다가 낮은 자세 그대로 어퍼, 이어서 훅.'),
    ComboExample('더킹 뒷손 어퍼 훅', [Moves.duckRear, Moves.rearUpper, Moves.leadHook],
        '리어 쪽으로 숙여 피하고 실린 체중으로 뒷손 어퍼, 리드 훅.'),
    ComboExample('원투 훅 훅', [Moves.jab, Moves.cross, Moves.leadHook, Moves.rearHook], '스트레이트 둘, 훅 둘. 거리를 좁히며 좌우로 몰아친다.'),
  ],
  Level.advanced: [
    // 상급: 길게 이어 치는 연타, 피하고 바로 받아치는 연결, 머리-몸통을 오가는 레벨 체인지를 쉬지 않고 섞는다.
    ComboExample('6연타 레벨 체인지', [Moves.jab, Moves.cross, Moves.leadHook, Moves.cross, Moves.leadBody, Moves.leadHook],
        '머리로 원투쓰리투를 몰아친 뒤 같은 손으로 바디-헤드 더블 훅. 체중을 좌우로 쉬지 않고 옮긴다.'),
    ComboExample('더블 슬립 카운터', [Moves.slipRear, Moves.slipLead, Moves.leadHook, Moves.cross, Moves.leadHook],
        '상대 원투를 바깥, 안쪽으로 연달아 흘리고, 체중이 실린 쪽부터 훅-스트레이트-훅으로 받아친다.'),
    ComboExample('위빙 카운터 연타', [Moves.jab, Moves.cross, Moves.weaveRear, Moves.cross, Moves.leadHook, Moves.rearUpper],
        '원투 뒤 돌아오는 훅을 위빙으로 흘리고, 일어서는 힘으로 스트레이트-훅-뒷손 어퍼.'),
    ComboExample('더킹 바디 연타', [Moves.duckRear, Moves.rearBody, Moves.leadHook, Moves.rearUpper, Moves.leadHook],
        '상대 잽 아래로 숙여 낮은 자세 그대로 뒷손 바디, 일어서며 훅-어퍼-훅.'),
    ComboExample('바디 잽 셋업', [Moves.jabBody, Moves.cross, Moves.leadHook, Moves.rearUpper, Moves.leadHook],
        '배로 잽을 넣어 가드를 내리게 하고, 열린 머리로 스트레이트-훅-어퍼-훅.'),
    ComboExample('스웨이 카운터 연타', [Moves.pullBack, Moves.cross, Moves.leadHook, Moves.rearBody, Moves.leadHook],
        '상대 잽을 뒤로 젖혀 피하고 되돌아오며 스트레이트-훅, 이어 몸통과 머리를 번갈아.'),
    ComboExample('훅 교환', [Moves.leadHook, Moves.weaveLead, Moves.leadHook, Moves.rearUpper, Moves.leadHook],
        '붙은 거리에서 훅을 주고받는다. 상대 훅을 위빙으로 흘리고 훅-어퍼-훅으로 되갚는다.'),
    ComboExample('슬립 어퍼 연타 후 빠지기', [Moves.slipLead, Moves.leadUpper, Moves.leadHook, Moves.cross, Moves.backStep],
        '상대 스트레이트를 리드 쪽으로 피하며 어퍼-훅-스트레이트, 반격 전에 뒤로 빠진다.'),
    ComboExample('두 번 피하고 바디-헤드', [Moves.jab, Moves.slipRear, Moves.duckRear, Moves.rearBody, Moves.leadHook, Moves.cross],
        '잽을 던져 반응을 끌어내고, 돌아오는 잽 두 개를 슬립과 더킹으로 흘린 뒤 낮은 자세에서 바디-훅-스트레이트.'),
    // 상급 기술이 들어간 콤비네이션
    ComboExample('원투 체크 훅', [Moves.jab, Moves.cross, Moves.leadHook, Moves.cross, Moves.checkHook],
        '원투쓰리투로 몰아친 뒤 반격하며 돌진해 들어오는 상대에게 훅을 맞히고 앞발로 돌아 옆으로 빠진다.'),
    ComboExample('더킹 점프 훅 연타', [Moves.duckLead, Moves.jumpHook, Moves.cross, Moves.leadHook, Moves.cross],
        '상대 스트레이트 아래로 숙였다가 뒷손 쪽으로 뛰어 들어가 훅, 잡은 각에서 투-훅-투.'),
    ComboExample('슬립 오버핸드 바디', [Moves.slipRear, Moves.overhand, Moves.leadBody, Moves.leadHook],
        '상대 잽을 바깥으로 흘리며 그 위로 오버핸드, 시선이 올라간 사이 바디-헤드 훅.'),
    ComboExample('위빙 오버핸드', [Moves.jab, Moves.weaveRear, Moves.overhand, Moves.leadHook, Moves.cross],
        '상대 훅을 위빙으로 흘리고 뒷발에 실린 체중으로 오버핸드-훅-스트레이트.'),
  ],
};
