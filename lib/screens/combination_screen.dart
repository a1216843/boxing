import 'package:flutter/material.dart';

import '../engine/combo_generator.dart';
import '../models/combo_library.dart';
import '../models/moves.dart';
import '../models/settings.dart';
import '../pose/sparring.dart';
import '../pose/sparring_view.dart';

/// 콤비네이션 보기: 난이도별 콤보 목록. 누르면 상대 인형과 함께 시연한다.
class CombinationListScreen extends StatefulWidget {
  const CombinationListScreen({super.key, required this.settings});

  /// 처음 보여 줄 난이도, 스탠스, 콜 방식.
  final TrainingSettings settings;

  @override
  State<CombinationListScreen> createState() => _CombinationListScreenState();
}

class _CombinationListScreenState extends State<CombinationListScreen> {
  late Level _level = widget.settings.level;

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final list = comboLibrary[_level]!;
    return Scaffold(
      appBar: AppBar(title: const Text('콤비네이션 보기')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<Level>(
              segments: [for (final l in Level.values) ButtonSegment(value: l, label: Text(l.label))],
              selected: {_level},
              onSelectionChanged: (v) => setState(() => _level = v.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(_level.description, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, i) {
                final e = list[i];
                return ListTile(
                  title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(Combo(e.moves).call(s.stance, s.callStyle),
                          style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: 2),
                      Text(e.note),
                    ],
                  ),
                  trailing: const Icon(Icons.play_circle_outline),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CombinationDemoScreen(example: e, stance: s.stance, callStyle: s.callStyle),
                  )),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 콤보 하나를 상대 인형과 함께 반복 시연한다. 아래에는 단계마다 내 동작과 상대 반응.
class CombinationDemoScreen extends StatefulWidget {
  const CombinationDemoScreen({super.key, required this.example, required this.stance, required this.callStyle});

  final ComboExample example;
  final Stance stance;
  final CallStyle callStyle;

  @override
  State<CombinationDemoScreen> createState() => _CombinationDemoScreenState();
}

class _CombinationDemoScreenState extends State<CombinationDemoScreen> {
  /// 보고 따라 할 수 있도록 실제보다 느린 템포로 만든다 (미트 콜 화면 인형과 비슷하게).
  late final _timeline = SparringTimeline(widget.example.moves, tempo: 1.3);
  late final _calls = Combo(widget.example.moves).phrasesPerMove(widget.stance, widget.callStyle);
  bool _playing = true;
  bool _slow = false;
  int _step = -1;

  @override
  Widget build(BuildContext context) {
    final e = widget.example;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(e.title)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(Combo(e.moves).call(widget.stance, widget.callStyle),
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(e.note, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Expanded(
              child: SparringView(
                timeline: _timeline,
                stance: widget.stance,
                speed: _slow ? 0.5 : 1.0,
                playing: _playing,
                onStep: (i) => setState(() => _step = i),
              ),
            ),
            _Legend(scheme: scheme),
            SizedBox(
              height: 74,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: e.moves.length,
                itemBuilder: (context, i) => _StepCard(
                  mine: _calls[i],
                  theirs: _timeline.opponentCall(i, widget.stance),
                  active: i == _step,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => setState(() => _playing = !_playing),
                      icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                      label: Text(_playing ? '일시정지' : '재생'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _slow = !_slow),
                      icon: const Icon(Icons.slow_motion_video),
                      label: Text(_slow ? '보통 속도' : '느리게'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 어느 인형이 나인지.
class _Legend extends StatelessWidget {
  const _Legend({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          dot(Colors.white, '나'),
          const SizedBox(width: 16),
          dot(const Color(0xFF90A4AE), '상대'),
          const SizedBox(width: 16),
          Text('좌우로 끌어 시점 회전', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.mine, required this.theirs, required this.active});

  final String mine;
  final String? theirs;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(minWidth: 84),
      decoration: BoxDecoration(
        color: active ? scheme.primary.withAlpha(60) : Colors.white.withAlpha(12),
        border: Border.all(color: active ? scheme.primary : Colors.transparent, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(mine, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(theirs ?? ' ',
              style: TextStyle(fontSize: 12, color: const Color(0xFF90A4AE).withAlpha(theirs == null ? 0 : 255))),
        ],
      ),
    );
  }
}
