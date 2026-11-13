#!/usr/bin/env python3
"""Tarot art from the owner's two pictures (Gemini/ChatGPT, 2026-11-12):

  reference/art/games/tarot_tile_src.jpg     cards close up, painted title  -> hub tile 320x180
  reference/art/games/tarot_preview_src.jpg  whole reading room             -> hub preview 960x540
  both                                                                      -> Landing background
                                                                               games/tarot/landing_bg.jpg (720x1280)

The Landing picture is portrait: the owner's wide picture (title + cards) is laid across the top at
full width over a night-blue gradient, so the painted title is whole.
The game uses cfg "art_title" = ART_TITLE (the painted title's top/bottom as fractions of the height).

  python tools/tarot_art.py
Needs Pillow.
"""
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "reference/art/games"
TILE_SRC = SRC / "tarot_tile_src.jpg"
PREV_SRC = SRC / "tarot_preview_src.jpg"
OUT_HUB = ROOT / "media/hub/game_art/tarot"
OUT_LAND = ROOT / "games/tarot/landing_bg.jpg"
W, H = 720, 1280
TITLE_TOP = 120          # the Landing crops a little off the top on tall phones
CARDS_SCALE = 0.8        # of the full width
TITLE_CROP = (80, 270)   # rows of the cards picture holding the painted title
CARDS_CROP = 285         # first row of the cards
# Painted title in the cards picture: y 135..235 of 768.
TITLE_Y = (135 / 768, 235 / 768)


def crop_16_9(im: Image.Image) -> Image.Image:
    w, h = im.size
    nw = int(h * 16 / 9)
    if nw <= w:
        x = (w - nw) // 2
        return im.crop((x, 0, x + nw, h))
    nh = int(w * 9 / 16)
    y = (h - nh) // 2
    return im.crop((0, y, w, y + nh))


def cover(im: Image.Image, w: int, h: int) -> Image.Image:
    s = max(w / im.width, h / im.height)
    r = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    x = (r.width - w) // 2
    y = (r.height - h) // 2
    return r.crop((x, y, x + w, y + h))


def fade_mask(size: tuple[int, int], top: int, bottom: int) -> Image.Image:
    """Alpha that fades the picture in over `top` rows and out over `bottom` rows."""
    w, h = size
    col = Image.new("L", (1, h))
    for y in range(h):
        col.putpixel((0, y), int(255 * min(1.0, y / max(1, top), (h - 1 - y) / max(1, bottom))))
    return col.resize((w, h))


def main() -> None:
    OUT_HUB.mkdir(parents=True, exist_ok=True)
    OUT_LAND.parent.mkdir(parents=True, exist_ok=True)
    tile = Image.open(TILE_SRC).convert("RGB")
    prev = Image.open(PREV_SRC).convert("RGB")
    crop_16_9(tile).resize((320, 180), Image.LANCZOS).save(OUT_HUB / "tile.webp", quality=85)
    crop_16_9(prev).resize((960, 540), Image.LANCZOS).save(OUT_HUB / "hero.webp", quality=85)

    # Night-blue gradient (the colours of the owner's room), brighter at both ends where the art sits.
    bg = Image.new("RGB", (W, H))
    for y in range(H):
        t = y / (H - 1)
        glow = max(0.0, 1.0 - abs(t - 0.5) * 2.0)  # 1 in the middle, 0 at the ends
        c = (round(16 - 8 * glow), round(22 - 12 * glow), round(54 - 26 * glow))
        bg.paste(c, (0, y, W, y + 1))
    k = W / tile.width
    # The painted title strip goes at the top (the Landing puts its own text under it); the five
    # cards sit at the bottom, clear of the buttons in the middle.
    title = tile.crop((0, TITLE_CROP[0], tile.width, TITLE_CROP[1])).resize((W, round((TITLE_CROP[1] - TITLE_CROP[0]) * k)), Image.LANCZOS)
    cw = round(W * CARDS_SCALE)
    cards = tile.crop((0, CARDS_CROP, tile.width, tile.height)).resize((cw, round((tile.height - CARDS_CROP) * cw / tile.width)), Image.LANCZOS)
    bg.paste(title, (0, TITLE_TOP), fade_mask(title.size, 40, 40))
    cards_top = H - cards.height - 24
    bg.paste(cards, ((W - cw) // 2, cards_top), fade_mask(cards.size, 90, 30))
    bg.save(OUT_LAND, quality=88)
    top = (TITLE_TOP + (TITLE_Y[0] * tile.height - TITLE_CROP[0]) * k) / H
    bottom = (TITLE_TOP + (TITLE_Y[1] * tile.height - TITLE_CROP[0]) * k) / H
    print(f"landing {W}x{H}; ART_TITLE = [{top:.3f}, {bottom:.3f}]")


if __name__ == "__main__":
    main()
