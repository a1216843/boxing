import 'package:boxing_coach/engine/combo_generator.dart';
import 'package:boxing_coach/models/combo_library.dart';
import 'package:boxing_coach/models/moves.dart';
import 'package:boxing_coach/models/settings.dart';
import 'package:boxing_coach/pose/skeleton.dart';
import 'package:boxing_coach/pose/sparring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final level in Level.values) {
    test('${level.label} 콤비네이션 목록은 그 난이도의 콤보 규칙을 지킨다', () {
      final p = level.profile;
      final list = comboLibrary[level]!;
      expect(list.length, greaterThanOrEqualTo(8));
      expect(list.map((e) => e.title).toSet().length, list.length);
      // 상급은 상급 기술만 넣은 목록이 아니다: 절반 넘게는 기술 없이 길이·연결로 어려운 콤비네이션.
      if (level == Level.advanced) {
        expect(list.where((e) => !e.moves.any((m) => m.special)).length, greaterThan(list.length / 2));
        final avg = list.fold(0, (a, e) => a + e.moves.length) / list.length;
        final mid = comboLibrary[Level.intermediate]!;
        expect(avg, greaterThan(mid.fold(0, (a, e) => a + e.moves.length) / mid.length + 0.8));
      }
      for (final e in list) {
        final m = e.moves;
        final why = e.title;
        expect(m.length, inInclusiveRange(1, p.maxLength), reason: why);
        expect(m.where((x) => x.isDefense).length, lessThanOrEqualTo(p.maxDefenses), reason: why);
        expect(m.where((x) => x.changesLevel).length, lessThanOrEqualTo(p.maxLow), reason: why);
        final specials = m.where((x) => x.special).map((x) => x.id).toList();
        expect(specials.length, lessThanOrEqualTo(p.maxSpecials), reason: why);
        expect(specials.toSet().length, specials.length, reason: why);
        var weight = Weight.center;
        for (var i = 0; i < m.length; i++) {
          expect(p.allows(m[i]), isTrue, reason: '$why ${m[i].id}');
          final bonus = i == 0 ? 1.0 : pairBonus['${m[i - 1].id}>${m[i].id}'] ?? 1.0;
          expect((m[i].compat[weight] ?? 0) * bonus, greaterThanOrEqualTo(ComboGenerator.awkwardThreshold),
              reason: '$why ${m[i].id}');
          if (m[i].type == MoveType.step) expect(i == 0 || i == m.length - 1, isTrue, reason: why);
          weight = m[i].result;
        }
      }
    });
  }

  test('상대 인형: 내 펀치는 상대에게 닿고, 내 회피에는 상대 펀치가 빗나간다', () {
    for (final e in comboLibrary.values.expand((l) => l)) {
      final sp = SparringTimeline(e.moves);
      for (var i = 0; i < e.moves.length; i++) {
        final m = e.moves[i];
        if (m.isPunch) {
          final t = SparringTimeline.lead + sp.me.impactOf(i);
          final me = sp.meAt(t), op = sp.opponentAt(t);
          final hand = me.leadGlow >= me.rearGlow ? J.leadHand : J.rearHand;
          final target = m.type == MoveType.body ? V3.lerp(op[J.pelvis], op[J.neck], 0.6) : op[J.head];
          // 주먹 중심과 머리(몸통) 중심 사이: 글러브와 머리가 맞닿는 거리 안팎.
          expect((me[hand] - target).length, lessThan(0.4), reason: '${e.title} ${m.id}');
        } else if (m.isDefense) {
          expect(sp.opponentCall(i, Stance.orthodox), startsWith('상대 '), reason: e.title);
          // 회피 동안 상대 주먹이 내 머리에 닿지 않는다.
          final s0 = SparringTimeline.lead + sp.me.startOf(i);
          for (var k = 0; k <= 40; k++) {
            final t = s0 + sp.me.secondsOf(i) * k / 40;
            final me = sp.meAt(t), op = sp.opponentAt(t);
            for (final h in [J.leadHand, J.rearHand]) {
              expect((op[h] - me[J.head]).length, greaterThan(0.14), reason: '${e.title} ${m.id} $k');
            }
          }
        }
      }
      // 끝나면 둘 다 처음 자리로.
      final a = sp.opponentAt(0), b = sp.opponentAt(sp.duration);
      for (final j in J.values) {
        expect((a[j] - b[j]).length, lessThan(1e-6), reason: '${e.title} $j');
      }
    }
  });

  test('점프 훅: 상대 뒷손 쪽 대각선으로 뛰어 들어가 각을 잡고, 상대는 따라 돌지 않는다', () {
    final sp = SparringTimeline([Moves.jab, Moves.jumpHook, Moves.cross]);
    final before = SparringTimeline.lead + sp.me.startOf(1);
    final after = SparringTimeline.lead + sp.me.impactOf(2);
    // 상대 기준 내 위치: 상대 쪽으로 가까워지고, 상대 뒷손 쪽(상대 기준 +x)으로 옮겨 간다.
    V3 mine(double t) => sp.opponentPlaceAt(t).inverse.apply(sp.meAt(t)[J.pelvis]);
    expect(mine(after).x - mine(before).x, greaterThan(0.15));
    // 상대는 원래 방향 그대로.
    expect((sp.opponentPlaceAt(after).angle - sp.opponentPlaceAt(before).angle).abs(), lessThan(1));
    // 점프 훅과 이어지는 스트레이트가 그 각에서 상대에게 닿는다 (위 '닿는다' 테스트와 같은 기준).
    for (final i in [1, 2]) {
      final t = SparringTimeline.lead + sp.me.impactOf(i);
      final me = sp.meAt(t), op = sp.opponentAt(t);
      final hand = me.leadGlow >= me.rearGlow ? J.leadHand : J.rearHand;
      expect((me[hand] - op[J.head]).length, lessThan(0.4), reason: '$i');
    }
  });

  test('체크 훅: 상대가 펀치를 뻗으며 돌진해 들어오다 맞고, 앞으로 고꾸라진다', () {
    final sp = SparringTimeline([Moves.jab, Moves.cross, Moves.checkHook]);
    final t = SparringTimeline.lead + sp.me.impactOf(2);
    final start = SparringTimeline.lead + sp.me.startOf(2);
    double gap(double at) => (sp.opponentAt(at)[J.pelvis] - sp.meAt(at)[J.pelvis]).length;
    // 체크 훅이 시작될 때보다 맞는 순간 상대가 가까이 와 있다 (몸으로 밀고 들어옴).
    expect(gap(t), lessThan(gap(start) - 0.1));
    // 앞손을 뻗고 있다.
    final at = sp.opponentAt(t - 0.05);
    expect((at[J.leadHand] - at[J.leadShoulder]).length, greaterThan(0.45));
    expect(sp.opponentCall(2, Stance.orthodox), '돌진하다 맞음');
  });

  test('상대 행동 이름: 맞은 것, 친 펀치 (스탠스 설정에 따라 좌우)', () {
    final sp = SparringTimeline([Moves.slipLead, Moves.leadHook]);
    expect(sp.opponentCall(0, Stance.orthodox), '상대 스트레이트');
    // 오소독스 상대의 라이트(뒷손) 훅은 레프트 위빙, 레프트 훅은 라이트 위빙으로 피한다.
    final weave = SparringTimeline([Moves.jab, Moves.weaveLead, Moves.leadHook, Moves.weaveRear, Moves.cross]);
    expect(weave.opponentCall(1, Stance.orthodox), '상대 라이트 훅');
    expect(weave.opponentCall(1, Stance.southpaw), '상대 레프트 훅');
    expect(weave.opponentCall(3, Stance.orthodox), '상대 레프트 훅');
    expect(weave.opponentCall(0, Stance.orthodox), '맞음');
    // 더킹은 스트레이트를 피한다.
    final duck = SparringTimeline([Moves.duckLead, Moves.leadUpper, Moves.duckRear, Moves.rearUpper]);
    expect(duck.opponentCall(0, Stance.orthodox), '상대 스트레이트');
    expect(duck.opponentCall(2, Stance.orthodox), '상대 잽');
  });
}
