#!/usr/bin/env python3
"""
DroneAid — Claude Code session-log redactor.

Reads JSONL text on stdin, writes redacted JSONL to stdout.

Strips:
  - Google API keys                      AIza[0-9A-Za-z_-]{35}
  - OpenAI / Anthropic-shaped keys       sk-[A-Za-z0-9_-]{20,}
  - OAuth access tokens                  ya29\\.[A-Za-z0-9_-]+
  - Firebase service-account blobs       any JSON object containing "private_key"
  - Bearer tokens                        Bearer [A-Za-z0-9._-]{20,}
  - 13-digit Thai national IDs           (bare 13-digit numbers)
  - Email addresses                      <local>@<domain>

Each redacted match is replaced with "[REDACTED:<kind>]" so the structure of
the JSON line is preserved.

Usage:
    python redact-secrets.py < input.jsonl > output.jsonl
    cat input.jsonl | python redact-secrets.py
"""

from __future__ import annotations

import json
import re
import sys
from typing import Any


# (kind, pattern)
SECRET_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("google-api-key", re.compile(r"AIza[0-9A-Za-z_\-]{35}")),
    ("sk-key",         re.compile(r"sk-[A-Za-z0-9_\-]{20,}")),
    ("ya29-token",     re.compile(r"ya29\.[A-Za-z0-9_\-]+")),
    ("bearer",         re.compile(r"Bearer\s+[A-Za-z0-9._\-]{20,}")),
    ("thai-id",        re.compile(r"(?<!\d)\d{13}(?!\d)")),
    ("email",          re.compile(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}")),
]


def redact_str(s: str) -> str:
    """Apply every regex pattern to a string and replace matches."""
    out = s
    for kind, pat in SECRET_PATTERNS:
        out = pat.sub(f"[REDACTED:{kind}]", out)
    return out


def redact_value(v: Any) -> Any:
    """Recursively redact strings inside dicts and lists; pass other types through."""
    if isinstance(v, str):
        return redact_str(v)
    if isinstance(v, list):
        return [redact_value(item) for item in v]
    if isinstance(v, dict):
        # Detect service-account JSON: presence of "private_key" → redact whole object
        if "private_key" in v or "client_email" in v and "private_key_id" in v:
            return {"__redacted__": "service-account-blob"}
        return {k: redact_value(val) for k, val in v.items()}
    return v


def process_line(raw: str) -> str:
    raw = raw.rstrip("\n")
    if not raw:
        return ""
    try:
        obj = json.loads(raw)
    except json.JSONDecodeError:
        # Not JSON — just regex-redact as text (best effort).
        return redact_str(raw)
    return json.dumps(redact_value(obj), ensure_ascii=False)


def main() -> int:
    for line in sys.stdin:
        out = process_line(line)
        if out:
            sys.stdout.write(out + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
