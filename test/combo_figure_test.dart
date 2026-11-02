import 'package:boxing_coach/models/moves.dart';
import 'package:boxing_coach/pose/combo_figure.dart';
import 'package:boxing_coach/pose/figure_painter.dart';
import 'package:boxing_coach/pose/poses.dart';
import 'package:boxing_coach/pose/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('콤보가 바뀌거나 다시 재생돼도 인형이 순간이동하지 않는다', (tester) async {
    Widget figure(List<Move> moves, int playId) => MaterialApp(
          home: ComboFigure(
            moves: moves,
            stance: Stance.orthodox,
            callStyle: CallStyle.values.first,
            tempo: 1,
            playId: playId,
          ),
        );
    // 화면 위치 = 카메라가 보는 지점 대비 골반.
    double shown() {
      final p = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((c) => c.painter)
          .whereType<FigurePainter>()
          .firstWhere((p) => p.zoom == 0.7);
      return (p.skeleton[J.pelvis] - p.focus).z;
    }

    const step = [Moves.jab, Moves.cross];
    await tester.pumpWidget(figure(step, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpWidget(figure(step, 1));
    var last = shown();
    // 두 번 반복 재생 + 다른 콤보로 바뀌는 순간까지, 프레임 사이 이동이 스텝 속도를 넘지 않는다.
    for (final (moves, id) in [(step, 2), (const [Moves.slipLead, Moves.leadHook], 3)]) {
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final now = shown();
        expect((now - last).abs(), lessThan(0.03), reason: 'frame $i of $id');
        last = now;
      }
      await tester.pumpWidget(figure(moves, id));
      await tester.pump(const Duration(milliseconds: 16));
      final now = shown();
      expect((now - last).abs(), lessThan(0.03), reason: 'switch to $id');
      last = now;
    }
  });

  testWidgets('더킹 도중 다음 콤보가 오면 낮은 자세가 남지 않고 가드로 돌아온다', (tester) async {
    Widget figure(List<Move> moves, int playId) => MaterialApp(
          home: ComboFigure(
            moves: moves,
            stance: Stance.orthodox,
            callStyle: CallStyle.values.first,
            tempo: 1,
            playId: playId,
          ),
        );
    double headDrop() {
      final p = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((c) => c.painter)
          .whereType<FigurePainter>()
          .firstWhere((p) => p.zoom == 0.7);
      return guardPose.build()[J.head].y - p.skeleton[J.head].y;
    }

    const duck = [Moves.jab, Moves.duckLead];
    await tester.pumpWidget(figure(duck, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpWidget(figure(duck, 1));
    var low = 0.0;
    for (var i = 0; i < 60 && low < 0.2; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      low = headDrop();
    }
    expect(low, greaterThan(0.2), reason: '더킹으로 낮아진 순간');
    await tester.pumpWidget(figure(const [Moves.cross, Moves.leadHook], 1));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // 가드 리듬으로 가볍게 오르내리는 정도만 남는다.
    expect(headDrop(), lessThan(0.1));
  });
}
