import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'moves.dart';

class LevelProfile {
  const LevelProfile({
    required this.lengthWeights,
    required this.maxDefenses,
    required this.defenseRate,
    required this.gapMin,
    required this.gapMax,
    required this.tempo,
    required this.quickChance,
    required this.beat,
    required this.offbeatChance,
    required this.lowRate,
    required this.maxLow,
    required this.levelSwitch,
    required this.pairEmphasis,
    required this.variety,
    this.specialRate = 1.0,
    this.maxSpecials = 0,
    this.excluded = const <String>{},
  });

  /// 콤보 길이별 확률 가중치. index 0 = 1동작.
  final List<double> lengthWeights;

  /// 한 콤보 안에 들어갈 수 있는 방어 동작 수. 많으면 펀치보다 피하기가 주가 되므로 초급은 1개.
  final int maxDefenses;

  /// 방어 동작이 뽑힐 확률 배율.
  final double defenseRate;

  /// 콤보 세트 사이 휴지(초)의 범위. 이 안에서 랜덤하게 뽑아 다음 콜이 언제 나올지 모르게 한다.
  final double gapMin;
  final double gapMax;

  /// 동작 수행 시간 배율 (초급일수록 여유 있게).
  final double tempo;

  /// 휴지 없이 바로 다음 콤보를 부를 확률.
  final double quickChance;

  /// 콜 박자 한 칸(초). 콜은 이 박자에 맞춰 떨어진다.
  final double beat;

  /// 다음 콜을 반 박자 당기거나 끌 확률.
  final double offbeatChance;

  /// 자세 높이를 바꾸는 동작(바디샷, 더킹, 위빙 = 레벨 체인지)이 뽑힐 확률 배율.
  final double lowRate;

  /// 한 콤보 안에 들어갈 수 있는 레벨 체인지 동작 수.
  final int maxLow;

  /// 앞 동작과 높이가 다른 동작(위 → 아래, 아래 → 위)에 주는 배율. 1보다 크면 위아래를 오가는 콤보가 많아진다.
  final double levelSwitch;

  /// 정석 연결 가중치([pairBonus])를 몇 제곱해 쓸지. 1보다 크면 원투·원투쓰리 같은 기본 콤보가 더 자주,
  /// 1보다 작으면 여러 조합이 고르게 나온다.
  final double pairEmphasis;

  /// 같은 종류(훅, 어퍼 등)가 콤보 안에 이미 있을 때 배율. 작을수록 여러 종류를 섞는다.
  final double variety;

  /// 상급 기술이 뽑힐 확률 배율.
  final double specialRate;

  /// 한 콤보 안에 들어갈 수 있는 상급 기술 수. 0이면 쓰지 않는다.
  final int maxSpecials;

  /// 이 레벨에서 쓰지 않는 동작 id.
  final Set<String> excluded;

  int get maxLength => lengthWeights.length;

  bool allows(Move m) => !excluded.contains(m.id) && (maxSpecials > 0 || !m.special);
}

enum Level {
  beginner('초급', '원투, 원투쓰리 같은 기본 콤보 위주. 바디·높이 변화는 가끔'),
  intermediate('중급', '바디샷·더킹·위빙으로 위아래를 오가며 여러 조합을 섞음'),
  advanced('상급', '길게 이어 치는 연타, 피하고 바로 받아치는 연결. 점프 훅·체크 훅·오버핸드도 섞음');

  const Level(this.label, this.description);
  final String label;

  /// 난이도 설명 (설정 화면).
  final String description;

  /// 초급: 기본 콤보(원투, 원투쓰리 등) 위주, 높이 변화는 가끔.
  /// 중급: 레벨 체인지를 섞어 위아래를 오가고, 여러 조합을 고르게.
  /// 상급: 중급보다 길게 이어 치고, 피하고 받아치는 연결을 더 섞는다. 점프 훅·체크 훅·오버핸드도 나온다.
  LevelProfile get profile => switch (this) {
        Level.beginner => const LevelProfile(
            lengthWeights: [0.2, 0.45, 0.35],
            maxDefenses: 1,
            defenseRate: 0.5,
            gapMin: 3,
            gapMax: 7,
            tempo: 1.4,
            quickChance: 0.04,
            beat: 0.8,
            offbeatChance: 0.15,
            lowRate: 0.35,
            maxLow: 1,
            levelSwitch: 1.0,
            pairEmphasis: 1.6,
            variety: 1.0,
            excluded: {'rearHook', 'jabBody', 'duckLead', 'duckRear', 'weaveLead', 'weaveRear'},
          ),
        Level.intermediate => const LevelProfile(
            lengthWeights: [0.05, 0.25, 0.35, 0.25, 0.1],
            maxDefenses: 2,
            defenseRate: 0.8,
            gapMin: 2,
            gapMax: 6,
            tempo: 1.15,
            quickChance: 0.08,
            beat: 0.65,
            offbeatChance: 0.25,
            lowRate: 1.3,
            maxLow: 3,
            levelSwitch: 1.8,
            pairEmphasis: 0.8,
            variety: 0.55,
          ),
        Level.advanced => const LevelProfile(
            lengthWeights: [0.02, 0.1, 0.24, 0.28, 0.22, 0.14],
            maxDefenses: 2,
            defenseRate: 1.0,
            gapMin: 1.5,
            gapMax: 5,
            tempo: 1.0,
            quickChance: 0.12,
            beat: 0.55,
            offbeatChance: 0.3,
            lowRate: 1.2,
            maxLow: 3,
            levelSwitch: 1.6,
            pairEmphasis: 0.8,
            variety: 0.55,
            specialRate: 1.3,
            maxSpecials: 2,
          ),
      };
}

class TrainingSettings {
  const TrainingSettings({
    this.level = Level.intermediate,
    this.stance = Stance.orthodox,
    this.callStyle = CallStyle.number,
    this.includeDefense = true,
    this.includeBody = true,
    this.earOnly = false,
    this.showFigure = true,
    this.roundSeconds = 180,
    this.restSeconds = 60,
    this.rounds = 3,
    this.speechRate = 0.55,
    this.repeatRatio = 0.4,
    this.comboRepeats = 2,
  });

  final Level level;
  final Stance stance;
  final CallStyle callStyle;
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

  /// 같은 콤보를 연달아 부르는 횟수. 한 번 놓쳐도 다음에 다시 칠 수 있게.
  final int comboRepeats;

  TrainingSettings copyWith({
    Level? level,
    Stance? stance,
    CallStyle? callStyle,
    bool? includeDefense,
    bool? includeBody,
    bool? earOnly,
    bool? showFigure,
    int? roundSeconds,
    int? restSeconds,
    int? rounds,
    double? speechRate,
    double? repeatRatio,
    int? comboRepeats,
  }) {
    return TrainingSettings(
      level: level ?? this.level,
      stance: stance ?? this.stance,
      callStyle: callStyle ?? this.callStyle,
      includeDefense: includeDefense ?? this.includeDefense,
      includeBody: includeBody ?? this.includeBody,
      earOnly: earOnly ?? this.earOnly,
      showFigure: showFigure ?? this.showFigure,
      roundSeconds: roundSeconds ?? this.roundSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      rounds: rounds ?? this.rounds,
      speechRate: speechRate ?? this.speechRate,
      repeatRatio: repeatRatio ?? this.repeatRatio,
      comboRepeats: comboRepeats ?? this.comboRepeats,
    );
  }

  Map<String, Object> toJson() => {
        'level': level.name,
        'stance': stance.name,
        'callStyle': callStyle.name,
        'includeDefense': includeDefense,
        'includeBody': includeBody,
        'earOnly': earOnly,
        'showFigure': showFigure,
        'roundSeconds': roundSeconds,
        'restSeconds': restSeconds,
        'rounds': rounds,
        'speechRate': speechRate,
        'repeatRatio': repeatRatio,
        'comboRepeats': comboRepeats,
      };

  factory TrainingSettings.fromJson(Map<String, dynamic> j) {
    const d = TrainingSettings();
    T pick<T extends Enum>(List<T> values, T fallback, String key) =>
        values.firstWhere((v) => v.name == j[key], orElse: () => fallback);
    return TrainingSettings(
      level: pick(Level.values, d.level, 'level'),
      stance: pick(Stance.values, d.stance, 'stance'),
      callStyle: pick(CallStyle.values, d.callStyle, 'callStyle'),
      includeDefense: j['includeDefense'] as bool? ?? d.includeDefense,
      includeBody: j['includeBody'] as bool? ?? d.includeBody,
      earOnly: j['earOnly'] as bool? ?? d.earOnly,
      showFigure: j['showFigure'] as bool? ?? d.showFigure,
      roundSeconds: (j['roundSeconds'] as num?)?.toInt() ?? d.roundSeconds,
      restSeconds: (j['restSeconds'] as num?)?.toInt() ?? d.restSeconds,
      rounds: (j['rounds'] as num?)?.toInt() ?? d.rounds,
      speechRate: (j['speechRate'] as num?)?.toDouble() ?? d.speechRate,
      repeatRatio: (j['repeatRatio'] as num?)?.toDouble() ?? d.repeatRatio,
      comboRepeats: (j['comboRepeats'] as num?)?.toInt() ?? d.comboRepeats,
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
