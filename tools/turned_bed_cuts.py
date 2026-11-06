"""Turned: cut the bed out of the owner's SL-01 (asleep) and SL-02 (sitting up), DECISIONS B-21, and the cot
out of SL-03 (out cold) and SL-04 (waking), DECISIONS B-26.

    python tools/turned_bed_cuts.py

Both pictures are Gemini edits of the upstairs painting (house_up), the same size and framing, so the bed sits
at the same painting pixels. Gemini repaints the whole picture a little (about 13/765 colour difference
everywhere), so only a box round the bed is used, its edges faded out over FEATHER px so it melts into the
game's painting. Writes games/turned/art/bed_asleep.png and bed_sitting.png (the box at painting scale); the
box's top-left corner is BED_BOX in turned_player.gd (keep the two the same).
SL-03 / SL-04 are edits of the cigar shop painting (cigar_shop_room.jpg): COT_BOX round the storeroom cot (her
arm hangs to the floor at x 1009, her boots end at y 760), written to cot_out.png / cot_waking.png; COT_BOX in
turned_player.gd is the same box.
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, "reference", "art", "turned", "gen")
ART = os.path.join(ROOT, "games", "turned", "art")
BOX = (56, 436, 404, 748)      # x0, y0, x1, y1 in painting px: the iron bed, her, the nightstand lamp
FEATHER = 16
PICS = [("SL-01", "bed_asleep"), ("SL-02", "bed_sitting")]
COT_BOX = (995, 470, 1205, 785)  # in the cigar shop painting
COT_FEATHER = 10
COT_PICS = [("SL-03", "cot_out"), ("SL-04", "cot_waking")]


def cut(box, feather, pics) -> None:
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    xs = np.minimum(np.arange(w), np.arange(w)[::-1]) / feather
    ys = np.minimum(np.arange(h), np.arange(h)[::-1]) / feather
    alpha = np.clip(np.minimum(ys[:, None], xs[None, :]), 0.0, 1.0)
    alpha = alpha * alpha * (3.0 - 2.0 * alpha)          # smoothstep: no visible edge
    for src, out in pics:
        im = Image.open(os.path.join(GEN, src + ".jpg")).convert("RGB").crop(box)
        rgba = np.dstack([np.asarray(im), (alpha * 255.0).astype(np.uint8)])
        path = os.path.join(ART, out + ".png")
        Image.fromarray(rgba).save(path, optimize=True)
        print(path, w, "x", h)


def main() -> None:
    cut(BOX, FEATHER, PICS)
    cut(COT_BOX, COT_FEATHER, COT_PICS)


if __name__ == "__main__":
    main()
