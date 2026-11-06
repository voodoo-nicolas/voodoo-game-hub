"""Turned: build a painted walk (the harbour, the night road) from the owner's pictures, joined left to right,
and cut out the things people walk behind (lamp posts, crates, trees, the gate post...) as transparent PNGs.
The street has its own tool (tools/turned_street_cuts.py); this one takes any crop of each picture.

    python tools/turned_walk_join.py [harbor|night_road] [--grid OUT_DIR]

Reads reference/art/turned/gen/<picture>.jpg (1264 x 848 each, a black frame and a grey margin).
Writes:
  scripts/games/turned/turned_walks.json      the panel table, the cut-outs' boxes and the margin grey for turned_area.gd
  games/turned/art/rooms/<area>.webp         the panels joined (each shows picture columns [x_from, x_to),
                                               blended over `blend` px into the next), the frame and the
                                               margin round the whole, WebP q88
  games/turned/art/<area>/<name>.png         cut-outs, cropped to their box FROM THE PANEL'S OWN PICTURE (so a
                                               thing near a join is whole), placed by turned_area.gd at the same
                                               box and y-sorted by their base
  --grid DIR                                 also writes the joined picture with a grid of panel coordinates
                                               (for tracing the walk map)
Coordinates are PANEL pixels (the picture's own x, y; panel k as listed in WALKS), the same as turned_area.gd
`_wp` / `_wr`: joined x = MX + off_k + (x - x_from_k), joined y = y - Y0 + MT, where off_0 = 0 and
off_k+1 = off_k + (x_to_k - x_from_k) - blend_k (turned_area.gd reads the table from turned_walks.json).
"""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, "reference", "art", "turned", "gen")
ART = os.path.join(ROOT, "games", "turned", "art")

Y0, Y1 = 44, 804                       # the picture inside the frame (top, bottom)
MX, MT, MB = 56, 41, 44                # margin round the joined picture

# area -> panels: (picture, x_from, x_to, blend into the next)
WALKS = {
    # HR-06 (the fish sheds) and HR-07 (the crane, the customs shed) added 2026-11-06 (DECISIONS B-25)
    "harbor": [("HR-01", 60, 1204, 24), ("HR-04", 60, 1204, 24), ("HR-06", 60, 1204, 24), ("HR-07", 60, 1204, 24),
               ("HR-05", 60, 1204, 0)],
    # the forest joins sit between trunks (the leaning tree at each picture's right edge and NR-03's big
    # trunk on its left are left out: blended, two trunks show through each other)
    # NR-08 (the stream, the footbridge) and NR-09 (the wayside shrine) added 2026-11-06 (DECISIONS B-25), their
    # big trunks at both edges left out (x 190..1150)
    "night_road": [("NR-05", 60, 1092, 24), ("NR-06", 60, 1120, 32), ("NR-07", 60, 1130, 96),
                   ("NR-08", 190, 1150, 64), ("NR-09", 190, 1150, 64), ("NR-03", 170, 1030, 64), ("NR-04", 700, 1204, 0)],
}

# area -> cut-outs: (name, panel, kind, extras, base y). The box is extras["box"] (x, y, w, h) or the polygons' bounds.
#   lamp: a post drawn by hand (head box, thin post, foot); poly: polygons (+ "discs": dark-only circles);
#   dark: the dark paint inside the polygons (bare branches against the mist) + "solid" polygons (the trunk)
CRATES = {"polys": [[(378, 619), (405, 610), (432, 603), (451, 578), (465, 568), (495, 571), (495, 600), (522, 601),
                     (522, 657), (512, 660), (475, 662), (450, 676), (425, 666), (405, 666), (378, 654)],
                    [(528, 612), (535, 603), (555, 603), (562, 612), (562, 642), (555, 650), (535, 650), (528, 642)]]}
BARREL = {"polys": [[(876, 612), (884, 600), (912, 600), (920, 612), (920, 645), (912, 657), (884, 657), (876, 645)]]}


def lamp(x):
    """A far-kerb gas lamp at picture x (head 254..306, foot on the kerb at 473)."""
    return {"box": (x - 24, 252, 48, 224), "head": (x - 16, 254, 32, 52)}


def bollard(x):
    return {"polys": [[(x - 7, 598), (x + 7, 598), (x + 8, 645), (x - 8, 645)]]}


CUTS = {
    "harbor": [c for k in (0, 1, 4) for c in (
        ("lamp%da" % k, k, "lamp", lamp(233), 473), ("lamp%db" % k, k, "lamp", lamp(943), 473),
        ("crates%d" % k, k, "poly", CRATES, 671))] + [("barrel4", 4, "poly", BARREL, 657)] + [
        # HR-06, HR-07: two lamps each (the right one at x 993)
        c for k in (2, 3) for c in (("lamp%da" % k, k, "lamp", lamp(233), 473), ("lamp%db" % k, k, "lamp", lamp(993), 473))],
    "night_road": [
        # NR-05: the cigar shop's street (the harbour's, the water filled in)
        ("lamp0a", 0, "lamp", lamp(233), 473), ("lamp0b", 0, "lamp", lamp(943), 473),
        ("lamp0n", 0, "lamp", {"box": (1036, 436, 48, 284), "head": (1044, 438, 32, 64), "foot": 28}, 718),
        ("crates0", 0, "poly", CRATES, 671), ("barrel0", 0, "poly", BARREL, 657),
        ("post0a", 0, "poly", bollard(70), 643), ("post0b", 0, "poly", bollard(205), 643),
        ("post0c", 0, "poly", bollard(340), 643), ("post0d", 0, "poly", bollard(680), 643),
        # NR-06: the last houses, the last lamp, the gate
        ("lamp1a", 1, "lamp", lamp(233), 473),
        ("post1a", 1, "poly", bollard(205), 643), ("post1b", 1, "poly", bollard(340), 643),
        ("post1c", 1, "poly", bollard(510), 643), ("post1d", 1, "poly", bollard(680), 643),
        ("gate", 1, "poly", {"polys": [
            [(828, 418), (858, 418), (866, 450), (882, 458), (882, 497), (873, 500), (873, 688), (890, 698), (890, 708),
             (800, 708), (802, 692), (810, 688), (810, 500), (800, 495), (800, 460), (818, 452)],
            [(853, 545), (870, 545), (903, 640), (906, 700), (860, 700)]]}, 706),
        # NR-07: the forest, the dead tree with the low branch
        ("tree2a", 2, "poly", {"polys": [
            [(205, 800), (225, 700), (240, 650), (250, 560), (265, 480), (285, 420), (305, 320), (315, 220), (350, 220),
             (340, 320), (318, 420), (300, 500), (300, 560), (298, 650), (275, 720), (265, 800)],
            [(255, 560), (240, 522), (200, 482), (160, 422), (148, 380), (160, 378), (176, 420), (216, 470), (258, 508)],
            [(140, 450), (140, 466), (200, 492), (240, 522), (246, 506), (210, 480)],
            [(318, 390), (390, 250), (420, 230), (426, 245), (400, 272), (336, 396)]]}, 800),
        ("tree2b", 2, "poly", {"polys": [
            [(300, 470), (330, 445), (380, 450), (420, 470), (446, 500), (446, 560), (440, 600), (420, 640), (380, 650),
             (330, 640), (300, 600)],
            [(342, 640), (366, 640), (369, 722), (341, 722)]]}, 722),
        ("dead2", 2, "poly", {"polys": [      # the trunk to its fork, the low branch over the path (its twigs left out)
            [(762, 290), (788, 290), (795, 450), (805, 692), (768, 692), (764, 450)],
            [(528, 425), (560, 420), (600, 414), (650, 407), (690, 400), (712, 402), (745, 418), (772, 434),
             (772, 452), (740, 434), (708, 418), (690, 415), (650, 422), (600, 429), (560, 435), (528, 441)]]}, 692),
        # NR-03: the second dead tree (panel 5 since NR-08, NR-09)
        ("dead3", 5, "poly", {"polys": [
            [(848, 395), (878, 395), (895, 560), (910, 688), (843, 688), (850, 560)],
            [(852, 393), (790, 363), (750, 360), (710, 368), (665, 388), (635, 418), (620, 458), (613, 482),
             (625, 484), (632, 460), (646, 428), (672, 401), (712, 381), (750, 374), (788, 377), (850, 410)]]}, 688),
        # NR-04: the stump before the vine house, the leaning tree at the end
        ("stump4", 6, "poly", {"polys": [[(852, 615), (860, 590), (882, 590), (890, 578), (894, 600), (896, 640), (906, 690),
                                          (846, 690)]]}, 690),
        ("tree4", 6, "poly", {"polys": [[(1035, 800), (1100, 800), (1150, 640), (1180, 560), (1204, 470), (1204, 360),
                                         (1185, 360), (1162, 520), (1140, 555), (1120, 540), (1050, 500), (1040, 512),
                                         (1110, 572), (1095, 650)]]}, 800),
    ],
}
LAYOUT = os.path.join(ROOT, "scripts", "games", "turned", "turned_walks.json")


def cut_box(ex) -> tuple:
    if "box" in ex:
        return ex["box"]
    pts = [p for poly in ex["polys"] + ex.get("solid", []) for p in poly]
    x0, y0 = min(p[0] for p in pts) - 2, min(p[1] for p in pts) - 2
    x1, y1 = max(p[0] for p in pts) + 2, max(p[1] for p in pts) + 2
    return (x0, y0, x1 - x0, y1 - y0)


def offsets(panels) -> list:
    off, out = 0, []
    for _, x0, x1, bl in panels:
        out.append(off)
        off += (x1 - x0) - bl
    return out


def load(name: str) -> Image.Image:
    return Image.open(os.path.join(GEN, name + ".jpg")).convert("RGB")


def join(panels) -> Image.Image:
    offs = offsets(panels)
    last = panels[-1]
    w = offs[-1] + last[2] - last[1]
    h = Y1 - Y0
    strip = np.zeros((h, w, 3), np.float32)
    prev_bl = 0
    for (name, x0, x1, bl), off in zip(panels, offs):
        p = np.asarray(load(name).crop((x0, Y0, x1, Y1))).astype(np.float32)
        if prev_bl:
            a = np.linspace(0.0, 1.0, prev_bl)[None, :, None]
            seam = strip[:, off:off + prev_bl] * (1.0 - a) + p[:, :prev_bl] * a
            strip[:, off:off + p.shape[1]] = p
            strip[:, off:off + prev_bl] = seam
        else:
            strip[:, off:off + p.shape[1]] = p
        prev_bl = bl
    grey = load(panels[0][0]).getpixel((20, 400))
    out = Image.new("RGB", (w + MX * 2, h + MT + MB), grey)
    ImageDraw.Draw(out).rectangle((MX - 4, MT - 4, MX + w + 3, MT + h + 3), fill=(20, 20, 20))
    out.paste(Image.fromarray(strip.clip(0, 255).astype(np.uint8)), (MX, MT))
    return out


def grid(img: Image.Image, panels, path: str) -> None:
    """The joined picture with panel coordinates every 50 px (labels every 100), panel k in the label."""
    g = img.copy()
    d = ImageDraw.Draw(g)
    offs = offsets(panels)
    for k, ((name, x0, x1, bl), off) in enumerate(zip(panels, offs)):
        for x in range((x0 // 50 + 1) * 50, x1, 50):
            jx = MX + off + x - x0
            d.line((jx, MT, jx, MT + Y1 - Y0), fill=(255, 0, 0) if x % 100 == 0 else (255, 160, 160), width=1)
            if x % 100 == 0:
                d.text((jx + 2, MT + 2), "%d:%d" % (k, x), fill=(255, 255, 0))
    for y in range(50, 850, 50):
        jy = y - Y0 + MT
        d.line((MX, jy, g.width - MX, jy), fill=(0, 255, 255) if y % 100 == 0 else (120, 200, 200), width=1)
        if y % 100 == 0:
            d.text((2, jy + 2), str(y), fill=(255, 255, 0))
    g.save(path)


def cut(area: str, panels, name, k, kind, ex, base) -> None:
    pic = load(panels[k][0])
    bx, by, bw, bh = cut_box(ex)
    crop = pic.crop((bx, by, bx + bw, by + bh))
    rgb = np.asarray(crop).astype(np.float32) / 255.0
    mx, mn = rgb.max(2), rgb.min(2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    shape = lum.shape

    def polymask(polys):
        img = Image.new("L", (shape[1], shape[0]), 0)
        dr = ImageDraw.Draw(img)
        for poly in polys:
            dr.polygon([(x - bx, y - by) for x, y in poly], fill=255)
        return np.asarray(img) > 0

    if kind == "lamp":
        hx, hy, hw, hh = ex["head"]
        m = np.zeros(shape, bool)
        m[hy - by:hy - by + hh, hx - bx:hx - bx + hw] = True
        cx = int(round(hx + hw / 2.0)) - bx
        top = hy + hh - by
        foot = ex.get("foot", 26)
        m[top:shape[0] - foot, cx - 4:cx + 5] = True
        m[shape[0] - foot:shape[0] - 2, cx - 9:cx + 10] = True
        m[top - 6:top + 8, cx - 16:cx + 17] |= lum[top - 6:top + 8, cx - 16:cx + 17] < 0.3   # the cross arm
    elif kind == "poly":
        m = polymask(ex["polys"])
        yy, xx = np.mgrid[0:shape[0], 0:shape[1]]
        for cx, cy, r in ex.get("discs", []):
            m |= ((xx - (cx - bx)) ** 2 + (yy - (cy - by)) ** 2 <= r * r) & (lum < 0.28)
        m = ndimage.binary_closing(m, iterations=1)
    else:   # "dark": the thing's dark paint inside its polygons (bare trees, branches against lighter mist)
        area_m = polymask(ex["polys"])
        m = area_m & (lum < ex.get("lum", 0.3))
        m = ndimage.binary_closing(m, iterations=2)
        m = ndimage.binary_dilation(m, iterations=1) & area_m
        if ex.get("solid"):
            m |= polymask(ex["solid"])
    alpha = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    out = crop.convert("RGBA")
    out.putalpha(alpha)
    os.makedirs(os.path.join(ART, area), exist_ok=True)
    out.save(os.path.join(ART, area, name + ".png"), optimize=True)
    print("  %-14s panel %d box %d,%d %dx%d" % (name, k, bx, by, bw, bh))


def write_layout() -> None:
    """scripts/games/turned/turned_walks.json: what turned_area.gd needs (the panels, the cut-outs' boxes and bases)."""
    import json
    out = {}
    for area, panels in WALKS.items():
        grey = load(panels[0][0]).getpixel((20, 400))
        out[area] = {"margin": "%02x%02x%02x" % grey, "panels": [list(p) for p in panels],
                     "cuts": [[c[0], c[1]] + list(cut_box(c[3])) + [c[4]] for c in CUTS[area]]}
    with open(LAYOUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("{" + "\n")
        for i, (area, d) in enumerate(out.items()):
            f.write('  "%s": {' % area + "\n" + '    "margin": "%s",' % d["margin"] + "\n")
            f.write('    "panels": %s,' % json.dumps(d["panels"]) + "\n" + '    "cuts": [' + "\n")
            f.write(("," + "\n").join("      " + json.dumps(c) for c in d["cuts"]))
            f.write("\n" + "    ]" + "\n" + "  }" + ("," if i < len(out) - 1 else "") + "\n")
        f.write("}" + "\n")


def main() -> None:
    args = sys.argv[1:]
    grid_dir = None
    if "--grid" in args:
        i = args.index("--grid")
        grid_dir = args[i + 1]
        del args[i:i + 2]
    areas = args or list(WALKS)
    write_layout()
    for area in areas:
        panels = WALKS[area]
        full = join(panels)
        full.save(os.path.join(ART, "rooms", area + ".webp"), quality=88, method=6)
        print(area, full.size, "offsets", offsets(panels))
        if grid_dir:
            grid(full, panels, os.path.join(grid_dir, area + "_grid.png"))
        for c in CUTS[area]:
            cut(area, panels, *c)


if __name__ == "__main__":
    main()
