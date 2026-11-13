#!/usr/bin/env python3
"""Bridge Master art from the owner's pictures (Gemini/ChatGPT, 2026-11-12, D:/Dev/Minigame Art/bridge Master):

  reference/art/games/bridge_master_landing_src.jpg  builder + jeep on a bridge (no title)
        -> hub tile 320x180, hub preview 960x540, Landing background games/bridge_master/landing_bg.jpg
  reference/art/games/bridge_master_{forest,desert,mesa}_src.jpg  empty canyons
        -> in-game backdrops games/bridge_master/bg_{forest,desert,mesa}.jpg (1280 wide)

The owner's titled copy ("Crossing Architect" + a store badge) is not used: wrong name, store badge.
  python tools/bridge_master_art.py      (needs Pillow)
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "reference/art/games"
OUT_HUB = ROOT / "media/hub/game_art/bridge_master"
OUT_GAME = ROOT / "games/bridge_master"


def crop_16_9(im: Image.Image) -> Image.Image:
    w, h = im.size
    nw = int(h * 16 / 9)
    if nw <= w:
        x = (w - nw) // 2
        return im.crop((x, 0, x + nw, h))
    nh = int(w * 9 / 16)
    y = (h - nh) // 2
    return im.crop((0, y, w, y + nh))


def main() -> None:
    OUT_HUB.mkdir(parents=True, exist_ok=True)
    OUT_GAME.mkdir(parents=True, exist_ok=True)
    land = crop_16_9(Image.open(SRC / "bridge_master_landing_src.jpg").convert("RGB"))
    land.resize((320, 180), Image.LANCZOS).save(OUT_HUB / "tile.webp", quality=85)
    land.resize((960, 540), Image.LANCZOS).save(OUT_HUB / "hero.webp", quality=85)
    land.resize((1280, 720), Image.LANCZOS).save(OUT_GAME / "landing_bg.jpg", quality=86)
    for name in ("forest", "desert", "mesa"):
        im = Image.open(SRC / f"bridge_master_{name}_src.jpg").convert("RGB")
        im.resize((1280, round(im.height * 1280 / im.width)), Image.LANCZOS).save(OUT_GAME / f"bg_{name}.jpg", quality=82)
    print("done")


if __name__ == "__main__":
    main()
