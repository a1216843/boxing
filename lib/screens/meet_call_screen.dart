import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../engine/combo_generator.dart';
import '../engine/speaker.dart';
import '../engine/voices.dart';
import '../models/moves.dart';
import '../models/settings.dart';
import 'session_screen.dart';

/// 미트 콜: 설정을 고르고 라운드를 시작한다.
class MeetCallScreen extends StatefulWidget {
  const MeetCallScreen({super.key, required this.speaker});

  final Speaker speaker;

  @override
  State<MeetCallScreen> createState() => _MeetCallScreenState();
}

class _MeetCallScreenState extends State<MeetCallScreen> {
  TrainingSettings? _settings;
  List<String> _samples = const [];
  List<TtsVoice> _voices = const [];

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
    await _loadVoices();
  }

  /// 브라우저는 음성 목록을 늦게 불러와서, 비어 있으면 잠시 뒤 한 번 더 읽는다.
  Future<void> _loadVoices() async {
    for (var i = 0; i < 4; i++) {
      final v = await widget.speaker.voices();
      if (!mounted) return;
      if (v.isNotEmpty) {
        setState(() => _voices = v);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
  }

  List<String> _makeSamples(TrainingSettings s) {
    final gen = ComboGenerator(s);
    final calls = <String>{};
    for (var i = 0; i < 40 && calls.length < 6; i++) {
      calls.add(gen.generate().call(s.stance, s.callStyle));
    }
    return calls.toList();
  }

  void _update(TrainingSettings next) {
    final prev = _settings!;
    final combosChanged = prev.level != next.level ||
        prev.stance != next.stance ||
        prev.callStyle != next.callStyle ||
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
    await widget.speaker.setVoice(_settings!.voice);
    await widget.speaker.setRate(_settings!.speechRate);
    // 화면용 구분점(" · ")을 쉼표로 바꿔 실제 세션처럼 끊어 읽는다.
    await widget.speaker.say(call.replaceAll(' · ', ', '));
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<Level>(
                  segments: [
                    for (final l in Level.values) ButtonSegment(value: l, label: Text(l.label)),
                  ],
                  selected: {s.level},
                  onSelectionChanged: (v) => _update(s.copyWith(level: v.first)),
                ),
                const SizedBox(height: 6),
                Text(s.level.description, style: Theme.of(context).textTheme.bodySmall),
              ],
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
            title: const Text('방어 동작 포함'),
            subtitle: const Text('슬립, 더킹, 위빙, 스웨이, 백스텝'),
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
          _VoiceTile(
            voices: _voices,
            selected: s.voice,
            onChanged: (v) {
              _update(s.copyWith(voice: v));
              _preview('잽, 투, 훅. 라운드 1, 시작');
            },
            onPreview: () => _preview('잽, 투, 훅. 라운드 1, 시작'),
          ),
          _SliderTile(
            title: '같은 콤보 연속 횟수',
            subtitle: '한 번 놓쳐도 다음에 다시 칠 수 있게',
            valueLabel: '${s.comboRepeats}회',
            value: s.comboRepeats.toDouble(),
            min: 1,
            max: 3,
            divisions: 2,
            onChanged: (v) => _update(s.copyWith(comboRepeats: v.round())),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
                onPressed: _start,
                icon: const Icon(Icons.sports_mma),
                label: const Text('시작', style: TextStyle(fontSize: 20)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 목소리 고르기. 기기에 있는 한국어 음성 중 자연스러운 순으로, 맨 위는 자동.
class _VoiceTile extends StatelessWidget {
  const _VoiceTile({required this.voices, required this.selected, required this.onChanged, required this.onPreview});

  final List<TtsVoice> voices;
  final String selected;
  final ValueChanged<String> onChanged;
  final VoidCallback onPreview;

  /// 기기마다 더 자연스러운 음성을 얻는 방법.
  static String get _hint {
    // 아이폰 사파리(웹)도 기기의 음성을 쓰므로 아이폰 설정 안내를 보여 준다.
    if (kIsWeb && defaultTargetPlatform != TargetPlatform.iOS) {
      return '마이크로소프트 엣지에서 열면 가장 자연스러운 음성(Natural)을 쓸 수 있어요.';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS =>
        '설정 > 손쉬운 사용 > 읽기 및 말하기 > 음성 > 한국어에서 "향상됨"·"고품질" 음성을 내려받으면 더 자연스러워요.',
      TargetPlatform.android => '설정 > 텍스트 음성 변환에서 Google 음성 엔진과 한국어 음성 데이터를 설치하면 더 자연스러워요.',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final known = selected.isEmpty || voices.any((v) => v.name == selected);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('목소리', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: known ? selected : '',
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(voices.isEmpty ? '자동' : '자동 (${voices.first.label})',
                          overflow: TextOverflow.ellipsis),
                    ),
                    for (final v in voices)
                      DropdownMenuItem(value: v.name, child: Text(v.label, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => onChanged(v ?? ''),
                ),
              ),
              IconButton(tooltip: '미리 듣기', icon: const Icon(Icons.volume_up), onPressed: onPreview),
            ],
          ),
          if (_hint.isNotEmpty) Text(_hint, style: theme.textTheme.bodySmall),
        ],
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
