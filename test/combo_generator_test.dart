import 'dart:math';

import 'package:boxing_coach/engine/combo_generator.dart';
import 'package:boxing_coach/models/moves.dart';
import 'package:boxing_coach/models/settings.dart';
import 'package:flutter_test/flutter_test.dart';

List<Combo> _sample(TrainingSettings s, {int n = 3000}) {
  final gen = ComboGenerator(s, random: Random(42));
  return [for (var i = 0; i < n; i++) gen.next()];
}

void main() {
  for (final level in Level.values) {
    group('${level.label} 콤보 규칙', () {
      final settings = TrainingSettings(level: level);
      final combos = _sample(settings);
      final profile = level.profile;

      test('체중이 앞에 실린 직후 리어 훅/어퍼는 나오지 않는다', () {
        for (final c in combos) {
          for (var i = 1; i < c.moves.length; i++) {
            if (c.moves[i - 1].result == Weight.lead) {
              expect(c.moves[i].id, isNot(anyOf('rearUpper', 'rearHook')), reason: c.key);
            }
          }
        }
      });

      test('모든 연결이 자세 기준을 넘는다', () {
        for (final c in combos) {
          var weight = Weight.center;
          Move? prev;
          for (final m in c.moves) {
            final bonus = prev == null ? 1.0 : pairBonus['${prev.id}>${m.id}'] ?? 1.0;
            expect((m.compat[weight] ?? 0) * bonus,
                greaterThanOrEqualTo(ComboGenerator.awkwardThreshold),
                reason: c.key);
            weight = m.result;
            prev = m;
          }
        }
      });

      test('길이, 방어 개수, 백스텝 위치', () {
        for (final c in combos) {
          final m = c.moves;
          expect(m.length, inInclusiveRange(1, profile.maxLength));
          expect(m.any((x) => x.isPunch), isTrue, reason: c.key);
          expect(m.where((x) => x.isDefense).length, lessThanOrEqualTo(profile.maxDefenses));
          for (var i = 0; i < m.length; i++) {
            if (m[i].id == 'backStep') expect(i == 0 || i == m.length - 1, isTrue, reason: c.key);
            expect(profile.allows(m[i]), isTrue, reason: c.key);
          }
        }
      });

      test('같은 콤보가 연속으로 나오지 않는다', () {
        for (var i = 1; i < combos.length; i++) {
          expect(combos[i].key, isNot(combos[i - 1].key));
        }
      });
    });
  }

  test('방어/바디 끄면 안 나온다', () {
    final combos = _sample(const TrainingSettings(includeDefense: false, includeBody: false));
    for (final c in combos) {
      for (final m in c.moves) {
        expect(m.isDefense || m.type == MoveType.body, isFalse, reason: c.key);
      }
    }
  });

  test('왼쪽 더킹 직후 라이트 어퍼는 나오지 않는다 (오소독스)', () {
    final combos = _sample(const TrainingSettings(level: Level.advanced), n: 5000);
    var ducks = 0;
    for (final c in combos) {
      final calls = [for (final m in c.moves) m.call(Stance.orthodox, CallStyle.name)];
      for (var i = 1; i < calls.length; i++) {
        if (calls[i - 1] == '레프트 더킹') {
          ducks++;
          expect(calls[i], isNot('라이트 어퍼'), reason: c.key);
        }
      }
    }
    expect(ducks, greaterThan(0));
  });

  test('콜 문구', () {
    expect(Moves.duckLead.call(Stance.orthodox, CallStyle.number), '레프트 더킹');
    expect(Moves.duckLead.call(Stance.southpaw, CallStyle.number), '라이트 더킹');
    expect(Moves.leadHook.call(Stance.orthodox, CallStyle.name), '레프트 훅');
    expect(Moves.leadHook.call(Stance.southpaw, CallStyle.name), '라이트 훅');
    expect(Moves.slipLead.call(Stance.orthodox, CallStyle.number), '레프트 슬립');
  });

  group('콤보 콜', () {
    String show(List<Move> moves, [CallStyle style = CallStyle.name]) =>
        Combo(moves).call(Stance.orthodox, style);
    String speak(List<Move> moves, [CallStyle style = CallStyle.name]) =>
        Combo(moves).speech(Stance.orthodox, style);

    test('숫자끼리는 붙이고 나머지는 동작마다 끊는다', () {
      expect(show([Moves.jab, Moves.cross, Moves.leadHook], CallStyle.number), '원투쓰리');
      expect(show([Moves.jab, Moves.cross, Moves.leadHook]), '원투 · 레프트 훅');
      expect(speak([Moves.jab, Moves.cross, Moves.leadHook]), '원투, 레프트 훅');
      expect(speak([Moves.rearBody, Moves.rearUpper]), '라이트 바디, 라이트 어퍼');
      expect(speak([Moves.leadBody, Moves.leadHook], CallStyle.number), '바디 쓰리, 쓰리');
    });

    test('이름 콜에서 잽은 "잽", 스트레이트가 이어질 때만 "원투"', () {
      expect(show([Moves.jab, Moves.leadHook]), '잽 · 레프트 훅');
      expect(show([Moves.jab, Moves.jab, Moves.cross]), '잽 · 원투');
      expect(speak([Moves.jab, Moves.jabBody, Moves.jab, Moves.jab, Moves.jabBody]),
          '잽, 바디 잽, 잽, 잽, 바디 잽');
      expect(speak([Moves.jab, Moves.jabBody], CallStyle.number), '원, 바디 원');
    });
  });
}
