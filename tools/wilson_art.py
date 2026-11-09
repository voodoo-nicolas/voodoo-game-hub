"""Beached (wilson) art pipeline: owner pictures in D:/dev/Wilson -> games/wilson/art/.
Run: python tools/wilson_art.py   (then Godot --import). See docs/wilson/DECISIONS.md W-20."""
import sys
from PIL import Image, ImageFilter, ImageDraw
import numpy as np
from collections import deque
SRC = "D:/dev/Wilson/"
OUT = "C:/Users/nick_/code/voodoo-game-hub/games/wilson/art/"

import sys
ONLY_SHEETS = "sheets" in sys.argv  # python tools/wilson_art.py sheets: skip the slow plate / palm part

def plate_and_palms():
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




if not ONLY_SHEETS:
    plate_and_palms()

# ================================================================ M3: sprite sheets on magenta
# ART_PROMPTS.md: sheets on flat magenta, no grid. Each sheet: named anchors (source pixels, measured
# from the owner's 2026-11-08 sheets); every connected blob goes to its nearest anchor; the background
# is keyed by colour distance from the border median + flood fill from the edges; magenta fringe
# despilled. Output WebP into games/wilson/art/<folder>/<name>.webp.
from scipy import ndimage
import os

def _key(a):
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, axis=0)
    d = np.sqrt(((a.astype(np.float32) - bg) ** 2).sum(-1))
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    mag = (r - g > 60) & (b - g > 30)
    near = (d < 70) | (mag & (d < 120))
    lab, n = ndimage.label(near)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bgm = np.isin(lab, list(edge)) | (d < 45)
    return ~bgm

def cut_sheet(src, anchors, folder, scale=0.5, max_side=None, min_area=60):
    a = np.asarray(Image.open(SRC + src).convert("RGB"))
    fg = ndimage.binary_opening(_key(a), iterations=1)
    lab, n = ndimage.label(fg)
    names = list(anchors)
    pts = np.array([anchors[k] for k in names], dtype=np.float32)
    owner = {}
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if sl is None:
            continue
        m = lab[sl] == i + 1
        area = int(m.sum())
        if area < min_area:
            continue
        cy, cx = ndimage.center_of_mass(m)
        c = np.array([sl[1].start + cx, sl[0].start + cy])
        inside = [j for j, (px, py) in enumerate(pts) if sl[1].start <= px < sl[1].stop and sl[0].start <= py < sl[0].stop and m[int(py) - sl[0].start, int(px) - sl[1].start] | True]
        if len(inside) >= 2 and area > 20000:
            # two poses touching: split the blob between the anchors inside it (nearest anchor per pixel)
            ys, xs = np.nonzero(m)
            ys = ys + sl[0].start
            xs = xs + sl[1].start
            dist = np.stack([(xs - pts[j][0]) ** 2 + (ys - pts[j][1]) ** 2 for j in inside])
            near = np.argmin(dist, axis=0)
            for jj, j in enumerate(inside):
                n += 1
                lab[ys[near == jj], xs[near == jj]] = n
                owner.setdefault(names[j], []).append(n)
            continue
        k = int(np.argmin(((pts - c) ** 2).sum(-1)))
        owner.setdefault(names[k], []).append(i + 1)
    os.makedirs(OUT + folder, exist_ok=True)
    edge_band = ndimage.binary_dilation(~fg, iterations=3)
    out = {}
    for name in names:
        ids = owner.get(name, [])
        if not ids:
            print("  MISSING", src, name)
            continue
        mask = np.isin(lab, ids)
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
        s = scale
        if max_side:
            s = min(1.0, max_side / max(img.size))
        img = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
        pad = Image.new("RGBA", (img.width + 8, img.height + 8), (0, 0, 0, 0))
        pad.alpha_composite(img, (4, 4))
        pad.save(OUT + folder + "/" + name + ".webp", "WEBP", quality=88, method=6)
        out[name] = pad.size
    print(src, "->", folder, len(out), "of", len(names))
    return out

# Character sheets (992x1059): 19 poses, same layout on all 8. Anchors from male1.
POSES = {
    "idle": (96, 205), "walk1": (235, 203), "walk2": (368, 204), "walk3": (500, 203), "walk4": (640, 203),
    "run": (843, 215), "sit": (110, 504), "sleep": (383, 482), "hammock": (761, 456), "fish": (400, 640),
    "chop": (666, 625), "craft": (887, 643), "eat": (94, 890), "drink": (240, 890), "shrug": (370, 890),
    "wave": (514, 881), "facepalm": (650, 890), "sulk": (886, 832), "collapse": (830, 1010),
}
LOOKS = {"male1": "male1.jpg", "male2": "male2.jpg", "male3": "male3.jpg", "male4": "male4.jpg",
         "female1": "female1.jpg", "female2": "demale2.jpg", "female3": "female3.jpg", "female4": "female4.jpg"}
for look, f in LOOKS.items():
    cut_sheet(f, {f"{look}_{p}": xy for p, xy in POSES.items()}, "chars", scale=0.5)

# Inventory icons (1376x768, 6x4 grid), ids from items.json.
INV_ROWS = [["fishing_pole", "stone_axe", "knife", "spear", "shovel", "coconut"],
            ["coconut_shell", "coconut_bowl", "rope", "hook", "shell", "stone"],
            ["stick", "frond", "bottle", "bottle_note", "fish_small", "fish_cooked"],
            ["fish_dried", "seaweed", "charcoal", "salt", "torch", "barometer"]]
INV_X = [138, 364, 586, 804, 1026, 1244]
INV_Y = [112, 295, 477, 660]
cut_sheet("inventory.jpg", {INV_ROWS[r][c]: (INV_X[c], INV_Y[r]) for r in range(4) for c in range(6)}, "icons", max_side=128)

# Rare materials (1100x960; anchors measured on a 900-wide preview, x1.2222).
RARE = {"conch_shell": (137, 125), "sea_glass": (370, 125), "copper_wire": (590, 120), "battery": (785, 118),
        "pearl": (122, 290), "brass_tube": (357, 290), "circuit_scrap": (592, 292), "magnet": (778, 292),
        "radio_tube": (122, 432), "amber": (285, 432), "old_coin": (455, 435), "broken_compass": (622, 460),
        "compass": (777, 445), "lens": (122, 565), "tar": (290, 565), "rubber_sap": (425, 562),
        "golden_coconut": (130, 678), "meteorite_shard": (322, 690), "captains_log": (555, 670), "map_piece": (760, 668)}
cut_sheet("rare materials.jpg", {k: (x * 1.2222, y * 1.2222) for k, (x, y) in RARE.items()}, "icons", max_side=128)

# Camp builds (1376x768).
CAMP = {"tent": (226, 169), "hammock": (582, 168), "garden_plot": (900, 163), "garden_sprouts": (1204, 163),
        "pit_unlit": (221, 432), "pit_embers": (586, 424), "crafting_stump": (912, 400), "water_still": (1207, 394),
        "drying_rack": (227, 636), "frond_bed": (596, 654), "signpost": (917, 631), "rain_catcher": (1210, 634)}
cut_sheet("camp builds.jpg", CAMP, "camp", scale=0.5)

# Fire parts (1100x960; x1.2222 from the preview).
FIRE = {"pit_unlit": (240, 157), "pit_embers": (665, 157), "flame_mid": (137, 398), "flame_small": (340, 423),
        "flame_large": (553, 383), "flame_core": (778, 400), "smoke": (176, 650), "torch": (453, 640)}
cut_sheet("fire3.jpg", {k: (x * 1.2222, y * 1.2222) for k, (x, y) in FIRE.items()}, "fire", scale=0.45, min_area=900)

# HUD icons (1100x960; x1.2222). Moon phases skipped (the sky draws the real phase).
HUD = {"heart": (128, 105), "food": (352, 105), "energy": (573, 105), "water": (775, 105),
       "bubble_s": (113, 288), "bubble_m": (272, 285), "bubble_l": (452, 283), "zzz": (625, 265), "sun": (618, 360),
       "cloud": (118, 478), "rain": (305, 468), "storm": (476, 478), "fog": (722, 486), "wind": (120, 665),
       "thermometer": (268, 665), "bottle": (387, 665), "backpack": (544, 665), "scroll": (690, 670), "gear": (818, 675)}
# the 3x3 moon-phase grid: anchored so its discs don't stick to the sun / zzz / fog / drop icons
for _i, (_x, _y) in enumerate([(x, y) for y in (248, 308, 368) for x in (720, 778, 836)]):
    HUD["moon_%d" % (_i + 1)] = (_x, _y)
cut_sheet("hud.jpg", {k: (x * 1.2222, y * 1.2222) for k, (x, y) in HUD.items()}, "hud", max_side=96)

# Grand Projects (grand.jpg, 1100x960, owner 2026-11-08). Keys = wilson_projects.gd `key`s; the slingshot,
# arcade and cinema are drawn too but their projects (GP09 / GP11 / GP12) are not built yet.
GRAND = {"shellphone": (190, 150), "windmill": (500, 160), "coconut_radio": (880, 150),
         "spyglass_tower": (160, 480), "treehouse": (450, 500), "lighthouse": (750, 480), "slingshot": (975, 470),
         "glider": (170, 800), "submarine": (440, 820), "arcade": (680, 800), "cinema": (940, 790)}
cut_sheet("grand.jpg", GRAND, "projects", scale=0.5, min_area=900)
