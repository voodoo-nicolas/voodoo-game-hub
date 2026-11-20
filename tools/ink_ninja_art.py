"""Ink Ninja: cut the owner's artwork into game pictures (owner, 2026-11-20).

  python tools/ink_ninja_art.py [--debug DIR]

Source: D:/Dev/Minigame Art/ink ninja/artwork/2 (Gemini / ChatGPT pictures on white or beige paper).
- Statues -> games/ink_ninja/art/<name>.png (paper made see-through, saturation 45 %, slightly warm, max 420 px).
- Boss poses -> games/ink_ninja/art/boss/<boss>_<pose>.png (saturation 60 %, same scale for every pose of a
  boss) and, for hard mode, <boss>_<pose>_hard.png where the smoke / ink / magic around the figure is
  repainted in full rainbow colours (like the owner's 5hard / 6hard; those two are used as they are).
- scripts/games/ink_ninja/ink_ninja_poses.gd: the feet anchor, facing and scale of every pose (generated).
Boxes are the figure's body (normalised x0, y0, x1, y1 inside the source or its `sub` slice); everything
outside the body box is "effect" and is coloured in the hard versions.
"""
import os, sys, zlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = "D:/Dev/Minigame Art/ink ninja/artwork/2"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "games", "ink_ninja", "art")
BOSS_OUT = os.path.join(ART, "boss")
POSES_GD = os.path.join(ROOT, "scripts", "games", "ink_ninja", "ink_ninja_poses.gd")
RATIO = {"idle": 1.0, "wind": 0.95, "strike": 0.88, "cast": 1.0, "air": 1.0, "hit": 0.9, "stagger": 0.72, "dead": 0.42}
RATIO_BOSS = {("tora", "hit"): 0.7, ("tora", "stagger"): 0.6, ("tora", "wind"): 0.85, ("tsuru", "stagger"): 0.72, ("calligrapher", "dead"): 0.72,
              ("warden", "hit"): 0.8, ("warden", "stagger"): 0.8, ("warden", "wind"): 0.85, ("warden", "strike"): 0.85, ("dragon", "strike"): 0.82}
INNER_SMOKE = {"dragon"}   # smoke wraps the figure: the smooth grey wash inside the body box is coloured too
# Bosses: a steeper paper cut (opaque bodies, not see-through washes) and darker mid-greys.
BOSS_LO, BOSS_HI, BOSS_GAMMA = 0.04, 0.16, 1.35
FIG_PX = 340          # body-box height of the idle pose in the output (the other poses keep its scale)

# name: (file, sub x0..x1 or None, box)
STATUES = {
    "akita": ("akita.jpg", None),
    "bonsai": ("bonsai.jpg", None),
    "dragon_rock": ("dragon2.png", None),
    "dragon_coil": ("dragon4.jpg", None),
    "dragon_snake": ("dragon6.jpg", None),
    "komainu2_l": ("komainu.jpg", (0.0, 0.5)),
    "komainu2_r": ("komainu.jpg", (0.5, 1.0)),
    "lion_a": ("lion.jpg", None),
    "lion_b": ("lion 2.jpg", None),
    "nio2": ("nio.jpg", None),
    "warrior": ("warrior.jpg", (0.0, 0.29)),
    "warrior_b": ("warrior.jpg", (0.29, 0.5)),
    "warrior_c": ("warrior.jpg", (0.71, 1.0)),
}

# boss -> pose -> (file, sub, face (-1 looks left), body box, effects worth colouring in hard mode)
BOSSES = {
    "warden": {
        "idle": ("1b.jpg", None, -1, (0.36, 0.12, 0.72, 0.94), False),
        "wind": ("1d.jpg", None, -1, (0.38, 0.14, 0.82, 0.96), False),
        "strike": ("1c.jpg", None, -1, (0.44, 0.10, 0.90, 0.95), True),
        "air": ("1h.jpg", (0.0, 0.5), -1, (0.22, 0.18, 0.80, 0.97), True),
        "cast": ("1h.jpg", (0.5, 1.0), -1, (0.28, 0.08, 0.76, 0.90), True),
        "hit": ("1e.jpg", None, -1, (0.40, 0.18, 0.92, 0.96), False),
        "stagger": ("1f.jpg", None, -1, (0.40, 0.18, 0.92, 0.96), False),
        "dead": ("1g.jpg", None, -1, (0.18, 0.28, 0.88, 0.90), True),
    },
    "tora": {
        "idle": ("2b.jpg", None, 1, (0.26, 0.10, 0.74, 0.96), False),
        "wind": ("2g.jpg", None, 1, (0.30, 0.12, 0.74, 0.95), False),
        "strike": ("2d.jpg", None, -1, (0.36, 0.12, 0.84, 0.96), True),
        "cast": ("2c.jpg", None, -1, (0.24, 0.12, 0.76, 0.96), False),
        "air": ("2e.jpg", (0.48, 1.0), -1, (0.12, 0.05, 0.92, 0.92), False),
        "hit": ("2e.jpg", (0.0, 0.48), -1, (0.10, 0.32, 0.92, 0.96), False),
        "stagger": ("2i.jpg", (0.0, 0.34), -1, (0.10, 0.34, 0.96, 0.96), False),
        "dead": ("2h.jpg", None, -1, (0.14, 0.28, 0.88, 0.96), True),
    },
    "dragon": {
        "idle": ("3b.jpg", None, -1, (0.30, 0.04, 0.66, 0.96), True),
        "wind": ("3c.jpg", None, -1, (0.32, 0.04, 0.70, 0.96), True),
        "strike": ("3e.jpg", None, -1, (0.34, 0.08, 0.86, 0.96), True),
        "cast": ("3g.jpg", None, -1, (0.30, 0.24, 0.72, 0.95), True),
        "air": ("3c.jpg", None, -1, (0.32, 0.04, 0.70, 0.96), True),
        "hit": ("3d.jpg", None, -1, (0.30, 0.04, 0.68, 0.96), True),
        "stagger": ("3e.jpg", None, -1, (0.34, 0.08, 0.86, 0.96), True),
        "dead": ("3f.jpg", None, -1, (0.22, 0.30, 0.90, 0.86), True),
    },
    "tsuru": {
        "idle": ("4b.jpg", None, -1, (0.30, 0.10, 0.62, 0.95), True),
        "wind": ("4a.jpg", (0.28, 0.68), -1, (0.24, 0.06, 0.76, 0.96), True),
        "strike": ("4d.jpg", None, -1, (0.38, 0.10, 0.80, 0.97), True),
        "cast": ("4c.jpg", None, -1, (0.42, 0.10, 0.86, 0.95), True),
        "air": ("4g.jpg", None, -1, (0.40, 0.08, 0.80, 0.95), True),
        "hit": ("4f.jpg", None, -1, (0.34, 0.10, 0.80, 0.95), True),
        "stagger": ("4e.jpg", None, -1, (0.32, 0.10, 0.70, 0.95), True),
        "dead": ("4fa.jpg", None, -1, (0.10, 0.34, 0.62, 0.92), True),
    },
    "calligrapher": {
        "idle": ("5b.jpg", None, -1, (0.54, 0.05, 0.90, 0.96), True),
        "wind": ("5c.jpg", None, -1, (0.54, 0.05, 0.94, 0.96), True),
        "strike": ("5d.jpg", None, -1, (0.50, 0.05, 0.90, 0.96), True),
        "cast": ("5g.jpg", None, -1, (0.24, 0.10, 0.58, 0.97), True),
        "air": ("5d.jpg", None, -1, (0.50, 0.05, 0.90, 0.96), True),
        "hit": ("5e.jpg", None, -1, (0.50, 0.05, 0.90, 0.96), True),
        "stagger": ("5f.jpg", None, -1, (0.50, 0.20, 0.96, 0.96), True),
        "dead": ("5f.jpg", None, -1, (0.50, 0.20, 0.96, 0.96), True),
    },
    "shu": {
        "idle": ("6b.jpg", None, 1, (0.40, 0.06, 0.62, 0.95), False),
        "wind": ("6c.jpg", None, 1, (0.36, 0.06, 0.64, 0.95), True),
        "strike": ("6d.jpg", None, 1, (0.36, 0.06, 0.66, 0.95), True),
        "cast": ("6h.jpg", None, 1, (0.36, 0.10, 0.66, 0.95), True),
        "air": ("6c.jpg", None, 1, (0.36, 0.06, 0.64, 0.95), True),
        "hit": ("6e.jpg", None, 1, (0.38, 0.06, 0.66, 0.95), True),
        "stagger": ("6f.jpg", None, 1, (0.34, 0.06, 0.66, 0.95), True),
        "dead": ("6g.jpg", None, 1, (0.22, 0.20, 0.86, 0.95), True),
    },
}
# The owner's own hard-mode pictures replace the generated colouring for these poses.
OWNER_HARD = {("calligrapher", "cast"): ("5hard.jpg", (0.24, 0.10, 0.58, 0.97)),
              ("shu", "cast"): ("6hard.jpg", (0.30, 0.14, 0.60, 0.96))}


def load(name, sub):
    im = Image.open(os.path.join(SRC, name)).convert("RGB")
    if sub:
        w = im.width
        im = im.crop((int(sub[0] * w), 0, int(sub[1] * w), im.height))
    return im


def paper_colour(a):
    edge = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)])
    return np.median(edge, axis=0)


def cut(im, lo=0.07, hi=0.32):
    """Paper -> transparent: alpha from the distance to the paper colour, colour un-blended from it."""
    a = np.asarray(im).astype(np.float32) / 255.0
    bg = paper_colour(a)
    d = np.max(np.abs(a - bg), axis=2)
    d = np.maximum(d, (bg.mean() - a.mean(axis=2)))
    alpha = np.clip((d - lo) / (hi - lo), 0.0, 1.0)
    alpha = alpha * alpha * (3 - 2 * alpha)
    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.clip((a - (1 - safe) * bg) / safe, 0.0, 1.0)
    return rgb, alpha


def mute(rgb, sat, warm=0.0):
    grey = (rgb * np.array([0.299, 0.587, 0.114])).sum(axis=2, keepdims=True)
    out = grey + (rgb - grey) * sat
    if warm:
        out = out * np.array([1.0 + warm, 1.0, 1.0 - warm])
    return np.clip(out, 0, 1)


def rainbow(rgb, alpha, box, seed, inner=False):
    """Hard mode: everything outside the body box (smoke, ink, slashes, cranes) in vivid rainbow colours,
    the figure itself stays ink."""
    h, w = alpha.shape
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    x0, y0, x1, y1 = box[0] * w, box[1] * h, box[2] * w, box[3] * h
    dx = np.maximum(np.maximum(x0 - xs, xs - x1), 0)
    dy = np.maximum(np.maximum(y0 - ys, ys - y1), 0)
    feather = 0.06 * h
    out_body = np.clip(np.hypot(dx, dy) / feather, 0, 1)
    # inside the body box, smoke (smooth grey wash) still takes a little colour
    grey = (rgb * np.array([0.299, 0.587, 0.114])).sum(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    lowsat = np.clip(1.0 - sat / 0.18, 0, 1)
    detail = np.asarray(Image.fromarray((grey * 255).astype(np.uint8)).filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(4))).astype(np.float32) / 255.0
    smooth = np.clip(1.0 - detail / 0.06, 0, 1)
    mask = np.maximum(out_body, (0.85 if inner else 0.0) * smooth * np.clip((grey - 0.25) / 0.2, 0, 1)) * lowsat
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, 1)
    # smooth bands (no seam): distance from the body plus slow waves
    hue = (np.hypot(xs - cx, ys - cy) / (0.7 * h) + 0.35 * (ys / h) + 0.18 * np.sin(xs / 61.0) + 0.12 * np.sin(ys / 43.0 + xs / 97.0) + ph) % 1.0
    # vivid colour, dark ink -> deep saturated colour, washes -> bright colour
    val = np.clip(0.55 + 0.6 * grey, 0, 1)
    hsv = np.stack([hue, np.full_like(hue, 0.95), val], axis=2)
    col = hsv_to_rgb(hsv)
    m = mask[..., None]
    rgb2 = rgb * (1 - m) + col * m
    alpha2 = np.clip(alpha + mask * alpha * 0.25, 0, 1)
    return rgb2, alpha2


def hsv_to_rgb(hsv):
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    i = np.floor(h * 6).astype(int) % 6
    f = h * 6 - np.floor(h * 6)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    r = np.choose(i, [v, q, p, p, t, v]); g = np.choose(i, [t, v, v, q, p, p]); b = np.choose(i, [p, p, t, v, v, q])
    return np.stack([r, g, b], axis=2)


def save(rgb, alpha, path, scale=None, maxpx=None, crop_to=None):
    img = Image.fromarray(np.dstack([rgb * 255, alpha * 255]).astype(np.uint8), "RGBA")
    if crop_to is not None:
        img = img.crop(crop_to)
    if scale:
        img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    if maxpx and max(img.size) > maxpx:
        f = maxpx / max(img.size)
        img = img.resize((round(img.width * f), round(img.height * f)), Image.LANCZOS)
    img.save(path, optimize=True)
    return img


def bbox(alpha, thr=0.12):
    ys, xs = np.where(alpha > thr)
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def main():
    debug = sys.argv[sys.argv.index("--debug") + 1] if "--debug" in sys.argv else None
    os.makedirs(BOSS_OUT, exist_ok=True)
    for name, (f, sub) in STATUES.items():
        rgb, alpha = cut(load(f, sub))
        rgb = mute(rgb, 0.45, 0.03)
        save(rgb, alpha, os.path.join(ART, name + ".png"), maxpx=420, crop_to=bbox(alpha))
    lines = ["extends RefCounted", "",
             "## GENERATED by tools/ink_ninja_art.py: do not edit by hand.",
             "## boss -> pose -> [ax, ay (feet in the picture, px), face (-1 looks left), hard picture exists].",
             "## Every picture is drawn at BOSS_H / FIG_PX world units per px (the body sizes are evened out by the tool).",
             "const FIG_PX := %d" % FIG_PX, "const POSES := {"]
    for boss, poses in BOSSES.items():
        lines.append('\t"%s": {' % boss)
        for pose, (f, sub, face, box, fx) in poses.items():
            src = load(f, sub)
            rgb, alpha = cut(src, BOSS_LO, BOSS_HI)
            rgb = rgb ** BOSS_GAMMA   # darker mid-greys: the boss reads in the mist
            h, w = alpha.shape
            bb = bbox(alpha)
            scale = FIG_PX * RATIO_BOSS.get((boss, pose), RATIO[pose]) / ((box[3] - box[1]) * h)
            ax = ((box[0] + box[2]) / 2 * w - bb[0]) * scale
            ay = (box[3] * h - bb[1]) * scale
            save(mute(rgb, 0.6), alpha, os.path.join(BOSS_OUT, "%s_%s.png" % (boss, pose)), scale=scale, crop_to=bb)
            hard = False
            if (boss, pose) in OWNER_HARD:
                hf, hbox = OWNER_HARD[(boss, pose)]
                hs = load(hf, None)
                hrgb, ha = cut(hs, BOSS_LO, BOSS_HI)
                hb = bbox(ha)
                # same body size as the normal pose
                hscale = scale * ((box[3] - box[1]) * h) / ((hbox[3] - hbox[1]) * hs.height)
                hrgb = np.where(np.repeat(((hrgb.max(axis=2) - hrgb.min(axis=2)) < 0.25)[..., None], 3, axis=2), mute(hrgb, 0.6), hrgb)
                save(hrgb, ha, os.path.join(BOSS_OUT, "%s_%s_hard.png" % (boss, pose)), scale=hscale, crop_to=hb)
                hax = ((hbox[0] + hbox[2]) / 2 * hs.width - hb[0]) * hscale
                hay = (hbox[3] * hs.height - hb[1]) * hscale
                lines.append('\t\t"%s": [%.1f, %.1f, %d, true, %.1f, %.1f, %.4f],' % (pose, ax, ay, face, hax, hay, hscale / scale))
                continue
            if fx:
                r2, a2 = rainbow(mute(rgb, 0.6), alpha, box, zlib.crc32((boss + pose).encode()) & 0xffff, boss in INNER_SMOKE)
                save(r2, a2, os.path.join(BOSS_OUT, "%s_%s_hard.png" % (boss, pose)), scale=scale, crop_to=bb)
                hard = True
            lines.append('\t\t"%s": [%.1f, %.1f, %d, %s],' % (pose, ax, ay, face, "true" if hard else "false"))
            if debug:
                dbg = Image.open(os.path.join(BOSS_OUT, "%s_%s%s.png" % (boss, pose, "_hard" if hard else ""))).convert("RGBA")
                bgc = Image.new("RGBA", dbg.size, (120, 140, 120, 255)); bgc.alpha_composite(dbg)
                d = ImageDraw.Draw(bgc); d.ellipse((ax - 6, ay - 6, ax + 6, ay + 6), fill=(255, 0, 0, 255))
                d.line((ax, ay, ax + face * 40, ay), fill=(255, 0, 0, 255), width=4)
                bgc.convert("RGB").save(os.path.join(debug, "%s_%s.jpg" % (boss, pose)))
        lines.append("\t},")
    lines.append("}")
    with open(POSES_GD, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
