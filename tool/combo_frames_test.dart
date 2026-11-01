// 콤보 애니메이션을 시간별 프레임으로 렌더링해 확인하는 개발용 도구.
// flutter test tool/combo_frames_test.dart --update-goldens
// → tool/combo_frames.png (줄마다 콤보 하나, 왼쪽→오른쪽 시간 순. 마지막 줄은 가드 리듬 한 주기)
import 'package:boxing_coach/models/moves.dart';
import 'package:boxing_coach/pose/figure_painter.dart';
import 'package:boxing_coach/pose/poses.dart';
import 'package:boxing_coach/pose/timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('combo frames', (tester) async {
    const combos = [
      [Moves.jab, Moves.jab, Moves.cross],
      [Moves.cross, Moves.leadHook, Moves.rearUpper],
      [Moves.slipLead, Moves.leadHook, Moves.backStep],
      [Moves.jabBody, Moves.rearBody, Moves.leadHook],
      [Moves.weaveRear, Moves.leadHook, Moves.weaveLead],
    ];
    const frames = 8;
    const tile = Size(170, 220);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(tile.width * frames, tile.height * (combos.length + 1));
    addTearDown(tester.view.reset);

    final rows = <Widget>[];
    for (final moves in combos) {
      final tl = PoseTimeline(moves);
      final guides = [
        for (var i = 0; i < moves.length; i++)
          [for (final g in motionGuides(moves[i])) g.translated(tl.baseOf(i))],
      ];
      rows.add(Row(textDirection: TextDirection.ltr, children: [
        for (var i = 0; i < frames; i++)
          () {
            // 동작 구간만 촘촘히 본다 (끝 복귀·스텝 구간 제외).
            final action = moves.fold(0.0, (a, m) => a + animSeconds(m));
            final t = action * (i + 1) / frames;
            final step = tl.stepAt(t);
            return SizedBox.fromSize(
              size: tile,
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                child: CustomPaint(
                  painter: FigurePainter(
                    tl.at(t),
                    mirror: true, // 오소독스
                    guides: step >= 0 ? guides[step] : const [],
                    focus: focusOf(tl.at(t)),
                  ),
                ),
              ),
            );
          }(),
      ]));
    }

    // 가드 리듬: 2.4Hz 한 주기를 8등분.
    rows.add(Row(textDirection: TextDirection.ltr, children: [
      for (var i = 0; i < frames; i++)
        SizedBox.fromSize(
          size: tile,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
            child: CustomPaint(
              painter: FigurePainter(
                withRhythm(guardPose, i / frames / 2.4, 1).build(),
                mirror: true,
                focus: focusOf(guardPose.build()),
              ),
            ),
          ),
        ),
    ]));

    const key = Key('frames');
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: Container(
        color: const Color(0xFF2A1010),
        child: Column(children: rows),
      ),
    ));
    await expectLater(find.byKey(key), matchesGoldenFile('combo_frames.png'));
  });
}
