"""Copies the owner's sprite library into the repo's shared sprite library.

    python tools/sprite_import.py D:/dev/sprites

Each entry of SETS below picks folders of one Kenney pack and makes them one
set (media/common/sprites/<set>/). Every other source folder laid out as a
"catalog pack" (LICENSE.txt + manifest.json + assets/<category>/*.png, like
gothic/ or village/) becomes the set <folder in snake_case> by itself, its
categories flattened and the "<folder>-" name prefix dropped. Names become
lowercase snake_case; numbered images (frames of an animation, or variants like
meteor_brown_big1..4) become a series <name>_<n>.png that keeps the source's
own numbers (0- or 1-based); a series with gaps is renumbered 1..n. PNGs are
copied byte for byte (they are checked to be real PNGs first).
Writes, for every set:
- a folder entry in media/CREDITS.json (`"file": "media/common/sprites/<set>/"`)
- its licence proof in media/licenses/sprites/
- docs/claude/sprite-library.md, the catalog of sprite ids (generated)
- docs/claude/sprite-sheets/<set>.jpg, a contact sheet labelled with the ids

Adds and updates only: a file that is in the repo but no longer in the source
is reported, never deleted (the owner decides). A source folder no SETS entry
covers is reported, not imported. Licence: the pack's own License.txt; only
CC0 is accepted, NC / ND licences are refused.
"""
from __future__ import annotations

import json
import re
import shutil
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "media/common/sprites"
PROOFS = ROOT / "media/licenses/sprites"
CREDITS = ROOT / "media/CREDITS.json"
CATALOG = ROOT / "docs/claude/sprite-library.md"
SHEETS = ROOT / "docs/claude/sprite-sheets"
DATE = "2026-10-24"

# set -> (source pack folder, its sub-folders to take, what it is, name prefix
# to drop). Sub-folders are searched recursively and flattened (names stay
# unique: the importer stops on a clash). Catalog packs are found by
# catalog_sets() and need no entry here.
SETS = {
    "space": ("kenney_space-shooter-remastered", ["PNG", "Backgrounds"],
              "Space shooter: player ships, enemies, UFOs, lasers, meteors, power-ups, damage overlays, "
              "engine fire, HUD bits, 4 tiling 256x256 backgrounds", ""),
    "space_ext": ("kenney_space-shooter-extension", ["PNG/Sprites X2"],
                  "Space shooter extension (2x size): astronauts, buildings, effects, meteors, missiles, "
                  "ship parts, rocket parts, rockets, ships, station pieces", "space_"),
    "smoke": ("kenney_smoke-particles", ["PNG"],
              "Smoke particles, 9-25 frames each: black smoke, explosion, fart, flash, white puff", ""),
    "iso_dungeon": ("kenney_isometric-miniature-dungeon", ["Isometric", "Characters"],
                "Isometric dungeon (256x512 canvases, 4 facings _e/_n/_s/_w): floors, walls, stairs, "
                "barrels, chests, columns, wooden structures; plus an animated man "
                "(male_<facing 0-7>_idle / _pickup / _run)", ""),
    "iso_dungeon_angle": ("kenney_isometric-miniature-dungeon", ["Angle"],
                          "The same dungeon pieces seen from above at an angle (256x512 canvases, 4 facings)", ""),
    "iso_library": ("kenney_isometric-miniature-library", ["Isometric"],
                "Isometric library (256x512 canvases, 4 facings): bookcases, books, desks, chairs, "
                "candles, globes, floors, walls", ""),
    "iso_library_angle": ("kenney_isometric-miniature-library", ["Angle"],
                          "The same library pieces seen from above at an angle (256x512 canvases, 4 facings)", ""),
    "textures": ("kenney_retro-textures-fantasy", ["PNG"],
                 "Retro fantasy pixel textures (64x64 and 64x128): bricks, stone, wood, doors, windows, "
                 "roofs, ground; draw with texture_filter = NEAREST", ""),
}
# Folders of the source that are deliberately not imported, with why.
SKIPPED = {
    "kenney_retro-fantasy-kit": "3D models (FBX/GLB/OBJ), not sprites; take them when a 3D game needs them",
}
# "<set>/<name>" -> name in the library. No alcohol references (CLAUDE.md).
RENAMES = {"anime_portraits/monk_drunken_master": "monk_wandering_master", "village/tavern": "inn",
           "space/black": "bg_black", "space/blue": "bg_blue", "space/dark_purple": "bg_dark_purple",
           "space/purple": "bg_purple"}
# "<set>/<name>" left out of the library, with why.
LEFT_OUT = {"cyberpunk/neon_sign_bar": "a neon sign reading BAR (no alcohol references, CLAUDE.md)"}
# Name suffixes dropped (anime-portraits names every file "...-anime").
DROP_SUFFIXES = ("_anime",)
SKIP_NAMES = {"preview", "sample", "information"}


def snake(text: str) -> str:
    text = text.replace("'", "")
    text = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", text)
    return re.sub(r"[^A-Za-z0-9]+", "_", text).strip("_").lower()


def library_name(stem: str, set_name: str, prefix: str) -> str:
    """The image's name in the library, before any frame split. `prefix` is
    dropped (spaceShips_001 -> ships_001; gothic-bell-tower -> bell_tower)."""
    name = snake(stem)
    if prefix and name.startswith(prefix):
        name = name[len(prefix):]
    for suffix in DROP_SUFFIXES:
        if name.endswith(suffix):
            name = name[: -len(suffix)]
    return RENAMES.get(f"{set_name}/{name}", name)


def split_frame(name: str) -> tuple[str, int | None]:
    """laser_blue01 -> (laser_blue, 1); male_0_run7 -> (male_0_run, 7);
    barrel_e -> (barrel_e, None)."""
    m = re.match(r"^(.*?)_?(\d+)$", name)
    if not m or not m.group(1).rstrip("_"):
        return name, None
    return m.group(1).rstrip("_"), int(m.group(2))


def png_size(path: Path) -> tuple[int, int]:
    head = path.read_bytes()[:24]
    if head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        raise SystemExit(f"{path}: not a PNG")
    return struct.unpack(">II", head[16:24])


def licence_of(pack: Path) -> dict:
    files = [p for p in pack.iterdir() if p.is_file() and p.name.lower() == "license.txt"]
    if not files:
        raise SystemExit(f"{pack.name}: no License.txt -- not imported (record its licence first)")
    text = files[0].read_text(encoding="utf-8", errors="replace")
    if re.search(r"non-?commercial|no-?deriv|\bNC\b|\bND\b", text, re.I):
        raise SystemExit(f"{pack.name}: the licence forbids commercial use or changes (NC / ND) -- not imported")
    if not re.search(r"CC0|Creative Commons Zero|publicdomain/zero", text):
        raise SystemExit(f"{pack.name}: licence not recognised (only CC0 is automatic) -- add it by hand")
    title = next((line.strip() for line in text.splitlines()
                  if line.strip() and not line.strip().startswith("#")), pack.name)
    return {"text": text, "title": title, "kenney": "kenney" in text.lower()}


def catalog_sets(src_root: Path) -> dict:
    """Catalog packs (LICENSE.txt + manifest.json + assets/), as SETS entries."""
    found = {}
    taken = {pack for pack, *_ in SETS.values()} | set(SKIPPED)
    for folder in sorted(p for p in src_root.iterdir() if p.is_dir() and p.name not in taken):
        if not ((folder / "manifest.json").is_file() and (folder / "assets").is_dir()):
            continue
        manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
        title = folder.name
        readme = folder / "README.md"
        if readme.is_file():
            first = readme.read_text(encoding="utf-8", errors="replace").splitlines()[:1]
            title = first[0].lstrip("# ").strip() if first else title
        counts = ", ".join(f"{n} {cat}" for cat, n in sorted(manifest.get("categoryCounts", {}).items()))
        set_name = snake(folder.name)
        if set_name in SETS:
            raise SystemExit(f"{folder.name}: set '{set_name}' is already a Kenney set -- rename one in SETS")
        found[set_name] = (folder.name, ["assets"], f"{title} ({counts})", set_name + "_")
    return found


def collect(src_root: Path, set_name: str, spec: tuple) -> dict[str, list[tuple[int | None, Path]]]:
    """base name -> [(frame number or None, source file)]."""
    pack, subs, _, prefix = spec
    groups: dict[str, list] = {}
    for sub in subs:
        folder = src_root / pack / sub
        if not folder.is_dir():
            raise SystemExit(f"{folder}: missing")
        for f in sorted(folder.rglob("*.png")):
            if f.stem.lower() in SKIP_NAMES:
                continue
            name = library_name(f.stem, set_name, prefix)
            if f"{set_name}/{name}" in LEFT_OUT:
                print(f"  left out {set_name}/{name}: {LEFT_OUT[set_name + '/' + name]}")
                continue
            base, n = split_frame(name)
            groups.setdefault(base, []).append((n, f))
    for base, items in groups.items():
        nums = [n for n, _ in items]
        if len(items) > 1 and None in nums:
            raise SystemExit(f"{set_name}/{base}: a single image and a numbered series share the name "
                             f"({[f.name for _, f in items]}) -- add a RENAMES entry")
        if len(set(nums)) != len(nums):
            raise SystemExit(f"{set_name}/{base}: two sources give the same file ({[str(f) for _, f in items]})")
        if len(items) > 1:
            nums = sorted(nums)
            if nums[0] not in (0, 1) or nums != list(range(nums[0], nums[0] + len(nums))):
                print(f"  note: {set_name}/{base}: source numbers {nums} renumbered 1-{len(nums)}")
                groups[base] = [(i + 1, f) for i, (_, f) in enumerate(sorted(items, key=lambda t: t[0]))]
    return groups


def dest_name(base: str, n: int | None, items: list) -> str:
    # One image keeps a plain name even if the source numbered it (Male_0_Idle0 -> male_0_idle).
    return f"{base}.png" if len(items) == 1 else f"{base}_{n}.png"


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    src_root = Path(sys.argv[1])
    if not src_root.is_dir():
        raise SystemExit(f"{src_root} is not a folder")
    sets = SETS | catalog_sets(src_root)
    known = {pack for pack, *_ in sets.values()} | set(SKIPPED)
    for folder in sorted(p for p in src_root.iterdir() if p.is_dir()):
        if folder.name not in known:
            print(f"  note: {folder.name} is not imported (add it to SETS in tools/sprite_import.py)")
    for pack, why in SKIPPED.items():
        if (src_root / pack).is_dir():
            print(f"  skipped {pack}: {why}")

    credits = json.loads(CREDITS.read_text(encoding="utf-8"))
    PROOFS.mkdir(parents=True, exist_ok=True)
    catalog = {}
    copied = 0
    for set_name, spec in sets.items():
        pack, _, what, _ = spec
        if not (src_root / pack).is_dir():
            print(f"  note: {pack} is not in {src_root}; set '{set_name}' left as it is")
            continue
        lic = licence_of(src_root / pack)
        groups = collect(src_root, set_name, spec)
        out_dir = LIB / set_name
        out_dir.mkdir(parents=True, exist_ok=True)
        wanted: set[str] = set()
        entries = []
        for base in sorted(groups):
            items = sorted(groups[base], key=lambda t: -1 if t[0] is None else t[0])
            sizes = []
            for n, src in items:
                sizes.append(png_size(src))
                name = dest_name(base, n, items)
                wanted.add(name)
                dest = out_dir / name
                if not dest.is_file() or dest.read_bytes() != src.read_bytes():
                    shutil.copyfile(src, dest)
                    copied += 1
            nums = [n for n, _ in items]
            frames = "" if len(items) == 1 else f"{len(items)} ({min(nums)}-{max(nums)})"
            entries.append((base, frames, sizes, items[0][1]))
        for stale in sorted(p.name for p in out_dir.glob("*.png") if p.name not in wanted):
            print(f"  note: {set_name}/{stale} is no longer in the source (kept; delete it by hand if wanted)")
        size = sum(p.stat().st_size for p in out_dir.glob("*.png"))
        catalog[set_name] = (entries, lic, what, size, pack)

        # Credit + proof (one proof per source pack).
        proof = PROOFS / f"{snake(pack)}.txt"
        proof.write_text(lic["text"], encoding="utf-8", newline="\n")
        if (src_root / pack / "manifest.json").is_file():
            # A catalog pack's manifest records the CC0 declaration and checksum of every file.
            shutil.copyfile(src_root / pack / "manifest.json", PROOFS / f"{snake(pack)}_manifest.json")
        rel_dir = f"media/common/sprites/{set_name}/"
        title = re.sub(r"[()]", "", lic["title"]).strip() if lic["kenney"] else what.split(" (")[0]
        entry = {
            "file": rel_dir,
            "what": f"Shared sprite library, set '{set_name}' (every file in the folder): {what}",
            "source": f"{title}, from the owner's library {src_root.as_posix()}/{pack}"
                      + ("" if lic["kenney"] else " (the pack's own notice: CC0 as declared by its catalog, "
                                                  "not an independent provenance check)"),
            "author": "Kenney Vleugels (Kenney.nl)" if lic["kenney"] else "see licence (catalog declares CC0)",
            "licence": "CC0",
            "proof": proof.relative_to(ROOT).as_posix(),
            "url": f"https://kenney.nl/assets/{pack.removeprefix('kenney_')}" if lic["kenney"] else "",
            "date": DATE,
        }
        assets = credits["assets"]
        for i, old in enumerate(assets):
            if old.get("file") == rel_dir:
                assets[i] = entry
                break
        else:
            assets.append(entry)

    CREDITS.write_text(json.dumps(credits, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    write_catalog(catalog)
    write_sheets(catalog)
    total = sum(c[3] for c in catalog.values())
    ids = sum(len(c[0]) for c in catalog.values())
    print(f"OK -- {ids} sprite ids in {len(catalog)} sets, {total / 1e6:.1f} MB; {copied} file(s) added or updated")


def size_text(sizes: list) -> str:
    ws, hs = [w for w, _ in sizes], [h for _, h in sizes]
    if min(ws) == max(ws) and min(hs) == max(hs):
        return f"{ws[0]}x{hs[0]}"
    return f"{min(ws)}-{max(ws)} x {min(hs)}-{max(hs)}"


def compact(entries: list) -> list:
    """barrel_e/_n/_s/_w with the same frames and size -> one row barrel_{e,n,s,w}."""
    by_base = {e[0]: e for e in entries}
    rows, done = [], set()
    for base, frames, sizes, _ in entries:
        if base in done:
            continue
        stem = base[:-2]
        four = [f"{stem}_{d}" for d in "ensw"]
        if base[-2:] in ("_e", "_n", "_s", "_w") and all(
                b in by_base and by_base[b][1] == frames and size_text(by_base[b][2]) == size_text(sizes)
                for b in four):
            done.update(four)
            rows.append((f"{stem}_{{e,n,s,w}}", frames, size_text(sizes)))
        else:
            done.add(base)
            rows.append((base, frames, size_text(sizes)))
    return rows


def write_catalog(catalog: dict) -> None:
    out = [
        "# Shared sprite library: catalog",
        "",
        "Generated by `python tools/sprite_import.py <folder>` -- do not edit by hand.",
        "How to use it: the header of `tools/templates/sprite_lib.gd` (SpriteLib).",
        "Pictures of every set, labelled with these ids: `docs/claude/sprite-sheets/<set>.jpg`.",
        "",
        "A sprite id is `<set>/<name>`. \"Frames\" = a numbered series (`SpriteLib.frames()`; the numbers are the",
        "file numbers, e.g. `SpriteLib.texture(\"space/laser_blue\", 3)`); empty = one image.",
        "`name_{e,n,s,w}` = four ids, one per facing.",
        "",
    ]
    for set_name, (entries, lic, what, size, pack) in catalog.items():
        rows = compact(entries)
        weight = f"{size / 1e6:.1f} MB" if size >= 1e6 else f"{size / 1e3:.0f} KB"
        if max(max(s) for e in entries for s in e[2]) <= 64 and "NEAREST" not in what:
            what += "; pixel art: draw with texture_filter = NEAREST"
        out += [f"## {set_name} ({len(entries)} ids, {weight}; from `{pack}`, CC0)", "",
                what + ".", "", "| id | frames | size (px) |", "|---|---|---|"]
        out += [f"| `{set_name}/{base}` | {frames} | {size} |" for base, frames, size in rows]
        out.append("")
    CATALOG.write_text("\n".join(out), encoding="utf-8", newline="\n")


def write_sheets(catalog: dict) -> None:
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        print("  note: Pillow is missing, contact sheets not made (pip install pillow)")
        return
    SHEETS.mkdir(parents=True, exist_ok=True)
    cell, label, cols = 112, 14, 10
    for set_name, (entries, *_rest) in catalog.items():
        # One tile per id (its first frame); a facing quartet shows its _s view once.
        tiles = []
        for row_base, frames, _ in compact(entries):
            base = row_base.replace("_{e,n,s,w}", "_s")
            src = next(e[3] for e in entries if e[0] == base)
            tiles.append((row_base, frames, src))
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * cell, rows * (cell + label)), (58, 58, 68))
        draw = ImageDraw.Draw(sheet)
        for i, (name, frames, src) in enumerate(tiles):
            im = Image.open(src).convert("RGBA")
            bbox = im.getbbox()
            if bbox:
                im = im.crop(bbox)  # 256x512 iso canvases are mostly empty
            fit = (cell - 6) / max(im.width, im.height)
            if fit >= 2:  # pixel art: blow up by whole steps, hard edges
                im = im.resize((im.width * int(fit), im.height * int(fit)), Image.NEAREST)
            else:
                im.thumbnail((cell - 6, cell - 6))
            x, y = (i % cols) * cell, (i // cols) * (cell + label)
            sheet.paste(im, (x + (cell - im.width) // 2, y + (cell - im.height) // 2), im)
            text = name.replace("_{e,n,s,w}", "_*") + (f" x{frames.split()[0]}" if frames else "")
            draw.text((x + 2, y + cell), text[:19], fill=(235, 235, 235))
        sheet.save(SHEETS / f"{set_name}.jpg", quality=80)


if __name__ == "__main__":
    main()
