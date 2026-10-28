// 모든 자세를 한 장의 그림으로 렌더링해 확인하는 개발용 도구.
// flutter test tool/pose_gallery_test.dart --update-goldens
// → tool/pose_gallery.png (윗줄 오소독스, 아랫줄 사우스포)
import 'package:boxing_coach/models/moves.dart';
import 'package:boxing_coach/pose/figure_painter.dart';
import 'package:boxing_coach/pose/poses.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pose gallery', (tester) async {
    const tile = Size(200, 260);
    const perRow = 6;
    final guard = guardPose.build();
    final tiles = [
      (guardPose, const <Guide>[], false),
      for (final m in Moves.all) (strikePose(m), motionGuides(m), m.isDefense),
    ];
    final rows = (tiles.length / perRow).ceil() * 2;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(tile.width * perRow, tile.height * rows);
    addTearDown(tester.view.reset);

    const key = Key('gallery');
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: Container(
        color: const Color(0xFF2A1010),
        child: Wrap(textDirection: TextDirection.ltr, children: [
          for (final mirror in [false, true])
            for (final (pose, guides, defense) in tiles)
            SizedBox.fromSize(
              size: tile,
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                child: CustomPaint(painter: FigurePainter(
                  pose.build(),
                  mirror: mirror,
                  guides: guides,
                  ghost: defense ? guard : null,
                  focus: pose.base,
                )),
              ),
            ),
        ]),
      ),
    ));
    await expectLater(find.byKey(key), matchesGoldenFile('pose_gallery.png'));
  });
}
