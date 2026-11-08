"""Beached (wilson) art pipeline: owner pictures in D:/dev/Wilson -> games/wilson/art/.
Run: python tools/wilson_art.py   (then Godot --import). See docs/wilson/DECISIONS.md W-20."""
import sys
from PIL import Image, ImageFilter, ImageDraw
import numpy as np
from collections import deque
SRC = "D:/dev/Wilson/"
OUT = "C:/Users/nick_/code/voodoo-game-hub/games/wilson/art/"

# ---- plate: everything above the horizon that is not palm / rock becomes transparent
im = Image.open(SRC + "5.jpg").convert("RGB")
a = np.asarray(im).astype(np.int32)
H, W, _ = a.shape
r, g, b = a[..., 0], a[..., 1], a[..., 2]
lum = (r * 3 + g * 6 + b) / 10
sat = a.max(-1) - a.min(-1)
HORIZON = 327
foliage = (g > r + 8) & (g - b > 40) & (lum < 215)
trunk = (r > g) & (r - b > 35) & (lum < 200)
rock = (sat < 34) & (lum < 205) & (np.abs(r - b) < 26)
outline = lum < 90
solid = foliage | trunk | rock | outline
solid[HORIZON:] = True
# only what is connected to the island (palms, rocks) survives
h, w = solid.shape
seen = np.zeros_like(solid)
q = deque()
for xv in range(w):
    if solid[HORIZON, xv]:
        seen[HORIZON, xv] = True; q.append((HORIZON, xv))
while q:
    cy, cx = q.popleft()
    for dy, dx in ((1,0),(-1,0),(0,1),(0,-1),(1,1),(-1,-1),(1,-1),(-1,1)):
        ny, nx = cy+dy, cx+dx
        if 0 <= ny < h and 0 <= nx < w and solid[ny, nx] and not seen[ny, nx]:
            seen[ny, nx] = True; q.append((ny, nx))
keepm = seen.copy()
keepm[HORIZON:] = True
# fill holes: sky is only what the top edge can reach
sky = np.zeros_like(keepm)
q = deque((0, xv) for xv in range(w) if not keepm[0, xv])
for (yv, xv) in list(q): sky[yv, xv] = True
while q:
    cy, cx = q.popleft()
    for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
        ny, nx = cy+dy, cx+dx
        if 0 <= ny < h and 0 <= nx < w and not keepm[ny, nx] and not sky[ny, nx]:
            sky[ny, nx] = True; q.append((ny, nx))
keepm = ~(sky | ((~seen) & (b - r > 20) & (lum > 140) & (np.arange(h)[:, None] < HORIZON)))
km = Image.fromarray((keepm * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
alpha = np.asarray(km).copy()
alpha[HORIZON:] = 255
rgba = np.dstack([a.astype(np.uint8), alpha])
Image.fromarray(rgba, "RGBA").save(OUT + "plate.webp", "WEBP", quality=85, method=6)
print("plate ok", (alpha[:HORIZON] < 128).mean())

# ---- debris cut-outs from the green sheet
sh = Image.open(SRC + "6.jpg").convert("RGB")
s = np.asarray(sh).astype(np.int32)
R, G, B = s[..., 0], s[..., 1], s[..., 2]
green = (G > R + 22) & (G > B + 12)
white = (R > 238) & (G > 238) & (B > 238)
def cut(name, box, exclude=None, target_w=None):
    x0, y0, x1, y1 = box
    sub = s[y0:y1, x0:x1]
    fg = ~green[y0:y1, x0:x1] & ~white[y0:y1, x0:x1]
    if exclude:
        ex0, ey0, ex1, ey1 = exclude
        fg[max(0, ey0 - y0):max(0, ey1 - y0), max(0, ex0 - x0):max(0, ex1 - x0)] = False
    # connected components: keep big ones
    h, w = fg.shape
    lab = np.zeros((h, w), np.int32); n = 0; sizes = {}
    for yv in range(h):
        row = fg[yv]
        for xv in np.nonzero(row & (lab[yv] == 0))[0]:
            if lab[yv, xv]: continue
            n += 1; q = deque([(yv, xv)]); lab[yv, xv] = n; c = 0
            while q:
                cy, cx = q.popleft(); c += 1
                for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
                    ny, nx = cy+dy, cx+dx
                    if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and not lab[ny, nx]:
                        lab[ny, nx] = n; q.append((ny, nx))
            sizes[n] = c
    big = max(sizes.values())
    keepl = [k for k, v in sizes.items() if v > max(150, big * 0.01)]
    mask = np.isin(lab, keepl)
    mimg = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
    alpha = np.asarray(mimg)
    # de-spill green on the edges
    sub2 = sub.copy()
    spill = sub2[..., 1] > (sub2[..., 0] + sub2[..., 2]) // 2 + 10
    sub2[..., 1] = np.where(spill, (sub2[..., 0] + sub2[..., 2]) // 2 + 10, sub2[..., 1])
    rgba = np.dstack([sub2.astype(np.uint8), alpha])
    img = Image.fromarray(rgba, "RGBA")
    img = img.crop(img.getbbox())
    if target_w:
        img = img.resize((target_w, round(img.height * target_w / img.width)), Image.LANCZOS)
    img.save(OUT + "debris_" + name + ".webp", "WEBP", quality=88, method=6)
    print(name, img.size, len(keepl))
BOXC = (446, 222, 930, 543)
cut("barrel", (0, 0, 682, 378), exclude=BOXC, target_w=200)
cut("crate", (694, 0, 1376, 378), exclude=BOXC, target_w=260)
cut("planks", (462, 238, 914, 528), target_w=300)
cut("sailcloth", (0, 389, 682, 768), exclude=BOXC, target_w=230)
cut("oar", (694, 389, 1376, 768), exclude=BOXC, target_w=240)

# ---- clouds in the plate's own style (pale, blue outline)
def cloud(fn, blobs, wd, ht):
    S = 3
    img = Image.new("RGBA", (wd * S, ht * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for (cx, cy, rr) in blobs:
        d.ellipse([(cx - rr - 4) * S, (cy - rr - 4) * S, (cx + rr + 4) * S, (cy + rr + 4) * S], fill=(110, 160, 180, 255))
    for (cx, cy, rr) in blobs:
        d.ellipse([(cx - rr) * S, (cy - rr) * S, (cx + rr) * S, (cy + rr) * S], fill=(222, 240, 245, 255))
    # flat bottom
    d.rectangle([0, (ht - 14) * S, wd * S, ht * S], fill=(0, 0, 0, 0))
    for (cx, cy, rr) in blobs:
        d.ellipse([(cx - rr * 0.8) * S, (cy - rr * 0.4) * S, (cx + rr * 0.8) * S, (cy + rr * 0.9) * S], fill=(196, 222, 232, 255))
    d.rectangle([0, (ht - 14) * S, wd * S, ht * S], fill=(0, 0, 0, 0))
    d.line([(20 * S, (ht - 15) * S), ((wd - 20) * S, (ht - 15) * S)], fill=(110, 160, 180, 255), width=3 * S)
    img = img.resize((wd, ht), Image.LANCZOS)
    img.save(OUT + fn, "WEBP", quality=90)
cloud("cloud_1.webp", [(60, 70, 34), (110, 52, 48), (170, 62, 40), (225, 78, 28)], 270, 110)
cloud("cloud_2.webp", [(50, 58, 26), (95, 44, 36), (145, 56, 28)], 190, 86)

# ---- Landing art: the clean plate, landscape
Image.open(SRC + "4.jpg").convert("RGB").save(OUT + "landing.webp", "WEBP", quality=80, method=6)

# ================================================================ palms C and D
plate = Image.open(OUT + "plate.webp").convert("RGBA")
a = np.asarray(plate).astype(np.int32).copy()
H, W = a.shape[:2]
r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
lum = (r * 3 + g * 6 + b) / 10
foliage = (g > r + 8) & (g - b > 40) & (lum < 215)
trunk = (r > g) & (r - b > 35) & (lum < 200) & (r > 90)
dark = lum < 100
HORIZON = 327
boxes = {"C": (1048, 140, 1222, 448), "D": (1196, 232, 1346, 452)}
out = a.copy()
for pid, (x0, y0, x1, y1) in boxes.items():
    core = np.zeros((H, W), bool)
    core[y0:y1, x0:x1] = (foliage | trunk)[y0:y1, x0:x1]
    # drop specks: keep the biggest connected blob (the palm)
    from collections import deque
    lab = np.zeros((H, W), np.int32); n = 0; sizes = {}
    ys, xs = np.nonzero(core)
    for yv, xv in zip(ys, xs):
        if lab[yv, xv]: continue
        n += 1; q = deque([(yv, xv)]); lab[yv, xv] = n; c = 0
        while q:
            cy, cx = q.popleft(); c += 1
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = cy + dy, cx + dx
                    if y0 <= ny < y1 and x0 <= nx < x1 and core[ny, nx] and not lab[ny, nx]:
                        lab[ny, nx] = n; q.append((ny, nx))
        sizes[n] = c
    keep = [k for k, v in sizes.items() if v > 300]
    core = np.isin(lab, keep)
    m = Image.fromarray((core * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    mask = (np.asarray(m) > 0)
    # dark outline pixels next to the palm belong to it; others (rocks) don't
    mask = mask & (core | dark | (al < 255) | (lum > 0))
    mask[:y0] = False; mask[y1:] = False; mask[:, :x0] = False; mask[:, x1:] = False
    # sprite
    spr = np.zeros_like(a)
    spr[mask] = a[mask]
    soft = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
    spr[..., 3] = np.minimum(np.asarray(soft).astype(np.int32), a[..., 3])
    img = Image.fromarray(spr.astype(np.uint8), "RGBA").crop((x0, y0, x1, y1))
    img.save(OUT + "palm_" + pid + ".webp", "WEBP", quality=90)
    # inpaint the plate: sky above the horizon, row interpolation below
    for yv in range(y0, y1):
        row = mask[yv]
        if not row.any():
            continue
        if yv < HORIZON:
            out[yv, row, 3] = 0
            continue
        xsr = np.nonzero(row)[0]
        lo, hi = xsr.min() - 1, xsr.max() + 1
        cl, ch = a[yv, max(lo, 0), :3], a[yv, min(hi, W - 1), :3]
        for xv in xsr:
            f = (xv - lo) / max(1, hi - lo)
            out[yv, xv, :3] = cl * (1 - f) + ch * f
            out[yv, xv, 3] = 255
    print(pid, img.size, "origin", (x0, y0))
sat = a[..., :3].max(-1) - a[..., :3].min(-1)
rock = (sat < 34) & (lum < 215) & (np.abs(r - b) < 26) & ~dark
rock_near = np.asarray(Image.fromarray((rock * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
for pid, (x0, y0, x1, y1) in boxes.items():
    sub = ~(rock | (dark & rock_near))
    from collections import deque
    seen = np.zeros((H, W), bool)
    q = deque()
    for yv in range(y0, min(y1, HORIZON)):
        for xv in range(x0, x1):
            if sub[yv, xv] and out[yv, xv, 3] < 128:
                seen[yv, xv] = True; q.append((yv, xv))
    while q:
        cy, cx = q.popleft()
        for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
            ny, nx = cy + dy, cx + dx
            if y0 <= ny < min(y1, HORIZON) and x0 <= nx < x1 and sub[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True; q.append((ny, nx))
    out[seen, 3] = 0
Image.fromarray(out.astype(np.uint8), "RGBA").save(OUT + "plate.webp", "WEBP", quality=85, method=6)
