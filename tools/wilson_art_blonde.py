"""The blonde (female5) extra poses: crops boxes out of her action sheets in D:/dev/Wilson
-> games/wilson/art/chars/female5_<pose>.webp. The sheets are crowded, so each pose is a hand-measured
box (source pixels); inside it the magenta is keyed out and only blobs centred in the box are kept."""
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

def cut_boxes(src, boxes, scale=0.5, min_area=500):
    a = np.asarray(Image.open(SRC + src).convert("RGB"))
    fg = ndimage.binary_opening(_key(a), iterations=1)
    lab, n = ndimage.label(fg)
    edge_band = ndimage.binary_dilation(~fg, iterations=3)
    for name, (x0, y0, x1, y1) in boxes.items():
        ids = []
        iw, ih = (x1 - x0) * 0.1, (y1 - y0) * 0.1
        for i, sl in enumerate(ndimage.find_objects(lab)):
            if sl is None:
                continue
            m = lab[sl] == i + 1
            if m.sum() < min_area:
                continue
            cy, cx = ndimage.center_of_mass(m)
            cx += sl[1].start
            cy += sl[0].start
            if x0 + iw <= cx < x1 - iw and y0 + ih <= cy < y1 - ih:
                ids.append(i + 1)
        if not ids:
            print("  MISSING", name)
            continue
        mask = np.isin(lab, ids)
        box = np.zeros_like(mask)
        box[y0:y1, x0:x1] = True
        mask &= box            # nothing from the neighbours' edges
        ys, xs = np.nonzero(mask)
        ya, yb, xa, xb = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        sub = a[ya:yb, xa:xb].astype(np.int32).copy()
        mk = mask[ya:yb, xa:xb]
        eb = edge_band[ya:yb, xa:xb]
        r, g, b = sub[..., 0], sub[..., 1], sub[..., 2]
        spill = np.clip(np.minimum(r, b) - g - 25, 0, None) * eb
        sub[..., 0] = r - (spill * 0.85).astype(np.int32)
        sub[..., 2] = b - (spill * 0.85).astype(np.int32)
        al = Image.fromarray((mk * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
        img = Image.fromarray(np.dstack([np.clip(sub, 0, 255).astype(np.uint8), np.asarray(al)]), "RGBA")
        img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
        pad = Image.new("RGBA", (img.width + 8, img.height + 8), (0, 0, 0, 0))
        pad.alpha_composite(img, (4, 4))
        pad.save(OUT + "female5_" + name + ".webp", "WEBP", quality=88, method=6)
        print(name, pad.size)

cut_boxes("female5_actions.jpg", {"carve": (30, 385, 200, 610), "weave": (210, 370, 400, 550), "tool": (400, 375, 570, 555)})
cut_boxes("female5_fishing.jpg", {
    "f_ready": (20, 20, 170, 370), "f_sit": (30, 295, 225, 600), "f_back": (230, 360, 380, 690),
    "f_swing": (375, 370, 540, 690), "f_wait": (565, 520, 700, 700), "f_bite": (700, 515, 820, 700),
    "f_strike": (825, 495, 985, 690), "f_fight": (30, 730, 170, 1050), "f_reel": (170, 730, 315, 1050),
    "f_net": (325, 730, 455, 1050), "f_catch": (455, 720, 600, 1050), "f_tired": (600, 730, 735, 1050),
    "f_hug": (740, 745, 865, 900)})
