#!/usr/bin/env python3
"""Structural pairing gate for the bilingual README pair.

DeepSeek Harness keeps every in-scope document as an English/Chinese pair bound
by a `*.i18n.yaml` consistency record, and requires the two sides to mirror each
other structurally (heading depths and order, list kinds, table dimensions,
verbatim code blocks). This project follows the same convention, so a translated
README cannot silently drift out of shape.

Usage:  scripts/verify-readme-pair.py [--root DIR] [--write]
        --write  re-record README.i18n.yaml from the current file contents
Exit:   0 clean, 1 violations found
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

EN = "README.md"
ZH = "README.zh.md"
RECORD = "README.i18n.yaml"

HEADING_RE = re.compile(r"^(#{1,6})\s+(.*)$")
FENCE_RE = re.compile(r"^(`{3,}|~{3,})(.*)$")
TABLE_RE = re.compile(r"^\|.*\|$")
LIST_RE = re.compile(r"^(\s*)([-*+]|\d+[.)])\s+")


def signature(text: str) -> dict[str, list]:
    """Reduce a document to the structure that must match across the pair."""
    headings: list[tuple[int, str]] = []
    fences: list[tuple[str, str]] = []
    tables: list[tuple[int, int]] = []
    lists: list[str] = []

    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]

        m = HEADING_RE.match(line)
        if m:
            headings.append((len(m.group(1)), m.group(2).strip()))
            i += 1
            continue

        m = FENCE_RE.match(line)
        if m:
            info = m.group(2).strip()
            body: list[str] = []
            i += 1
            while i < len(lines) and not FENCE_RE.match(lines[i]):
                body.append(lines[i])
                i += 1
            i += 1  # closing fence
            fences.append((info, "\n".join(body)))
            continue

        if TABLE_RE.match(line):
            rows = 0
            cols = 0
            while i < len(lines) and TABLE_RE.match(lines[i]):
                cells = [c for c in lines[i].strip().strip("|").split("|")]
                cols = max(cols, len(cells))
                rows += 1
                i += 1
            tables.append((rows, cols))
            continue

        m = LIST_RE.match(line)
        if m:
            ordered = m.group(2)[0].isdigit()
            depth = len(m.group(1)) // 2
            lists.append(f"{'ol' if ordered else 'ul'}@{depth}")
            i += 1
            continue

        i += 1

    return {"headings": headings, "fences": fences, "tables": tables, "lists": lists}


def git_blob_hash(path: Path) -> str:
    return subprocess.run(
        ["git", "hash-object", str(path)],
        capture_output=True, text=True, check=True,
    ).stdout.strip()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    root = Path(args.root)
    en_p, zh_p = root / EN, root / ZH
    if not en_p.exists() or not zh_p.exists():
        print(f"FAIL  both {EN} and {ZH} are required", file=sys.stderr)
        return 1

    if args.write:
        (root / RECORD).write_text(
            "# Bilingual-pair consistency record: the git blob hash of each side as of\n"
            "# the last confirmed-consistent state. After editing either side, bring the\n"
            "# other along and re-record with:  scripts/verify-readme-pair.py --write\n"
            f"{EN}: {git_blob_hash(en_p)}\n"
            f"{ZH}: {git_blob_hash(zh_p)}\n",
            encoding="utf-8",
        )
        print(f"OK    recorded {RECORD}")

    en_text, zh_text = en_p.read_text(encoding="utf-8"), zh_p.read_text(encoding="utf-8")
    a, b = signature(en_text), signature(zh_text)
    problems: list[str] = []

    # language switcher immediately after the H1
    def switcher_ok(text: str, needle: str) -> bool:
        lines = text.splitlines()
        for idx, line in enumerate(lines):
            if HEADING_RE.match(line):
                nxt = lines[idx + 1] if idx + 1 < len(lines) else ""
                nxt2 = lines[idx + 2] if idx + 2 < len(lines) else ""
                return needle in nxt or needle in nxt2
        return False

    if not switcher_ok(en_text, "README.zh.md"):
        problems.append(f"{EN}: missing the 'English | [中文](README.zh.md)' switcher after the H1")
    if not switcher_ok(zh_text, "README.md"):
        problems.append(f"{ZH}: missing the '[English](README.md) | 中文' switcher after the H1")

    # Heading *depths* and order must match; the text is supposed to differ,
    # that is the whole point of a translation.
    if [d for d, _ in a["headings"]] != [d for d, _ in b["headings"]]:
        problems.append(
            f"heading depths/order differ: en={[d for d, _ in a['headings']]} "
            f"zh={[d for d, _ in b['headings']]}"
        )
    if a["fences"] != b["fences"]:
        problems.append("code blocks differ (info string or body) between the pair")
    if a["tables"] != b["tables"]:
        problems.append(f"table dimensions differ: en={a['tables']} zh={b['tables']}")
    if a["lists"] != b["lists"]:
        problems.append(f"list kinds/counts differ: en={a['lists']} zh={b['lists']}")

    # recorded hashes must match the working tree (an edited side goes red)
    rec = root / RECORD
    if rec.exists():
        recorded = {}
        for line in rec.read_text(encoding="utf-8").splitlines():
            if line.startswith("#") or ":" not in line:
                continue
            k, v = line.split(":", 1)
            recorded[k.strip()] = v.strip()
        for name, path in ((EN, en_p), (ZH, zh_p)):
            if recorded.get(name) != git_blob_hash(path):
                problems.append(f"{name} changed since the pair was last confirmed (re-run with --write)")
    else:
        problems.append(f"{RECORD} is missing (run with --write)")

    if problems:
        print(f"FAIL  README pair:\n")
        for p in problems:
            print(f"  - {p}")
        return 1

    print(f"OK    README pair mirrors structurally ({len(a['headings'])} headings, "
          f"{len(a['fences'])} code blocks, {len(a['tables'])} tables)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
