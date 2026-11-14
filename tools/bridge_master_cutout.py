#!/usr/bin/env python3
"""Bridge Master game art from the owner's AI pictures (2026-11-13,
D:/Dev/Minigame Art/bridge Master/prompts/, made from the prompts Claude wrote).

The pictures are JPGs with a fake "transparent" grey checkerboard painted in (or a
plain sky for the pier), so this cuts the background out: a pixel is background
when it is grey and close to one of the checker shades (or to the sky colour)
AND it connects to the picture's border. Dark ink outlines stop the fill, so
grey steel inside an outline is kept.

Copies the sources to reference/art/games/bridge_master_parts/ and writes PNGs
to games/bridge_master/parts/, and parts.json (next to the sources) (cliff edge and road height,
vehicle wheel positions as fractions of the picture).

  python tools/bridge_master_cutout.py [source folder]
Needs Pillow.
"""
import json
import shutil
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC_DEFAULT = Path("D:/Dev/Minigame Art/bridge Master/prompts")
KEEP = ROOT / "reference/art/games/bridge_master_parts"
OUT = ROOT / "games/bridge_master/parts"

# source file -> (output name, kind, output width)
PARTS = {
    "1.jpg": ("cliff_forest_l", "cliff", 512),
    "2.jpg": ("cliff_forest_r", "cliff", 512),
    "3a.jpg": ("cliff_desert_l", "cliff", 512),
    "3b.jpg": ("cliff_desert_r", "cliff", 512),
    "3c.jpg": ("cliff_mesa_l", "cliff", 512),
    "3d.jpg": ("cliff_mesa_r", "cliff", 512),
    "4.jpg": ("pier", "sky", 256),
    "5.jpg": ("water", "checker", 1024),
    "6a.jpg": ("beam_wood", "checker", 1024),
    "7.jpg": ("beam_steel", "checker", 1024),
    "8.jpg": ("road_steel", "checker", 1024),
    "8a.jpg": ("road_wood", "checker", 1024),
    "9.jpg": ("cable", "checker", 1024),
    "11.jpg": ("bolts", "bolts", 0),
    "car1.jpg": ("veh_car", "checker", 512),
    "car2.jpg": ("veh_van", "checker", 512),
    "car3.jpg": ("veh_bus", "checker", 640),
    "car4.jpg": ("veh_truck", "checker", 640),
    "car5.jpg": ("veh_heavy", "checker", 640),
    # 2026-11-14: sharp desert cliff (replaces 3a.jpg) and the Garage vehicles (bought with stars).
    "21.jpg": ("cliff_desert_l", "cliff", 640),
    "car 6.jpg": ("skin_monster", "checker", 512),
    "car7.jpg": ("skin_rusty", "checker", 512),
    "car8.jpg": ("skin_racer", "checker", 512),
    "car9.jpg": ("skin_wiener", "checker", 512),
    "car10.jpg": ("skin_icecream", "checker", 512),
    "car11.jpg": ("skin_convertible", "checker", 512),
    "car13.jpg": ("skin_firetruck", "checker", 640),
    "limo.png": ("skin_limo", "png", 640),
    "pumpin.jpg": ("skin_pumpkin", "checker", 512),
    "rover.png": ("skin_rover", "png", 512),
    "taco.png": ("skin_taco", "png", 512),
    "tank.png": ("skin_tank", "png", 512),
}
# Sources replaced by a later picture (same output name): skipped.
SUPERSEDED = {"3a.jpg"}


def grey_levels(im: Image.Image) -> list:
    """The checker's grey shades, from the border pixels."""
    w, h = im.size
    px = im.load()
    counts = {}
    for x in range(0, w, 3):
        for y in (1, 4, h - 2, h - 5):
            r, g, b = px[x, y]
            if max(r, g, b) - min(r, g, b) < 14:
                k = (r + g + b) // 3 // 6
                counts[k] = counts.get(k, 0) + 1
    for y in range(0, h, 3):
        for x in (1, 4, w - 2, w - 5):
            r, g, b = px[x, y]
            if max(r, g, b) - min(r, g, b) < 14:
                k = (r + g + b) // 3 // 6
                counts[k] = counts.get(k, 0) + 1
    top = sorted(counts, key=counts.get, reverse=True)
    first = top[0]
    # The other shade: the most common bucket at least 30 levels away.
    second = next((k for k in top[1:] if abs(k - first) * 6 >= 30), first)
    return [first * 6 + 3, second * 6 + 3]


def cut(im: Image.Image, kind: str) -> Image.Image:
    im = im.convert("RGB")
    w, h = im.size
    px = im.load()
    if kind == "sky":
        def is_bg(c):
            r, g, b = c
            return b > 150 and b >= r + 8 and b >= g - 6 and (r + g + b) > 420
    else:
        levels = grey_levels(im)

        lo = min(levels[:2]) - 16
        hi = max(levels[:2]) + 16

        def is_bg(c):
            # Any grey between the two checker shades: the soft lines between
            # the squares are in-between greys, so this lets the fill cross them.
            r, g, b = c
            if max(r, g, b) - min(r, g, b) > 18:
                return False
            return lo <= (r + g + b) / 3 <= hi
    bg = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        i = y * w + x
        if bg[i] or not is_bg(px[x, y]):
            continue
        bg[i] = 1
        if x > 0: q.append((x - 1, y))
        if x < w - 1: q.append((x + 1, y))
        if y > 0: q.append((x, y - 1))
        if y < h - 1: q.append((x, y + 1))
    alpha = Image.frombytes("L", (w, h), bytes(0 if b else 255 for b in bg))
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    out = im.convert("RGBA")
    out.putalpha(alpha)
    return out


def cable_band(im: Image.Image) -> Image.Image:
    """The cable is grey on a dark grey checker: keep the rows that are not checker."""
    im = im.convert("RGB")
    w, h = im.size
    px = im.load()
    levels = grey_levels(im)
    rows = []
    for y in range(h):
        hits = 0
        for x in range(0, w, 2):
            r, g, b = px[x, y]
            v = (r + g + b) / 3
            if any(abs(v - L) <= 8 for L in levels):
                hits += 1
        rows.append(hits / (w / 2))
    band = [y for y in range(h) if rows[y] < 0.45]
    mid = sorted(band)[len(band) // 2]
    top = mid
    while top > 0 and rows[top - 1] < 0.45:
        top -= 1
    bot = mid
    while bot < h - 1 and rows[bot + 1] < 0.45:
        bot += 1
    out = im.crop((0, top, w, bot + 1)).convert("RGBA")
    a = Image.new("L", out.size, 255)
    for y in (0, out.height - 1):
        for x in range(out.width):
            a.putpixel((x, y), 110)
    out.putalpha(a)
    return out


# Vehicles drawn facing left, flipped so all drive to the right.
FACE_LEFT = {"veh_bus", "veh_heavy"}
# Outer wheel centres and tyre radius as fractions of the (flipped) picture's width,
# read off the pictures by eye; the tyres touch the picture's bottom edge.
WHEELS = {
    "veh_car": {"rear": 0.18, "front": 0.79, "r": 0.10},
    "veh_van": {"rear": 0.19, "front": 0.77, "r": 0.10},
    "veh_bus": {"rear": 0.22, "front": 0.78, "r": 0.09},
    "veh_truck": {"rear": 0.21, "front": 0.80, "r": 0.08},
    "veh_heavy": {"rear": 0.18, "front": 0.82, "r": 0.075},
}

# Garage vehicles: outer wheel centres (rear, front) and tyre radius, fractions of the
# width, read off the cut pictures by eye (wheels() guesses badly on these). The tank's are
# the ends of its tracks, the rover's its outer wheels.
SKIN_WHEELS = {
    "skin_convertible": {"rear": 0.26, "front": 0.82, "r": 0.065},
    "skin_firetruck": {"rear": 0.225, "front": 0.845, "r": 0.055},
    "skin_icecream": {"rear": 0.20, "front": 0.86, "r": 0.08},
    "skin_limo": {"rear": 0.105, "front": 0.81, "r": 0.04},
    "skin_monster": {"rear": 0.17, "front": 0.83, "r": 0.17},
    "skin_pumpkin": {"rear": 0.12, "front": 0.87, "r": 0.11},
    "skin_racer": {"rear": 0.16, "front": 0.78, "r": 0.06},
    "skin_rover": {"rear": 0.10, "front": 0.79, "r": 0.09},
    "skin_rusty": {"rear": 0.18, "front": 0.76, "r": 0.07},
    "skin_taco": {"rear": 0.17, "front": 0.76, "r": 0.085},
    "skin_tank": {"rear": 0.12, "front": 0.86, "r": 0.08},
    "skin_wiener": {"rear": 0.16, "front": 0.78, "r": 0.07},
}

# Ground line of each cliff (fraction of the cut picture's height), read off the
# pictures by eye: the trees on the forest cliff stand above it.
CLIFF_TOP = {"cliff_forest_l": 0.24, "cliff_forest_r": 0.05, "cliff_desert_l": 0.04,
             "cliff_desert_r": 0.05, "cliff_mesa_l": 0.09, "cliff_mesa_r": 0.07}
# Where the painted checkerboard starts showing through the rock (fraction of height).
CLIFF_FADE = {"cliff_desert_r": 0.28, "cliff_mesa_l": 0.36, "cliff_mesa_r": 0.40}


def heal_cliff(im: Image.Image, start: float) -> Image.Image:
    """Below `start`, blends into a median-smoothed copy (no checker left) that
    darkens toward the bottom, like rock going into shadow."""
    rgb = im.convert("RGB")
    smooth = rgb.filter(ImageFilter.MedianFilter(9)).filter(ImageFilter.GaussianBlur(16))
    w, h = im.size
    out = rgb.copy()
    o = out.load(); sm = smooth.load(); src = rgb.load()
    y0 = int(h * start)
    ramp = max(1, int(h * 0.08))
    for y in range(max(0, y0 - ramp), h):
        t = min(1.0, (y - (y0 - ramp)) / ramp)
        dark = 1.0 - 0.45 * max(0.0, (y - y0) / max(1, h - y0))
        for x in range(w):
            a = src[x, y]; b = sm[x, y]
            o[x, y] = tuple(int((a[i] * (1 - t) + b[i] * t) * dark) for i in range(3))
    res = out.convert("RGBA")
    res.putalpha(im.getchannel("A"))
    return res


def glass(im: Image.Image) -> Image.Image:
    """Vehicle windows kept the checker (enclosed by outlines): paint them glass."""
    px = im.load()
    w, h = im.size
    for y in range(int(h * 0.62)):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0 and max(r, g, b) - min(r, g, b) < 16 and 120 <= (r + g + b) / 3 <= 256:
                k = y / h
                px[x, y] = (int(200 - 60 * k), int(232 - 30 * k), int(248 - 15 * k), a)
    return im


def cover_brand(im: Image.Image) -> Image.Image:
    """The AI painted a real brand on the hot-dog car (a meat company's name and its
    trademarked car name): paint each label over with the bun colour (no real brands,
    docs/IP_AUDIT.md)."""
    from PIL import ImageDraw
    w, h = im.size
    px = im.load()
    # Mean of the light bun pixels left of the first label.
    b0 = BRAND_BOXES[0]
    cs = [px[x, y] for x in range(int((b0[0] - 0.05) * w), int(b0[0] * w)) for y in range(int(b0[1] * h), int(b0[3] * h))
          if px[x, y][3] > 200 and sum(px[x, y][:3]) > 330]
    col = tuple(sum(c[i] for c in cs) // len(cs) for i in range(3)) + (255,)
    for box in BRAND_BOXES:
        ImageDraw.Draw(im).rounded_rectangle((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)), radius=6, fill=col)
    return im


# Labels to paint over on skin_wiener (fractions of the cut picture), read off by eye.
BRAND_BOXES = [(0.255, 0.38, 0.385, 0.66), (0.575, 0.47, 0.69, 0.68)]


# Checker left inside a vehicle's outline that should be see-through (not glass):
# under the monster truck, between the fire ladder's rungs, the pumpkin's windows.
HOLES = {"skin_monster": (0.0, 0.45, 1.0, 0.8), "skin_firetruck": (0.0, 0.0, 1.0, 0.25),
         "skin_pumpkin": (0.3, 0.15, 0.85, 0.7)}


def holes(im: Image.Image, box: tuple) -> Image.Image:
    px = im.load()
    w, h = im.size
    for y in range(int(box[1] * h), int(box[3] * h)):
        for x in range(int(box[0] * w), int(box[2] * w)):
            r, g, b, a = px[x, y]
            if a > 0 and max(r, g, b) - min(r, g, b) < 16 and 110 <= (r + g + b) / 3 <= 256:
                px[x, y] = (r, g, b, 0)
    return im


def trim(im: Image.Image) -> Image.Image:
    box = im.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
    return im.crop(box) if box else im


def resize_w(im: Image.Image, w: int) -> Image.Image:
    if w <= 0 or im.width <= w:
        return im
    return im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)


def cliff_meta(im: Image.Image, right_side: bool) -> dict:
    """Road height (first row that is mostly solid) and the edge column."""
    a = im.getchannel("A").load()
    w, h = im.size
    top = 0
    for y in range(h):
        solid = sum(1 for x in range(w) if a[x, y] > 128)
        if solid > w * 0.6:
            top = y
            break
    mid = min(h - 1, top + h // 6)
    cols = [x for x in range(w) if a[x, mid] > 128]
    edge = (min(cols) if right_side else max(cols)) if cols else (0 if right_side else w - 1)
    return {"top": round(top / h, 4), "edge": round(edge / w, 4)}


def wheels(im: Image.Image) -> dict:
    """Wheel centres: the two lowest dark blobs, found on the bottom band."""
    a = im.getchannel("A").load()
    rgb = im.convert("RGB").load()
    w, h = im.size
    bottom = max(y for y in range(h) for x in range(0, w, 4) if a[x, y] > 128)
    band = bottom - int(h * 0.04)
    xs = [x for x in range(w) if a[x, band] > 128 and sum(rgb[x, band]) < 200]
    runs = []
    for x in xs:
        if runs and x - runs[-1][1] <= 3:
            runs[-1][1] = x
        else:
            runs.append([x, x])
    runs = [r for r in runs if r[1] - r[0] > w * 0.03]
    if len(runs) < 2:
        return {"rear": 0.22, "front": 0.78, "r": 0.1}
    rear = (runs[0][0] + runs[0][1]) / 2
    front = (runs[-1][0] + runs[-1][1]) / 2
    r = (runs[-1][1] - runs[-1][0]) / 2
    radius = r * 1.25  # the band cuts below the hub: the tyre is a bit bigger
    return {"rear": round(rear / w, 4), "front": round(front / w, 4),
            "r": round(radius / w, 4), "ground": round(bottom / h, 4)}


def main() -> None:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else SRC_DEFAULT
    KEEP.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    meta = {}
    for name, (out, kind, width) in PARTS.items():
        if name in SUPERSEDED:
            continue
        f = src / name
        if not f.exists():
            print("missing", f)
            continue
        shutil.copy2(f, KEEP / name)
        im = Image.open(f)
        if kind == "bolts":
            # Four square tiles in a row: keep the round middle of each.
            im = im.convert("RGB")
            tw = im.width // 4
            for i, nm in enumerate(["bolt", "anchor", "plate", "marker"]):
                tile = im.crop((i * tw, 0, (i + 1) * tw, im.height))
                s = min(tile.size)
                tile = tile.crop(((tile.width - s) // 2, (tile.height - s) // 2, (tile.width + s) // 2, (tile.height + s) // 2))
                tile = tile.crop((s * 0.2, s * 0.2, s * 0.8, s * 0.8)).resize((96, 96), Image.LANCZOS).convert("RGBA")
                mask = Image.new("L", (96 * 4, 96 * 4), 0)
                from PIL import ImageDraw
                ImageDraw.Draw(mask).ellipse((4, 4, 96 * 4 - 4, 96 * 4 - 4), fill=255)
                tile.putalpha(mask.resize((96, 96), Image.LANCZOS))
                tile.save(OUT / f"{nm}.png")
            continue
        if out == "cable":
            im = cable_band(im)
            im = resize_w(im, width)
            im.save(OUT / f"{out}.png", optimize=True)
            meta.setdefault("size", {})[out] = [im.width, im.height]
            continue
        if kind == "png":
            im = im.convert("RGBA")  # already transparent
        else:
            im = cut(im, "sky" if kind == "sky" else "checker")
        if kind == "sky":
            # Keep the pillar above the waterline (the river is drawn by the game).
            a = im.getchannel("A")
            im = trim(im)
            im = im.crop((0, 0, im.width, int(im.height * 0.93)))
        elif out == "water":
            im = trim(im)
        else:
            im = trim(im)
        im = resize_w(im, width)
        if out in CLIFF_FADE:
            im = heal_cliff(im, CLIFF_FADE[out])
        if out in HOLES:
            im = holes(im, HOLES[out])
        if out == "skin_wiener":
            im = cover_brand(im)
        if out.startswith("veh_") or (out.startswith("skin_") and kind != "png"):
            im = glass(im)
            if out in FACE_LEFT:
                im = im.transpose(Image.FLIP_LEFT_RIGHT)
        im.save(OUT / f"{out}.png", optimize=True)
        if kind == "cliff":
            meta[out] = cliff_meta(im, out.endswith("_r"))
            meta[out]["top"] = CLIFF_TOP[out]
        elif out.startswith("veh_"):
            meta[out] = WHEELS[out]
        elif out.startswith("skin_"):
            meta[out] = SKIN_WHEELS[out]
        meta.setdefault("size", {})[out] = [im.width, im.height]
        print(out, im.size, meta.get(out, ""))
    (KEEP / "parts.json").write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
