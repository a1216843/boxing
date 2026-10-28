import 'dart:math';

import '../models/moves.dart';
import '../models/settings.dart';

class Combo {
  Combo(this.moves);

  final List<Move> moves;

  String get key => moves.map((m) => m.id).join('-');

  /// 콤보 전체를 수행하는 데 걸리는 대략적인 시간(초).
  double get duration => moves.fold(0.0, (sum, m) => sum + m.duration);

  /// 화면용 콜. 동작 단위를 " · "로 구분한다 ("잽 · 바디 잽 · 잽").
  String call(Stance stance, CallStyle style) => phrases(stance, style).join(' · ');

  /// TTS용 콜. 동작 사이에 쉼표를 넣어 짧게 끊어 읽게 한다.
  /// "라이트 바디 라이트 어퍼"가 "라이트, 바디 라이트, 어퍼"처럼 섞여 들리지 않도록.
  String speech(Stance stance, CallStyle style) => phrases(stance, style).join(', ');

  /// 끊어 읽는 단위. 숫자끼리는 한 덩어리("원투쓰리"), 나머지는 동작 하나씩.
  List<String> phrases(Stance stance, CallStyle style) {
    final out = <String>[];
    String? prev;
    for (var i = 0; i < moves.length; i++) {
      final token = _token(i, stance, style);
      if (prev != null && _numberTokens.contains(prev) && _numberTokens.contains(token)) {
        out.last += token;
      } else {
        out.add(token);
      }
      prev = token;
    }
    return out;
  }

  /// 이름 콜에서 잽은 "잽"이지만, 바로 스트레이트가 이어지면 "원투"로 부른다.
  String _token(int i, Stance stance, CallStyle style) {
    final m = moves[i];
    if (style == CallStyle.name && m.id == Moves.jab.id) {
      final next = i + 1 < moves.length ? moves[i + 1] : null;
      return next?.id == Moves.cross.id ? '원' : '잽';
    }
    return m.call(stance, style);
  }
}

const _numberTokens = {'원', '투', '쓰리', '포', '파이브', '식스'};

/// 체중 이동 규칙을 따라 콤보를 만든다.
///
/// 한 동작씩 이어 붙이며, 현재 체중 위치에서 자세가 무너지는 동작
/// (예: 리드 쪽으로 슬립한 직후 리어 어퍼)은 후보에서 뺀다.
/// 이미 나온 콤보를 일정 확률로 다시 불러 패턴이 몸에 익게 한다.
class ComboGenerator {
  ComboGenerator(this.settings, {Random? random}) : _rnd = random ?? Random() {
    _moves = Moves.all.where(_enabled).toList();
  }

  /// compat × pairBonus가 이 값보다 작으면 자세상 무리한 연결로 보고 금지.
  static const awkwardThreshold = 0.12;
  static const poolSize = 8;

  final TrainingSettings settings;
  final Random _rnd;
  late final List<Move> _moves;
  final List<Combo> _pool = [];
  final List<String> _recent = [];

  LevelProfile get _profile => settings.level.profile;

  bool _enabled(Move m) {
    if (m.isDefense && !settings.includeDefense) return false;
    if (m.type == MoveType.body && !settings.includeBody) return false;
    return _profile.allows(m);
  }

  /// 다음에 부를 콤보. 직전 두 콤보와는 겹치지 않는다.
  Combo next() {
    Combo? combo;
    if (_pool.length >= 3 && _rnd.nextDouble() < settings.repeatRatio) {
      final candidates = _pool.where((c) => !_recent.contains(c.key)).toList();
      if (candidates.isNotEmpty) combo = candidates[_rnd.nextInt(candidates.length)];
    }
    combo ??= _fresh();
    _recent.add(combo.key);
    if (_recent.length > 2) _recent.removeAt(0);
    return combo;
  }

  Combo _fresh() {
    var combo = generate();
    for (var i = 0; i < 10 && _recent.contains(combo.key); i++) {
      combo = generate();
    }
    if (!_pool.any((p) => p.key == combo.key)) {
      _pool.add(combo);
      if (_pool.length > poolSize) _pool.removeAt(0);
    }
    return combo;
  }

  /// 규칙에 맞는 새 콤보 하나.
  Combo generate() {
    for (var attempt = 0; attempt < 30; attempt++) {
      final combo = _tryBuild(_weightedIndex(_profile.lengthWeights) + 1);
      if (combo != null) return combo;
    }
    return Combo([Moves.jab, Moves.cross]);
  }

  Combo? _tryBuild(int length) {
    final seq = <Move>[];
    var weight = Weight.center;
    var low = false;
    for (var i = 0; i < length; i++) {
      final candidates = <Move>[];
      final scores = <double>[];
      for (final m in _moves) {
        final s = _score(m, seq, weight, low, length);
        if (s > 0) {
          candidates.add(m);
          scores.add(s);
        }
      }
      if (candidates.isEmpty) return null;
      final m = candidates[_weightedIndex(scores)];
      seq.add(m);
      weight = m.result;
      low = m.lowAfter;
    }
    if (!seq.any((m) => m.isPunch)) return null;
    return Combo(seq);
  }

  double _score(Move m, List<Move> seq, Weight weight, bool low, int length) {
    final index = seq.length;
    final prev = seq.isEmpty ? null : seq.last;

    var fit = m.compat[weight] ?? 0;
    if (prev != null) fit *= pairBonus['${prev.id}>${m.id}'] ?? 1.0;
    if (fit < awkwardThreshold) return 0;

    var s = fit * m.freq;

    if (m.isDefense) {
      if (length == 1) return 0;
      if (seq.where((x) => x.isDefense).length >= _profile.maxDefenses) return 0;
      if (m.type == MoveType.step && index != 0 && index != length - 1) return 0;
      if (prev != null && prev.isDefense) {
        if (seq.length >= 2 && seq[seq.length - 2].isDefense) return 0;
        s *= 0.15;
      }
      s *= _profile.defenseRate;
    } else if (prev != null && prev.isDefense) {
      s *= 1.4; // 피하고 바로 카운터
    }

    if (prev != null && prev.id == m.id) {
      if (seq.length >= 2 && seq[seq.length - 2].id == m.id) return 0;
      s *= m.type == MoveType.jab ? 0.6 : 0.15;
    }

    if (index == 0 && m.type == MoveType.jab) s *= 1.8;

    if (low) {
      s *= switch (m.type) {
        MoveType.uppercut => 1.6,
        MoveType.body => 1.3,
        MoveType.jab => 0.7,
        MoveType.straight => 0.8,
        _ => 1.0,
      };
    }
    return s;
  }

  int _weightedIndex(List<double> weights) {
    final total = weights.fold(0.0, (a, b) => a + b);
    var r = _rnd.nextDouble() * total;
    for (var i = 0; i < weights.length; i++) {
      r -= weights[i];
      if (r < 0) return i;
    }
    return weights.length - 1;
  }
}
