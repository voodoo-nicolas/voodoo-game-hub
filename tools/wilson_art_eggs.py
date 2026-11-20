"""Beached easter eggs (owner, 2026-11-20): cuts the special sheets in D:/dev/Wilson into
games/wilson/art/chars/. Run: python tools/wilson_art_eggs.py   (then Godot --import).

- special1.jpg: Nicolas, the 19-pose sheet (same layout as male1) -> nicolas_<pose>.webp
- special2.jpg: Nicolas's action poses -> nicolas_job_<job>_<n>.webp (frames of an odd job / action)
- heather1/2/3.jpg, Emilia.jpg, blondecry.jpg (white backgrounds) -> job_egg_<id>_<n>.webp
  (the blonde female5's secret odd jobs when she is named Heather or Emilia)

Each figure is found automatically (background keyed from the border colour, blobs merged with a small
dilation so loose hair stays with its head), sorted in reading order, and scaled so the head size
matches the regular sheets (`scale`)."""
import os
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
SRC = "D:/dev/Wilson/"
OUT = "C:/Users/nick_/code/voodoo-game-hub/games/wilson/art/chars/"

def _key(a):
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, axis=0)
    d = np.sqrt(((a.astype(np.float32) - bg) ** 2).sum(-1))
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    mag = (r - g > 60) & (b - g > 30)
    near = (d < 70) | (mag & (d < 120))
    lab, n = ndimage.label(near)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    return ~(np.isin(lab, list(edge)) | (d < 45))

def figures(src, min_area=4000, merge=6, row_h=150):
    """[(mask, bbox)] of every figure in reading order (rows of `row_h` source pixels)."""
    a = np.asarray(Image.open(SRC + src).convert("RGB"))
    fg = ndimage.binary_opening(_key(a), iterations=1)
    lab, n = ndimage.label(ndimage.binary_dilation(fg, iterations=merge))
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if sl is None:
            continue
        m = (lab == i + 1) & fg
        if m.sum() < min_area:
            continue
        out.append((m, sl))
    out.sort(key=lambda f: (round(f[1][0].stop / row_h), f[1][1].start))
    return a, fg, out

def save(a, fg, mask, name, scale):
    edge_band = ndimage.binary_dilation(~fg, iterations=3)
    ys, xs = np.nonzero(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    sub = a[y0:y1, x0:x1].astype(np.int32).copy()
    mk = mask[y0:y1, x0:x1]
    eb = edge_band[y0:y1, x0:x1]
    r, g, b = sub[..., 0], sub[..., 1], sub[..., 2]
    spill = np.clip(np.minimum(r, b) - g - 25, 0, None) * eb
    sub[..., 0] = r - (spill * 0.85).astype(np.int32)
    sub[..., 2] = b - (spill * 0.85).astype(np.int32)
    al = Image.fromarray((mk * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
    img = Image.fromarray(np.dstack([np.clip(sub, 0, 255).astype(np.uint8), np.asarray(al)]), "RGBA")
    img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    pad = Image.new("RGBA", (img.width + 8, img.height + 8), (0, 0, 0, 0))
    pad.alpha_composite(img, (4, 4))
    pad.save(OUT + name + ".webp", "WEBP", quality=88, method=6)
    print(name, pad.size)

# The 19-pose layout (anchors from male1, tools/wilson_art.py POSES).
POSES = {
    "idle": (96, 205), "walk1": (235, 203), "walk2": (368, 204), "walk3": (500, 203), "walk4": (640, 203),
    "run": (843, 215), "sit": (110, 504), "sleep": (383, 482), "hammock": (761, 456), "fish": (400, 640),
    "chop": (666, 625), "craft": (887, 643), "eat": (94, 890), "drink": (240, 890), "shrug": (370, 890),
    "wave": (514, 881), "facepalm": (650, 890), "sulk": (886, 832), "collapse": (830, 1010),
}

def nicolas_sheet():
    a, fg, figs = figures("special1.jpg", min_area=2500, merge=3)
    pts = np.array(list(POSES.values()), dtype=np.float32)
    names = list(POSES)
    owner = {}
    for m, sl in figs:
        cy, cx = ndimage.center_of_mass(m)
        k = int(np.argmin(((pts - np.array([cx, cy])) ** 2).sum(-1)))
        owner.setdefault(names[k], []).append(m)
    for name in names:
        if name not in owner:
            print("  MISSING nicolas", name)
            continue
        save(a, fg, np.logical_or.reduce(owner[name]), "nicolas_" + name, 0.5)

def cut_boxes(src, boxes, prefix, scale, min_area=300):
    """Crowded sheets: one hand-measured box (source pixels) per figure; blobs centred inside the box,
    clipped to it (the water strip under the wading poses joins them otherwise)."""
    a = np.asarray(Image.open(SRC + src).convert("RGB"))
    fg = ndimage.binary_opening(_key(a), iterations=1)
    lab, n = ndimage.label(fg)
    objs = ndimage.find_objects(lab)
    for name, (x0, y0, x1, y1) in boxes.items():
        box = np.zeros_like(fg)
        box[y0:y1, x0:x1] = True
        ids = []
        for i, sl in enumerate(objs):
            if sl is None:
                continue
            m = (lab[sl] == i + 1) & box[sl]
            if m.sum() < min_area:
                continue
            cy, cx = ndimage.center_of_mass(lab[sl] == i + 1)      # a neighbour's arm poking in: skip
            if not (x0 <= sl[1].start + cx < x1 and y0 <= sl[0].start + cy < y1):
                continue
            ids.append(i + 1)
        if not ids:
            print("  MISSING", src, name)
            continue
        save(a, fg, np.isin(lab, ids) & box, prefix + name, scale)

# special2.jpg (1024x1024): Nicolas's actions, one box each (job ids = the game's action / pastime ids).
NIC_JOBS = {
    "splash_1": (20, 35, 200, 275), "seawater_1": (200, 80, 345, 275), "spear_1": (345, 20, 520, 275),
    "spear_2": (520, 30, 700, 275), "fish_1": (700, 15, 925, 280), "skip_stone_1": (850, 70, 1015, 285),
    "search_sand_1": (25, 305, 190, 515), "dig_1": (195, 325, 380, 525), "shake_1": (390, 275, 530, 525),
    "haul_1": (520, 285, 705, 525), "fan_fire_1": (705, 350, 870, 525), "roast_1": (865, 340, 1015, 525),
    "sandcastle_1": (20, 550, 215, 735), "catch_crab_1": (255, 550, 420, 720), "tally_1": (465, 530, 645, 720),
    "peek_1": (665, 540, 815, 865), "carve_1": (825, 540, 1015, 725), "drum_1": (25, 795, 165, 1000),
    "yoga_1": (185, 690, 280, 1018), "rest_1": (335, 725, 645, 855), "swim_1": (280, 875, 485, 1012),
    "swim_2": (485, 875, 690, 1012), "float_1": (690, 905, 1015, 1012)}

def nicolas_jobs():
    cut_boxes("special2.jpg", NIC_JOBS, "nicolas_job_", 0.5)

# The blonde's secret jobs: [source, job id, scale]. Scales put her head at the size of the sheets' heads.
EGGS = [("heather1.jpg", "egg_freak", 0.13), ("heather2.jpg", "egg_hair", 0.13), ("blondecry.jpg", "egg_cry", 0.25)]

def eggs():
    cut_boxes("heather3.jpg", {"egg_soothe_%d" % (i + 1): b for i, b in enumerate([
        (25, 470, 250, 840), (250, 470, 435, 840), (435, 470, 620, 840), (620, 470, 805, 840),
        (805, 470, 980, 840), (980, 470, 1190, 840)])}, "job_", 0.32)
    cut_boxes("Emilia.jpg", {"egg_drink_%d" % (i + 1): b for i, b in enumerate([
        (15, 430, 340, 745), (330, 560, 690, 725), (675, 340, 840, 735), (840, 340, 1030, 735),
        (1010, 365, 1165, 735), (1165, 330, 1365, 735)])}, "job_", 0.4)
    for src, job, sc in EGGS:
        a, fg, figs = figures(src, min_area=4000, merge=8, row_h=300)
        for i, (m, sl) in enumerate(figs):
            save(a, fg, m, "job_%s_%d" % (job, i + 1), sc)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    nicolas_sheet()
    nicolas_jobs()
    eggs()
