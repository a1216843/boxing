import 'package:web/web.dart' as web;

/// iOS Safari는 사용자가 탭한 그 순간에 한 번 말해야 이후 음성이 나온다.
/// 버튼 핸들러 안에서 동기로 빈 문장을 읽어 음성 출력을 연다.
void unlockSpeech() {
  final u = web.SpeechSynthesisUtterance(' ')..volume = 0;
  web.window.speechSynthesis.speak(u);
}
