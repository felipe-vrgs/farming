#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]

# Keep vendored plugin sources out of lint/format.
EXCLUDED_DIR_PREFIXES = (
    "addons/",
)


def is_excluded(path: Path) -> bool:
    rel = path.as_posix()
    return any(rel.startswith(pfx) for pfx in EXCLUDED_DIR_PREFIXES)


def collect_gd_files() -> list[str]:
    files: list[str] = []
    for p in REPO_ROOT.rglob("*.gd"):
        rel = p.relative_to(REPO_ROOT)
        if is_excluded(rel):
            continue
        files.append(str(rel).replace("\\", "/"))
    files.sort()
    return files


def run(cmd: list[str]) -> None:
    p = subprocess.run(cmd, cwd=str(REPO_ROOT), text=True)
    if p.returncode != 0:
        raise SystemExit(p.returncode)


def main() -> None:
    os.chdir(REPO_ROOT)
    files = collect_gd_files()
    if not files:
        print("[lint] No .gd files found (unexpected).")
        return

    # NOTE:
    # We intentionally do NOT enforce gdformat in CI. gdformat is "uncompromising"
    # and only configurable for line length and indentation. This includes stylistic
    # choices like "two blank lines between functions", which this repo does not want
    # to enforce automatically.
    run(["gdlint", *files])
    print("[lint] OK")


if __name__ == "__main__":
    main()

