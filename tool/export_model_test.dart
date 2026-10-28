// 인형의 펀치 동작을 30fps 관절 좌표(COCO 17점 순서, 3D)로 내보내는 개발용 도구.
// 실제 선수 데이터(BoxingVI)와 같은 지표로 비교할 때 쓴다.
// EXPORT_PATH=<경로> flutter test tool/export_model_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:boxing_coach/models/moves.dart';
import 'package:boxing_coach/pose/poses.dart';
import 'package:boxing_coach/pose/skeleton.dart';
import 'package:boxing_coach/pose/timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('export punches', () {
    const punches = {
      'Jab': Moves.jab,
      'Cross': Moves.cross,
      'Lead Hook': Moves.leadHook,
      'Rear Hook': Moves.rearHook,
      'Lead Uppercut': Moves.leadUpper,
      'Rear Uppercut': Moves.rearUpper,
    };
    // 오소독스: 리드 = 왼쪽. COCO 순서 (눈·귀는 코로 대신).
    List<List<double>> coco(Skeleton s) {
      final nose = s[J.head] + s.facing * 0.11;
      final joints = [
        nose, nose, nose, nose, nose,
        s[J.leadShoulder], s[J.rearShoulder],
        s[J.leadElbow], s[J.rearElbow],
        s[J.leadHand], s[J.rearHand],
        s[J.leadHip], s[J.rearHip],
        s[J.leadKnee], s[J.rearKnee],
        s[J.leadFoot], s[J.rearFoot],
      ];
      return [for (final p in joints) [p.x, p.y, p.z]];
    }

    final out = <String, Object>{};
    for (final MapEntry(key: name, value: move) in punches.entries) {
      final tl = PoseTimeline([move]);
      final frames = (animSeconds(move) * 30).round() + 1;
      out[name] = {
        'duration': animSeconds(move),
        'frames': [for (var i = 0; i < frames; i++) coco(tl.at(i / 30))],
      };
    }
    final path = Platform.environment['EXPORT_PATH'] ?? 'build/model_punches.json';
    File(path).writeAsStringSync(jsonEncode(out));
  });
}
