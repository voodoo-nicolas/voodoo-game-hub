#!/usr/bin/env python3
"""Hub game art: tile.webp (16:9, 320x180) + hero.webp (1920x1080) per game.

  python tools/make_hub_art.py                 placeholders for every game that has no art yet
  python tools/make_hub_art.py --force         redo the placeholders (never touches art you supplied)
  python tools/make_hub_art.py --from DIR      real art: DIR/<id>.png|jpg|webp (hero) and
                                               DIR/<id>_tile.* (optional tile) -> converted to WebP
  python tools/make_hub_art.py --report        sizes only

Output: media/hub/game_art/<id>/tile.webp and hero.webp (APK-side, in the hub, not in the
game's pack). Placeholders are self-made: the owner's category picture (media/hub/categories),
darkened and tinted per game, a neon grid and the game's emoji. Each file gets a
media/CREDITS.json entry (proof: media/licenses/HUB_GAME_ART.md). Needs Pillow + numpy.
Hero focal point is the RIGHT half (landscape text sits over the left 45%; portrait crops to the centre).
"""
import argparse
import colorsys
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "media/hub/game_art"
CATS = ROOT / "media/hub/categories"
CREDITS = ROOT / "media/CREDITS.json"
PROOF = "media/licenses/HUB_GAME_ART.md"
EMOJI_FONT = Path("C:/Windows/Fonts/seguiemj.ttf")
TILE = (320, 180)
HERO = (1920, 1080)
CAT_FILE = {"Word": "word", "Arcade": "arcade", "Cards": "cards", "Intelligence": "intelligence",
            "Puzzle & Board": "puzzle", "Adventure": "adventure", "Dice": "dice", "Party": "party"}
SELF_MADE = "placeholder: category art + code-drawn glow (Claude Code)"


def games() -> list[tuple[str, str, str]]:
    m = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    out = []
    for cat in m["categories"]:
        if cat.get("archived"):
            continue
        for g in cat["games"]:
            if g.get("id") and not g.get("archived"):
                out.append((g["id"], g.get("icon", "🎮"), cat["name"]))
    return out


def hue_of(gid: str) -> float:
    return int(hashlib.md5(gid.encode()).hexdigest()[:6], 16) / 0xFFFFFF * 0.58  # red..blue, never purple


def cover(im: Image.Image, size: tuple[int, int], fx: float, fy: float) -> Image.Image:
    w, h = im.size
    s = max(size[0] / w, size[1] / h)
    im = im.resize((int(w * s) + 1, int(h * s) + 1), Image.LANCZOS)
    x = int((im.width - size[0]) * fx)
    y = int((im.height - size[1]) * fy)
    return im.crop((x, y, x + size[0], y + size[1]))


def tint(im: Image.Image, hue: float, dark: float) -> Image.Image:
    a = np.asarray(im.convert("RGB"), dtype=np.float32) / 255.0
    lum = (a * [0.3, 0.59, 0.11]).sum(axis=2, keepdims=True)
    r, g, b = colorsys.hsv_to_rgb(hue, 0.75, 1.0)
    colour = np.array([r, g, b], dtype=np.float32)
    out = (a * 0.45 + lum * colour * 1.1 * 0.75 + colour * 0.06) * dark
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))


def grid(size: tuple[int, int], hue: float, step: int) -> Image.Image:
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r, g, b = [int(c * 255) for c in colorsys.hsv_to_rgb(hue, 0.5, 1.0)]
    for x in range(0, size[0], step):
        d.line([(x, 0), (x, size[1])], fill=(r, g, b, 22))
    for y in range(0, size[1], step):
        d.line([(0, y), (size[0], y)], fill=(r, g, b, 22))
    return im


def glyph(emoji: str, px: int, hue: float) -> Image.Image:
    """The emoji with a soft neon halo, on a transparent square 2x its size."""
    canvas = Image.new("RGBA", (px * 2, px * 2), (0, 0, 0, 0))
    try:
        font = ImageFont.truetype(str(EMOJI_FONT), 109)
        tmp = Image.new("RGBA", (136, 128), (0, 0, 0, 0))
        ImageDraw.Draw(tmp).text((0, 0), emoji, font=font, embedded_color=True)
        bbox = tmp.getbbox()
        if bbox:
            tmp = tmp.crop(bbox)
        k = px / max(tmp.size)
        tmp = tmp.resize((max(1, int(tmp.width * k)), max(1, int(tmp.height * k))), Image.LANCZOS)
    except Exception:
        tmp = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        ImageDraw.Draw(tmp).ellipse((0, 0, px - 1, px - 1), outline=(255, 255, 255, 230), width=max(2, px // 14))
    r, g, b = [int(c * 255) for c in colorsys.hsv_to_rgb(hue, 0.6, 1.0)]
    halo = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    alpha = Image.new("L", canvas.size, 0)
    pos = ((canvas.width - tmp.width) // 2, (canvas.height - tmp.height) // 2)
    alpha.paste(tmp.split()[3], pos)
    glow = alpha.filter(ImageFilter.GaussianBlur(px * 0.16)).point(lambda v: min(255, int(v * 1.5)))
    halo.putalpha(glow)
    halo.paste(Image.new("RGBA", canvas.size, (r, g, b, 255)), (0, 0), glow)
    canvas = Image.alpha_composite(canvas, halo)
    canvas.alpha_composite(tmp, pos)
    return canvas


def make(gid: str, emoji: str, cat: str, hero: bool) -> Image.Image:
    size = HERO if hero else TILE
    h = hue_of(gid)
    src = Image.open(CATS / f"{CAT_FILE.get(cat, 'arcade')}.jpg")
    fx = (hue_of(gid + "x") * 0.9) + 0.05
    fy = (hue_of(gid + "y") * 0.8) + 0.1
    base = tint(cover(src, size, fx, fy), h, 0.78 if hero else 0.9).convert("RGBA")
    base.alpha_composite(grid(size, h, 60 if hero else 20))
    # vignette
    yy, xx = np.mgrid[0:size[1], 0:size[0]].astype(np.float32)
    d = np.sqrt(((xx / size[0] - 0.5) * 1.3) ** 2 + ((yy / size[1] - 0.45) * 1.3) ** 2)
    v = np.clip(1.15 - d * 0.9, 0.35, 1.0)[..., None]
    arr = np.asarray(base, dtype=np.float32)
    arr[..., :3] *= v
    base = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert("RGBA")
    px = int(size[1] * (0.36 if hero else 0.52))
    g = glyph(emoji, px, h)
    cx = int(size[0] * (0.70 if hero else 0.5))
    cy = int(size[1] * (0.46 if hero else 0.5))
    base.alpha_composite(g, (cx - g.width // 2, cy - g.height // 2))
    return base.convert("RGB")


def convert(path: Path, size: tuple[int, int]) -> Image.Image:
    return cover(Image.open(path).convert("RGB"), size, 0.5, 0.4 if size == HERO else 0.5)


def save(im: Image.Image, path: Path, hero: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, "WEBP", quality=62 if hero else 78, method=6)


def update_credits(ids: list[str], note: dict[str, str]) -> None:
    data = json.loads(CREDITS.read_text(encoding="utf-8"))
    keep = [a for a in data["assets"] if not str(a.get("file", "")).startswith("media/hub/game_art/")]
    for gid in ids:
        for name in ("tile.webp", "hero.webp"):
            if not (OUT / gid / name).is_file():
                continue
            real = note.get(gid, "")
            keep.append({
                "file": f"media/hub/game_art/{gid}/{name}",
                "what": f"Hub art for {gid} ({'tile 16:9' if name.startswith('tile') else 'hero, portrait'})",
                "source": real or "generated by tools/make_hub_art.py from media/hub/categories (owner art)",
                "author": "Viral (owner)" if real else "Viral (owner art) + Claude Code",
                "licence": "owner-proprietary",
                "proof": PROOF,
                "url": "",
                "date": "2026-10-13",
                "processed_by": ("converted to WebP (Claude Code)" if real else SELF_MADE),
            })
    data["assets"] = keep
    CREDITS.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")


def report() -> None:
    files = sorted(OUT.rglob("*.webp"))
    total = sum(f.stat().st_size for f in files)
    print(f"{len(files)} files, {total / 1024 / 1024:.2f} MB in media/hub/game_art/")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--from", dest="src")
    ap.add_argument("--report", action="store_true")
    args = ap.parse_args()
    if args.report:
        report()
        return 0
    real: dict[str, str] = {}
    all_games = games()
    if args.src:
        src = Path(args.src)
        for gid, _e, _c in all_games:
            hero = next((p for ext in ("png", "jpg", "jpeg", "webp") for p in [src / f"{gid}.{ext}"] if p.is_file()), None)
            tile = next((p for ext in ("png", "jpg", "jpeg", "webp") for p in [src / f"{gid}_tile.{ext}"] if p.is_file()), None)
            if hero:
                save(convert(hero, HERO), OUT / gid / "hero.webp", True)
                save(convert(tile or hero, TILE), OUT / gid / "tile.webp", False)
                real[gid] = str(hero.name)
        print(f"converted {len(real)} supplied image(s)")
    else:
        # Art you supplied earlier is recorded in CREDITS with a real source: leave it alone.
        existing = json.loads(CREDITS.read_text(encoding="utf-8"))["assets"]
        for a in existing:
            f = str(a.get("file", ""))
            if f.startswith("media/hub/game_art/") and not str(a.get("source", "")).startswith("generated"):
                real[f.split("/")[3]] = str(a["source"])
        if not EMOJI_FONT.is_file():
            print("warning: Segoe UI Emoji not found; placeholders get a plain ring instead of the emoji", file=sys.stderr)
        n = 0
        for gid, emoji, cat in all_games:
            if gid in real:
                continue
            t, h = OUT / gid / "tile.webp", OUT / gid / "hero.webp"
            if t.is_file() and h.is_file() and not args.force:
                continue
            save(make(gid, emoji, cat, False), t, False)
            save(make(gid, emoji, cat, True), h, True)
            n += 1
        print(f"made placeholders for {n} game(s)")
    update_credits([g[0] for g in all_games], real)
    report()
    return 0


if __name__ == "__main__":
    sys.exit(main())
