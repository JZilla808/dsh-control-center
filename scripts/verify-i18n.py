#!/usr/bin/env python3
"""Catalog consistency gate for dsh-control-center.

Mirrors the spirit of DeepSeek Harness's own `verify-translation-pairing` gate:
a translation is only trustworthy if it is *structurally* the same as its
source. The TUI layout depends on that — the fzf banner and preview are sized in
terminal columns, and CJK glyphs are two columns wide, so a catalog that quietly
grows a key, drops one, or changes a `%s` placeholder will break the layout at
runtime rather than at review time.

Checks
  1. every locale defines exactly the same key set as the base locale
  2. no duplicate keys inside one catalog
  3. printf placeholders (%s) match between locales for each key
  4. `card.*` labels share one display width *within* a locale, so the status
     card columns stay aligned in every language

Usage:  scripts/verify-i18n.py [--root DIR]
Exit:   0 clean, 1 violations found
"""

from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from pathlib import Path

BASE = "en"

# [key]='value'   (values are single-quoted in the catalogs; '' escapes a quote)
ENTRY_RE = re.compile(r"\[([A-Za-z0-9_.]+)\]\s*=\s*'((?:[^']|'')*)'")
PLACEHOLDER_RE = re.compile(r"%[sd]")


def display_width(s: str) -> int:
    """Terminal columns: East Asian Wide/Fullwidth count double."""
    return sum(2 if unicodedata.east_asian_width(c) in ("W", "F") else 1 for c in s)


def parse_catalog(path: Path) -> dict[str, str]:
    entries: dict[str, str] = {}
    dupes: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        for key, value in ENTRY_RE.findall(line):
            if key in entries:
                dupes.append(key)
            entries[key] = value.replace("''", "'")
    if dupes:
        raise ValueError(f"{path.name}: duplicate keys: {', '.join(sorted(set(dupes)))}")
    return entries


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    args = ap.parse_args()

    locales_dir = Path(args.root) / "locales"
    files = sorted(locales_dir.glob("*.zsh"))
    if not files:
        print(f"no catalogs found in {locales_dir}", file=sys.stderr)
        return 1

    catalogs: dict[str, dict[str, str]] = {}
    for f in files:
        try:
            catalogs[f.stem] = parse_catalog(f)
        except ValueError as e:
            print(f"FAIL  {e}")
            return 1

    if BASE not in catalogs:
        print(f"FAIL  base locale '{BASE}' missing", file=sys.stderr)
        return 1

    base = catalogs[BASE]
    problems: list[str] = []

    for name, cat in sorted(catalogs.items()):
        if name == BASE:
            continue
        missing = sorted(set(base) - set(cat))
        extra = sorted(set(cat) - set(base))
        for k in missing:
            problems.append(f"{name}: missing key '{k}'")
        for k in extra:
            problems.append(f"{name}: unexpected key '{k}' (not in {BASE})")
        for k in sorted(set(base) & set(cat)):
            a = sorted(PLACEHOLDER_RE.findall(base[k]))
            b = sorted(PLACEHOLDER_RE.findall(cat[k]))
            if a != b:
                problems.append(
                    f"{name}: placeholder mismatch for '{k}': {BASE}={a or '[]'} vs {name}={b or '[]'}"
                )

    # card.* alignment: one shared display width per locale
    for name, cat in sorted(catalogs.items()):
        widths = {k: display_width(v) for k, v in cat.items() if k.startswith("card.")}
        if len(set(widths.values())) > 1:
            detail = ", ".join(f"{k}={w}" for k, w in sorted(widths.items()))
            problems.append(f"{name}: card.* labels differ in display width ({detail})")

    n_keys = len(base)
    if problems:
        print(f"FAIL  {len(problems)} problem(s) across {len(catalogs)} locale(s):\n")
        for p in problems:
            print(f"  - {p}")
        return 1

    langs = ", ".join(sorted(catalogs))
    print(f"OK    {len(catalogs)} locales ({langs}), {n_keys} keys each, placeholders and card widths aligned")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
