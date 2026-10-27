#!/usr/bin/env python3
"""Imports the owner's Poker art (Gemini images in D:/dev/minigame art/poker/<look>/game art/)
into the game: games/video_poker/art/<look>/<slot>.webp, the slots video_poker_look.gd reads.

    python tools/poker_art_import.py "D:/dev/minigame art/poker" classic [--out DIR]

What it does (the source pictures are photos of cards on a marble table and chips on a fake
checkerboard, not clean assets):
  - card back and the 16 face cards (A J Q K x 4 suits): finds the card's outer edge, cuts it out
    with rounded corners (transparent outside) and saves 350x500 (5:7);
  - card_face: the card back with its crest painted out, a blank marble face for the number cards
    (their pips are drawn in code);
  - chips: the 3x3 sheet is cut into chip_1..chip_6 (white red blue green black gold; the third row
    is a spare set and ignored) on a transparent background; dealer: the same;
  - table_portrait: the empty table, as is.
Source names -> slots are in FACES below ("queen spades2" is an alternate; the owner picks).
Writes the .import files too (lossy, so the pack stays small) and prints what it did.
Needs numpy, scipy and Pillow. The sources stay outside the repo.
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parent.parent
CARD_W, CARD_H = 350, 500
# slot -> source file stem (lowercase). Clubs are the "treble" files; "ERROR TREBLE CLEF QUEEN" is a reject.
FACES = {
    "A_s": "ace spades", "J_s": "jack spades", "Q_s": "queen spades", "K_s": "spades king",
    "A_h": "ace of hearts", "J_h": "jack of hearts", "Q_h": "queen of hearts", "K_h": "king of hearts",
    "A_d": "diamonds ace", "J_d": "diamonds jack", "Q_d": "queen diamonds", "K_d": "king diamonds",
    "A_c": "treble ace", "J_c": "treble jack", "Q_c": "treble queen", "K_c": "treble king",
}
BACK = "card"
CHIP_SHEET = "chips"
DEALER = "dealer"
TABLE = "table"
# Row-major cells of the 3x3 chip sheet used for chip_1..chip_6 (white red blue / green black gold).
CHIP_CELLS = [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2)]


def find_source(folder: Path, stem: str) -> Path:
    for p in folder.iterdir():
        if p.stem.lower() == stem.lower() and p.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp"):
            return p
    raise FileNotFoundError(f"{stem} not found in {folder}")


def card_rect(img: Image.Image) -> tuple[int, int, int, int]:
    """The card's outer edge (l, t, r, b): first the frame inside it (the strongest long lines),
    then the thin bright rim a little outside that, found by edge strength along each side."""
    g = ndi.gaussian_filter(np.asarray(img.convert("L"), dtype=float), 1.0)
    gx = np.abs(ndi.sobel(g, axis=1))
    gy = np.abs(ndi.sobel(g, axis=0))
    h, w = g.shape
    cp = gx[h // 4:3 * h // 4].sum(axis=0)
    rp = gy[:, w // 4:3 * w // 4].sum(axis=1)
    il = int(np.argmax(cp[:w // 3]))
    ir = int(2 * w // 3 + np.argmax(cp[2 * w // 3:]))
    it = int(np.argmax(rp[:h // 3]))
    ib = int(2 * h // 3 + np.argmax(rp[2 * h // 3:]))
    bw, bh = ir - il, ib - it
    ys = slice(it + int(bh * 0.2), ib - int(bh * 0.2))
    xs = slice(il + int(bw * 0.2), ir - int(bw * 0.2))
    reach = range(14, 80)
    left = max(reach, key=lambda d: gx[ys, il - d].mean())
    right = max(reach, key=lambda d: gx[ys, min(w - 1, ir + d)].mean())
    top = max(reach, key=lambda d: gy[it - d, xs].mean())
    bottom = max(reach, key=lambda d: gy[min(h - 1, ib + d), xs].mean())
    return il - left, it - top, ir + right, ib + bottom


def cut_card(src: Path) -> Image.Image:
    img = Image.open(src).convert("RGB")
    l, t, r, b = card_rect(img)
    inset = 2  # drop the rim's halo
    crop = img.crop((l + inset, t + inset, r - inset, b - inset)).resize((CARD_W * 2, CARD_H * 2), Image.LANCZOS)
    rad = int(CARD_W * 2 * 0.058)
    mask = Image.new("L", crop.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, crop.width - 1, crop.height - 1), rad, fill=255)
    out = crop.convert("RGBA")
    out.putalpha(mask)
    return out.resize((CARD_W, CARD_H), Image.LANCZOS)


def blank_face(back: Image.Image) -> Image.Image:
    """The card back with the crest painted out: a dark marble face for the number cards."""
    a = np.asarray(back.convert("RGB"), dtype=float)
    h, w, _ = a.shape
    inner = np.zeros((h, w), dtype=bool)
    mx, my = int(w * 0.075), int(h * 0.06)
    inner[my:h - my, mx:w - mx] = True
    # the marble between the crest and the frame, diffused over the middle
    base = a.copy()
    fill = a.copy()
    known = ~inner
    # grow colour inwards by repeated blurring of the known region
    acc = np.where(known[..., None], a, 0.0)
    wgt = known.astype(float)
    for sigma in (30, 30, 30, 30, 30, 30):
        num = np.stack([ndi.gaussian_filter(acc[..., c], sigma) for c in range(3)], axis=-1)
        den = ndi.gaussian_filter(wgt, sigma)[..., None]
        est = num / np.maximum(den, 1e-6)
        fill = np.where(known[..., None], a, est)
        acc = fill
        wgt = np.ones_like(wgt)
    # marble veins from smoothed noise
    rng = np.random.default_rng(7)
    n = sum(ndi.gaussian_filter(rng.standard_normal((h, w)), s) * s for s in (3, 7, 18))
    n = (n - n.mean()) / (n.std() + 1e-6)
    veins = np.exp(-np.abs(n) * 5.0)
    mottle = ndi.gaussian_filter(rng.standard_normal((h, w)), 12)
    mottle = mottle / (np.abs(mottle).max() + 1e-6)
    lum = fill.mean(axis=2, keepdims=True)
    face = fill * (0.9 + 0.22 * mottle[..., None]) + veins[..., None] * np.array([12.0, 20.0, 16.0])
    face = np.clip(face, 0, 255)
    # keep the original frame ring untouched at the edge of the inner area
    soft = ndi.gaussian_filter(inner.astype(float), 3)[..., None]
    out = a * (1 - soft) + face * soft
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).convert("RGBA")
    img.putalpha(back.getchannel("A"))
    return img


def checker_mask(a: np.ndarray) -> np.ndarray:
    """True where a pixel is the fake transparency checkerboard: two greys, ~205 and ~255."""
    mean = a.mean(axis=2)
    chroma = a.max(axis=2) - a.min(axis=2)
    return (chroma < 12) & (((mean >= 188) & (mean <= 218)) | (mean >= 243))


def cut_discs(img: Image.Image, cells: list[tuple[int, int]], rows: int, cols: int, size: int) -> list[Image.Image]:
    a = np.asarray(img.convert("RGB"), dtype=float)
    h, w, _ = a.shape
    cw, ch = w / cols, h / rows
    found = []
    for r, c in cells:
        x0, y0, x1, y1 = int(c * cw), int(r * ch), int((c + 1) * cw), int((r + 1) * ch)
        cell = a[y0:y1, x0:x1]
        solid = ndi.binary_opening(~checker_mask(cell), iterations=4)
        lab, n = ndi.label(solid)
        if n == 0:
            raise RuntimeError("empty chip cell")
        # The chip's centre is the biggest piece's centre (the body or inner disc, concentric with the rim).
        sizes = ndi.sum(solid, lab, range(1, n + 1))
        cy, cx = ndi.center_of_mass(lab == (1 + int(np.argmax(sizes))))
        # Its radius is where the real pixels end along most rays (a white chip's rim is the colour of the
        # fake checkerboard, so only its coloured stripes reach the edge, and a neighbour's edge can intrude).
        hh, ww = solid.shape
        reach = []
        for ang in np.linspace(0, 2 * np.pi, 360, endpoint=False):
            far = 0
            for rr in range(int(min(hh, ww) * 0.2), int(min(hh, ww) * 0.62)):
                x, y = int(cx + rr * np.cos(ang)), int(cy + rr * np.sin(ang))
                if 0 <= x < ww and 0 <= y < hh and solid[y, x]:
                    far = rr
            reach.append(far)
        found.append((x0, y0, cx, cy, float(np.percentile(reach, 92))))
    # All the chips on a sheet are one size: the median radius beats a single chip's guess.
    rad = float(np.median([f[4] for f in found]))
    out = []
    for x0, y0, cx, cy, _ in found:
        pad = rad * 1.04
        piece = img.crop((int(x0 + cx - pad), int(y0 + cy - pad), int(x0 + cx + pad), int(y0 + cy + pad))).convert("RGBA")
        big = piece.resize((size * 2, size * 2), Image.LANCZOS)
        m = Image.new("L", big.size, 0)
        edge = size * 2 * (1 - rad / pad) / 2
        ImageDraw.Draw(m).ellipse((edge, edge, size * 2 - edge, size * 2 - edge), fill=255)
        big.putalpha(m.filter(ImageFilter.GaussianBlur(1.2)))
        out.append(big.resize((size, size), Image.LANCZOS))
    return out


def save(img: Image.Image, path: Path, quality: int = 86) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "WEBP", quality=quality, method=6)
    write_import(path)
    shown = path.relative_to(ROOT) if ROOT in path.parents else path
    print(f"  {shown}  {img.size[0]}x{img.size[1]}  {path.stat().st_size // 1024} KB")


IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://{res}"

[params]

compress/mode=1
compress/high_quality=false
compress/lossy_quality=0.85
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


def write_import(path: Path) -> None:
    if ROOT not in path.parents:
        return  # not inside the project (a trial run): nothing to import
    imp = path.with_name(path.name + ".import")
    if imp.exists():
        return  # Godot has already imported it: keep its uid and settings
    imp.write_text(IMPORT.format(res=path.relative_to(ROOT).as_posix()), encoding="utf-8", newline="\n")


def add_credits(out: Path, look: str, src: Path) -> None:
    """Adds a media/CREDITS.json entry for every art file in `out` that has none (STANDARDS section 10)."""
    import datetime
    import json
    path = ROOT / "media" / "CREDITS.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    have = {e.get("file") for e in data["assets"]}
    added = 0
    what = {"card_back": "card back", "card_face": "blank card face for the number cards (the card back with the crest painted out)",
            "dealer": "dealer button", "table_portrait": "empty top-down table"}
    for f in sorted(out.glob("*.webp")):
        rel = f.relative_to(ROOT).as_posix()
        if rel in have:
            continue
        stem = f.stem
        if stem.startswith("face_"):
            label = f"face card / ace {stem[5:].replace('_', ' of ')} (s h d c = spades hearts diamonds clubs)"
        elif stem.startswith("chip_"):
            label = f"poker chip {stem[5:]} (white red blue green black gold)"
        else:
            label = what.get(stem, stem)
        data["assets"].append({
            "file": rel,
            "what": f"Poker ({look} look): {label}",
            "source": f"the owner's picture in {src} (outside the repo; also Google Drive > Viral Game Hub > poker)",
            "author": "Viral (owner)",
            "licence": "owner-proprietary",
            "proof": "media/licenses/OWNER_GAME_ART.md",
            "url": "",
            "date": datetime.date.today().isoformat(),
            "ai_tool": "Google Gemini (owner)",
            "ai_plan": "plan not stated by the owner",
            "processed_by": "tools/poker_art_import.py (cut out of the photo, rounded corners / background removed, WebP) (Claude Code)",
        })
        added += 1
    path.write_text(json.dumps(data, indent=1, ensure_ascii=False) + chr(10), encoding="utf-8", newline=chr(10))
    print(f"CREDITS.json: {added} entries added")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("look")
    ap.add_argument("--out", default=str(ROOT / "games" / "video_poker" / "art"))
    ap.add_argument("--only", default="", help="comma list of slots, e.g. card_back,A_s")
    ap.add_argument("--credits", action="store_true", help="add the media/CREDITS.json entries for the files written")
    args = ap.parse_args()
    folder = Path(args.src) / args.look / "game art"
    out = Path(args.out) / args.look
    only = {s for s in args.only.split(",") if s}
    want = lambda s: not only or s in only
    print(f"{folder} -> {out}")
    back = None
    if want("card_back") or want("card_face"):
        back = cut_card(find_source(folder, BACK))
    if want("card_back"):
        save(back, out / "card_back.webp")
    if want("card_face"):
        save(blank_face(back), out / "card_face.webp")
    for slot, stem in FACES.items():
        if want(f"face_{slot}"):
            save(cut_card(find_source(folder, stem)), out / f"face_{slot}.webp")
    if want("chips"):
        chips = cut_discs(Image.open(find_source(folder, CHIP_SHEET)), CHIP_CELLS, 3, 3, 256)
        for i, ch in enumerate(chips, 1):
            save(ch, out / f"chip_{i}.webp")
    if want("dealer"):
        d = cut_discs(Image.open(find_source(folder, DEALER)), [(0, 0)], 1, 1, 256)[0]
        save(d, out / "dealer.webp")
    if want("table_portrait"):
        t = Image.open(find_source(folder, TABLE)).convert("RGB")
        save(t, out / "table_portrait.webp", quality=84)
    if args.credits:
        add_credits(out, args.look, folder)
    return 0


if __name__ == "__main__":
    sys.exit(main())
