#!/usr/bin/env python3
from __future__ import annotations

import os
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]


def die(msg: str) -> None:
    print(f"[sanity_check] ERROR: {msg}", file=sys.stderr)
    raise SystemExit(1)


def check_exists(rel_path: str) -> None:
    p = REPO_ROOT / rel_path
    if not p.exists():
        die(f"Missing required path: {rel_path}")


def res_to_fs(res_path: str) -> Path:
    # Accept: res://foo/bar.gd or *res://foo/bar.gd
    p = res_path.strip().strip('"').strip()
    if p.startswith("*"):
        p = p[1:]
    if not p.startswith("res://"):
        die(f"Unexpected resource path format: {res_path}")
    return REPO_ROOT / p.replace("res://", "").replace("\\", "/")


def parse_project_autoloads(project_text: str) -> list[str]:
    # Very small parser: look for lines like
    # Foo="*res://path/to/file.gd"
    autoloads: list[str] = []
    in_autoload = False
    for line in project_text.splitlines():
        if line.strip() == "[autoload]":
            in_autoload = True
            continue
        if in_autoload and line.startswith("[") and line.strip().endswith("]"):
            in_autoload = False
        if not in_autoload:
            continue
        m = re.search(r'=\s*"([^"]+)"\s*$', line)
        if not m:
            continue
        autoloads.append(m.group(1))
    return autoloads


def parse_scene_loader_level_scenes(scene_loader_text: str) -> list[str]:
    # Find strings like "res://levels/island.tscn" inside LEVEL_SCENES.
    # This is intentionally simple.
    return re.findall(r'"(res://levels/[^"]+\.tscn)"', scene_loader_text)


def main() -> None:
    # Baseline required files.
    check_exists("project.godot")
    check_exists("README.md")
    check_exists("main.tscn")
    check_exists("globals/game_flow/scene_loader.gd")

    project_text = (REPO_ROOT / "project.godot").read_text(encoding="utf-8")
    scene_loader_text = (REPO_ROOT / "globals/game_flow/scene_loader.gd").read_text(encoding="utf-8")

    # Ensure docs referenced by README exist.
    check_exists("docs/architecture.md")
    check_exists("docs/code_organization.md")
    check_exists("docs/cutscenes.md")

    # Autoload targets exist.
    for res_path in parse_project_autoloads(project_text):
        fs_path = res_to_fs(res_path)
        if not fs_path.exists():
            die(f"Autoload target missing: {res_path} -> {fs_path.as_posix()}")

    # Level scenes referenced by SceneLoader exist.
    for level_scene in parse_scene_loader_level_scenes(scene_loader_text):
        fs_path = res_to_fs(level_scene)
        if not fs_path.exists():
            die(f"SceneLoader level scene missing: {level_scene} -> {fs_path.as_posix()}")

    # Quick check: project.godot expects Godot 4.5 feature.
    if '"4.5"' not in project_text and "4.5" not in project_text:
        die("project.godot does not mention expected Godot 4.5 feature tag")

    print("[sanity_check] OK")


if __name__ == "__main__":
    # GitHub Actions uses POSIX paths; Windows devs can still run this locally.
    os.chdir(REPO_ROOT)
    main()

