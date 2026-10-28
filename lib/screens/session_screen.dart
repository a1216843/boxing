import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../engine/session_controller.dart';
import '../engine/speaker.dart';
import '../models/settings.dart';
import '../pose/combo_figure.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.settings, required this.speaker});

  final TrainingSettings settings;
  final Speaker speaker;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late final SessionController _session = SessionController(widget.settings, widget.speaker);

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _session.start();
  }

  @override
  void dispose() {
    _session.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final s = _session;
        final color = _phaseColor(s.phase);
        final clock = s.phase == SessionPhase.ready
            ? Duration(seconds: widget.settings.roundSeconds)
            : s.remaining;
        return Scaffold(
          backgroundColor: Color.lerp(Colors.black, color, 0.25),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('라운드 ${s.round} / ${widget.settings.rounds}', style: text.titleMedium),
                      const Spacer(),
                      Chip(label: Text(_phaseLabel(s)), backgroundColor: color),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _format(clock),
                    style: text.displayLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (_showFigure(s)) ...[
                    const SizedBox(height: 8),
                    _callView(s, text.headlineLarge),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ComboFigure(
                        moves: s.combo!.moves,
                        stance: widget.settings.stance,
                        callStyle: widget.settings.callStyle,
                        // 화면으로 자세를 확인하는 용도라 실제보다 약간 느리게.
                        tempo: widget.settings.level.profile.tempo * 1.2,
                        playId: s.actionId,
                        holds: s.plan!.holds,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else
                    Expanded(child: Center(child: _callView(s, text.displayMedium))),
                  _controls(s),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _showFigure(SessionController s) =>
      widget.settings.showFigure &&
      !widget.settings.earOnly &&
      s.phase == SessionPhase.work &&
      s.combo != null;

  Widget _callView(SessionController s, TextStyle? style) {
    final hide = widget.settings.earOnly && s.phase == SessionPhase.work;
    final Widget child = hide
        ? Icon(Icons.graphic_eq, key: ValueKey(s.displayId), size: 120, color: Colors.white70)
        // 한글은 글자 단위로 줄이 바뀌므로("백 / 스텝") 단어 단위로 감싼다.
        : Wrap(
            key: ValueKey(s.displayId),
            alignment: WrapAlignment.center,
            spacing: 16,
            children: [
              for (final word in (s.display ?? '').split(' '))
                Text(
                  word,
                  style: style?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                ),
            ],
          );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }

  Widget _controls(SessionController s) {
    const height = Size.fromHeight(60);
    if (s.phase == SessionPhase.finished) {
      return FilledButton(
        style: FilledButton.styleFrom(minimumSize: height),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('돌아가기'),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: height),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.stop),
            label: const Text('그만'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: height),
            onPressed: s.togglePause,
            icon: Icon(s.paused ? Icons.play_arrow : Icons.pause),
            label: Text(s.paused ? '계속' : '일시정지'),
          ),
        ),
      ],
    );
  }
}

Color _phaseColor(SessionPhase p) => switch (p) {
      SessionPhase.ready => Colors.amber.shade800,
      SessionPhase.work => Colors.red.shade700,
      SessionPhase.rest => Colors.teal.shade700,
      SessionPhase.finished => Colors.blueGrey.shade700,
    };

String _phaseLabel(SessionController s) {
  if (s.paused) return '일시정지';
  return switch (s.phase) {
    SessionPhase.ready => '준비',
    SessionPhase.work => '운동',
    SessionPhase.rest => '휴식',
    SessionPhase.finished => '완료',
  };
}

String _format(Duration d) {
  final total = (d.inMilliseconds / 1000).ceil();
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}
