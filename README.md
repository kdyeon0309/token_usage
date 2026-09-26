# TokenBar

Claude Code와 Codex의 사용량을 macOS 메뉴 막대에서 확인하는 개인용 앱입니다.

## 개발

```bash
xcodegen generate
xcodebuild -project TokenBar.xcodeproj -scheme TokenBar -configuration Debug build
```

macOS 13 이상이 필요합니다.

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
