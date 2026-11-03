# 미트 콜 (boxing_coach)

미트 트레이닝처럼 콤보 사인을 랜덤으로 만들어 TTS로 불러주는 Flutter 앱 (Android / iOS / 웹).

웹 버전: https://a1216843.github.io/boxing/ (아이폰은 사파리로 열고 "홈 화면에 추가")

## 기능

홈에서 세 가지를 고릅니다.

- **미트 콜**: 난이도·스탠스·콜 방식을 고르고 라운드를 시작하면 콤보를 TTS로 불러 주고 인형이 따라 칩니다.
- **콤보 카드 맵**: 자세(체중)마다 다음에 이어질 수 있는 동작을 카드로 보는 웹 페이지 (`web/combo_map/`).
- **콤비네이션 보기**: 난이도별 콤보 목록(`lib/models/combo_library.dart`)에서 하나를 고르면 상대 인형과 함께 시연합니다.
  내가 치면 상대가 맞고(머리가 젖혀지거나 몸이 접힘), 내가 피하면 상대가 그 회피에 맞는 펀치를 칩니다
  (리어 쪽 슬립·스웨이·백스텝 ← 잽, 리드 쪽 슬립 ← 스트레이트, 더킹·위빙 ← 뒷손 훅). `lib/pose/sparring.dart`

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
| `lib/models/settings.dart` | 난이도별 프로필(콤보 길이, 템포, 박자, 반 박자 확률, 세트 사이 휴지 범위), 설정 저장 |
| `lib/engine/combo_generator.dart` | 규칙을 따라 콤보 생성, 익숙한 콤보 반복 풀 |
| `lib/engine/pacer.dart` | 콜 타이밍: 같은 콤보를 연달아(기본 2회) 부르고, 세트 사이엔 랜덤한 휴지 |
| `lib/engine/session_controller.dart` | 라운드/휴식 타이머와 콜 루프 |
| `lib/engine/speaker.dart` | TTS 큐 |
| `lib/models/combo_library.dart` | 콤비네이션 보기 목록 (난이도별) |
| `lib/pose/sparring.dart` | 상대 인형: 내 동작에 맞춘 맞기·공격, 마주 선 거리 |
| `lib/screens/home_screen.dart` | 홈 (세 기능) |
| `lib/screens/meet_call_screen.dart` | 미트 콜 설정·시작 |
| `lib/screens/combination_screen.dart` | 콤비네이션 목록과 시연 |

## 콤보 규칙

모든 동작은 리드/리어 손 기준으로 정의하고, 각 동작 후 체중이 어디(앞/가운데/뒤)에 실리는지 추적합니다.

- 체중이 **앞발**에 실리면(투, 리어 훅/어퍼, 리드 쪽 슬립·위빙) → 리드 손(훅, 어퍼)이 자연스럽고 리어 훅/어퍼는 금지
- 체중이 **뒷발**에 실리면(리드 훅/어퍼, 리어 쪽 슬립·위빙, 스웨이) → 리어 손(투, 어퍼)이 자연스러움
- 더킹/위빙/바디샷 후 낮은 자세 → 어퍼·바디 가중치 상승
- `compat × pairBonus`가 0.12 미만이면 금지. 바디→헤드 더블 훅처럼 체중상 어색해도 정석인 연결은 `pairBonus`로 허용

규칙을 바꾸려면 `moves.dart`의 숫자만 고치면 됩니다.

## 난이도

| | 동작 | 콤보 성격 |
|---|---|---|
| 초급 | 기본 펀치 + 슬립·스웨이·백스텝 (더킹·위빙·리어 훅·바디 잽 제외) | 정석 연결 가중치를 키워 원투·원투쓰리 같은 기본 콤보 위주. 레벨 체인지(바디샷)는 콤보당 최대 1개, 드물게 |
| 중급 | 기본 동작 전부 | 레벨 체인지(바디샷·더킹·위빙)를 콤보당 3개까지, 높이가 바뀌는 연결에 가중치. 같은 종류 펀치는 덜 겹치게 해 조합을 고르게. 방어 2개까지 |
| 상급 | 중급 + 점프 훅, 체크 훅, 오버핸드 | 중급보다 길게(최대 6동작) 이어 치고, 피하고 받아치는 연결을 더 섞음. 상급 기술은 콤보당 2개까지(같은 기술은 한 번) |

난이도별 숫자는 `settings.dart`의 `LevelProfile`(`lowRate`, `maxLow`, `levelSwitch`, `pairEmphasis`, `variety`, `specialRate`, `maxSpecials`)에 있습니다.

점프 훅은 리드 쪽 앞 대각선(오소독스끼리면 상대 뒷손 쪽)으로 뛰어 들어가 각을 잡고, 체크 훅은 앞발을 축으로 돌아 옆으로 빠집니다.
인형은 그렇게 옮겨 간 자리와 돈 방향을 다음 동작에 그대로 이어 갑니다. 백스텝은 두 발이 함께 뒤로 한 번에 뜁니다.
