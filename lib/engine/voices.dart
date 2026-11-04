/// 기기에 있는 한국어 TTS 음성 중 자연스러운 것을 고른다.
///
/// flutter_tts가 플랫폼마다 주는 정보가 다르다:
/// - iOS/macOS: quality(default / enhanced / premium), identifier
/// - Android: quality(very high / high / normal …), network_required
/// - 웹: 이름과 언어만. 그래서 이름으로 가린다 (엣지 "… Online (Natural)", 크롬 "Google 한국의").
class TtsVoice {
  const TtsVoice({required this.name, required this.locale, this.quality, this.network = false, this.identifier});

  final String name;
  final String locale;
  final String? quality;
  final bool network;
  final String? identifier;

  static TtsVoice? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name']?.toString();
    final locale = raw['locale']?.toString();
    if (name == null || locale == null) return null;
    return TtsVoice(
      name: name,
      locale: locale,
      quality: raw['quality']?.toString(),
      network: raw['network_required']?.toString() == '1',
      identifier: raw['identifier']?.toString(),
    );
  }

  bool get isKorean => locale.toLowerCase().replaceAll('_', '-').startsWith('ko');

  /// flutter_tts setVoice에 넘길 값. iOS는 identifier가 있으면 그것으로 정확히 고른다.
  Map<String, String> toMap() => {
        'name': name,
        'locale': locale,
        if (identifier != null && identifier!.isNotEmpty) 'identifier': identifier!,
      };

  /// 클수록 자연스럽다 (대략적인 순위).
  int get score {
    final n = name.toLowerCase();
    var s = 0;
    // 웹: 엣지의 신경망 음성이 가장 자연스럽고, 크롬의 구글 음성이 그다음.
    if (n.contains('natural')) s += 100;
    if (n.contains('online')) s += 30;
    if (n.contains('google')) s += 50;
    // iOS/macOS: 설정에서 내려받는 향상된·고품질 음성.
    switch (quality) {
      case 'premium':
        s += 90;
      case 'enhanced':
        s += 70;
      // Android: 품질 등급.
      case 'very high':
        s += 60;
      case 'high':
        s += 40;
      case 'low' || 'very low':
        s -= 20;
    }
    if (n.contains('premium') || n.contains('고품질')) s += 20;
    if (n.contains('enhanced') || n.contains('향상')) s += 15;
    if (n.contains('compact')) s -= 20;
    // 인터넷이 필요한 음성은 콜이 늦게 나올 수 있어 같은 품질이면 기기 음성을 먼저.
    if (network) s -= 10;
    return s;
  }

  /// 화면에 보일 이름.
  String get label {
    // 안드로이드 구글 음성은 "ko-kr-x-ism-local" 같은 이름이라 읽기 쉽게 바꾼다.
    final android = RegExp(r'^ko-kr-x-(\w+)-(local|network)$').firstMatch(name.toLowerCase());
    if (android != null) {
      return '음성 ${android.group(1)!.toUpperCase()} (${android.group(2) == 'network' ? '온라인' : '기기'})';
    }
    final tag = switch (quality) {
      'premium' => ' · 고품질',
      'enhanced' => ' · 향상됨',
      'very high' => ' · 매우 좋음',
      _ => '',
    };
    final short = name.replaceAll(RegExp(r'\s*-\s*Korean \(Korea\)$'), '');
    return '$short$tag';
  }
}

/// 한국어 음성만, 자연스러운 순서로.
List<TtsVoice> koreanVoices(Iterable<Object?> raw) {
  final seen = <String>{};
  final list = [
    for (final v in raw.map(TtsVoice.fromMap))
      if (v != null && v.isKorean && seen.add('${v.name}|${v.locale}')) v,
  ];
  list.sort((a, b) {
    final d = b.score - a.score;
    return d != 0 ? d : a.name.compareTo(b.name);
  });
  return list;
}

/// [preferred] 이름의 음성. 없거나 비어 있으면(자동) 가장 자연스러운 음성.
TtsVoice? pickVoice(List<TtsVoice> voices, String preferred) {
  if (voices.isEmpty) return null;
  if (preferred.isNotEmpty) {
    for (final v in voices) {
      if (v.name == preferred) return v;
    }
  }
  return voices.first;
}
