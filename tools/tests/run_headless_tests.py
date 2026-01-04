#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
TEST_SCENE = "res://tests/headless/test_runner.tscn"


def find_godot(explicit: str | None) -> str | None:
    """
    Locate a Godot executable for headless tests.

    Priority:
    - --godot argument
    - GODOT_BIN env var (full path)
    - GODOT env var (full path)
    - 'godot4' on PATH
    - 'godot' on PATH
    """
    def _normalize_exe(p: str) -> str:
        # Allow users to pass/define paths with quotes (common on Windows when paths contain spaces).
        # subprocess/CreateProcess requires the raw path without wrapping quotes.
        p = p.strip()
        if (p.startswith('"') and p.endswith('"')) or (p.startswith("'") and p.endswith("'")):
            p = p[1:-1].strip()
        return p

    if explicit:
        return _normalize_exe(explicit)
    for key in ("GODOT_BIN", "GODOT"):
        v = os.environ.get(key)
        if v:
            return _normalize_exe(v)
    for cand in ("godot4", "godot"):
        p = shutil.which(cand)
        if p:
            return p
    return None


_SHUTDOWN_NOISE_PATTERNS: tuple[re.Pattern[str], ...] = (
    # Godot sometimes emits these at shutdown in headless runs even when tests pass.
    # They are noisy and can drown out actual test output.
    re.compile(r'^WARNING: \d+ RID of type "CanvasItem" was leaked\.$'),
    re.compile(r"^\s+at: _free_rids \(.*\)$"),
    re.compile(r"^WARNING: ObjectDB instances leaked at exit \(run with --verbose for details\)\.$"),
    re.compile(r"^\s+at: cleanup \(.*\)$"),
    re.compile(r"^ERROR: \d+ resources still in use at exit \(run with --verbose for details\)\.$"),
    re.compile(r"^\s+at: clear \(.*\)$"),
)


def strip_known_shutdown_noise(text: str) -> str:
    """
    Remove known, end-of-process shutdown noise from Godot headless output.

    We intentionally only strip *trailing* lines that match known patterns so we
    don't hide real warnings/errors that occur during the run.
    """
    if not text:
        return text
    lines = text.splitlines()
    i = len(lines) - 1
    while i >= 0:
        line = lines[i].rstrip("\r")
        if line.strip() == "":
            i -= 1
            continue
        if any(p.match(line) for p in _SHUTDOWN_NOISE_PATTERNS):
            i -= 1
            continue
        break
    stripped = "\n".join(lines[: i + 1]).strip("\n")
    return stripped + ("\n" if stripped else "")


def main() -> int:
    ap = argparse.ArgumentParser(description="Run Godot headless tests for this repo.")
    ap.add_argument(
        "--godot",
        help="Path to Godot executable (e.g. C:\\\\path\\\\Godot_v4.5-stable_win64.exe)",
        default=None,
    )
    args = ap.parse_args()

    os.chdir(REPO_ROOT)
    godot = find_godot(args.godot)
    if not godot:
        print(
            "[headless_tests] ERROR: Could not find Godot executable.\n"
            "Provide it with ONE of the following:\n"
            "  - Pass --godot \"C:\\path\\to\\Godot.exe\"\n"
            "  - Set env var GODOT_BIN to your Godot 4.x binary path\n",
            file=sys.stderr,
        )
        return 2

    cmd = [
        godot,
        "--path",
        str(REPO_ROOT),
        "--headless",
        "--scene",
        TEST_SCENE,
    ]
    print("[headless_tests] Running:", " ".join(cmd))
    env = os.environ.copy()
    env["FARMING_TEST_MODE"] = "1"
    env.setdefault("FARMING_TEST_TIMEOUT_S", "60")
    try:
        p = subprocess.run(
            cmd,
            cwd=str(REPO_ROOT),
            text=True,
            capture_output=True,
            env=env,
            timeout=float(env["FARMING_TEST_TIMEOUT_S"]) + 30.0,
        )
    except subprocess.TimeoutExpired as e:
        print("[headless_tests] ERROR: Timed out waiting for Godot to exit.", file=sys.stderr)
        if e.stdout:
            print(e.stdout, file=sys.stderr)
        if e.stderr:
            print(e.stderr, file=sys.stderr)
        return 124
    out = strip_known_shutdown_noise(p.stdout or "")
    err = strip_known_shutdown_noise(p.stderr or "")
    if out:
        print(out, end="" if out.endswith("\n") else "\n")
    if err:
        print(err, end="" if err.endswith("\n") else "\n", file=sys.stderr)
    return int(p.returncode)


if __name__ == "__main__":
    raise SystemExit(main())
