#!/usr/bin/env python3
"""Persist Claude Code usage data for TokenBar and preserve the existing status line."""

import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time


APP_DIR = pathlib.Path.home() / "Library" / "Application Support" / "TokenBar"
SNAPSHOT_PATH = APP_DIR / "claude.json"
CONFIG_PATH = APP_DIR / "claude_bridge_config.json"


def read_previous_snapshot() -> dict:
    try:
        value = json.loads(SNAPSHOT_PATH.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return value if isinstance(value, dict) else {}


def merge_rate_limits(data: dict, previous: dict, now: float) -> dict | None:
    """Keep a known window while a new Claude session is waiting for its first reply."""
    incoming = data.get("rate_limits")
    incoming = incoming if isinstance(incoming, dict) else {}
    old = previous.get("rate_limits")
    old = old if isinstance(old, dict) else {}

    merged = {}
    for name in ("five_hour", "seven_day", "spend_limit"):
        current_window = incoming.get(name)
        if isinstance(current_window, dict):
            merged[name] = current_window
            continue

        old_window = old.get(name)
        reset_at = old_window.get("resets_at") if isinstance(old_window, dict) else None
        if isinstance(reset_at, (int, float)) and reset_at > now:
            merged[name] = old_window

    return merged or None


def write_snapshot(data: dict) -> None:
    captured_at = time.time()
    previous = read_previous_snapshot()
    snapshot = {
        "version": 1,
        "captured_at": captured_at,
        "model": data.get("model"),
        "cost": data.get("cost"),
        "context_window": data.get("context_window"),
        "rate_limits": merge_rate_limits(data, previous, captured_at),
    }
    APP_DIR.mkdir(parents=True, exist_ok=True)
    fd, temp_path = tempfile.mkstemp(prefix="claude-", suffix=".json", dir=APP_DIR)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(snapshot, handle, separators=(",", ":"))
        os.replace(temp_path, SNAPSHOT_PATH)
    finally:
        if os.path.exists(temp_path):
            os.unlink(temp_path)


def original_command() -> str | None:
    try:
        config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    command = config.get("original_command")
    return command if isinstance(command, str) and command.strip() else None


def fallback_line(data: dict) -> str:
    model = data.get("model") or {}
    parts = [model.get("display_name") or model.get("id") or "Claude"]
    context = data.get("context_window") or {}
    used = context.get("used_percentage")
    parts.append(f"ctx {used:.0f}% used" if isinstance(used, (int, float)) else "ctx --")
    limits = data.get("rate_limits") or {}
    for key, label in (("five_hour", "5h"), ("seven_day", "weekly")):
        used = (limits.get(key) or {}).get("used_percentage")
        if isinstance(used, (int, float)):
            parts.append(f"{label} {max(0, min(100, 100 - used)):.0f}% left")
        else:
            parts.append(f"{label} --")
    return " | ".join(parts)


def main() -> int:
    raw = sys.stdin.buffer.read()
    try:
        data = json.loads(raw)
        write_snapshot(data)
    except (OSError, ValueError, TypeError):
        print("Claude | usage unavailable")
        return 0

    command = original_command()
    if command:
        result = subprocess.run(
            command,
            input=raw,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            shell=True,
            executable="/bin/zsh",
            check=False,
        )
        output = result.stdout.decode("utf-8", errors="replace").rstrip()
        if output:
            print(output)
            return 0

    print(fallback_line(data))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

