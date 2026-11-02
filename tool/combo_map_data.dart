// 콤보 카드 지도(web/combo_map/)가 읽는 동작 데이터. 앱의 콤보 규칙과 같은 값을 그대로 옮긴다.
import 'dart:convert';

import 'package:boxing_coach/models/moves.dart';
import 'package:boxing_coach/models/settings.dart';

/// web/combo_map/data.js 내용.
String comboMapDataJs() {
  final data = {
    'moves': [
      for (final m in Moves.all)
        {
          'id': m.id,
          'type': m.type.name,
          'defense': m.isDefense,
          'nameO': m.call(Stance.orthodox, CallStyle.name),
          'nameS': m.call(Stance.southpaw, CallStyle.name),
          'compat': {for (final e in m.compat.entries) e.key.name: e.value},
          'result': m.result.name,
          'low': m.lowAfter,
          'freq': m.freq,
        },
    ],
    'bonus': pairBonus,
    'levels': {
      for (final l in Level.values)
        l.name: {
          'excluded': l.profile.excluded.toList(),
          'maxDefenses': l.profile.maxDefenses,
          'defenseRate': l.profile.defenseRate,
          'lengthWeights': l.profile.lengthWeights,
        },
    },
  };
  return '// tool/combo_map_export_test.dart 로 만든 파일. 직접 고치지 말 것.\n'
      'const DATA = ${const JsonEncoder.withIndent(' ').convert(data)};\n';
}
