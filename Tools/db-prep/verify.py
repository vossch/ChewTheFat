#!/usr/bin/env python3
"""Smoke-check ChewTheFat/Resources/{usda,offs}.sqlite.

Used as a pre-commit gate: ensures the bundled RAG databases have the expected
schema (food_entry, serving, food_fts FTS5) and non-zero row counts. Exits
non-zero if anything is wrong. Intentionally forgiving about exact row counts
— those change with USDA/OFFs releases.
"""

from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

EXPECTED = ("usda.sqlite", "offs.sqlite")
RESOURCES = Path(__file__).resolve().parents[2] / "ChewTheFat" / "Resources"


def check(db_path: Path) -> list[str]:
    errors: list[str] = []
    if not db_path.exists():
        return [f"{db_path.name}: file missing"]
    try:
        with sqlite3.connect(f"file:{db_path}?mode=ro", uri=True) as conn:
            cur = conn.cursor()
            cur.execute(
                "SELECT name FROM sqlite_master WHERE type IN ('table','virtual')"
            )
            names = {row[0] for row in cur.fetchall()}
            for required in ("food_entry", "serving", "food_fts"):
                if required not in names:
                    errors.append(f"{db_path.name}: missing table '{required}'")
            if "food_fts" in names:
                cur.execute(
                    "SELECT sql FROM sqlite_master WHERE name='food_fts'"
                )
                row = cur.fetchone()
                if row and "fts5" not in (row[0] or "").lower():
                    errors.append(f"{db_path.name}: food_fts is not FTS5")
            if not errors:
                cur.execute("SELECT COUNT(*) FROM food_entry")
                count = cur.fetchone()[0]
                if count < 100:
                    errors.append(
                        f"{db_path.name}: food_entry has only {count} rows"
                    )
    except sqlite3.Error as exc:
        errors.append(f"{db_path.name}: sqlite error: {exc}")
    return errors


def main() -> int:
    all_errors: list[str] = []
    for name in EXPECTED:
        all_errors.extend(check(RESOURCES / name))
    if all_errors:
        for e in all_errors:
            print(f"✗ {e}", file=sys.stderr)
        return 1
    print("✓ reference databases look healthy")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
