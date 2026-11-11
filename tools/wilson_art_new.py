"""Beached (wilson) art, 2026-11-10 batch (docs/wilson/ART_PROMPTS_MISSING.md): item sheets 1-7 and the
single build pictures in D:/dev/Wilson -> games/wilson/art/{icons,camp,projects}/.
Run: python tools/wilson_art_new.py   (then Godot --import). Sheets have a white background; the single
pictures have a checkerboard baked in (white / grey squares), so the background is every low-saturation
light pixel connected to the border of the box."""
import os
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

SRC = "D:/dev/Wilson/"
OUT = "C:/Users/nick_/code/voodoo-game-hub/games/wilson/art/"


def sizes_ok(sz):
    return [v >= 250 for v in sz]


def cut(src, box, out, max_side, min_v=225, max_sat=14, inner=False, erode=0):
    im = Image.open(SRC + src).convert("RGB")
    a = np.asarray(im.crop(box)).astype(np.int32)
    sat = a.max(-1) - a.min(-1)
    light = (a.min(-1) >= min_v) | ((sat <= max_sat) & (a.min(-1) >= 120) & (min_v < 200))
    light &= sat <= max_sat + 6
    lab, n = ndimage.label(light)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    if inner:      # checkerboard seen through gaps (canopy, desalinator): every big light grey patch is background
        sz = ndimage.sum(light, lab, range(1, n + 1))
        bg |= np.isin(lab, [i + 1 for i, v in enumerate(sizes_ok(sz)) if v])
    fg = ~bg
    if erode:
        fg = ndimage.binary_erosion(fg, iterations=erode)
    fg = ndimage.binary_opening(fg, iterations=1)
    lab2, n2 = ndimage.label(fg)
    if n2 == 0:
        print("  EMPTY", src, out)
        return
    sizes = ndimage.sum(fg, lab2, range(1, n2 + 1))
    keep = np.isin(lab2, [i + 1 for i, s in enumerate(sizes) if s >= 0.04 * sizes.max()])
    if not inner:
        keep = ndimage.binary_fill_holes(keep)
    ys, xs = np.nonzero(keep)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    al = Image.fromarray((keep * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
    img = Image.fromarray(np.dstack([a.clip(0, 255).astype(np.uint8), np.asarray(al)]), "RGBA").crop((x0, y0, x1, y1))
    s = min(1.0, max_side / max(img.size))
    img = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
    pad = Image.new("RGBA", (img.width + 8, img.height + 8), (0, 0, 0, 0))
    pad.alpha_composite(img, (4, 4))
    os.makedirs(os.path.dirname(OUT + out), exist_ok=True)
    pad.save(OUT + out + ".webp", "WEBP", quality=88, method=6)
    print("  ", out, pad.size)


def grid(src, names, cols, rows, folder, max_side=128, size=(1376, 768)):
    """names row by row; None = skip. Cells are inset a little so neighbours do not bleed in."""
    cw, ch = size[0] / cols, size[1] / rows
    for i, nm in enumerate(names):
        if not nm:
            continue
        c, r = i % cols, i // cols
        cut(src, (int(c * cw + 6), int(r * ch + 6), int((c + 1) * cw - 6), int((r + 1) * ch - 6)), f"{folder}/{nm}", max_side)


# ---- item icons (4 x 3 sheets, 1376x768)
grid("sheet 1.jpg", ["bait", "bandage", "barrel", "blunt_knife", "boot", "clay", "clay_jar", "cloth_scrap", "compost", "copper_tube", "crab", "crab_cooked"], 4, 3, "icons")
grid("sheet 2.jpg", ["driftwood", "drum", "dry_frond", "fish_oil", "fish_big", "fish_bone", "fish_guts", "fish_stew", "frond_hat", "fish_oil_lamp", "husk_fiber", "nail"], 4, 3, "icons")
grid("sheet 3.jpg", ["oar", "paper", "plank", "seaweed_crisps", "rubber_sling", "sailcloth", "sand", "seawater", "spark_kit", "seeds", "spyglass", "sweet_potato"], 4, 3, "icons")
# sheet 4: the first cell is a second sweet potato; the net, fish hook, rope and patched cloth are extras
grid("sheet 4.jpg", [None, "sweet_potato_roast", "tin_can", "trunk", "wax", "wind_chime", None, None, None, None, None, None], 4, 3, "icons")

# ---- craft-list icons of built things (sheet 6: 3x3, 1024x1024; sheet 5 / 7 are 1376x768)
grid("sheet 6.jpg", ["campfire", "canopy", "crafting_stump", "drying_rack", "fish_trap", "frond_bed", "frond_shelter", "garden_plot", "hammock"], 3, 3, "icons", size=(1024, 1024))
# sheet 7 is not a regular grid: boxes (x0, y0, x1, y1)
for nm, box in {"kiln": (40, 20, 340, 280), "sundial": (400, 30, 700, 260), "rain_catcher": (740, 30, 1010, 360),
                "smokehouse": (1020, 20, 1350, 380), "raft_section": (50, 290, 360, 490), "tent": (360, 270, 720, 510),
                "sos_flag": (80, 490, 330, 750), "water_still": (360, 520, 710, 730)}.items():
    cut("sheet 7.jpg", box, f"icons/{nm}", 128)

# ---- in-world builds (single pictures, checkerboard background)
for src, nm, folder in [("frond shelter.jpg", "frond_shelter", "camp"), ("fish trap.jpg", "fish_trap", "camp"),
                        ("SOS flag.jpg", "sos_flag", "camp"), ("canopy.jpg", "canopy", "camp"),
                        ("Smokehouse.jpg", "smokehouse", "camp"), ("kiln.jpg", "kiln", "camp"),
                        ("Sundial.jpg", "sundial", "camp"), ("raft section.jpg", "raft_section", "camp"),
                        ("desalinator.jpg", "desalinator", "projects"), ("cellar.jpg", "cellar", "projects"),
                        ("museum.jpg", "museum", "projects"), ("golden coconut.jpg", "shrine", "projects")]:
    w, h = Image.open(SRC + src).size
    cut(src, (0, 0, w, h), f"{folder}/{nm}", 260, min_v=140, max_sat=12, inner=True, erode=3 if nm in ("cellar", "shrine") else 0)


# ---- the wide island plate (2026-11-10): island wide.jpg (1696x624) -> plate.webp 2087x768, sky transparent
# (the rocks above the horizon stay: they are grey-brown, the sky is blue). The old plate is games/wilson/art/plate_old.webp.
def wide_plate():
    im = Image.open(SRC + "island wide.jpg").convert("RGB")
    s = 768 / im.height
    im = im.resize((round(im.width * s), 768), Image.LANCZOS)
    a = np.asarray(im).astype(np.int32)
    h, w, _ = a.shape
    hor = 324
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    sky = (b - r > 14) & (np.arange(h)[:, None] < hor)
    sky = ndimage.binary_opening(sky, iterations=1)
    al = Image.fromarray(((~sky) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    al = np.asarray(al).copy()
    al[hor:] = 255
    out = np.dstack([a.astype(np.uint8), al])
    os.makedirs(OUT, exist_ok=True)
    old = OUT + "plate.webp"
    if os.path.exists(old) and not os.path.exists(OUT + "plate_old.webp"):
        os.replace(old, OUT + "plate_old.webp")
    Image.fromarray(out, "RGBA").save(OUT + "plate.webp", "WEBP", quality=88, method=6)
    sand = (r > 200) & (b < 160) & (r - b > 55)
    np.save(os.path.expanduser("~/wilson_sand.npy"), sand)
    print("plate", w, h)


wide_plate()


# ---- 2026-11-10 later: palm2.jpg (a leaning palm = palm_E, a young palm = palm_F) and bamboo.jpg (clump + 3 items).
# The checkerboard here is dark grey: min_v 80. cut() prints the sprite size; the foot of the trunk is measured below.
def foot(path):
    im = Image.open(OUT + path).convert("RGBA")
    a = np.asarray(im)
    ys, xs = np.nonzero(a[..., 3] > 128)
    low = ys > ys.max() - 6
    return im.size, int(xs[low].mean()), int(ys.max())


cut("palm2.jpg", (60, 60, 800, 720), "palm_E", 320, min_v=80, max_sat=12, inner=True)
cut("palm2.jpg", (820, 260, 1140, 720), "palm_F", 200, min_v=80, max_sat=12, inner=True)
for n in ("palm_E", "palm_F"):
    print(n, foot(n + ".webp"))
cut("bamboo.jpg", (150, 30, 760, 740), "camp/bamboo_clump", 260, min_v=120, max_sat=12, inner=True)
cut("bamboo.jpg", (960, 30, 1230, 370), "icons/bamboo", 128, min_v=120, max_sat=12, inner=True)
cut("bamboo.jpg", (900, 300, 1240, 550), "icons/bamboo_pole", 128, min_v=120, max_sat=12, inner=True)
cut("bamboo.jpg", (890, 530, 1250, 740), "icons/bamboo_bundle", 128, min_v=120, max_sat=12, inner=True)


# ---- 2026-11-11: fixes. (1) palm_C / palm_D (cut out of the old plate) have a hole in the crown and a ragged
# cut trunk foot: the hole is filled with the nearest leaf colour and a grass tuft (palm_grass, from the small
# palm's foot in palm2.jpg, trunk removed) is drawn over every foot in the game.
def fix_palms():
    for n in ("palm_C", "palm_D"):
        p = OUT + n + ".webp"
        im = Image.open(p).convert("RGBA")
        a = np.asarray(im).copy()
        solid = a[..., 3] > 128
        filled = ndimage.binary_fill_holes(solid)
        hole = filled & ~solid
        if hole.any():
            idx = ndimage.distance_transform_edt(~solid, return_distances=False, return_indices=True)
            a[hole] = a[idx[0][hole], idx[1][hole]]
            a[hole, 3] = 255
            Image.fromarray(a, "RGBA").save(p, "WEBP", quality=90, method=6)
        print(n, "hole px", int(hole.sum()))


def palm_grass():
    im = Image.open(SRC + "palm2.jpg").convert("RGB")
    a = np.asarray(im.crop((915, 630, 1050, 690))).astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    sat = a.max(-1) - a.min(-1)
    bgp = (a.min(-1) >= 80) & (sat <= 14)
    lab, n = ndimage.label(bgp)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    fg = ~np.isin(lab, list(edge)) & ~bgp
    brown = (r > g + 8) & (r > b + 20)
    fg &= ~brown
    fg = ndimage.binary_opening(fg, iterations=1)
    ys, xs = np.nonzero(fg)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    al = Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
    img = Image.fromarray(np.dstack([a.clip(0, 255).astype(np.uint8), np.asarray(al)]), "RGBA").crop(box)
    img = img.resize((round(img.width * 1.1), round(img.height * 1.1)), Image.LANCZOS)
    img.save(OUT + "palm_grass.webp", "WEBP", quality=90, method=6)
    print("palm_grass", img.size)


fix_palms()
palm_grass()
