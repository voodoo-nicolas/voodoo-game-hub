"""Turned: cut an NPC's walk cycle out of the owner's green sheets (same layout as her walk: four frames in a
row, prompts in docs/turned/ART_PROMPTS_V2_READY.md Step 10).

    python tools/turned_npc_walk_frames.py

Reads the sheets in SHEETS (reference/art/turned/gen/SK-0n.jpg) and writes
games/turned/art/npc_<sprite>_<side|down|up>_w0..w3.png, laid out like the still sprites (same canvas, figure
height and foot line as tools/turned_walk_frames.py, which does the keying and the frame split).
`use` picks which of the sheet's four frames goes in w0..w3: in the shopkeeper's side sheet (SK-01) the lamp is
missing from passing frame 2, so frame 4 is used for both passing frames; his back sheet (SK-03) has a lamp in
BOTH hands in its passing frames 2 and 4, so his back walk uses the two clean steps, each held for two frames.
His first front sheet came out as a side view with the face turned to the camera (kept as SK-02-side.jpg, not
used); the owner's redo (SK-02.jpg, 2026-11-06, DECISIONS B-26) is a true front view, all four frames clean.
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

import turned_walk_frames as wf

SRC = os.path.join(wf.ROOT, "reference", "art", "turned", "gen")   # copies of the owner's D:/dev/minigame art/rpg/turned/characters/sk-0n.jpg
SHEETS = [
    # (sheet, sprite, direction, which sheet frame for w0..w3)
    ("SK-01.jpg", "shopkeeper_road", "side", [0, 3, 2, 3]),   # its frame 2 has no lamp: the other passing frame twice
    ("SK-03.jpg", "shopkeeper_road", "up", [0, 0, 2, 2]),
    ("SK-02.jpg", "shopkeeper_road", "down", [0, 1, 2, 3]),
]


def frames(alpha: np.ndarray) -> list:
    """Like turned_walk_frames.frames, but two figures joined by a lamp are split at their thinnest column."""
    solid = ndimage.binary_opening(alpha > 0.5, iterations=2)
    count = solid.sum(0)
    runs, x = [], 0
    while x < len(count):
        if count[x] > 3:
            x0 = x
            while x < len(count) and count[x] > 3:
                x += 1
            runs.append([x0, x])
        x += 1
    runs = [r for r in runs if r[1] - r[0] > 25]
    while len(runs) < 4:
        i = int(np.argmax([r[1] - r[0] for r in runs]))
        x0, x1 = runs[i]
        q = (x1 - x0) // 4
        cut_x = x0 + q + int(np.argmin(count[x0 + q:x1 - q]))
        runs[i:i + 1] = [[x0, cut_x], [cut_x, x1]]
    assert len(runs) == 4, runs
    return runs


def cut(im: np.ndarray) -> list:
    rgb, alpha = wf.key(im)
    out = []
    for x0, x1 in frames(alpha):
        m = alpha[:, x0:x1] > 0.5
        ys = np.where(m.any(1))[0]
        out.append((x0, x1, ys[0], ys[-1] + 1))
    h = float(np.median([b[3] - b[2] for b in out]))
    k = wf.FIG_H * wf.CANVAS / h
    pics = []
    for x0, x1, y0, y1 in out:
        # only this frame's columns: in a tightly spaced sheet (SK-02) the neighbours stand inside the 600 px crop
        own = np.zeros_like(alpha)
        own[:, x0:x1] = alpha[:, x0:x1]
        rgba = np.dstack([rgb, own * 255.0]).clip(0, 255).astype(np.uint8)
        m = alpha[y0:y1, x0:x1] > 0.5
        top = m[: int((y1 - y0) * 0.35)]
        cx = x0 + float(np.where(top.any(0))[0].mean())
        ox, oy = max(int(cx) - 300, 0), max(y0 - 40, 0)
        crop = Image.fromarray(rgba[oy:y1, ox:int(cx) + 300])
        crop = crop.resize((round(crop.width * k), round(crop.height * k)), Image.LANCZOS)
        canvas = Image.new("RGBA", (wf.CANVAS, wf.CANVAS), (0, 0, 0, 0))
        canvas.alpha_composite(crop, (round(wf.CANVAS / 2 - (cx - ox) * k), round(wf.FEET * wf.CANVAS - (y1 - oy) * k)))
        a = np.asarray(canvas)[..., 3] > 0
        lab, n = ndimage.label(ndimage.binary_dilation(a, iterations=3))
        if n > 1:
            sizes = ndimage.sum(a, lab, range(1, n + 1))
            arr = np.asarray(canvas).copy()
            arr[..., 3] = np.where(lab == (int(np.argmax(sizes)) + 1), arr[..., 3], 0)
            canvas = Image.fromarray(arr)
        pics.append(canvas)
    return pics, k


def main() -> None:
    for sheet, sprite, side, use in SHEETS:
        im = np.asarray(Image.open(os.path.join(SRC, sheet)).convert("RGB")).astype(np.float32)
        pics, k = cut(im)
        for j, i in enumerate(use):
            out = os.path.join(wf.ART, "npc_%s_%s_w%d.png" % (sprite, side, j))
            pics[i].save(out, optimize=True)
            print(out, "scale %.3f" % k)


if __name__ == "__main__":
    main()
