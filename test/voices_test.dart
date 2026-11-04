import 'package:boxing_coach/engine/voices.dart';
import 'package:boxing_coach/models/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('웹: 엣지 Natural > 크롬 Google > 윈도우 기본 음성, 다른 언어는 뺀다', () {
    final v = koreanVoices([
      {'name': 'Microsoft Heami - Korean (Korean)', 'locale': 'ko-KR'},
      {'name': 'Google 한국의', 'locale': 'ko-KR'},
      {'name': 'Microsoft SunHi Online (Natural) - Korean (Korea)', 'locale': 'ko-KR'},
      {'name': 'Google US English', 'locale': 'en-US'},
    ]);
    expect(v.map((e) => e.name), [
      'Microsoft SunHi Online (Natural) - Korean (Korea)',
      'Google 한국의',
      'Microsoft Heami - Korean (Korean)',
    ]);
    expect(v.first.label, 'Microsoft SunHi Online (Natural)');
  });

  test('iOS: 고품질 > 향상됨 > 기본, identifier로 고른다', () {
    final v = koreanVoices([
      {'name': 'Yuna', 'locale': 'ko-KR', 'quality': 'default', 'identifier': 'com.apple.voice.compact.ko-KR.Yuna'},
      {'name': 'Yuna (향상됨)', 'locale': 'ko-KR', 'quality': 'enhanced', 'identifier': 'com.apple.voice.enhanced.ko-KR.Yuna'},
      {'name': 'Yuna (고품질)', 'locale': 'ko-KR', 'quality': 'premium', 'identifier': 'com.apple.voice.premium.ko-KR.Yuna'},
    ]);
    expect(v.map((e) => e.quality), ['premium', 'enhanced', 'default']);
    expect(v.first.toMap()['identifier'], 'com.apple.voice.premium.ko-KR.Yuna');
  });

  test('안드로이드: 품질이 같으면 인터넷이 필요 없는 음성 먼저, 이름은 읽기 쉽게', () {
    final v = koreanVoices([
      {'name': 'ko-kr-x-ism-network', 'locale': 'ko-KR', 'quality': 'high', 'network_required': '1'},
      {'name': 'ko-kr-x-ism-local', 'locale': 'ko-KR', 'quality': 'high', 'network_required': '0'},
      {'name': 'ko-KR-language', 'locale': 'ko-KR', 'quality': 'normal', 'network_required': '0'},
    ]);
    expect(v.first.name, 'ko-kr-x-ism-local');
    expect(v.first.label, '음성 ISM (기기)');
    expect(v[1].label, '음성 ISM (온라인)');
  });

  test('고른 음성이 없으면 자동(가장 자연스러운 음성)', () {
    final v = koreanVoices([
      {'name': 'A', 'locale': 'ko-KR'},
      {'name': 'Google 한국의', 'locale': 'ko-KR'},
    ]);
    expect(pickVoice(v, '')!.name, 'Google 한국의');
    expect(pickVoice(v, 'A')!.name, 'A');
    expect(pickVoice(v, '없는 음성')!.name, 'Google 한국의');
    expect(pickVoice(const [], ''), isNull);
  });

  test('목소리 설정이 저장·복원된다', () {
    const s = TrainingSettings(voice: 'Google 한국의');
    expect(TrainingSettings.fromJson(s.toJson()).voice, 'Google 한국의');
    expect(TrainingSettings.fromJson(const {}).voice, '');
  });
}
