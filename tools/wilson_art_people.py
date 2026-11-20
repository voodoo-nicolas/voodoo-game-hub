"""Beached: the castaways' action pictures from the owner's People folder (2026-11-20, D:/Dev/Wilson/People/People)
-> games/wilson/art/chars/<look>_job_<job>_<n>.webp. These are the frames a running action / pastime cycles
(wilson_castaway.gd `job_frames`, JOB_ALIAS). Run: python tools/wilson_art_people.py   (then Godot --import)

- magenta sheets (male1 / male3 / male4 / female1): one hand-measured box per figure (BOXES);
- transparent sheets (female4 / female3): figures found by alpha, named in reading order (AUTO);
- the blonde (female5): one picture per action (BLONDE).
Every frame is scaled to the height its job should have on screen (H), because the sheets draw the figures at
very different sizes. `python tools/wilson_art_people.py preview` writes numbered contact sheets to the folder
in WILSON_PREVIEW (that is how the boxes / names were checked)."""
import os
import sys
import numpy as np
from PIL import Image, ImageFilter, ImageDraw
from scipy import ndimage
SRC = "D:/Dev/Wilson/People/People/"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "games", "wilson", "art", "chars") + "/"

def _key(a, alpha):
    if alpha is not None:
        return alpha > 40
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, axis=0)
    d = np.sqrt(((a.astype(np.float32) - bg) ** 2).sum(-1))
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    mag = (r - g > 60) & (b - g > 30)
    near = (d < 70) | (mag & (d < 120))
    lab, n = ndimage.label(near)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    return ~(np.isin(lab, list(edge)) | (d < 45))

def load(src):
    im = Image.open(SRC + src)
    a = np.asarray(im.convert("RGB"))
    alpha = None
    if im.mode in ("RGBA", "LA", "P"):
        alpha = np.asarray(im.convert("RGBA"))[..., 3]
        if alpha.min() > 200:
            alpha = None          # an opaque PNG
    fg = ndimage.binary_opening(_key(a, alpha), iterations=1)
    eb = ndimage.binary_dilation(~fg, iterations=3)
    return a, fg, eb

def figures(fg, merge=5, min_area=3000):
    lab, n = ndimage.label(ndimage.binary_dilation(fg, iterations=merge))
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if sl is None:
            continue
        m = (lab == i + 1) & fg
        if m.sum() < min_area * (fg.shape[0] / 1024.0) ** 2:
            continue
        out.append((m, sl))
    h = fg.shape[0]
    out.sort(key=lambda f: (int((f[1][0].start + f[1][0].stop) / 2 / (h / 5.0)), f[1][1].start))
    return out

def save(a, eb, mask, name, scale):
    ys, xs = np.nonzero(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    sub = a[y0:y1, x0:x1].astype(np.int32).copy()
    mk = mask[y0:y1, x0:x1]
    e = eb[y0:y1, x0:x1]
    r, g, b = sub[..., 0], sub[..., 1], sub[..., 2]
    spill = np.clip(np.minimum(r, b) - g - 25, 0, None) * e
    sub[..., 0] = r - (spill * 0.85).astype(np.int32)
    sub[..., 2] = b - (spill * 0.85).astype(np.int32)
    al = Image.fromarray((mk * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
    img = Image.fromarray(np.dstack([np.clip(sub, 0, 255).astype(np.uint8), np.asarray(al)]), "RGBA")
    img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    pad = Image.new("RGBA", (img.width + 8, img.height + 8), (0, 0, 0, 0))
    pad.alpha_composite(img, (4, 4))
    pad.save(OUT + name + ".webp", "WEBP", quality=88, method=6)

# Height of each job's frame in output pixels (a standing castaway on the 19-pose sheets is ~160).
H = {"splash": 160, "seawater": 118, "spear": 170, "fish": 165, "skip_stone": 128, "search_sand": 138, "dig": 112,
     "shake": 165, "haul": 150, "fan_fire": 104, "roast": 104, "catch_crab": 100, "tally": 104, "carve": 104,
     "sandcastle": 108, "peek": 162, "yoga": 190, "rest": 62, "drum": 108, "swim": 72, "float": 48}

def save_h(a, eb, mask, name, job):
    ys = np.nonzero(mask)[0]
    save(a, eb, mask, name, H[job] / float(ys.max() - ys.min() + 1))

# Magenta sheets: one box per figure (source pixels, measured on the numbered previews). [job, (x0, y0, x1, y1)]
BOXES = {
    "male1": ("Male White/IMG_3032.JPG", [
        ("splash", (10, 15, 200, 270)), ("seawater", (200, 60, 345, 270)), ("spear", (345, 15, 520, 270)), ("spear", (520, 30, 700, 270)),
        ("fish", (700, 10, 830, 270)), ("skip_stone", (830, 70, 1010, 270)), ("search_sand", (30, 310, 180, 512)), ("dig", (193, 318, 370, 512)),
        ("shake", (382, 280, 545, 515)), ("haul", (540, 290, 730, 512)), ("fan_fire", (732, 340, 875, 512)), ("roast", (875, 340, 1015, 512)),
        ("yoga", (240, 520, 337, 832)), ("catch_crab", (420, 535, 627, 690)), ("peek", (663, 565, 790, 832)), ("tally", (808, 520, 1002, 695)),
        ("sandcastle", (20, 603, 222, 810)), ("rest", (367, 697, 650, 815)), ("drum", (833, 695, 963, 875)), ("swim", (40, 868, 350, 998)),
        ("swim", (397, 856, 665, 1008)), ("float", (698, 902, 1002, 1015))]),
    "male3": ("Male Brown/IMG_3034.JPG", [
        ("splash", (15, 20, 195, 272)), ("seawater", (195, 60, 345, 272)), ("spear", (345, 20, 520, 272)), ("spear", (520, 30, 700, 272)),
        ("fish", (710, 15, 850, 278)), ("skip_stone", (852, 75, 1010, 278)), ("search_sand", (30, 313, 186, 517)), ("dig", (195, 330, 378, 520)),
        ("shake", (395, 282, 525, 525)), ("haul", (525, 290, 703, 520)), ("fan_fire", (709, 355, 860, 522)), ("roast", (862, 345, 1014, 520)),
        ("sandcastle", (15, 548, 195, 732)), ("catch_crab", (260, 555, 443, 715)), ("carve", (470, 536, 638, 720)), ("peek", (670, 543, 810, 863)),
        ("tally", (826, 546, 1010, 725)), ("rest", (347, 731, 638, 855)), ("drum", (30, 803, 156, 1000)), ("yoga", (192, 695, 275, 1015)),
        ("swim", (287, 885, 480, 1003)), ("swim", (495, 883, 685, 1020)), ("float", (690, 912, 1012, 1012))]),
    "male4": ("Male Black/IMG_3036.JPG", [
        ("splash", (15, 25, 180, 262)), ("seawater", (180, 60, 345, 262)), ("spear", (352, 22, 520, 262)), ("spear", (520, 30, 695, 262)),
        ("fish", (705, 10, 830, 268)), ("skip_stone", (832, 65, 1012, 270)), ("search_sand", (27, 297, 172, 504)), ("dig", (172, 313, 347, 512)),
        ("shake", (357, 267, 512, 515)), ("haul", (512, 280, 682, 510)), ("fan_fire", (689, 340, 849, 505)), ("roast", (832, 320, 1009, 500)),
        ("sandcastle", (14, 521, 207, 700)), ("carve", (220, 520, 342, 698)), ("catch_crab", (640, 537, 817, 705)), ("tally", (826, 520, 1010, 703)),
        ("peek", (25, 720, 151, 1012)), ("yoga", (187, 688, 269, 1015)), ("rest", (307, 712, 575, 826)), ("swim", (758, 737, 992, 838)),
        ("drum", (311, 842, 434, 1000)), ("swim", (467, 851, 696, 987)), ("float", (711, 876, 1004, 1010))]),
    "female1": ("Brunette Female/IMG_3030.JPG", [
        ("splash", (10, 30, 190, 255)), ("seawater", (190, 60, 330, 255)), ("spear", (330, 30, 490, 255)), ("spear", (490, 60, 655, 255)),
        ("fish", (655, 25, 800, 255)), ("skip_stone", (800, 80, 980, 255)), ("search_sand", (42, 285, 173, 469)), ("dig", (192, 308, 353, 468)),
        ("shake", (386, 263, 504, 470)), ("haul", (517, 274, 686, 463)), ("roast", (40, 492, 210, 643)), ("roast", (244, 485, 414, 640)),
        ("fan_fire", (438, 488, 590, 640)), ("catch_crab", (622, 502, 783, 648)), ("tally", (805, 483, 964, 652)), ("sandcastle", (28, 671, 190, 843)),
        ("rest", (333, 686, 621, 808)), ("swim", (648, 688, 978, 788)), ("swim", (648, 824, 978, 913)), ("drum", (32, 862, 167, 1040)),
        ("yoga", (208, 663, 296, 1048)), ("peek", (332, 799, 440, 1048)), ("float", (659, 947, 975, 1040))]),
}
# Transparent sheets: figures found by alpha, named in reading order ("+" = part of the figure before: her crab).
AUTO = {
    "female4": ("Black Female/Black female 22 pose transparent sprite sheet.png", 5, [
        "splash", "swim", "swim", "float", "seawater", "spear", "spear", "fish", "search_sand", "skip_stone", "dig", "shake",
        "haul", "roast", "fan_fire", "catch_crab", "+", "tally", "sandcastle", "yoga", "rest", "peek", "drum"]),
    "female3": ("Redhead Female/22 pose spread transparent.png", 12, [
        "splash", "swim", "swim", "float", "seawater", "spear", "spear", "fish", "skip_stone", "search_sand", "dig", "shake",
        "haul", "roast", "fan_fire", "catch_crab", "tally", "sandcastle", "yoga", "rest", "peek", "drum"]),
}
# The blonde: one picture each. [file, job]
BLONDE = [
    ("IMG_3002.JPG", "splash"), ("IMG_3003.JPG", "swim"), ("IMG_3004.JPG", "float"), ("IMG_3005.JPG", "seawater"),
    ("IMG_3006.JPG", "spear"), ("IMG_3007.PNG", "spear"), ("IMG_3008.PNG", "spear"), ("IMG_3010.PNG", "fish"),
    ("IMG_3011.PNG", "skip_stone"), ("IMG_3012.PNG", "search_sand"), ("IMG_3013.PNG", "dig"), ("IMG_3014.PNG", "shake"),
    ("IMG_3015.PNG", "haul"), ("IMG_3016.PNG", "fan_fire"), ("IMG_3017.PNG", "roast"), ("IMG_3020.PNG", "catch_crab"),
    ("IMG_3021.PNG", "tally"), ("IMG_3023.PNG", "sandcastle"), ("IMG_3025.PNG", "yoga"), ("IMG_3026.JPG", "rest"),
    ("IMG_3027.JPG", "peek"),
]

def boxed(fg, box):
    """The figure inside a box: its big pieces (a neighbour's arm or the water strip poking in stay small or clipped)."""
    x0, y0, x1, y1 = box
    sub = fg[y0:y1, x0:x1]
    lab, n = ndimage.label(ndimage.binary_dilation(sub, iterations=2))
    if n == 0:
        return None
    sizes = ndimage.sum(sub, lab, range(1, n + 1))
    keep = [i + 1 for i, sz in enumerate(sizes) if sz >= 0.15 * sizes.max()]
    m = np.zeros_like(fg)
    m[y0:y1, x0:x1] = np.isin(lab, keep) & sub
    return m

def build():
    for look, (src, boxes) in BOXES.items():
        a, fg, eb = load(src)
        count = {}
        for job, box in boxes:
            m = boxed(fg, box)
            if m is None or m.sum() < 500:
                print("  MISSING", look, job, box)
                continue
            count[job] = count.get(job, 0) + 1
            save_h(a, eb, m, "%s_job_%s_%d" % (look, job, count[job]), job)
        print(look, sum(count.values()), "frames")
    for look, (src, merge, names) in AUTO.items():
        a, fg, eb = load(src)
        figs = figures(fg, merge)
        if len(figs) != len(names):
            print("  COUNT", look, len(figs), "figures for", len(names), "names")
        parts = []
        for (m, sl), job in zip(figs, names):
            if job == "+":
                parts[-1][1] = parts[-1][1] | m
            else:
                parts.append([job, m])
        count = {}
        for job, m in parts:
            count[job] = count.get(job, 0) + 1
            save_h(a, eb, m, "%s_job_%s_%d" % (look, job, count[job]), job)
        print(look, sum(count.values()), "frames")
    count = {}
    for f, job in BLONDE:
        a, fg, eb = load("Blonde Female/" + f)
        figs = figures(fg, 8)
        if not figs:
            print("  MISSING", f)
            continue
        m = np.logical_or.reduce([fm for fm, sl in figs])
        count[job] = count.get(job, 0) + 1
        save_h(a, eb, m, "female5_job_%s_%d" % (job, count[job]), job)
    print("female5", sum(count.values()), "frames")

def preview(dst):
    os.makedirs(dst, exist_ok=True)
    for look, (src, merge, names) in AUTO.items():
        a, fg, eb = load(src)
        im = Image.fromarray(a).convert("RGB")
        d = ImageDraw.Draw(im)
        for i, (m, sl) in enumerate(figures(fg, merge)):
            d.rectangle((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop), outline=(255, 255, 0), width=max(2, a.shape[0] // 300))
            d.text((sl[1].start + 4, sl[0].start + 2), str(i), fill=(255, 255, 0), font_size=max(18, a.shape[0] // 25))
        im.thumbnail((1400, 1400))
        im.save(os.path.join(dst, look + ".png"))
    for look, (src, boxes) in BOXES.items():
        im = Image.open(SRC + src).convert("RGB")
        d = ImageDraw.Draw(im)
        for i, (job, b) in enumerate(boxes):
            d.rectangle(b, outline=(255, 255, 0), width=3)
            d.text((b[0] + 4, b[1] + 2), job, fill=(255, 255, 0), font_size=20)
        im.save(os.path.join(dst, look + ".png"))

if __name__ == "__main__":
    if "preview" in sys.argv:
        preview(os.environ.get("WILSON_PREVIEW", "."))
    else:
        build()
