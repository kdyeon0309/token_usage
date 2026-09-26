# TokenBar

Claude Code와 Codex의 사용량을 macOS 메뉴 막대에서 확인하는 개인용 앱입니다.

## 개발

```bash
xcodegen generate
xcodebuild -project TokenBar.xcodeproj -scheme TokenBar -configuration Debug build
```

macOS 13 이상이 필요합니다.

Release 앱을 사용자 Applications 폴더에 설치하려면 다음 명령을 실행합니다. 기존
TokenBar 앱은 타임스탬프가 붙은 이름으로 백업됩니다.

```bash
zsh scripts/install_app.sh
open ~/Applications/TokenBar.app
```

## Claude Code 연결

Claude Code가 공식 Status Line 입력으로 전달하는 5시간/주간 한도를 로컬 파일에
저장합니다. 기존 Status Line 명령은 그대로 실행되며 설정 파일도 자동으로 백업됩니다.

```bash
python3 scripts/install_claude_bridge.py
```

또는 TokenBar 팝오버 아래의 **Claude 연결** 버튼을 누를 수 있습니다. 설치 후 Claude
Code를 시작하거나 메시지를 한 번 보내면 TokenBar에 표시됩니다.

## Codex 연결

별도 설정 없이 `~/.codex/sessions`의 로컬 사용량 이벤트를 읽습니다. 인증 정보와
대화 내용은 읽지 않으며, 토큰 집계와 한도 필드만 디코딩합니다. Codex를 사용한 뒤
최대 60초 안에 메뉴 막대 값이 갱신됩니다.

팝오버에서 로그인 시 자동 실행을 켜거나 끌 수 있습니다.

## 표시와 알림 설정

팝오버 아래에서 메뉴 막대 표시를 다음 중 하나로 선택할 수 있습니다.

- Claude와 Codex를 모두 표시
- 남은 한도가 가장 적은 서비스만 표시
- 아이콘만 표시

**잔여량 알림**을 켜면 macOS 알림 권한을 요청합니다. 각 서비스의 5시간 또는
주간 한도가 20%, 10%, 5%에 도달할 때 한 번씩 알립니다. 알림 기록은 한도 리셋
주기별로 저장되므로 앱을 다시 실행해도 같은 단계의 알림을 반복하지 않습니다.

각 서비스 카드에는 연결 상태, 데이터 출처, 마지막 수집 시각이 표시됩니다. 마지막
데이터가 10분 이상 지난 경우에는 데이터 지연 상태로 표시됩니다.

## 사용 속도 안내

TokenBar는 각 서비스의 5시간 한도 리셋 시각을 기준으로 시간당 안전 사용률을
계산합니다. 최근 사용률 기록이 5분 이상 쌓이면 다음 정보도 표시합니다.

- 최근 1시간 기준 사용 속도
- 현재 속도를 유지했을 때의 예상 소진 시각
- 리셋까지 한도가 유지되는지 여부
- Claude와 Codex 중 잔여량이 더 여유로운 서비스 추천

사용률 기록은 `~/Library/Application Support/TokenBar/usage-history.json`에만 저장되며
7일이 지난 기록은 자동으로 삭제됩니다. 대화 내용이나 인증 정보는 저장하지 않습니다.
