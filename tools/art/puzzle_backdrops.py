# In-game backdrops for Block Escape, Arrow Pop and Arrows. Self-made, procedural
# (Python/Pillow, no source images). Run from the repo root:  python tools/art/puzzle_backdrops.py
import random
from PIL import Image, ImageDraw, ImageFilter

W, H = 720, 1280


def gradient(top, bot, grain, seed):
    random.seed(seed)
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        row = [int(top[i] * (1 - t) + bot[i] * t) for i in range(3)]
        for x in range(W):
            n = random.randint(-grain, grain)
            px[x, y] = (max(0, min(255, row[0] + n)), max(0, min(255, row[1] + n)), max(0, min(255, row[2] + n)))
    return img.filter(ImageFilter.GaussianBlur(0.6))


def emboss_dots(img, r, step, hex_grid, shadow_rgb, light_rgb, shadow_a, light_a):
    hi = Image.new("L", (W, H), 0)
    sh = Image.new("L", (W, H), 0)
    dh, ds = ImageDraw.Draw(hi), ImageDraw.Draw(sh)
    dy = int(step * 0.866) if hex_grid else step
    for row, y in enumerate(range(-step, H + step, dy)):
        off = step / 2 if (hex_grid and row % 2) else 0
        for x in range(-step, W + step, step):
            cx, cy = x + off, y
            ds.ellipse([cx - r + 3, cy - r + 4, cx + r + 3, cy + r + 4], fill=255)
            dh.ellipse([cx - r, cy - r, cx + r - 4, cy + r - 5], fill=120)
            dh.ellipse([cx - r * 0.55, cy - r * 0.6, cx - r * 0.1, cy - r * 0.2], fill=255)
    hi = hi.filter(ImageFilter.GaussianBlur(3)).point(lambda v: int(v * light_a))
    sh = sh.filter(ImageFilter.GaussianBlur(4)).point(lambda v: int(v * shadow_a))
    img = Image.composite(Image.new("RGB", (W, H), shadow_rgb), img, sh)
    return Image.composite(Image.new("RGB", (W, H), light_rgb), img, hi)


# Arrow Pop, classic: pale sky bubble-wrap.
img = gradient((214, 236, 248), (186, 214, 236), 5, 11)
emboss_dots(img, 22, 60, True, (120, 160, 200), (255, 255, 255), 0.35, 0.55).save(
    "games/arrow_pop/bg_light.jpg", quality=86, optimize=True)

# Block Escape, classic: a toy baseplate (square stud grid) on sky blue.
img = gradient((196, 222, 246), (160, 196, 232), 4, 22)
emboss_dots(img, 17, 52, False, (90, 130, 180), (255, 255, 255), 0.3, 0.5).save(
    "games/block_escape/bg_light.jpg", quality=86, optimize=True)

# Arrows, classic: graph paper with fine grain and a soft vignette.
img = gradient((236, 240, 247), (222, 228, 240), 4, 33)
d = ImageDraw.Draw(img)
for x in range(0, W, 24):
    d.line([(x, 0), (x, H)], fill=(205, 214, 232) if x % 120 else (184, 196, 222), width=1)
for y in range(0, H, 24):
    d.line([(0, y), (W, y)], fill=(205, 214, 232) if y % 120 else (184, 196, 222), width=1)
img.filter(ImageFilter.GaussianBlur(0.4)).save("games/arrows/bg_light.jpg", quality=86, optimize=True)
print("ok")
