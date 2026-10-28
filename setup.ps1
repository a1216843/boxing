# Android/iOS 플랫폼 폴더를 생성하고 TTS 설정을 붙인다. 프로젝트 폴더에서 한 번만 실행.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# 기존 lib/, pubspec.yaml 등은 덮어쓰지 않는다.
flutter create --project-name boxing_coach --org com.example --platforms android,ios .

# flutter create 기본 템플릿 테스트는 이 앱에 맞지 않으므로 삭제.
Remove-Item test/widget_test.dart -ErrorAction SilentlyContinue

# Android 11+ 에서 TTS 엔진을 찾으려면 queries 선언이 필요하다.
$manifest = 'android/app/src/main/AndroidManifest.xml'
$xml = Get-Content $manifest -Raw
if ($xml -notmatch 'TTS_SERVICE') {
    $intent = "`n        <intent>`n            <action android:name=`"android.intent.action.TTS_SERVICE`" />`n        </intent>"
    if ($xml -match '<queries>') {
        $xml = $xml -replace '<queries>', "<queries>$intent"
    } else {
        $xml = $xml -replace '</manifest>', "    <queries>$intent`n    </queries>`n</manifest>"
    }
    Set-Content $manifest $xml -Encoding utf8 -NoNewline
}

flutter pub get
