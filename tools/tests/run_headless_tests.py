#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
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
    if explicit:
        return explicit
    for key in ("GODOT_BIN", "GODOT"):
        v = os.environ.get(key)
        if v:
            return v
    for cand in ("godot4", "godot"):
        p = shutil.which(cand)
        if p:
            return p
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description="Run Godot headless tests for this repo.")
    ap.add_argument(
        "--godot",
        help="Path to Godot executable (e.g. C:\\\\path\\\\Godot_v4.5-stable_win64.exe)",
        default=None,
    )
    ap.add_argument(
        "--include-runtime",
        action="store_true",
        help="Include the runtime smoke suite (loads/changes scenes; slower/noisier).",
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
    if args.include_runtime:
        env["FARMING_TEST_INCLUDE_RUNTIME"] = "1"
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
    if p.stdout:
        print(p.stdout, end="" if p.stdout.endswith("\n") else "\n")
    if p.stderr:
        print(p.stderr, end="" if p.stderr.endswith("\n") else "\n", file=sys.stderr)
    return int(p.returncode)


if __name__ == "__main__":
    raise SystemExit(main())
