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

설치 후 Claude Code를 시작하거나 메시지를 한 번 보내면 TokenBar에 표시됩니다.
