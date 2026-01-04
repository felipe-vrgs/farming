#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import subprocess
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

def git_diff_has_changes() -> bool:
    p = subprocess.run(
        ["git", "diff", "--name-only", "--"],
        cwd=str(REPO_ROOT),
        text=True,
        capture_output=True,
    )
    if p.returncode != 0:
        # If git isn't available, fall back to "no changes" rather than blocking.
        return False
    return bool(p.stdout.strip())


def main() -> None:
    ap = argparse.ArgumentParser(description="Run gdformat on repo .gd files.")
    ap.add_argument(
        "--check",
        action="store_true",
        help="Fail if gdformat would change files (runs gdformat, then checks git diff).",
    )
    args = ap.parse_args()

    os.chdir(REPO_ROOT)
    files = collect_gd_files()
    if not files:
        print("[format] No .gd files found.")
        return

    print(f"[format] Running gdformat on {len(files)} files...")
    run(["gdformat", *files])
    if args.check and git_diff_has_changes():
        print("[format] ERROR: Files are not formatted. Run: python tools/lint/format.py", flush=True)
        raise SystemExit(1)

    print("[format] OK")

if __name__ == "__main__":
    main()
