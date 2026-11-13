#!/usr/bin/env python3
"""Smaller pictures for the WEB build only (owner 2026-11-13: GitHub refuses files over
100 MB, and the web index.pck reached 141 MB, 99 MB of it lossless textures).

Run it in the throwaway clean worktree the web build is made from (docs/claude/web-build.md),
BEFORE `godot --import` and `hub.py web --publish`. It rewrites the .import file of every
texture whose source file is bigger than MIN_BYTES: lossy WebP (compress/mode=1, quality
QUALITY) and the longest side capped at SIZE_LIMIT. Never commit what it changes: the APK
and PC builds keep full-quality, lossless pictures.

  python tools/web_shrink.py [--root DIR] [--quality 0.75] [--size 1600] [--min-kb 150]
"""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=str(ROOT))
    ap.add_argument("--quality", type=float, default=0.75)
    ap.add_argument("--size", type=int, default=1600)
    ap.add_argument("--min-kb", type=int, default=150)
    a = ap.parse_args()
    root = Path(a.root)
    changed = 0
    before = 0
    for imp in root.rglob("*.import"):
        if ".godot" in imp.parts or "docs" in imp.parts[:len(root.parts) + 1]:
            continue
        text = imp.read_text(encoding="utf-8")
        if 'importer="texture"' not in text:
            continue
        src = imp.with_suffix("")
        if not src.is_file() or src.stat().st_size < a.min_kb * 1024:
            continue
        before += src.stat().st_size
        new = re.sub(r"^compress/mode=\d+$", "compress/mode=1", text, flags=re.M)
        new = re.sub(r"^compress/lossy_quality=[\d.]+$", f"compress/lossy_quality={a.quality}", new, flags=re.M)
        new = re.sub(r"^process/size_limit=\d+$", f"process/size_limit={a.size}", new, flags=re.M)
        if new != text:
            imp.write_text(new, encoding="utf-8")
            changed += 1
    print(f"web_shrink: {changed} textures set to lossy WebP q{a.quality}, max {a.size}px "
          f"(sources {before / 1e6:.1f} MB); reimport before exporting")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
