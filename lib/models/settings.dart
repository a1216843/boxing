import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'moves.dart';

class LevelProfile {
  const LevelProfile({
    required this.lengthWeights,
    required this.maxDefenses,
    required this.defenseRate,
    required this.baseGap,
    required this.tempo,
    required this.quickChance,
    required this.longChance,
    required this.beat,
    required this.offbeatChance,
    required this.breakChance,
    this.excluded = const <String>{},
  });

  /// 콤보 길이별 확률 가중치. index 0 = 1동작.
  final List<double> lengthWeights;

  /// 한 콤보 안에 들어갈 수 있는 방어 동작 수.
  final int maxDefenses;

  /// 방어 동작이 뽑힐 확률 배율.
  final double defenseRate;

  /// 콤보 사이 기본 휴지(초).
  final double baseGap;

  /// 동작 수행 시간 배율 (초급일수록 여유 있게).
  final double tempo;

  /// 쉴 틈 없이 몰아치는 콜이 나올 확률.
  final double quickChance;

  /// 일부러 길게 끌어 긴장을 유지시키는 휴지가 나올 확률.
  final double longChance;

  /// 콜 박자 한 칸(초). 콜은 이 박자에 맞춰 떨어진다.
  final double beat;

  /// 다음 콜을 반 박자 당기거나 끌 확률.
  final double offbeatChance;

  /// 콤보 중간에서 끊었다가 반 박자~한 박자 늦게 나머지를 부를 확률.
  final double breakChance;

  /// 이 레벨에서 쓰지 않는 동작 id.
  final Set<String> excluded;

  int get maxLength => lengthWeights.length;

  bool allows(Move m) => !excluded.contains(m.id);
}

enum Level {
  beginner('초급'),
  intermediate('중급'),
  advanced('고급');

  const Level(this.label);
  final String label;

  LevelProfile get profile => switch (this) {
        Level.beginner => const LevelProfile(
            lengthWeights: [0.2, 0.45, 0.35],
            maxDefenses: 1,
            defenseRate: 0.5,
            baseGap: 2.6,
            tempo: 1.4,
            quickChance: 0.06,
            longChance: 0.1,
            beat: 0.8,
            offbeatChance: 0.15,
            breakChance: 0.1,
            excluded: {'rearHook', 'jabBody', 'weaveLead', 'weaveRear', 'pullBack'},
          ),
        Level.intermediate => const LevelProfile(
            lengthWeights: [0.1, 0.3, 0.35, 0.25],
            maxDefenses: 2,
            defenseRate: 0.8,
            baseGap: 1.8,
            tempo: 1.15,
            quickChance: 0.14,
            longChance: 0.12,
            beat: 0.65,
            offbeatChance: 0.25,
            breakChance: 0.2,
          ),
        Level.advanced => const LevelProfile(
            lengthWeights: [0.06, 0.2, 0.3, 0.26, 0.18],
            maxDefenses: 2,
            defenseRate: 1.0,
            baseGap: 1.2,
            tempo: 1.0,
            quickChance: 0.22,
            longChance: 0.12,
            beat: 0.55,
            offbeatChance: 0.3,
            breakChance: 0.25,
          ),
      };
}

class TrainingSettings {
  const TrainingSettings({
    this.level = Level.intermediate,
    this.stance = Stance.orthodox,
    this.callStyle = CallStyle.number,
    this.callDirection = true,
    this.includeDefense = true,
    this.includeBody = true,
    this.earOnly = false,
    this.showFigure = true,
    this.roundSeconds = 180,
    this.restSeconds = 60,
    this.rounds = 3,
    this.speechRate = 0.55,
    this.repeatRatio = 0.4,
  });

  final Level level;
  final Stance stance;
  final CallStyle callStyle;

  /// 레프트/라이트 방향을 콜에 넣는다. 끄면 흐름상 정해지는 방향은 생략한다.
  final bool callDirection;
  final bool includeDefense;
  final bool includeBody;

  /// 화면에 콤보를 띄우지 않고 소리로만 훈련.
  final bool earOnly;

  /// 콤보 동작을 픽토그램으로 보여준다.
  final bool showFigure;
  final int roundSeconds;
  final int restSeconds;
  final int rounds;
  final double speechRate;

  /// 이미 나온 콤보를 다시 부를 확률. 높을수록 패턴이 몸에 익는다.
  final double repeatRatio;

  TrainingSettings copyWith({
    Level? level,
    Stance? stance,
    CallStyle? callStyle,
    bool? callDirection,
    bool? includeDefense,
    bool? includeBody,
    bool? earOnly,
    bool? showFigure,
    int? roundSeconds,
    int? restSeconds,
    int? rounds,
    double? speechRate,
    double? repeatRatio,
  }) {
    return TrainingSettings(
      level: level ?? this.level,
      stance: stance ?? this.stance,
      callStyle: callStyle ?? this.callStyle,
      callDirection: callDirection ?? this.callDirection,
      includeDefense: includeDefense ?? this.includeDefense,
      includeBody: includeBody ?? this.includeBody,
      earOnly: earOnly ?? this.earOnly,
      showFigure: showFigure ?? this.showFigure,
      roundSeconds: roundSeconds ?? this.roundSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      rounds: rounds ?? this.rounds,
      speechRate: speechRate ?? this.speechRate,
      repeatRatio: repeatRatio ?? this.repeatRatio,
    );
  }

  Map<String, Object> toJson() => {
        'level': level.name,
        'stance': stance.name,
        'callStyle': callStyle.name,
        'callDirection': callDirection,
        'includeDefense': includeDefense,
        'includeBody': includeBody,
        'earOnly': earOnly,
        'showFigure': showFigure,
        'roundSeconds': roundSeconds,
        'restSeconds': restSeconds,
        'rounds': rounds,
        'speechRate': speechRate,
        'repeatRatio': repeatRatio,
      };

  factory TrainingSettings.fromJson(Map<String, dynamic> j) {
    const d = TrainingSettings();
    T pick<T extends Enum>(List<T> values, T fallback, String key) =>
        values.firstWhere((v) => v.name == j[key], orElse: () => fallback);
    return TrainingSettings(
      level: pick(Level.values, d.level, 'level'),
      stance: pick(Stance.values, d.stance, 'stance'),
      callStyle: pick(CallStyle.values, d.callStyle, 'callStyle'),
      callDirection: j['callDirection'] as bool? ?? d.callDirection,
      includeDefense: j['includeDefense'] as bool? ?? d.includeDefense,
      includeBody: j['includeBody'] as bool? ?? d.includeBody,
      earOnly: j['earOnly'] as bool? ?? d.earOnly,
      showFigure: j['showFigure'] as bool? ?? d.showFigure,
      roundSeconds: (j['roundSeconds'] as num?)?.toInt() ?? d.roundSeconds,
      restSeconds: (j['restSeconds'] as num?)?.toInt() ?? d.restSeconds,
      rounds: (j['rounds'] as num?)?.toInt() ?? d.rounds,
      speechRate: (j['speechRate'] as num?)?.toDouble() ?? d.speechRate,
      repeatRatio: (j['repeatRatio'] as num?)?.toDouble() ?? d.repeatRatio,
    );
  }
}

abstract final class SettingsStore {
  static const _key = 'training_settings';

  static Future<TrainingSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return const TrainingSettings();
      return TrainingSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const TrainingSettings();
    }
  }

  static Future<void> save(TrainingSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(s.toJson()));
  }
}
