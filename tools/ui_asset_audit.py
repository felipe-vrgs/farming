#!/usr/bin/env python3
"""
UI asset audit / cleanup tool.

Godot exports only referenced resources by default, so unused images usually
won't affect final build size. However, unused files still add repo weight and
can make asset management harder.

This script:
- Scans the project for `res://assets/ui/...` references (in .tscn/.tres/.gd/etc)
- Lists image files under assets/ui that are unreferenced
- Optionally moves or deletes them (and their adjacent .import files)
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
from dataclasses import dataclass
from pathlib import Path


PROJECT_FILE_EXTS = {
    ".gd",
    ".gdshader",
    ".tscn",
    ".tres",
    ".cfg",
    ".godot",
    ".md",
    ".dtl",
    ".dch",
    ".json",
    ".yml",
    ".yaml",
}

UI_IMAGE_EXTS = {
    ".png",
    ".webp",
    ".jpg",
    ".jpeg",
    ".svg",
}

UI_PREFIX = "res://assets/ui/"


@dataclass(frozen=True)
class AuditResult:
    referenced_paths: set[str]
    ui_images: list[Path]
    unused_images: list[Path]


def _iter_project_files(root: Path) -> list[Path]:
    out: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(root):
        # Skip Godot's generated folders and VCS.
        parts = Path(dirpath).parts
        if ".godot" in parts or ".git" in parts:
            dirnames[:] = []
            continue
        for fn in filenames:
            p = Path(dirpath) / fn
            if p.suffix.lower() in PROJECT_FILE_EXTS:
                out.append(p)
    return out


def _extract_referenced_ui_paths(project_files: list[Path]) -> set[str]:
    # Capture `res://assets/ui/...<image>` with common image extensions.
    exts = "|".join(re.escape(ext.lstrip(".")) for ext in sorted(UI_IMAGE_EXTS))
    pattern = re.compile(rf"{re.escape(UI_PREFIX)}[^\"]+?\.({exts})", re.IGNORECASE)

    referenced: set[str] = set()
    for p in project_files:
        try:
            data = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for m in pattern.finditer(data):
            # Normalize to forward slashes (Godot res:// paths).
            referenced.add(m.group(0).replace("\\", "/"))
    return referenced


def _iter_ui_images(ui_dir: Path) -> list[Path]:
    imgs: list[Path] = []
    for dirpath, _dirnames, filenames in os.walk(ui_dir):
        for fn in filenames:
            p = Path(dirpath) / fn
            if p.suffix.lower() in UI_IMAGE_EXTS:
                imgs.append(p)
    imgs.sort(key=lambda p: str(p).lower())
    return imgs


def audit(project_root: Path) -> AuditResult:
    ui_dir = project_root / "assets" / "ui"
    if not ui_dir.exists():
        raise SystemExit(f"UI folder not found: {ui_dir}")

    project_files = _iter_project_files(project_root)
    referenced = _extract_referenced_ui_paths(project_files)
    ui_images = _iter_ui_images(ui_dir)

    unused: list[Path] = []
    for img in ui_images:
        # Convert filesystem path -> Godot res:// path.
        rel = img.relative_to(project_root).as_posix()
        res_path = f"res://{rel}"
        if res_path not in referenced:
            unused.append(img)

    return AuditResult(referenced_paths=referenced, ui_images=ui_images, unused_images=unused)


def _maybe_import_path(img: Path) -> Path | None:
    imp = img.with_name(img.name + ".import")
    return imp if imp.exists() else None


def move_unused(project_root: Path, unused: list[Path], dest_rel: str) -> None:
    dest = project_root / dest_rel
    dest.mkdir(parents=True, exist_ok=True)

    for img in unused:
        rel_under_ui = img.relative_to(project_root / "assets" / "ui")
        out_img = dest / rel_under_ui
        out_img.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(img), str(out_img))

        imp = _maybe_import_path(img)
        if imp is not None:
            out_imp = out_img.with_name(out_img.name + ".import")
            out_imp.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(imp), str(out_imp))


def delete_unused(unused: list[Path]) -> None:
    for img in unused:
        try:
            img.unlink()
        except FileNotFoundError:
            pass
        imp = _maybe_import_path(img)
        if imp is not None:
            try:
                imp.unlink()
            except FileNotFoundError:
                pass


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit/cleanup assets/ui images.")
    parser.add_argument(
        "--project-root",
        default=".",
        help="Path to Godot project root (contains project.godot).",
    )
    parser.add_argument(
        "--move-unused-to",
        default="",
        help="Move unused images (and adjacent .import) to this folder (relative to project root).",
    )
    parser.add_argument(
        "--delete-unused",
        action="store_true",
        help="Delete unused images (and adjacent .import).",
    )
    args = parser.parse_args()

    root = Path(args.project_root).resolve()
    if not (root / "project.godot").exists():
        raise SystemExit(f"Not a Godot project root (missing project.godot): {root}")

    res = audit(root)

    print(f"Referenced UI paths found: {len(res.referenced_paths)}")
    print(f"UI images found: {len(res.ui_images)}")
    print(f"Unused UI images: {len(res.unused_images)}")
    if res.unused_images:
        for p in res.unused_images:
            print(f"- {p.relative_to(root).as_posix()}")

    if args.delete_unused and args.move_unused_to:
        raise SystemExit("Choose only one: --delete-unused or --move-unused-to")

    if args.move_unused_to:
        move_unused(root, res.unused_images, args.move_unused_to)
        print(f"Moved {len(res.unused_images)} unused images to: {args.move_unused_to}")
    elif args.delete_unused:
        delete_unused(res.unused_images)
        print(f"Deleted {len(res.unused_images)} unused images.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
