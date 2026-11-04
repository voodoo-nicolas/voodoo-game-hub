"""Turned: build the painted street from the owner's three pictures (ST-01..03) and cut out the things
people walk behind (trees, lamp posts, the stall, the carriage) as transparent PNGs.

    python tools/turned_street_cuts.py

Reads reference/art/turned/gen/ST-01.jpg .. ST-03.jpg (1264 x 848 each, a black frame and a grey margin).
Writes:
  games/turned/art/rooms/street.webp           the three pictures joined (frames cut away at the joins, 24 px
                                                 blended), the frame and margin round the whole, WebP q88
  games/turned/art/street/<name>.png           cut-outs, cropped to their box (turned_area.gd _build_street
                                                 places them at the same box, y-sorted by their base)
Coordinates below are PANEL pixels (k = 0, 1, 2 for ST-01..03), the same as turned_area.gd `_sp` / `_sr`:
joined x = x - 4 + 1120 k, joined y = y - 3.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, "reference", "art", "turned", "gen")
OUT_BG = os.path.join(ROOT, "games", "turned", "art", "rooms", "street.webp")
OUT_CUT = os.path.join(ROOT, "games", "turned", "art", "street")

X0, X1, Y0, Y1 = 60, 1204, 44, 804     # the picture inside the frame
OV = 24                                # px blended at each join
STEP = (X1 - X0) - OV                  # 1120: one panel further along
MX, MT, MB = 56, 41, 44                # margin round the joined picture

# name, panel, box (x, y, w, h), kind, extras
CUTS = [
    ("tree_w", 0, (8, 468, 236, 334), "tree", {"trunk": (100, 670, 45, 132)}),
    ("tree_mid", 1, (645, 466, 240, 336), "tree", {"trunk": (745, 670, 45, 132)}),
    ("tree_e", 2, (922, 466, 254, 336), "tree", {"trunk": (1035, 680, 45, 122)}),
    ("lamp_far0", 0, (210, 252, 48, 226), "lamp", {"head": (218, 252, 32, 56)}),
    ("lamp_far1", 1, (210, 252, 48, 226), "lamp", {"head": (218, 252, 32, 56)}),
    ("lamp_far2", 2, (210, 252, 48, 226), "lamp", {"head": (218, 252, 32, 56)}),
    ("lamp_near0", 0, (982, 494, 50, 228), "lamp", {"head": (990, 494, 34, 56)}),
    ("lamp_near1", 1, (86, 494, 50, 228), "lamp", {"head": (94, 494, 34, 56)}),
    ("lamp_near2", 1, (982, 494, 50, 228), "lamp", {"head": (990, 494, 34, 56)}),
    ("lamp_near3", 2, (86, 494, 50, 228), "lamp", {"head": (94, 494, 34, 56)}),
    ("stall", 1, (200, 562, 176, 198), "poly", {
        "polys": [[(204, 648), (212, 568), (366, 566), (373, 648)], [(214, 664), (360, 664), (360, 702), (214, 702)],
                  [(210, 640), (221, 640), (221, 758), (210, 758)], [(347, 640), (358, 640), (358, 758), (347, 758)]]}),
    ("carriage", 2, (158, 476, 458, 220), "poly", {
        "polys": [[(200, 500), (214, 485), (346, 481), (358, 520), (416, 543), (422, 602), (360, 612), (250, 614), (198, 600)],
                  # the horse (gaps between the legs left out)
                  [(422, 575), (445, 562), (500, 565), (530, 553), (558, 520), (580, 510), (597, 517), (614, 545),
                   (602, 562), (576, 557), (562, 590), (556, 632), (553, 682), (539, 682), (536, 640), (526, 640),
                   (523, 682), (509, 682), (511, 630), (481, 628), (477, 682), (461, 682), (459, 641), (449, 646),
                   (449, 682), (433, 682), (429, 632), (420, 612)],
                  [(392, 594), (470, 592), (470, 604), (392, 606)]],          # the shafts
        "discs": [(208, 645, 47), (372, 650, 42)]}),                          # the wheels: their dark rim and spokes
]


def join() -> Image.Image:
    ims = [Image.open(os.path.join(GEN, "ST-0%d.jpg" % i)).convert("RGB") for i in (1, 2, 3)]
    parts = [np.asarray(im.crop((X0, Y0, X1, Y1))).astype(np.float32) for im in ims]
    h, w = parts[0].shape[:2]
    strip = np.zeros((h, w * 3 - OV * 2, 3), np.float32)
    strip[:, :w] = parts[0]
    a = np.linspace(0.0, 1.0, OV)[None, :, None]
    for k, p in enumerate(parts[1:], 1):
        x = k * STEP
        seam = strip[:, x:x + OV] * (1.0 - a) + p[:, :OV] * a
        strip[:, x:x + w] = p
        strip[:, x:x + OV] = seam
    grey = ims[0].getpixel((20, 400))
    out = Image.new("RGB", (strip.shape[1] + MX * 2, h + MT + MB), grey)
    ImageDraw.Draw(out).rectangle((MX - 4, MT - 4, MX + strip.shape[1] + 3, MT + h + 3), fill=(20, 20, 20))
    out.paste(Image.fromarray(strip.clip(0, 255).astype(np.uint8)), (MX, MT))
    return out


def jx(k: int, x: float) -> int:
    return int(round(x - 4 + STEP * k))


def jy(y: float) -> int:
    return int(round(y - 3))


def rect_mask(shape, box, k, x0, y0):
    m = np.zeros(shape, bool)
    bx, by, bw, bh = box
    xa, ya = jx(k, bx) - x0, jy(by) - y0
    m[max(ya, 0):max(ya + bh, 0), max(xa, 0):max(xa + bw, 0)] = True
    return m


def cut(full: Image.Image, name, k, box, kind, ex) -> None:
    bx, by, bw, bh = box
    x0, y0 = jx(k, bx), jy(by)
    rgb = np.asarray(full.crop((x0, y0, x0 + bw, y0 + bh))).astype(np.float32) / 255.0
    mx, mn = rgb.max(2), rgb.min(2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    shape = lum.shape
    if kind == "tree":
        green = (sat > 0.16) & (rgb[..., 1] >= rgb[..., 2])
        m = ndimage.binary_opening(green, iterations=1)
        m = ndimage.binary_closing(m, iterations=4)
        m = ndimage.binary_fill_holes(m)
        m = ndimage.binary_dilation(m, iterations=2)        # keep the dark outline
        m |= rect_mask(shape, ex["trunk"], k, x0, y0) & (lum < 0.55)
    elif kind == "lamp":
        # drawn by hand: the head (glass and cap), a thin post down the middle, a wider foot
        m = rect_mask(shape, ex["head"], k, x0, y0)
        hx, hy, hw, hh = ex["head"]
        cx = jx(k, hx + hw / 2.0) - x0
        top = jy(hy + hh) - y0
        m[top:shape[0] - 26, cx - 4:cx + 5] = True
        m[shape[0] - 26:shape[0] - 4, cx - 9:cx + 10] = True
        m[top - 6:top + 8, cx - 16:cx + 17] |= lum[top - 6:top + 8, cx - 16:cx + 17] < 0.3   # the cross arm
    elif kind == "poly":
        img = Image.new("L", (shape[1], shape[0]), 0)
        d = ImageDraw.Draw(img)
        for poly in ex["polys"]:
            d.polygon([(jx(k, x) - x0, jy(y) - y0) for x, y in poly], fill=255)
        m = np.asarray(img) > 0
        yy, xx = np.mgrid[0:shape[0], 0:shape[1]]
        for cx, cy, r in ex.get("discs", []):
            disc = (xx - (jx(k, cx) - x0)) ** 2 + (yy - (jy(cy) - y0)) ** 2 <= r * r
            m |= disc & (lum < 0.28)
        m = ndimage.binary_closing(m, iterations=1)
    else:
        # the thing's own colours (black paint, brown horse and wood, the striped canvas), not the grey cobbles
        m = (lum < 0.15) | ((sat > 0.28) & (lum < 0.85)) | ((sat > 0.12) & (lum > 0.55))
        m = ndimage.binary_opening(m, iterations=1)
        for f in ex.get("fill", []):
            m |= rect_mask(shape, f, k, x0, y0)
        lab, n = ndimage.label(ndimage.binary_dilation(m, iterations=1))
        if n:
            sizes = ndimage.sum(m, lab, range(1, n + 1))
            keep = [i + 1 for i, s in enumerate(sizes) if s > 300]
            m &= np.isin(lab, keep)
        m = ndimage.binary_closing(m, iterations=2)
        m = ndimage.binary_dilation(m, iterations=1)
    alpha = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    pic = full.crop((x0, y0, x0 + bw, y0 + bh)).convert("RGBA")
    pic.putalpha(alpha)
    pic.save(os.path.join(OUT_CUT, name + ".png"), optimize=True)
    print("  %-11s joined box %d,%d %dx%d" % (name, x0, y0, bw, bh))


def main() -> None:
    full = join()
    full.save(OUT_BG, quality=88, method=6)
    print("street.webp", full.size)
    os.makedirs(OUT_CUT, exist_ok=True)
    for c in CUTS:
        cut(full, *c)


if __name__ == "__main__":
    main()
