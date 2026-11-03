// 콤비네이션 보기(두 인형) 애니메이션을 시간별 프레임으로 렌더링해 확인하는 개발용 도구.
// flutter test tool/sparring_frames_test.dart --update-goldens
// → tool/sparring_frames.png (줄마다 콤보 하나, 왼쪽→오른쪽 시간 순)
import 'package:boxing_coach/models/moves.dart';
import 'package:boxing_coach/pose/figure_painter.dart';
import 'package:boxing_coach/pose/sparring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sparring frames', (tester) async {
    const combos = [
      [Moves.jab, Moves.cross, Moves.leadHook],
      [Moves.slipRear, Moves.cross],
      [Moves.jab, Moves.cross, Moves.weaveRear, Moves.cross],
      [Moves.cross, Moves.leadHook, Moves.weaveLead, Moves.leadHook],
      [Moves.jab, Moves.cross, Moves.duckRear, Moves.rearUpper],
      [Moves.jab, Moves.cross, Moves.leadBody, Moves.leadHook],
      [Moves.jab, Moves.cross, Moves.checkHook],
      [Moves.jab, Moves.jumpHook, Moves.cross],
      [Moves.slipRear, Moves.slipLead, Moves.leadHook, Moves.cross, Moves.leadHook],
      [Moves.slipLead, Moves.leadUpper, Moves.leadHook, Moves.cross, Moves.backStep],
    ];
    const frames = 10;
    const tile = Size(200, 200);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(tile.width * frames, tile.height * combos.length);
    addTearDown(tester.view.reset);

    final rows = <Widget>[];
    for (final moves in combos) {
      final sp = SparringTimeline(moves, tempo: 1.3);
      final from = SparringTimeline.lead + sp.me.startOf(0), to = SparringTimeline.lead + sp.me.actionEnd;
      rows.add(Row(textDirection: TextDirection.ltr, children: [
        for (var i = 0; i < frames; i++)
          () {
            final t = from + (to - from) * (i + 0.5) / frames;
            final me = sp.meAt(t), opp = sp.opponentAt(t);
            final step = sp.stepAt(t);
            return SizedBox.fromSize(
              size: tile,
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                child: Stack(children: [
                  CustomPaint(
                    size: tile,
                    painter: FigurePainter(me,
                        opponent: opp, mirror: true, focus: sparringFocus(me, opp), viewYaw: -72, elevation: 12, zoom: 0.62),
                  ),
                  Positioned(
                    left: 4,
                    top: 2,
                    child: Text(
                      step < 0 ? '' : '${moves[step].id} / ${sp.opponentCall(step, Stance.orthodox) ?? ''}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                ]),
              ),
            );
          }(),
      ]));
    }

    const key = Key('frames');
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(color: const Color(0xFF2A1010), child: Column(children: rows)),
      ),
    ));
    await expectLater(find.byKey(key), matchesGoldenFile('sparring_frames.png'));
  });
}
