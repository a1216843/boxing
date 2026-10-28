# 미트 콜 (boxing_coach)

미트 트레이닝처럼 콤보 사인을 랜덤으로 만들어 TTS로 불러주는 Flutter 앱 (Android / iOS / 웹).

웹 버전: https://a1216843.github.io/boxing/ (아이폰은 사파리로 열고 "홈 화면에 추가")

## 실행

```powershell
./setup.ps1          # 처음 한 번: android/ios 폴더 생성 + TTS 설정 + pub get
flutter test         # 콤보 규칙 테스트
flutter run          # 연결된 기기에서 실행
```

iOS 빌드는 macOS + Xcode가 필요합니다.

## 웹 (아이폰은 사파리로)

`main`에 올리면 GitHub Actions(`.github/workflows/pages.yml`)가 테스트 후 웹으로 빌드해
`https://<계정>.github.io/<저장소>/`에 배포합니다. 저장소 Settings → Pages → Source를 **GitHub Actions**로 한 번 설정해야 합니다.

아이폰에서는 사파리로 열고 공유 → "홈 화면에 추가"하면 앱처럼 쓸 수 있습니다.
웹에서는 화면이 잠기거나 다른 앱으로 넘어가면 콜이 멈추고, 음악 소리를 줄여주는 기능은 없습니다.

```powershell
flutter build web --release --no-web-resources-cdn   # 로컬 빌드: build/web
```

## 구조

| 파일 | 역할 |
|---|---|
| `lib/models/moves.dart` | 동작 정의, 체중 전이 규칙(`compat`/`result`), 정석 연결 가중치(`pairBonus`) |
| `lib/models/settings.dart` | 난이도별 프로필(콤보 길이, 템포, 박자, 반 박자·끊어 부르기·몰아치기·뜸들이기 확률), 설정 저장 |
| `lib/engine/combo_generator.dart` | 규칙을 따라 콤보 생성, 익숙한 콤보 반복 풀 |
| `lib/engine/pacer.dart` | 콜 타이밍: 박자 위에 콜을 얹고, 반 박자 당기기·끌기, 콤보 끊어 부르기, 몰아치기·뜸들이기 |
| `lib/engine/session_controller.dart` | 라운드/휴식 타이머와 콜 루프 |
| `lib/engine/speaker.dart` | TTS 큐 |

## 콤보 규칙

모든 동작은 리드/리어 손 기준으로 정의하고, 각 동작 후 체중이 어디(앞/가운데/뒤)에 실리는지 추적합니다.

- 체중이 **앞발**에 실리면(투, 리어 훅/어퍼, 리드 쪽 슬립·위빙) → 리드 손(훅, 어퍼)이 자연스럽고 리어 훅/어퍼는 금지
- 체중이 **뒷발**에 실리면(리드 훅/어퍼, 리어 쪽 슬립·위빙, 풀백) → 리어 손(투, 어퍼)이 자연스러움
- 더킹/위빙/바디샷 후 낮은 자세 → 어퍼·바디 가중치 상승
- `compat × pairBonus`가 0.12 미만이면 금지. 바디→헤드 더블 훅처럼 체중상 어색해도 정석인 연결은 `pairBonus`로 허용

규칙을 바꾸려면 `moves.dart`의 숫자만 고치면 됩니다.
