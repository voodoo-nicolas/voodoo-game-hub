# Landing-page art for Block Escape, Arrow Pop and Arrows. Self-made, procedural
# (Python/Pillow, no source images, no third-party assets). Drawn at 2x and scaled down
# for smooth edges. The hero picture sits in the lower half (the landing's title and buttons
# cover the top); the top and the icon row at the bottom are dimmed.
# Run from the repo root:  python tools/art/puzzle_landing_art.py
import math
import random
from PIL import Image, ImageDraw, ImageFilter

W, H = 720, 1280
S = 2  # supersample
SW, SH = W * S, H * S


def backdrop(top, bot, seed, grain=6):
    random.seed(seed)
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        row = [int(top[i] * (1 - t) + bot[i] * t) for i in range(3)]
        for x in range(W):
            n = random.randint(-grain, grain)
            px[x, y] = tuple(max(0, min(255, row[i] + n)) for i in range(3))
    return img.filter(ImageFilter.GaussianBlur(0.6)).resize((SW, SH), Image.BICUBIC)


def glow(img, cx, cy, r, rgb, a):
    m = Image.new("L", (SW, SH), 0)
    ImageDraw.Draw(m).ellipse([cx - r, cy - r, cx + r, cy + r], fill=int(255 * a))
    m = m.filter(ImageFilter.GaussianBlur(r * 0.45))
    return Image.composite(Image.new("RGB", (SW, SH), rgb), img, m)


def shade(rgb, k):
    return tuple(max(0, min(255, int(c * k))) for c in rgb)


def finish(img, path, dim_from=0.52):
    # Vignette + darker lower half for the buttons.
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    for y in range(H):
        t = y / (H - 1)
        a = int(110 * max(0.0, 1 - t / dim_from)) + (int(170 * ((t - 0.86) / 0.14)) if t > 0.86 else 0)
        d.line([(0, y), (W, y)], fill=a)
    v = Image.new("L", (W, H), 0)
    ImageDraw.Draw(v).ellipse([-W * 0.25, -H * 0.15, W * 1.25, H * 1.1], fill=255)
    v = v.filter(ImageFilter.GaussianBlur(120)).point(lambda p: 255 - p)
    out = img.resize((W, H), Image.LANCZOS)
    dark = Image.new("RGB", (W, H), (4, 6, 14))
    out = Image.composite(dark, out, m)
    out = Image.composite(dark, out, v.point(lambda p: int(p * 0.7)))
    out.save(path, quality=88, optimize=True)


def shadow_layer(img, draw_fn, off, blur, a):
    m = Image.new("L", (SW, SH), 0)
    draw_fn(ImageDraw.Draw(m), off)
    m = m.filter(ImageFilter.GaussianBlur(blur)).point(lambda p: int(p * a))
    return Image.composite(Image.new("RGB", (SW, SH), (0, 0, 0)), img, m)


# ---------------------------------------------------------------- Block Escape
# A toy-brick board seen from above, one brick bursting out through its gate.
def block_escape():
    img = backdrop((14, 26, 64), (6, 10, 28), 101)
    img = glow(img, SW * 0.5, SH * 0.68, 620, (40, 90, 190), 0.55)
    RED, YEL, BLU, GRN, ORA, PUR = (232, 58, 58), (255, 200, 40), (40, 120, 235), (60, 190, 90), (255, 130, 30), (150, 80, 220)
    cell = 118
    cols, rows = 6, 6
    bx = (SW - cols * cell) // 2
    by = int(SH * 0.51)
    # Board tray
    def tray(d, o):
        d.rounded_rectangle([bx - 36 + o, by - 36 + o, bx + cols * cell + 36 + o, by + rows * cell + 36 + o], 56, fill=255)
    img = shadow_layer(img, tray, 28, 40, 0.75)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([bx - 36, by - 36, bx + cols * cell + 36, by + rows * cell + 36], 56, fill=(34, 48, 92))
    d.rounded_rectangle([bx - 36, by - 36, bx + cols * cell + 36, by + rows * cell + 30], 56, fill=(52, 70, 128))
    d.rounded_rectangle([bx - 6, by - 6, bx + cols * cell + 6, by + rows * cell + 6], 26, fill=(22, 32, 66))
    for r in range(rows):
        for c in range(cols):
            x, y = bx + c * cell, by + r * cell
            col = (34, 48, 94) if (r + c) % 2 else (40, 56, 106)
            d.rounded_rectangle([x + 4, y + 4, x + cell - 4, y + cell - 4], 14, fill=col)
            d.ellipse([x + cell / 2 - 22, y + cell / 2 - 18, x + cell / 2 + 22, y + cell / 2 + 26], fill=shade(col, 0.8))
            d.ellipse([x + cell / 2 - 22, y + cell / 2 - 24, x + cell / 2 + 22, y + cell / 2 + 20], fill=shade(col, 1.18))
    # Gates on the frame: coloured slots
    gates = [(RED, "top", 1, 2), (BLU, "right", 3, 2), (YEL, "bottom", 3, 2), (GRN, "left", 1, 2)]
    for col, side, start, ln in gates:
        if side == "top":
            r = [bx + start * cell + 10, by - 34, bx + (start + ln) * cell - 10, by - 8]
        elif side == "bottom":
            r = [bx + start * cell + 10, by + rows * cell + 8, bx + (start + ln) * cell - 10, by + rows * cell + 34]
        elif side == "left":
            r = [bx - 34, by + start * cell + 10, bx - 8, by + (start + ln) * cell - 10]
        else:
            r = [bx + cols * cell + 8, by + start * cell + 10, bx + cols * cell + 34, by + (start + ln) * cell - 10]
        d.rounded_rectangle(r, 12, fill=col)
        d.rounded_rectangle([r[0] + 4, r[1] + 4, r[2] - 4, (r[1] + r[3]) / 2], 8, fill=shade(col, 1.25))

    def brick(img, cells, col, dx=0, dy=0):
        pad = 9
        def sil(dd, o):
            for (c, r) in cells:
                x, y = bx + c * cell + dx, by + r * cell + dy
                dd.rounded_rectangle([x + pad + o, y + pad + o, x + cell - pad + o, y + cell - pad + o], 26, fill=255)
        img = shadow_layer(img, sil, 16, 14, 0.6)
        dd = ImageDraw.Draw(img)
        cs = set(cells)
        for (c, r) in cells:
            x, y = bx + c * cell + dx, by + r * cell + dy
            x0, y0, x1, y1 = x + pad, y + pad, x + cell - pad, y + cell - pad
            # merge with neighbours
            if (c + 1, r) in cs: x1 = x + cell + pad
            if (c, r + 1) in cs: y1 = y + cell + pad
            dd.rounded_rectangle([x0, y0, x1, y1], 26, fill=shade(col, 0.72))
            dd.rounded_rectangle([x0, y0, x1, y1 - 12], 26, fill=col)
        for (c, r) in cells:
            x, y = bx + c * cell + dx, by + r * cell + dy
            dd.rounded_rectangle([x + pad + 12, y + pad + 8, x + cell - pad - 12, y + pad + 30], 12, fill=shade(col, 1.22))
            cx, cy = x + cell / 2, y + cell / 2
            dd.ellipse([cx - 34, cy - 26, cx + 34, cy + 40], fill=shade(col, 0.68))
            dd.ellipse([cx - 34, cy - 34, cx + 34, cy + 30], fill=shade(col, 1.08))
            dd.ellipse([cx - 22, cy - 26, cx + 2, cy - 8], fill=shade(col, 1.4))
        return img

    img = brick(img, [(0, 0), (0, 1)], GRN)
    img = brick(img, [(3, 0), (4, 0), (4, 1)], ORA)
    img = brick(img, [(2, 1), (2, 2)], PUR)
    img = brick(img, [(5, 2), (5, 3)], BLU)
    img = brick(img, [(0, 3), (1, 3), (0, 4)], YEL)
    img = brick(img, [(3, 2), (3, 3), (4, 3)], RED)
    img = brick(img, [(1, 5), (2, 5)], BLU)
    img = brick(img, [(4, 4), (4, 5), (5, 5)], GRN)
    img = brick(img, [(2, 4)], ORA)
    # The escaping brick: yellow, half out through the bottom gate, with speed lines.
    d = ImageDraw.Draw(img)
    for i, off in enumerate([-40, 0, 40]):
        x = bx + 3.5 * cell + off
        d.rounded_rectangle([x - 7, by + rows * cell - 200 + abs(off) * 2, x + 7, by + rows * cell + 40], 7,
                            fill=(255, 226, 120))
    img = brick(img, [(3, 5)], YEL, dy=int(cell * 0.7))
    img = glow(img, bx + 3.5 * cell, by + rows * cell + 140, 160, (255, 210, 80), 0.35)
    finish(img, "games/block_escape/landing.jpg", 0.5)


# ---------------------------------------------------------------- Arrows
# Tangled fat arrows on dark graph paper; one flies free off the top edge.
def arrows():
    img = backdrop((16, 22, 58), (6, 8, 24), 202)
    d = ImageDraw.Draw(img)
    g = 48
    for x in range(0, SW, g):
        d.line([(x, 0), (x, SH)], fill=(30, 40, 86) if (x // g) % 5 else (40, 54, 110), width=2)
    for y in range(0, SH, g):
        d.line([(0, y), (SW, y)], fill=(30, 40, 86) if (y // g) % 5 else (40, 54, 110), width=2)
    img = glow(img, SW * 0.5, SH * 0.62, 640, (70, 60, 170), 0.45)
    COLS = [(255, 138, 61), (255, 95, 162), (56, 182, 255), (255, 211, 64), (120, 220, 140), (180, 120, 255)]
    cell = 110
    ox, oy = (SW - 12 * cell) // 2, int(SH * 0.36)
    random.seed(7)
    paths = [
        [(1, 1), (1, 4), (4, 4)],
        [(2, 0), (6, 0), (6, 3)],
        [(10, 1), (10, 5), (7, 5)],
        [(3, 6), (3, 9), (0, 9)],
        [(5, 7), (9, 7), (9, 10)],
        [(11, 8), (11, 11), (7, 11)],
        [(5, 2), (8, 2)],
        [(2, 11), (5, 11), (5, 9)],
        [(8, 3), (8, 6)],
        [(0, 6), (0, 7), (2, 7)],
    ]

    def pts(p, dx=0, dy=0):
        return [(ox + c * cell + cell / 2 + dx, oy + r * cell + cell / 2 + dy) for c, r in p]

    def draw_arrow(img, p, col, dx=0, dy=0):
        q = pts(p, dx, dy)
        def sil(dd, o):
            qq = [(x + o, y + o) for x, y in q]
            dd.line(qq, fill=255, width=46, joint="curve")
            for x, y in qq:
                dd.ellipse([x - 23, y - 23, x + 23, y + 23], fill=255)
        img = shadow_layer(img, sil, 14, 12, 0.7)
        dd = ImageDraw.Draw(img)
        dd.line(q, fill=shade(col, 0.7), width=46, joint="curve")
        for x, y in q:
            dd.ellipse([x - 23, y - 23, x + 23, y + 23], fill=shade(col, 0.7))
        qh = [(x, y - 5) for x, y in q]
        dd.line(qh, fill=col, width=36, joint="curve")
        for x, y in qh:
            dd.ellipse([x - 18, y - 18, x + 18, y + 18], fill=col)
        dd.line([(x, y - 10) for x, y in q], fill=shade(col, 1.3), width=8, joint="curve")
        # head
        (x0, y0), (x1, y1) = q[-2], q[-1]
        a = math.atan2(y1 - y0, x1 - x0)
        tip = (x1 + math.cos(a) * 62, y1 + math.sin(a) * 62)
        l = (x1 + math.cos(a + 2.2) * 50, y1 + math.sin(a + 2.2) * 50)
        r = (x1 + math.cos(a - 2.2) * 50, y1 + math.sin(a - 2.2) * 50)
        dd.polygon([(tip[0], tip[1] + 6), (l[0], l[1] + 6), (r[0], r[1] + 6)], fill=shade(col, 0.7))
        dd.polygon([tip, l, r], fill=col)
        return img

    for i, p in enumerate(paths):
        img = draw_arrow(img, p, COLS[i % len(COLS)])
    # The free arrow: shooting up and out, with a dashed trail.
    d = ImageDraw.Draw(img)
    fx = ox + 9 * cell + cell / 2
    for y in range(int(oy + 9 * cell), int(oy + 2 * cell), -70):
        d.rounded_rectangle([fx - 7, y - 34, fx + 7, y], 7, fill=(255, 240, 200))
    img = glow(img, fx, oy + 0.6 * cell, 170, (255, 200, 120), 0.4)
    img = draw_arrow(img, [(9, 2), (9, 1), (9, 0)], (255, 211, 64), dy=-int(cell * 0.6))
    finish(img, "games/arrows/landing.jpg", 0.36)


# ---------------------------------------------------------------- Arrow Pop
# Two colours only (coral + cream) on dark bubble-wrap: arrows popping bubbles.
def arrow_pop():
    img = backdrop((20, 32, 56), (8, 12, 24), 303)
    CORAL, CREAM = (255, 107, 94), (255, 227, 179)
    r, step = 64, 168
    bubbles = []
    for row, y in enumerate(range(-step, SH + step, int(step * 0.866))):
        off = step / 2 if row % 2 else 0
        for x in range(-step, SW + step, step):
            bubbles.append((x + off, y))
    random.seed(99)
    popped = set(random.sample(range(len(bubbles)), 9))
    tinted = {}
    for i in random.sample(range(len(bubbles)), 26):
        tinted[i] = CORAL if i % 2 else CREAM
    sh = Image.new("L", (SW, SH), 0)
    ds = ImageDraw.Draw(sh)
    for cx, cy in bubbles:
        ds.ellipse([cx - r + 10, cy - r + 14, cx + r + 10, cy + r + 14], fill=200)
    img = Image.composite(Image.new("RGB", (SW, SH), (2, 4, 10)), img, sh.filter(ImageFilter.GaussianBlur(12)))
    d = ImageDraw.Draw(img)
    for i, (cx, cy) in enumerate(bubbles):
        if i in popped:
            # flat, crinkled popped bubble
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(26, 38, 62))
            for k in range(7):
                a = k * math.tau / 7 + 0.3
                d.line([(cx, cy), (cx + math.cos(a) * r * 0.8, cy + math.sin(a) * r * 0.8)], fill=(40, 56, 86), width=5)
            continue
        base = tinted.get(i)
        body = (44, 66, 104) if base is None else shade(base, 0.62)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=body)
        d.ellipse([cx - r + 8, cy - r + 6, cx + r - 14, cy + r - 16], fill=shade(body, 1.25) if base is None else shade(base, 0.85))
        d.ellipse([cx - r * 0.6, cy - r * 0.66, cx - r * 0.12, cy - r * 0.28], fill=(230, 240, 255) if base is None else shade(base, 1.25))
    # Arrows in flight, each heading for a bubble of its colour, with burst marks.
    shots = [((300, 2350), (480, 1620), CORAL), ((1180, 2400), (1010, 1660), CREAM), ((160, 1900), (700, 1400), CREAM),
             ((1330, 2050), (1160, 1520), CORAL)]
    for (x0, y0), (x1, y1), col in shots:
        a = math.atan2(y1 - y0, x1 - x0)
        hx, hy = x1 - math.cos(a) * 120, y1 - math.sin(a) * 120
        tx, ty = hx - math.cos(a) * 300, hy - math.sin(a) * 300
        def sil(dd, o):
            dd.line([(tx + o, ty + o), (hx + o, hy + o)], fill=255, width=26)
        img = shadow_layer(img, sil, 14, 10, 0.7)
        d = ImageDraw.Draw(img)
        for k in range(1, 5):
            px_, py_ = tx - math.cos(a) * k * 46, ty - math.sin(a) * k * 46
            rr = 13 - k * 2.5
            d.ellipse([px_ - rr, py_ - rr, px_ + rr, py_ + rr], fill=shade(col, 0.8))
        d.line([(tx, ty), (hx, hy)], fill=shade(col, 0.7), width=26)
        d.line([(tx, ty - 4), (hx, hy - 4)], fill=col, width=18)
        tip = (hx + math.cos(a) * 64, hy + math.sin(a) * 64)
        l = (hx + math.cos(a + 2.4) * 46, hy + math.sin(a + 2.4) * 46)
        rt = (hx + math.cos(a - 2.4) * 46, hy + math.sin(a - 2.4) * 46)
        d.polygon([tip, l, rt], fill=col)
        # fletching
        for s in (2.6, -2.6):
            d.line([(tx, ty), (tx + math.cos(a + s) * 40, ty + math.sin(a + s) * 40)], fill=col, width=12)
        # pop burst at target
        img = glow(img, x1, y1, 120, col, 0.45)
        d = ImageDraw.Draw(img)
        for k in range(10):
            b = k * math.tau / 10
            d.line([(x1 + math.cos(b) * 70, y1 + math.sin(b) * 70), (x1 + math.cos(b) * 120, y1 + math.sin(b) * 120)],
                   fill=col, width=12)
        d.ellipse([x1 - 26, y1 - 26, x1 + 26, y1 + 26], fill=shade(col, 1.15))
    finish(img, "games/arrow_pop/landing.jpg", 0.4)


block_escape()
arrows()
arrow_pop()
print("ok")
