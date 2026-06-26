#!/usr/bin/env python3
"""Validate trophy wall submissions for the RTV lab."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

ALLOWED_FIELDS = {"handle", "message"}
HANDLE_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,31}$")
MAX_MESSAGE_LENGTH = 96


def _has_control_text(value: str) -> bool:
    return any(ord(char) < 32 for char in value)


def validate_submission(path: Path, payload: Any) -> list[str]:
    errors: list[str] = []
    label = str(path)

    if not isinstance(payload, dict):
        return [f"{label}: submission must be a JSON object"]

    unexpected = sorted(set(payload) - ALLOWED_FIELDS)
    for field in unexpected:
        errors.append(f"{label}: unexpected field {field!r}")

    missing = sorted(ALLOWED_FIELDS - set(payload))
    for field in missing:
        errors.append(f"{label}: missing field {field!r}")

    handle = payload.get("handle")
    if not isinstance(handle, str) or not HANDLE_PATTERN.fullmatch(handle):
        errors.append(
            f"{label}: handle must be 1 to 32 letters, numbers, underscores, or hyphens"
        )
    elif path.stem != handle:
        errors.append(f"{label}: filename must match handle {handle!r}")

    message = payload.get("message")
    if not isinstance(message, str):
        errors.append(f"{label}: message must be a string")
    elif not message.strip():
        errors.append(f"{label}: message must not be empty")
    elif len(message) > MAX_MESSAGE_LENGTH:
        errors.append(f"{label}: message must be {MAX_MESSAGE_LENGTH} characters or fewer")
    elif "<" in message or ">" in message or _has_control_text(message):
        errors.append(f"{label}: message contains unsupported characters")

    return errors


def load_json(path: Path) -> tuple[Any | None, str | None]:
    try:
        return json.loads(path.read_text(encoding="utf-8")), None
    except json.JSONDecodeError as exc:
        return None, f"{path}: invalid JSON: {exc.msg}"


def validate_all(root: Path) -> list[str]:
    submission_dir = root / "submissions"
    paths = sorted(submission_dir.glob("*.json")) if submission_dir.exists() else []
    errors: list[str] = []
    seen_handles: dict[str, Path] = {}

    for path in paths:
        payload, error = load_json(path)
        if error:
            errors.append(error)
            continue

        assert payload is not None
        errors.extend(validate_submission(path, payload))

        if isinstance(payload, dict) and isinstance(payload.get("handle"), str):
            key = payload["handle"].casefold()
            if key in seen_handles:
                errors.append(
                    f"{path}: duplicate handle also declared in {seen_handles[key]}"
                )
            else:
                seen_handles[key] = path

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate RTV trophy wall submissions")
    parser.add_argument("root", nargs="?", default=".", help="demo repository root")
    args = parser.parse_args()

    errors = validate_all(Path(args.root))
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print("submission validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
