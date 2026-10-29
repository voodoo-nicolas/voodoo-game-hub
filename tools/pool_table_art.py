"""Builds Pool's two top-down tables from the owner's art (2026-10-29).

The owner's pictures (reference/art/games/pool_table_*_src.jpg) are a square
and a 4:3 table with one side pocket each; a real pool table's playing
surface is 2:1 with a side pocket in the middle of each long rail. Nothing is
stretched out of shape: the picture is cut into pieces and laid out again at
the game's proportions (scripts/games/pool/pool_engine.gd W x H, rail RAIL in
pool_game.gd):
- one corner (pocket + rail joint), mirrored into all four corners;
- a clean stretch of rail between two diamonds, stretched along the wood
  grain to the rail's length;
- the side pocket, put in the middle of both long rails;
- one diamond, re-laid at the regulation spots (quarters of the short rail,
  eighths of the long rails);
- the cloth, mirror-tiled from a patch with no logo on it, the logo pasted in
  the middle with a soft edge, a cushion shadow round the edge.

    python tools/pool_table_art.py        # writes games/pool/table_*.jpg
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "games" / "pool"

W, H = 500, 1000      # pool_engine.gd playing surface (world units)
RAIL = 42             # pool_game.gd RAIL: wood + cushion, world units
PX = 1.6              # output pixels per world unit
B = round(RAIL * PX)  # rail band in output pixels
SW, SH = round(W * PX), round(H * PX)

# Measured on the source pictures (pixels of the source).
SOURCES = {
    "classic": {
        "src": "pool_table_classic_src.jpg",
        "band": 75,                 # outer edge to cushion nose, top and left
        "top_clean": (205, 282),    # rail between two diamonds, no diamond
        "left_clean": (207, 278),
        "diamond_x": 296,           # a top-rail diamond
        "side": ("left", 511, 75),  # side pocket: which rail, centre, its band
        "logo": (275, 295, 735, 765),
        "felt": (110, 110, 330, 290),   # plain cloth, no logo or glow
        "logo_w": 0.56,             # logo width / surface width
        "vignette": 0.10,
    },
    "voodoo": {
        "src": "pool_table_voodoo_src.jpg",
        "band": 75,
        "top_clean": (216, 292),
        "left_clean": (207, 287),
        "diamond_x": 306,
        "side": ("bottom", 600, 72),
        "logo": (360, 245, 835, 700),
        "felt": (120, 110, 330, 240),
        "logo_w": 0.60,
        "vignette": 0.22,
    },
}


def feather_mask(size, edges, fw):
    """White mask, fading to black over fw pixels on the given edges ("ltrb")."""
    w, h = size
    m = Image.new("L", size, 255)
    px = m.load()
    for y in range(h):
        for x in range(w):
            a = 1.0
            if "l" in edges:
                a = min(a, x / fw)
            if "r" in edges:
                a = min(a, (w - 1 - x) / fw)
            if "t" in edges:
                a = min(a, y / fw)
            if "b" in edges:
                a = min(a, (h - 1 - y) / fw)
            px[x, y] = int(255 * max(0.0, min(1.0, a)))
    return m


def mirror_fill(patch, size):
    """Fills size by tiling patch mirrored, so no seams show."""
    pw, ph = patch.size
    block = Image.new("RGB", (pw * 2, ph * 2))
    block.paste(patch, (0, 0))
    block.paste(patch.transpose(Image.FLIP_LEFT_RIGHT), (pw, 0))
    block.paste(patch.transpose(Image.FLIP_TOP_BOTTOM), (0, ph))
    block.paste(patch.transpose(Image.ROTATE_180), (pw, ph))
    out = Image.new("RGB", size)
    for y in range(0, size[1], ph * 2):
        for x in range(0, size[0], pw * 2):
            out.paste(block, (x, y))
    return out


def build(name, s):
    src = Image.open(ROOT / "reference" / "art" / "games" / s["src"]).convert("RGB")
    f = B / s["band"]
    src = src.resize((round(src.width * f), round(src.height * f)), Image.LANCZOS)

    def sc(v):
        return round(v * f)

    out = Image.new("RGB", (SW + 2 * B, SH + 2 * B))
    ow, oh = out.size

    # Cloth: the colour round the logo plus the patch's weave (its fine
    # detail only, so the patch's own light falloff can't band when tiled).
    lx0, ly0, lx1, ly1 = (sc(v) for v in s["logo"])
    logo = src.crop((lx0, ly0, lx1, ly1))
    ring = [logo.getpixel((x, y)) for x in range(0, logo.width, 4) for y in (2, logo.height - 3)]
    ring += [logo.getpixel((x, y)) for y in range(0, logo.height, 4) for x in (2, logo.width - 3)]
    flat = tuple(sorted(p[i] for p in ring)[len(ring) // 2] for i in range(3))
    fx0, fy0, fx1, fy1 = (sc(v) for v in s["felt"])
    patch = src.crop((fx0, fy0, fx1, fy1))
    weave = ImageChops.subtract(patch, patch.filter(ImageFilter.GaussianBlur(10)), 1.0, 128)
    felt = ImageChops.add(Image.new("RGB", (SW, SH), flat), mirror_fill(weave, (SW, SH)), 1.0, -128)
    # Logo, soft-edged.
    lw = round(SW * s["logo_w"])
    logo = logo.resize((lw, round(logo.height * lw / logo.width)), Image.LANCZOS)
    m = Image.new("L", logo.size, 0)
    inset = round(min(logo.size) * 0.06)
    ImageDraw.Draw(m).ellipse((inset, inset, logo.width - inset, logo.height - inset), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(min(logo.size) * 0.07))
    felt.paste(logo, ((SW - logo.width) // 2, (SH - logo.height) // 2), m)
    # Cushion shadow and a light vignette.
    shade = Image.new("L", (SW, SH), 0)
    d = ImageDraw.Draw(shade)
    for i in range(14):
        d.rectangle((i, i, SW - 1 - i, SH - 1 - i), outline=int(150 * (1 - i / 14) ** 2))
    vig = Image.new("L", (SW, SH), 0)
    ImageDraw.Draw(vig).ellipse((-SW * 0.35, -SH * 0.2, SW * 1.35, SH * 1.2), fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(SW * 0.2)).point(lambda v: int((255 - v) * s["vignette"]))
    shade = ImageChops.lighter(shade, vig)
    felt = Image.composite(Image.new("RGB", felt.size, (0, 0, 0)), felt, shade)
    out.paste(felt, (B, B))

    # Rails: a clean stretch, stretched along the grain.
    t0, t1 = (sc(v) for v in s["top_clean"])
    top = src.crop((t0, 0, t1, B)).resize((ow, B), Image.LANCZOS)
    out.paste(top, (0, 0))
    out.paste(top.transpose(Image.FLIP_TOP_BOTTOM), (0, oh - B))
    l0, l1 = (sc(v) for v in s["left_clean"])
    left = src.crop((0, l0, B, l1)).resize((B, oh), Image.LANCZOS)
    out.paste(left, (0, 0))
    out.paste(left.transpose(Image.FLIP_LEFT_RIGHT), (ow - B, 0))

    # Diamonds: cut one out by its gold colour, re-lay it at the regulation spots.
    dx = sc(s["diamond_x"])
    box = src.crop((dx - sc(16), 0, dx + sc(16), B))
    gold = [(x, y) for y in range(box.height) for x in range(box.width)
            if (lambda p: p[0] > 150 and p[1] > 115 and p[2] < 160 and p[0] - p[2] > 40)(box.getpixel((x, y)))]
    xs = [p[0] for p in gold]
    ys = [p[1] for p in gold]
    dia = box.crop((min(xs) - 2, min(ys) - 2, max(xs) + 3, max(ys) + 3))
    dm = Image.new("L", dia.size, 0)
    for x, y in gold:
        dm.putpixel((x - min(xs) + 2, y - min(ys) + 2), 255)
    dm = dm.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    dcy = (min(ys) + max(ys)) // 2  # depth of the diamond in the rail
    for i in (1, 2, 3):
        x = B + SW * i // 4
        for y, flip in ((dcy, False), (oh - 1 - dcy, True)):
            pic, pm = (dia.transpose(Image.FLIP_TOP_BOTTOM), dm.transpose(Image.FLIP_TOP_BOTTOM)) if flip else (dia, dm)
            out.paste(pic, (x - pic.width // 2, y - pic.height // 2), pm)
    sdia, sdm = dia.transpose(Image.ROTATE_90), dm.transpose(Image.ROTATE_90)
    for i in (1, 2, 3, 5, 6, 7):
        y = B + SH * i // 8
        for x in (dcy, ow - 1 - dcy):
            out.paste(sdia, (x - sdia.width // 2, y - sdia.height // 2), sdm)

    # Side pockets, middle of both long rails.
    rail, c, band = s["side"]
    c = sc(c)
    half = sc(88)
    deep = sc(band) + 1  # the rail only: the cloth round it is ours
    if rail == "left":
        tile = src.crop((0, c - half, deep, c + half))
    else:  # a bottom-rail pocket, turned to sit on the left rail
        tile = src.crop((c - half, src.height - deep, c + half, src.height)).transpose(Image.ROTATE_270)
        tile = tile.resize((round(tile.width * s["band"] / band), tile.height), Image.LANCZOS)
    tm = feather_mask(tile.size, "tb", sc(10))
    y = B + SH // 2 - tile.height // 2
    out.paste(tile, (0, y), tm)
    out.paste(tile.transpose(Image.FLIP_LEFT_RIGHT), (ow - tile.width, y), tm.transpose(Image.FLIP_LEFT_RIGHT))

    # Corners: the top-left one, mirrored.
    cs = sc(132)
    corner = src.crop((0, 0, cs, cs))
    # Only the rails and the pocket: the source's cloth there is shaded
    # differently from ours.
    cm = Image.new("L", corner.size, 0)
    d = ImageDraw.Draw(cm)
    d.rectangle((0, 0, cs, B), fill=255)
    d.rectangle((0, 0, B, cs), fill=255)
    d.ellipse((sc(65 - 40), sc(65 - 40), sc(65 + 40), sc(65 + 40)), fill=255)
    cm = ImageChops.multiply(cm.filter(ImageFilter.GaussianBlur(1.5)), feather_mask(corner.size, "rb", sc(12)))
    for flip_x in (False, True):
        for flip_y in (False, True):
            pic, pm = corner, cm
            if flip_x:
                pic, pm = pic.transpose(Image.FLIP_LEFT_RIGHT), pm.transpose(Image.FLIP_LEFT_RIGHT)
            if flip_y:
                pic, pm = pic.transpose(Image.FLIP_TOP_BOTTOM), pm.transpose(Image.FLIP_TOP_BOTTOM)
            out.paste(pic, (ow - cs if flip_x else 0, oh - cs if flip_y else 0), pm)

    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"table_{name}.jpg"
    out.save(path, quality=86, optimize=True)
    print(f"{path.relative_to(ROOT)}: {out.size[0]}x{out.size[1]}, {path.stat().st_size // 1024} KB")


if __name__ == "__main__":
    for name, s in SOURCES.items():
        build(name, s)
