#!/usr/bin/env python3
"""Builds the shipped brand images in media/hub/brand/ from the owner's
sources in reference/art/brand/ (never edit the outputs by hand -- rerun this).

    python tools/brand/make_brand.py            # everything
    python tools/brand/make_brand.py --preview  # also writes before/after sheets to builds/brand_preview/

Needs numpy, scipy and Pillow (`pip install numpy scipy pillow`); not part of
hub.py because nothing else in the project needs them.

What it makes (folders with a .gdignore are never imported, so they add
nothing to the APK unless the exporter itself reads them):
  masters/vskull_logo.png        the V-skull with real alpha (the source JPG has
                                 a fake transparency checkerboard baked into it)
  masters/vskull_logo_small.png  simplified small-size variant (no flames), for
                                 icons that end up 48 px on a launcher
  launcher/                      Android launcher icons named in export_presets.cfg
                                 (the Android exporter reads them straight from disk)
  store/                         Play Store icon 512x512 + feature graphic 1024x500
  boot/splash.png                boot splash (portrait; Godot stores it raw)
  hub_wordmark.png           the VIRAL wordmark for the hub header, edges
                             faded so the backdrop shows through
  hub_bg_portrait.jpg        hub backgrounds, darkened for >= 4.5:1 text contrast
  hub_bg_landscape.jpg
and assets/icon.png, the project icon (PC window + shortcut, Android fallback).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "reference/art/brand"
OUT = ROOT / "media/hub/brand"
PREVIEW = ROOT / "builds/brand_preview"

# Hub text colours that sit straight on the background (Settings.palette()
# dark theme). The background is darkened until the dimmest of them keeps
# 4.5:1 against the brightest 1% of background pixels.
TEXT_ON_BG = {"text_dim": (0.78, 0.7, 0.88), "link": (0.8, 0.45, 1.0),
              "version": (0.7, 0.58, 0.85), "account": (0.92, 0.8, 1.0)}
MIN_CONTRAST = 4.5
NEAR_BLACK = (6, 6, 14)


# ---------------------------------------------------------------- helpers

def load_rgb(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float64)


def to_img(rgba: np.ndarray) -> Image.Image:
    mode = "RGBA" if rgba.shape[2] == 4 else "RGB"
    return Image.fromarray(np.clip(np.rint(rgba), 0, 255).astype(np.uint8), mode)


def srgb_to_lin(c: np.ndarray) -> np.ndarray:
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def rel_lum(rgb: np.ndarray) -> np.ndarray:
    lin = srgb_to_lin(rgb)
    return 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]


def contrast(l1: float, l2: float) -> float:
    hi, lo = max(l1, l2), min(l1, l2)
    return (hi + 0.05) / (lo + 0.05)


def over(fg: Image.Image, bg: Image.Image, xy=(0, 0)) -> Image.Image:
    out = bg.convert("RGBA").copy()
    out.alpha_composite(fg.convert("RGBA"), dest=xy)
    return out


# ---------------------------------------------------------------- checkerboard removal

# Where the V-skull sits in vskull_logo_src.jpg (1264x843): everything inside
# the V's triangle or the skull's dome is logo, never background (the bone
# greys there look like checker squares to the pixel tests).
V_TRIANGLE = [(205, 125), (1055, 125), (632, 835)]
DOME = (635, 210, 142, 134)  # centre x, centre y, radius x, radius y


def _local_level(lum: np.ndarray, mask: np.ndarray, size: int = 61) -> np.ndarray:
    """Average grey of the `mask` pixels around each pixel (nearest value
    where none are in reach)."""
    num = ndimage.uniform_filter(np.where(mask, lum, 0.0), size)
    den = ndimage.uniform_filter(mask.astype(np.float64), size)
    have = den > 0.02
    lvl = num / np.maximum(den, 1e-6)
    _, (iy, ix) = ndimage.distance_transform_edt(~have, return_indices=True)
    return lvl[iy, ix]


def _continue_1d(lab: np.ndarray, direction: int, max_edge_gap: int = 4) -> tuple[np.ndarray, np.ndarray]:
    """Walks one row (or column) of checker labels (+1 light, -1 dark,
    0 unknown) in `direction` and continues the square pattern into each
    unknown stretch, using the edge spacing seen just before it. Returns the
    guesses (0 = no guess) and how far each one reached past the last known pixel."""
    seq = lab if direction == 1 else lab[::-1]
    n = seq.shape[0]
    guess = np.zeros(n)
    dist = np.full(n, np.inf)
    known = np.nonzero(seq)[0]
    if known.size < 2:
        return guess, dist
    edges: list[float] = []
    for a, b in zip(known[:-1], known[1:]):
        gap = b - a
        if gap > max_edge_gap:
            # An unknown stretch: continue the pattern from what came before.
            if len(edges) >= 3:
                p = float(np.median(np.diff(edges[-5:])))
                if 14.0 <= p <= 24.0:
                    xs = np.arange(a + 1, b, dtype=np.float64)
                    e = edges[-1]
                    flips = np.floor((xs - e) / p) - np.floor((a - e) / p)
                    guess[a + 1:b] = seq[a] * np.where(flips % 2 == 0, 1.0, -1.0)
                    dist[a + 1:b] = xs - a
            edges = []  # what follows is a fresh stretch of known squares
        elif seq[b] != seq[a]:
            edges.append((a + b) / 2.0)
    if direction == -1:
        guess, dist = guess[::-1], dist[::-1]
    return guess, dist


def checker_labels(lab: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Continues the known checker labels into the unknown pixels along rows
    and columns, both ways; each pixel keeps the guess that reached least far."""
    h, w = lab.shape
    best = np.zeros((h, w))
    best_d = np.full((h, w), np.inf)

    def take(sl, g, d):
        better = (g != 0) & (d < best_d[sl])
        best[sl] = np.where(better, g, best[sl])
        best_d[sl] = np.where(better, d, best_d[sl])

    for y in range(h):
        for direction in (1, -1):
            take(np.s_[y, :], *_continue_1d(lab[y], direction))
    for x in range(w):
        for direction in (1, -1):
            take(np.s_[:, x], *_continue_1d(lab[:, x], direction))
    return best, best_d


def remove_checkerboard(src: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """RGB with a baked grey checkerboard -> (RGBA with real alpha, mask of
    the opaque V + skull).

    The checker is AI-drawn: two neutral greys (~39 and ~88) in squares of
    17-21 px that drift across the image, so no global grid fits. Instead:
    1. neutral pixels at one of the two levels, or on the blurred step
       between two squares, are background (alpha 0);
    2. under faint glow, the square's grey is read from the pixel's least
       tinted channel (red or blue glow barely moves it); under strong glow,
       the pattern of the clear squares beside it is continued in;
    3. colour-to-alpha against that grey: the smallest alpha that explains
       the pixel as foreground over it (keeps the glow soft and saturated);
    4. the V and the skull (fixed shapes above) are opaque;
    5. faint colourless leftovers (a misread square) and specks are dropped.
    """
    h, w, _ = src.shape
    lum = src.mean(axis=2)
    low = src.min(axis=2)
    chroma = src.max(axis=2) - low

    neutral = chroma < 14
    dark_bg = neutral & (lum > 26) & (lum < 54)
    light_bg = neutral & (lum > 70) & (lum < 106)
    near_dark = ndimage.binary_dilation(dark_bg, iterations=3)
    near_light = ndimage.binary_dilation(light_bg, iterations=3)
    step_bg = neutral & (lum >= 54) & (lum <= 70) & near_dark & near_light
    bg = dark_bg | light_bg | step_bg

    lvl_dark = _local_level(lum, dark_bg)
    lvl_light = _local_level(lum, light_bg)
    # Faint glow: the least tinted channel still shows the square's grey.
    mid = (lvl_dark + lvl_light) / 2
    sure_light = low > mid + 10
    sure_dark = low < lvl_dark + 8
    # Strong glow: continue the square pattern in from the clear squares
    # around it (rows and columns; the grid changes size between bands of
    # the image, so it's followed locally, never fitted globally).
    known = np.where(light_bg, 1.0, np.where(dark_bg, -1.0, 0.0))
    known = np.where(ndimage.binary_erosion(light_bg | dark_bg, iterations=1), known, 0.0)
    cont, reach = checker_labels(known)
    light = np.where(sure_light, True, np.where(sure_dark, False, low > mid))
    use_cont = ~sure_light & ~sure_dark & (cont != 0) & (reach < 90)
    light = np.where(use_cont, cont > 0, light)
    light = np.where(light_bg, True, np.where(dark_bg, False, light))
    b = np.where(light, lvl_light, lvl_dark)
    b = np.where(step_bg, lum, b)
    B = np.repeat(b[..., None], 3, axis=2)

    up = np.where(src > B, (src - B) / np.maximum(255.0 - B, 1e-6), 0.0)
    down = np.where(src < B, (B - src) / np.maximum(B, 1e-6), 0.0)
    alpha = np.max(np.maximum(up, down), axis=2)
    alpha[bg] = 0.0

    # The V + skull: opaque.
    shape = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(shape)
    d.polygon(V_TRIANGLE, fill=255)
    cx, cy, rx, ry = DOME
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
    inside = np.asarray(shape) > 0
    # Only where the logo really is: the triangle's top edge and the dome's
    # rim also cross some glow and background.
    solid = ndimage.binary_fill_holes(alpha > 0.5) & inside
    solid = ndimage.binary_erosion(ndimage.binary_dilation(solid, iterations=2), iterations=2)
    solid = ndimage.binary_fill_holes(solid) & inside

    a = np.where(solid, 1.0, alpha)
    safe = np.maximum(a, 1e-6)[..., None]
    fgc = np.clip((src - (1.0 - a)[..., None] * B) / safe, 0, 255)
    fgc = np.where(solid[..., None], src, fgc)

    # A misread square comes out as faint grey "foreground"; real glow is coloured.
    f_chroma = fgc.max(axis=2) - fgc.min(axis=2)
    ghost = ~solid & (a < 0.18) & (f_chroma < 50)
    a = np.where(ghost, 0.0, a)

    # Noise floor + specks.
    a = np.clip((a - 0.04) / 0.96, 0, 1)
    # Keep the logo itself, plus loose wisps only if they're coloured glow
    # (stray checker squares that slipped through are grey).
    keep = a > 0.03
    lab, n = ndimage.label(keep)
    if n:
        idx = np.arange(1, n + 1)
        sizes = ndimage.sum(keep, lab, index=idx)
        colour = ndimage.mean(f_chroma, lab, index=idx)
        main = int(np.argmax(sizes)) + 1
        ok = (idx == main) | ((sizes >= 40) & (colour > 80))
        keep = np.isin(lab, idx[ok])
    a = np.where(keep, a, 0.0)
    # Soften the outer edge a little so it never reads as a cut-out halo.
    a = np.where(solid, 1.0, np.minimum(ndimage.gaussian_filter(a, 0.8), 1.0))
    return np.dstack([fgc, a * 255.0]), solid


def trim(img: Image.Image, pad: int = 8) -> Image.Image:
    bbox = img.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox()
    if not bbox:
        return img
    l, t, r, b = bbox
    return img.crop((max(l - pad, 0), max(t - pad, 0), min(r + pad, img.width), min(b + pad, img.height)))


def body_only(src: np.ndarray, solid: np.ndarray) -> Image.Image:
    """Small-size variant: only the V + skull (no flames, no wide glow), with
    a thin glow in its own edge colours so it still reads as neon at 48 px."""
    core = solid.astype(np.float64)
    edge_a = ndimage.gaussian_filter(core, 0.8)
    glow = ndimage.gaussian_filter(core, 5.0)
    alpha = np.maximum(edge_a, glow * 0.6)
    weight = glow[..., None]
    edge_rgb = ndimage.gaussian_filter(src * core[..., None], (5, 5, 0)) / np.maximum(weight, 1e-6)
    rgb = np.where(solid[..., None], src, np.clip(edge_rgb * 1.4, 0, 255))
    return to_img(np.dstack([rgb, alpha * 255.0]))


def vskull_glyph(canvas: int = 432) -> Image.Image:
    """Monochrome (themed) icon: the V-skull redrawn as flat vector shapes --
    Android tints it one colour, so it has to read by shape alone, and the
    painted logo's lines turn to blobs when flattened. Drawn at 4x and
    scaled down for smooth edges. Coordinates are for the 432 px canvas;
    everything stays inside the 264 px safe circle."""
    k = 4
    s = canvas * k / 432.0

    def P(x, y):
        return (x * s, y * s)

    v = Image.new("L", (canvas * k, canvas * k), 0)
    d = ImageDraw.Draw(v)
    # The V: outer triangle minus the inner one (arms ~20 px thick).
    outer = [(106, 146), (326, 146), (216, 346)]
    inc = (216.0, 211.0)  # incentre of `outer`
    f = 0.69
    inner = [(inc[0] + f * (x - inc[0]), inc[1] + f * (y - inc[1])) for x, y in outer]
    d.polygon([P(*p) for p in outer], fill=255)
    d.polygon([P(*p) for p in inner], fill=0)

    skull = Image.new("L", v.size, 0)
    ds = ImageDraw.Draw(skull)
    # Dome rising above the V's top edge, jaw narrowing into the V.
    ds.ellipse([*P(166, 132), *P(266, 230)], fill=255)
    ds.polygon([P(176, 200), P(256, 200), P(240, 262), P(192, 262)], fill=255)
    # Holes: angry eyes, nose, three tooth gaps.
    ds.polygon([P(182, 188), P(208, 196), P(206, 212), P(186, 208)], fill=0)
    ds.polygon([P(250, 188), P(224, 196), P(226, 212), P(246, 208)], fill=0)
    ds.polygon([P(216, 216), P(208, 232), P(224, 232)], fill=0)
    for x in (202, 216, 230):
        ds.rectangle([*P(x - 2.5, 244), *P(x + 2.5, 262)], fill=0)

    # A gap around the skull so it reads apart from the V's arms.
    sk = np.asarray(skull) > 0
    solid_skull = ndimage.binary_fill_holes(sk)
    gap = ndimage.binary_dilation(solid_skull, iterations=int(7 * s))
    vv = (np.asarray(v) > 0) & ~gap
    m = (vv | sk).astype(np.float64) * 255.0
    big = Image.fromarray(m.astype(np.uint8), "L")
    a = big.resize((canvas, canvas), Image.LANCZOS)
    white = Image.new("RGBA", (canvas, canvas), (255, 255, 255, 0))
    white.putalpha(a)
    return white


# ---------------------------------------------------------------- compositions

def fit_in_circle(logo: Image.Image, diameter: float, canvas: int) -> Image.Image:
    """Scales `logo` so its solid pixels sit inside a centred circle of
    `diameter` px on a transparent `canvas`-square image."""
    a = np.asarray(logo.getchannel("A")) > 200
    ys, xs = np.nonzero(a)
    # Smallest circle around the solid pixels, centred on their bbox centre
    # moved up or down (the V is a triangle: heavy at the top).
    cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
    best = None
    for fy in np.linspace(-0.25, 0.25, 21):
        c_y = cy + fy * (ys.max() - ys.min())
        r = np.sqrt((xs - cx) ** 2 + (ys - c_y) ** 2).max()
        if best is None or r < best[0]:
            best = (r, cx, c_y)
    r, cx, c_y = best
    scale = (diameter / 2) / r
    big = logo.resize((max(1, round(logo.width * scale)), max(1, round(logo.height * scale))), Image.LANCZOS)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(big, (round(canvas / 2 - cx * scale), round(canvas / 2 - c_y * scale)), big)
    return out


def dark_crop(bg: Image.Image, size: tuple[int, int], center=(0.5, 0.5), dim=0.35, blur=0.0) -> Image.Image:
    """Cover-crop `bg` to `size` around `center` (fractions), scaled by `dim`."""
    tw, th = size
    scale = max(tw / bg.width, th / bg.height)
    big = bg.resize((round(bg.width * scale), round(bg.height * scale)), Image.LANCZOS)
    cx = int(center[0] * big.width - tw / 2)
    cy = int(center[1] * big.height - th / 2)
    cx = min(max(cx, 0), big.width - tw)
    cy = min(max(cy, 0), big.height - th)
    crop = big.crop((cx, cy, cx + tw, cy + th))
    if blur:
        crop = crop.filter(ImageFilter.GaussianBlur(blur))
    arr = np.asarray(crop.convert("RGB")).astype(np.float64) * dim
    return to_img(arr)


def darken_for_text(img: Image.Image) -> tuple[Image.Image, float, float]:
    """Darkens until the dimmest TEXT_ON_BG colour has MIN_CONTRAST against
    the 99th-percentile background luminance. Returns (image, factor, ratio)."""
    arr = np.asarray(img.convert("RGB")).astype(np.float64)
    text_l = min(rel_lum(np.array(c) * 255.0) for c in TEXT_ON_BG.values())
    factor = 1.0
    for _ in range(60):
        l99 = float(np.percentile(rel_lum(arr * factor), 99))
        if contrast(text_l, l99) >= MIN_CONTRAST:
            break
        factor *= 0.95
    l99 = float(np.percentile(rel_lum(arr * factor), 99))
    return to_img(arr * factor), factor, contrast(text_l, l99)


def feather_edges(img: Image.Image, frac: float = 0.16) -> Image.Image:
    """Fades the image's own backdrop out towards every edge."""
    w, h = img.size
    yy, xx = np.mgrid[0:h, 0:w]
    dx = np.minimum(xx, w - 1 - xx) / (frac * w)
    dy = np.minimum(yy, h - 1 - yy) / (frac * h)
    m = np.clip(np.minimum(dx, dy), 0, 1)
    m = m * m * (3 - 2 * m)
    arr = np.asarray(img.convert("RGBA")).astype(np.float64)
    arr[..., 3] *= m
    return to_img(arr)


def lockup(bg: Image.Image, wordmark: Image.Image, center_y: float) -> Image.Image:
    """`bg` with the wordmark scene at its native size (it is only 598x393,
    so any upscaling turns it soft), faded into the background at its edges.
    The VIRAL lettering can't be cut out of that scene cleanly (pink brush
    strokes over red lightning, the V running through them), so the whole
    scene is the lockup until there's a separate lettering file."""
    out = bg.convert("RGBA")
    fw = feather_edges(wordmark, 0.28)
    out.alpha_composite(fw, (round(out.width / 2 - fw.width / 2), round(out.height * center_y - fw.height / 2)))
    return out


# ---------------------------------------------------------------- main

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    args = ap.parse_args()
    for sub in ("launcher", "store", "boot", "masters"):
        (OUT / sub).mkdir(parents=True, exist_ok=True)
        (OUT / sub / ".gdignore").touch()

    src = load_rgb(SRC / "vskull_logo_src.jpg")
    full_rgba, solid = remove_checkerboard(src)
    full = to_img(full_rgba)
    logo = trim(full, pad=24)
    logo.save(OUT / "masters/vskull_logo.png")
    small = trim(body_only(src, solid), pad=16)
    small.save(OUT / "masters/vskull_logo_small.png")
    print(f"  vskull_logo.png {logo.size}, vskull_logo_small.png {small.size}")

    bg_src = Image.open(SRC / "background.jpg").convert("RGB")
    wordmark = Image.open(SRC / "viral_logo_wordmark.png").convert("RGB")

    # Launcher icons. Adaptive icons: 108 dp canvas = 432 px; the launcher's
    # mask shows the middle 72 dp (288 px) and never cuts inside 66 dp
    # (264 px). They end up ~48 px on a home screen, so they use the small
    # variant (no flames).
    icon_bg = dark_crop(bg_src, (432, 432), center=(0.5, 0.3), dim=0.2, blur=3.0)
    icon_bg.save(OUT / "launcher/adaptive_background_432.png")
    fg = fit_in_circle(small, 256, 432)
    fg.save(OUT / "launcher/adaptive_foreground_432.png")
    vskull_glyph().save(OUT / "launcher/adaptive_monochrome_432.png")
    # Android < 8 shows this one as is: full-bleed square.
    main_icon = over(fit_in_circle(small, 170, 192), dark_crop(bg_src, (192, 192), (0.5, 0.3), 0.2, 1.5))
    main_icon.convert("RGB").save(OUT / "launcher/main_192.png")

    # Project icon (PC window/shortcut, where it's also shown at 16-32 px).
    project_icon = over(fit_in_circle(small, 900, 1024), dark_crop(bg_src, (1024, 1024), (0.5, 0.3), 0.2, 4.0))
    project_icon.convert("RGB").save(ROOT / "assets/icon.png")

    # Play Store icon: full-bleed square, 32-bit PNG, no own rounding (Play masks it).
    store_icon = over(fit_in_circle(logo, 440, 512), dark_crop(bg_src, (512, 512), (0.5, 0.3), 0.28, 2.0))
    store_icon.save(OUT / "store/play_icon_512.png")  # RGBA = 32-bit

    # Play feature graphic 1024x500 and the boot splash (portrait; Godot
    # scales it to fit the screen and fills the rest with its bg colour).
    feat = lockup(dark_crop(bg_src, (1024, 500), center=(0.5, 0.45), dim=0.5), wordmark, 0.5)
    feat.convert("RGB").save(OUT / "store/feature_graphic_1024x500.png")
    splash = lockup(dark_crop(bg_src, (1080, 1920), center=(0.5, 0.5), dim=0.4), wordmark, 0.45)
    splash.convert("RGB").save(OUT / "boot/splash.png", optimize=True)

    # Hub header wordmark: native size, its backdrop faded at the edges.
    feather_edges(wordmark, 0.14).save(OUT / "hub_wordmark.png")

    # Hub backgrounds.
    port, f1, c1 = darken_for_text(dark_crop(bg_src, (720, 1280), center=(0.5, 0.5), dim=1.0))
    land, f2, c2 = darken_for_text(dark_crop(bg_src, (1280, 720), center=(0.5, 0.5), dim=1.0))
    port.save(OUT / "hub_bg_portrait.jpg", quality=88)
    land.save(OUT / "hub_bg_landscape.jpg", quality=88)
    print(f"  hub backgrounds darkened x{f1:.2f} / x{f2:.2f}: dimmest text {c1:.2f}:1 / {c2:.2f}:1")

    if args.preview:
        PREVIEW.mkdir(parents=True, exist_ok=True)
        (PREVIEW / ".gdignore").touch()  # builds/ is inside the Godot project
        before = Image.open(SRC / "vskull_logo_src.jpg").convert("RGBA")
        tiles = [before]
        for colour in [(0, 0, 0), (255, 255, 255), (255, 0, 255)]:
            tiles.append(over(full, Image.new("RGBA", full.size, colour + (255,))))
        tiles.append(over(full, dark_crop(bg_src, full.size, dim=0.35)))
        tw, th = full.width // 2, full.height // 2
        sheet = Image.new("RGBA", (tw * 3, th * 2), (20, 20, 20, 255))
        for i, t in enumerate(tiles):
            sheet.paste(t.resize((tw, th), Image.LANCZOS), ((i % 3) * tw, (i // 3) * th))
        sheet.convert("RGB").save(PREVIEW / "logo_before_after.png")
        # Launcher icons at real sizes: the visible 72 dp middle, circle-masked.
        wall = Image.new("RGBA", (420, 330), (30, 30, 40, 255))
        d = ImageDraw.Draw(wall)
        full_fg = fit_in_circle(logo, 256, 432)
        x = 10
        for size in (48, 72, 96, 144):
            for row, layer in ((0, full_fg), (1, fg)):
                ic = over(layer, icon_bg).crop((72, 72, 360, 360)).resize((size, size), Image.LANCZOS)
                m = Image.new("L", (size, size), 0)
                ImageDraw.Draw(m).ellipse((0, 0, size - 1, size - 1), fill=255)
                ic.putalpha(m)
                wall.alpha_composite(ic, (x, 10 + row * 155))
            x += size + 12
        d.text((10, 312), "top: full logo    bottom: small variant (shipped)", fill=(220, 220, 220))
        wall.convert("RGB").save(PREVIEW / "icons_at_size.png")
        print(f"  previews in {PREVIEW.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
