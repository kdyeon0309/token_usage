#!/usr/bin/env python3
"""Install TokenBar's Claude status-line bridge while preserving existing output."""

import json
import os
import pathlib
import shutil
import sys
import time


def main() -> int:
    repo_script = pathlib.Path(__file__).with_name("claude_statusline_bridge.py")
    app_dir = pathlib.Path.home() / "Library" / "Application Support" / "TokenBar"
    installed_script = app_dir / "claude_statusline_bridge.py"
    bridge_config = app_dir / "claude_bridge_config.json"
    claude_dir = pathlib.Path(os.environ.get("CLAUDE_CONFIG_DIR", pathlib.Path.home() / ".claude"))
    settings_path = claude_dir / "settings.json"

    app_dir.mkdir(parents=True, exist_ok=True)
    claude_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(repo_script, installed_script)
    installed_script.chmod(0o755)

    try:
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        settings = {}
    except ValueError as error:
        print(f"settings.json 파싱 실패: {error}", file=sys.stderr)
        return 1

    if not isinstance(settings, dict):
        print("settings.json 최상위 값은 객체여야 합니다.", file=sys.stderr)
        return 1

    previous = settings.get("statusLine")
    previous_command = previous.get("command") if isinstance(previous, dict) else None
    bridge_command = f"python3 {json.dumps(str(installed_script))}"
    if previous_command and previous_command != bridge_command:
        bridge_config.write_text(
            json.dumps({"original_command": previous_command}, indent=2) + "\n",
            encoding="utf-8",
        )

    if settings_path.exists():
        backup = settings_path.with_name(f"settings.json.tokenbar-backup-{int(time.time())}")
        shutil.copy2(settings_path, backup)
        print(f"백업: {backup}")

    settings["statusLine"] = {
        "type": "command",
        "command": bridge_command,
        "refreshInterval": 60,
    }
    temp_path = settings_path.with_suffix(".json.tmp")
    temp_path.write_text(json.dumps(settings, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(temp_path, settings_path)
    print(f"설치 완료: {settings_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

