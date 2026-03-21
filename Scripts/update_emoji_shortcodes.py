#!/usr/bin/env python3
"""
Regenerates SwiftDiscourseHub/Services/EmojiShortcodes.swift
from https://github.com/discourse/discourse-emojis dist/ data.

Usage:
    python3 Scripts/update_emoji_shortcodes.py

Requires: gh CLI authenticated (uses GitHub API to fetch files).
"""

import json
import subprocess
import sys
from pathlib import Path

REPO = "discourse/discourse-emojis"
OUTPUT = Path(__file__).resolve().parent.parent / "SwiftDiscourseHub" / "Services" / "EmojiShortcodes.swift"


def fetch_json(path: str) -> any:
    """Fetch a JSON file from the discourse-emojis repo via gh CLI."""
    result = subprocess.run(
        ["gh", "api", f"repos/{REPO}/contents/{path}", "--jq", ".content"],
        capture_output=True, text=True, check=True,
    )
    import base64
    return json.loads(base64.b64decode(result.stdout.strip()))


def main():
    print(f"Fetching emoji data from {REPO}...")
    emojis = fetch_json("dist/emojis.json")
    aliases = fetch_json("dist/aliases.json")

    # Build name -> unicode mapping
    mapping: dict[str, str] = {}
    for e in emojis:
        name = e["name"]
        code = e["code"]
        chars = "".join(chr(int(cp, 16)) for cp in code.split("-"))
        mapping[name] = chars

    # Add aliases (alias -> same unicode as canonical name)
    alias_count = 0
    for canonical, alias_list in aliases.items():
        if canonical in mapping:
            for alias in alias_list:
                mapping[alias] = mapping[canonical]
                alias_count += 1

    print(f"  {len(emojis)} emojis + {alias_count} aliases = {len(mapping)} total entries")

    # Generate Swift file
    lines = []
    for name in sorted(mapping.keys()):
        char = mapping[name]
        lines.append(f'    "{name}": "{char}"')

    swift = (
        "// Generated from https://github.com/discourse/discourse-emojis\n"
        "// Run Scripts/update_emoji_shortcodes.py to regenerate.\n"
        "\n"
        "enum EmojiShortcodes {\n"
        "    static let map: [String: String] = [\n"
        + ",\n".join(lines)
        + ",\n"
        "    ]\n"
        "}\n"
    )

    OUTPUT.write_text(swift, encoding="utf-8")
    print(f"  Wrote {OUTPUT}")


if __name__ == "__main__":
    main()
