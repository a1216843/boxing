// 콤보 카드 지도(web/combo_map/)의 데이터와 카드 그림을 다시 만드는 개발용 도구.
// 동작 값이나 자세를 바꾼 뒤: flutter test tool/combo_map_export_test.dart
// → web/combo_map/data.js, web/combo_map/cards/<동작>_<o|s>.png (o = 오소독스, s = 사우스포)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:boxing_coach/models/moves.dart';
import 'package:boxing_coach/pose/figure_painter.dart';
import 'package:boxing_coach/pose/poses.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'combo_map_data.dart';

const _out = 'web/combo_map';

void main() {
  testWidgets('combo map export', (tester) async {
    Directory('$_out/cards').createSync(recursive: true);
    File('$_out/data.js').writeAsStringSync(comboMapDataJs());

    const size = Size(360, 440);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final guard = guardPose.build();
    final tiles = [
      ('guard', guard, const <Guide>[], false),
      for (final m in Moves.all) (m.id, peakSkeleton(m), motionGuides(m), !m.isPunch),
    ];
    for (final (id, skeleton, guides, defense) in tiles) {
      // 앱 하단 카드와 같은 그림: 오소독스는 좌우를 뒤집어 그린다.
      for (final mirror in [true, false]) {
        const key = Key('tile');
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: SizedBox.fromSize(
            size: size,
            child: CustomPaint(
              painter: FigurePainter(
                skeleton,
                mirror: mirror,
                guides: guides,
                ghost: defense ? guard : null,
                focus: focusOf(skeleton),
                zoom: 0.85,
                floor: false,
              ),
            ),
          ),
        ));
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$_out/cards/${id}_${mirror ? 'o' : 's'}.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }
    }
  });
}
