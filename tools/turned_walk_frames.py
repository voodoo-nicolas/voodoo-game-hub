"""Turned: cut her walk cycle out of the owner's three green sheets (WK-01 walking right, WK-02 towards the
camera, WK-03 away; four frames each, prompts in docs/turned/ART_PROMPTS_V2_READY.md Step 8).

    python tools/turned_walk_frames.py

Reads reference/art/turned/gen/WK-01.jpg .. WK-03.jpg. Writes games/turned/art/player_<side|down|up>_w0..w3.png:
the green keyed out (and its spill taken off the edges), each frame on a 512 x 512 canvas laid out like the
still sprites (player_down.png etc.: the figure about 72% of the canvas tall, the soles at 92%), one scale per
sheet (so the four frames match), centred on the head and shoulders (the legs swing, the body does not).
Towards and away from the camera, frames 2 and 3 are frames 0 and 1 mirrored (the sheets swing the skirt the
same way on both steps).
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, "reference", "art", "turned", "gen")
ART = os.path.join(ROOT, "games", "turned", "art")
SHEETS = [("WK-01", "side"), ("WK-02", "down"), ("WK-03", "up")]
CANVAS = 512
FIG_H = 0.719          # the still sprites: 184 px of 256
FEET = 0.92


def key(rgb: np.ndarray):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    spill = g - np.maximum(r, b)                       # the green screen: well above both red and blue
    alpha = np.clip((60.0 - spill) / 35.0, 0.0, 1.0)   # 25 and less: her; 60 and more: the screen
    out = rgb.copy()
    out[..., 1] = np.minimum(g, np.maximum(r, b) + 4.0)  # no green fringe (her colours have no green cast)
    return out, alpha


def frames(alpha: np.ndarray) -> list:
    """Column ranges of the four figures (split at the green gaps between them)."""
    solid = ndimage.binary_opening(alpha > 0.5, iterations=2)
    cols = solid.sum(0) > 3
    runs, x = [], 0
    while x < len(cols):
        if cols[x]:
            x0 = x
            while x < len(cols) and cols[x]:
                x += 1
            runs.append([x0, x])
        x += 1
    runs = [r for r in runs if r[1] - r[0] > 25]        # stray hairs and specks
    while len(runs) > 4:                                # a gap inside one figure (an arm): join the closest
        gaps = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
        i = int(np.argmin(gaps))
        runs[i:i + 2] = [[runs[i][0], runs[i + 1][1]]]
    assert len(runs) == 4, runs
    return runs


def main() -> None:
    for name, side in SHEETS:
        im = np.asarray(Image.open(os.path.join(GEN, name + ".jpg")).convert("RGB")).astype(np.float32)
        rgb, alpha = key(im)
        runs = frames(alpha)
        boxes = []
        for x0, x1 in runs:
            m = alpha[:, x0:x1] > 0.5
            ys = np.where(m.any(1))[0]
            boxes.append((x0, x1, ys[0], ys[-1] + 1))
        h = float(np.median([b[3] - b[2] for b in boxes]))
        k = FIG_H * CANVAS / h
        for i, (x0, x1, y0, y1) in enumerate(boxes):
            m = alpha[y0:y1, x0:x1] > 0.5
            top = m[: int((y1 - y0) * 0.35)]
            cx = x0 + float(np.where(top.any(0))[0].mean())  # the head and shoulders
            rgba = np.dstack([rgb, alpha * 255.0]).clip(0, 255).astype(np.uint8)
            pad = 40
            crop = Image.fromarray(rgba[max(y0 - pad, 0):y1, max(int(cx) - 300, 0):int(cx) + 300])
            ox = max(int(cx) - 300, 0)
            oy = max(y0 - pad, 0)
            crop = crop.resize((round(crop.width * k), round(crop.height * k)), Image.LANCZOS)
            canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
            # the soles (y1) at FEET, the head and shoulders (cx) in the middle
            px = round(CANVAS / 2 - (cx - ox) * k)
            py = round(FEET * CANVAS - (y1 - oy) * k)
            canvas.alpha_composite(crop, (px, py))
            # keep only this figure: its neighbours' edges may reach into the crop
            a = np.asarray(canvas)[..., 3] > 0
            lab, n = ndimage.label(ndimage.binary_dilation(a, iterations=3))
            if n > 1:
                sizes = ndimage.sum(a, lab, range(1, n + 1))
                keep = lab == (int(np.argmax(sizes)) + 1)
                arr = np.asarray(canvas).copy()
                arr[..., 3] = np.where(keep, arr[..., 3], 0)
                canvas = Image.fromarray(arr)
            if side != "side" and i >= 2:
                # towards / away from the camera both of the sheet's steps swing the skirt to the same side, so
                # she lurched one way every step (owner: "waddles"): the second step is the first one mirrored
                continue
            for j, pic in ([(i, canvas)] if side == "side" else
                           [(i, canvas), (i + 2, canvas.transpose(Image.FLIP_LEFT_RIGHT))]):
                out = os.path.join(ART, "player_%s_w%d.png" % (side, j))
                pic.save(out, optimize=True)
                print(out, "scale %.3f" % k)


if __name__ == "__main__":
    main()
