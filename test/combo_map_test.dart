import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/combo_map_data.dart';

void main() {
  test('콤보 카드 지도 데이터가 앱의 동작 값과 같다', () {
    expect(
      File('web/combo_map/data.js').readAsStringSync().replaceAll('\r\n', '\n'),
      comboMapDataJs(),
      reason: '동작 값이 바뀌었으면 flutter test tool/combo_map_export_test.dart 로 다시 만든다',
    );
  });
}
