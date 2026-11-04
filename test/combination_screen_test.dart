import 'package:boxing_coach/models/combo_library.dart';
import 'package:boxing_coach/models/moves.dart';
import 'package:boxing_coach/models/settings.dart';
import 'package:boxing_coach/engine/combo_generator.dart';
import 'package:boxing_coach/screens/combination_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('콤비네이션 보기: 콜 방식을 바꾸면 목록 표기가 그 방식으로 바뀌고 설정에 저장된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const s = TrainingSettings(level: Level.beginner, callStyle: CallStyle.number);
    await tester.pumpWidget(const MaterialApp(home: CombinationListScreen(settings: s)));
    final first = comboLibrary[Level.beginner]![4].moves;
    final number = Combo(first).call(s.stance, CallStyle.number);
    final name = Combo(first).call(s.stance, CallStyle.name);
    expect(number, isNot(name));
    expect(find.text(number), findsOneWidget);

    await tester.tap(find.text(CallStyle.name.label));
    await tester.pumpAndSettle();
    expect(find.text(name), findsOneWidget);
    expect(find.text(number), findsNothing);
    expect((await SettingsStore.load()).callStyle, CallStyle.name);
  });
}
