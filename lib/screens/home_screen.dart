import 'package:flutter/material.dart';

import '../engine/combo_generator.dart';
import '../engine/speaker.dart';
import '../models/moves.dart';
import '../models/settings.dart';
import 'session_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.speaker});

  final Speaker speaker;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TrainingSettings? _settings;
  List<String> _samples = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await SettingsStore.load();
    try {
      await widget.speaker.init();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _settings = s;
      _samples = _makeSamples(s);
    });
  }

  List<String> _makeSamples(TrainingSettings s) {
    final gen = ComboGenerator(s);
    final calls = <String>{};
    for (var i = 0; i < 40 && calls.length < 6; i++) {
      calls.add(gen.generate().call(s.stance, s.callStyle, direction: s.callDirection));
    }
    return calls.toList();
  }

  void _update(TrainingSettings next) {
    final prev = _settings!;
    final combosChanged = prev.level != next.level ||
        prev.stance != next.stance ||
        prev.callStyle != next.callStyle ||
        prev.callDirection != next.callDirection ||
        prev.includeDefense != next.includeDefense ||
        prev.includeBody != next.includeBody;
    setState(() {
      _settings = next;
      if (combosChanged) _samples = _makeSamples(next);
    });
    SettingsStore.save(next);
  }

  Future<void> _preview(String call) async {
    widget.speaker.unlock();
    await widget.speaker.interrupt();
    await widget.speaker.setRate(_settings!.speechRate);
    await widget.speaker.say(call);
  }

  void _start() {
    widget.speaker.unlock();
    widget.speaker.interrupt();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SessionScreen(settings: _settings!, speaker: widget.speaker),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    if (s == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('미트 콜')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Section(
            title: '난이도',
            child: SegmentedButton<Level>(
              segments: [
                for (final l in Level.values) ButtonSegment(value: l, label: Text(l.label)),
              ],
              selected: {s.level},
              onSelectionChanged: (v) => _update(s.copyWith(level: v.first)),
            ),
          ),
          _Section(
            title: '스탠스',
            child: SegmentedButton<Stance>(
              segments: [
                for (final v in Stance.values) ButtonSegment(value: v, label: Text(v.label)),
              ],
              selected: {s.stance},
              onSelectionChanged: (v) => _update(s.copyWith(stance: v.first)),
            ),
          ),
          _Section(
            title: '콜 방식',
            child: SegmentedButton<CallStyle>(
              segments: [
                for (final v in CallStyle.values) ButtonSegment(value: v, label: Text(v.label)),
              ],
              selected: {s.callStyle},
              onSelectionChanged: (v) => _update(s.copyWith(callStyle: v.first)),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('방향 지시 (레프트/라이트)'),
            subtitle: const Text('끄면 흐름상 정해지는 방향은 생략, 같은 손 연타는 "더블"'),
            value: s.callDirection,
            onChanged: (v) => _update(s.copyWith(callDirection: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('방어 동작 포함'),
            subtitle: const Text('슬립, 더킹, 위빙, 풀백, 백스텝'),
            value: s.includeDefense,
            onChanged: (v) => _update(s.copyWith(includeDefense: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('바디 공격 포함'),
            value: s.includeBody,
            onChanged: (v) => _update(s.copyWith(includeBody: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('자세 그림 표시'),
            subtitle: const Text('콤보 동작을 단계별 픽토그램으로'),
            value: s.showFigure,
            onChanged: s.earOnly ? null : (v) => _update(s.copyWith(showFigure: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('소리만 모드'),
            subtitle: const Text('화면에 콤보를 띄우지 않음'),
            value: s.earOnly,
            onChanged: (v) => _update(s.copyWith(earOnly: v)),
          ),
          const Divider(height: 32),
          _SliderTile(
            title: '라운드 시간',
            valueLabel: _mmss(s.roundSeconds),
            value: s.roundSeconds.toDouble(),
            min: 30,
            max: 300,
            divisions: 9,
            onChanged: (v) => _update(s.copyWith(roundSeconds: v.round())),
          ),
          _SliderTile(
            title: '휴식 시간',
            valueLabel: _mmss(s.restSeconds),
            value: s.restSeconds.toDouble(),
            min: 15,
            max: 120,
            divisions: 7,
            onChanged: (v) => _update(s.copyWith(restSeconds: v.round())),
          ),
          _SliderTile(
            title: '라운드 수',
            valueLabel: '${s.rounds}R',
            value: s.rounds.toDouble(),
            min: 1,
            max: 12,
            divisions: 11,
            onChanged: (v) => _update(s.copyWith(rounds: v.round())),
          ),
          _SliderTile(
            title: '말 속도',
            valueLabel: s.speechRate.toStringAsFixed(2),
            value: s.speechRate,
            min: 0.35,
            max: 0.8,
            divisions: 9,
            onChanged: (v) => _update(s.copyWith(speechRate: v)),
          ),
          _SliderTile(
            title: '익숙한 콤보 반복',
            subtitle: '높을수록 같은 패턴이 자주 나와 몸에 익음',
            valueLabel: '${(s.repeatRatio * 100).round()}%',
            value: s.repeatRatio,
            min: 0,
            max: 0.8,
            divisions: 8,
            onChanged: (v) => _update(s.copyWith(repeatRatio: v)),
          ),
          const Divider(height: 32),
          Row(
            children: [
              Text('콤보 미리보기', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                tooltip: '다시 만들기',
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() => _samples = _makeSamples(s)),
              ),
            ],
          ),
          for (final call in _samples)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(call, style: const TextStyle(fontSize: 18)),
              trailing: const Icon(Icons.volume_up),
              onTap: () => _preview(call),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
            onPressed: _start,
            icon: const Icon(Icons.sports_mma),
            label: const Text('시작', style: TextStyle(fontSize: 20)),
          ),
        ),
      ),
    );
  }
}

String _mmss(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    this.subtitle,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const Spacer(),
            Text(valueLabel, style: theme.textTheme.titleSmall),
          ],
        ),
        if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
