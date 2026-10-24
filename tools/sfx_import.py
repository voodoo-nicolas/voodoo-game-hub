"""Copies the owner's sound library into the repo's shared sound library.

    python tools/sfx_import.py D:/dev/audio

Each top folder of the source is one set (media/common/sfx/<set>/). Names
become lowercase snake_case; a sound with several takes is <name>_1.ogg,
<name>_2.ogg... (Kenney's _000.._004 renumbered from 1). OGG files up to
160 kbps are copied as they are; heavier OGGs and every other format are
encoded to OGG Vorbis with ffmpeg. Writes, for every set:
- a folder entry in media/CREDITS.json (`"file": "media/common/sfx/<set>/"`)
- its licence proof in media/licenses/sfx/
- docs/claude/sfx-library.md, the catalog of sound ids (generated)

Adds and updates only: a file that is in the repo but no longer in the
source is reported, never deleted (the owner decides). Licence: the set's
own License.txt (a root License.txt counts for the set its title names);
CC0 is recognised, NC / ND licences are refused, and a set without a licence
file is recorded as the owner's statement (media/licenses/sfx/OWNER_SFX.md).
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "media/common/sfx"
PROOFS = ROOT / "media/licenses/sfx"
CREDITS = ROOT / "media/CREDITS.json"
CATALOG = ROOT / "docs/claude/sfx-library.md"
FFMPEG_DIR = Path(os.path.expandvars(r"%LOCALAPPDATA%\Programs\ffmpeg\bin"))
AUDIO = (".ogg", ".wav", ".mp3", ".m4a", ".flac", ".aac", ".opus")
MAX_KBPS = 160

# Source folder -> set name (anything else: its name in snake_case).
SET_NAMES = {
    "casino": "casino", "rpg sounds": "rpg", "impact-sounds": "impact", "sci fi": "scifi",
    "voiceover-pack-fighter": "voice", "ambient sounds": "ambient", "weather": "weather",
}
# Source file stem -> name in the library (no alcohol references, CLAUDE.md).
RENAMES = {"bar_people talking": "crowd_chatter"}
# What the owner said about files that come without a licence file.
OWNER_STATEMENT = "all audios are owned by us, or free to use without attribution"
OWNER_DATE = "2026-10-24"


def ff(tool: str) -> str:
    exe = FFMPEG_DIR / f"{tool}.exe"
    return str(exe) if exe.is_file() else tool


def snake(text: str) -> str:
    text = text.replace("'", "")
    text = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", text)
    text = re.sub(r"[^A-Za-z0-9]+", "_", text).strip("_").lower()
    return text


def split_take(stem: str, set_name: str) -> tuple[str, int | None]:
    """card-slide-3 -> (card_slide, 3); footstep07 -> (footstep, 7); 1 -> (count, 1).
    A name that repeats its set's name drops it (impact: impactBell_heavy -> bell_heavy)."""
    name = snake(RENAMES.get(stem, stem))
    if name.startswith(set_name + "_"):
        name = name[len(set_name) + 1:]
    m = re.match(r"^(.*?)_?(\d+)$", name)
    if not m:
        return name, None
    base = m.group(1).rstrip("_") or "count"
    return base, int(m.group(2))


def probe(path: Path) -> tuple[str, float, int]:
    """(codec, seconds, bits per second)."""
    out = subprocess.run([ff("ffprobe"), "-v", "error", "-show_entries", "format=duration,bit_rate:stream=codec_name",
                          "-of", "json", str(path)], capture_output=True, text=True, check=True).stdout
    data = json.loads(out)
    codec = data.get("streams", [{}])[0].get("codec_name", "")
    fmt = data.get("format", {})
    return codec, float(fmt.get("duration", 0) or 0), int(fmt.get("bit_rate", 0) or 0)


def licence_of(src_root: Path, folder: Path) -> dict:
    """{"kind": "cc0"|"owner", "text": licence text, "title": pack title}."""
    own = sorted(folder.rglob("License.txt"))
    root = src_root / "License.txt"
    texts = [p.read_text(encoding="utf-8", errors="replace") for p in own]
    if not texts and root.is_file():
        text = root.read_text(encoding="utf-8", errors="replace")
        if slug(title_of(text)) == slug(folder.name):
            texts = [text]
    if not texts:
        return {"kind": "owner", "text": "", "title": ""}
    text = texts[0]
    if re.search(r"non-?commercial|no-?deriv|\bNC\b|\bND\b", text, re.I):
        raise SystemExit(f"{folder.name}: the licence forbids commercial use or changes (NC / ND) -- not imported")
    if not re.search(r"CC0|Creative Commons Zero|publicdomain/zero", text):
        raise SystemExit(f"{folder.name}: licence not recognised (only CC0 is automatic) -- add it by hand")
    return {"kind": "cc0", "text": text, "title": title_of(text)}


def title_of(text: str) -> str:
    for line in text.splitlines():
        line = line.strip()
        if line:
            return line
    return ""


def slug(title: str) -> str:
    title = re.sub(r"\(.*?\)", "", title)
    return re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")


def encode(src: Path, dest: Path, seconds: float) -> None:
    quality = "2" if seconds > 10 else "3"  # long ambience ~64 kbps mono, effects ~80-110
    subprocess.run([ff("ffmpeg"), "-y", "-v", "error", "-i", str(src), "-map_metadata", "-1",
                    "-c:a", "libvorbis", "-q:a", quality, str(dest)], check=True)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    src_root = Path(sys.argv[1])
    if not src_root.is_dir():
        raise SystemExit(f"{src_root} is not a folder")
    credits = json.loads(CREDITS.read_text(encoding="utf-8"))
    PROOFS.mkdir(parents=True, exist_ok=True)
    catalog: dict[str, list] = {}
    owner_files: list[str] = []
    imported = 0
    for folder in sorted(p for p in src_root.iterdir() if p.is_dir()):
        set_name = SET_NAMES.get(folder.name.lower(), snake(folder.name))
        files = sorted(p for p in folder.rglob("*") if p.suffix.lower() in AUDIO and p.stem.lower() != "preview")
        if not files:
            continue
        lic = licence_of(src_root, folder)
        groups: dict[str, list] = {}
        for f in files:
            base, n = split_take(f.stem, set_name)
            groups.setdefault(base, []).append((n if n is not None else -1, f))
        out_dir = LIB / set_name
        out_dir.mkdir(parents=True, exist_ok=True)
        wanted: set[str] = set()
        entries = []
        for base in sorted(groups):
            takes = [f for _, f in sorted(groups[base], key=lambda t: (t[0], t[1].name))]
            names = [f"{base}.ogg"] if len(takes) == 1 else [f"{base}_{i}.ogg" for i in range(1, len(takes) + 1)]
            seconds = []
            for src, name in zip(takes, names):
                dest = out_dir / name
                wanted.add(name)
                codec, secs, bps = probe(src)
                seconds.append(secs)
                if codec == "vorbis" and bps <= MAX_KBPS * 1000:
                    if not dest.is_file() or dest.read_bytes() != src.read_bytes():
                        shutil.copyfile(src, dest)
                        imported += 1
                elif not dest.is_file() or dest.stat().st_mtime < src.stat().st_mtime:
                    encode(src, dest, secs)
                    imported += 1
                if lic["kind"] == "owner":
                    owner_files.append(f"{src.relative_to(src_root).as_posix()} -> {dest.relative_to(ROOT).as_posix()}")
            entries.append((f"{set_name}/{base}", len(takes), min(seconds), max(seconds)))
        for stale in sorted(p.name for p in out_dir.glob("*.ogg") if p.name not in wanted):
            print(f"  note: {set_name}/{stale} is no longer in the source (kept; delete it by hand if wanted)")
        size = sum(p.stat().st_size for p in out_dir.glob("*.ogg"))
        catalog[set_name] = [entries, lic, folder.name, size]

        # Credit + proof.
        rel_dir = f"media/common/sfx/{set_name}/"
        if lic["kind"] == "cc0":
            proof = PROOFS / f"kenney_{slug(lic['title']).replace('-', '_')}.txt" if "kenney" in lic["text"].lower() \
                else PROOFS / f"{set_name}_licence.txt"
            proof.write_text(lic["text"], encoding="utf-8", newline="\n")
            kenney = "kenney" in lic["text"].lower()
            entry = {
                "file": rel_dir,
                "what": f"Shared sound library, set '{set_name}' (every file in the folder)",
                "source": f"{re.sub(r'[()]', '', lic['title']).strip()}, from the owner's library {src_root.as_posix()}/{folder.name}",
                "author": "Kenney Vleugels (Kenney.nl)" if kenney else "see licence",
                "licence": "CC0",
                "proof": proof.relative_to(ROOT).as_posix(),
                "url": f"https://kenney.nl/assets/{slug(lic['title'])}" if kenney else "",
                "date": OWNER_DATE,
            }
        else:
            entry = {
                "file": rel_dir,
                "what": f"Shared sound library, set '{set_name}' (every file in the folder)",
                "source": f"Supplied by the owner from {src_root.as_posix()}/{folder.name} (original source not stated)",
                "author": "Viral (owner)",
                "licence": "owner-proprietary",
                "proof": "media/licenses/sfx/OWNER_SFX.md",
                "url": "",
                "date": OWNER_DATE,
            }
        assets = credits["assets"]
        for i, old in enumerate(assets):
            if old.get("file") == rel_dir:
                assets[i] = entry
                break
        else:
            assets.append(entry)

    if owner_files:
        lines = [
            "# Owner-supplied sounds (no licence file)",
            "",
            f"On {OWNER_DATE} the owner wrote, about the sound library at `{src_root.as_posix()}`:",
            f"\"{OWNER_STATEMENT}\".",
            "",
            "These files came without a licence file, so that statement is their licence record.",
            "Original source not stated; if one is ever found, record it here.",
            "",
        ] + [f"- `{line}`" for line in owner_files]
        (PROOFS / "OWNER_SFX.md").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    CREDITS.write_text(json.dumps(credits, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    write_catalog(catalog)
    total = sum(c[3] for c in catalog.values())
    print(f"OK -- {sum(len(c[0]) for c in catalog.values())} sounds in {len(catalog)} sets, "
          f"{total / 1e6:.1f} MB; {imported} file(s) added or updated")


def write_catalog(catalog: dict) -> None:
    out = [
        "# Shared sound library: catalog",
        "",
        "Generated by `python tools/sfx_import.py <folder>` -- do not edit by hand.",
        "How to use it: `docs/claude/i18n-gameinfo-sfx.md` (Shared sound library).",
        "",
        "A sound id is `<set>/<name>`. \"Takes\" = how many recordings it has (`SoundLib.play()` picks one at random).",
        "",
    ]
    for set_name, (entries, lic, folder, size) in catalog.items():
        licence = f"{lic['title']}, CC0" if lic["kind"] == "cc0" else "owner-supplied"
        out += [f"## {set_name} ({len(entries)} sounds, {size / 1e3:.0f} KB; {licence})", "",
                "| id | takes | length |", "|---|---|---|"]
        for sid, takes, lo, hi in entries:
            length = f"{lo:.1f} s" if abs(hi - lo) < 0.05 else f"{lo:.1f}-{hi:.1f} s"
            out.append(f"| `{sid}` | {takes} | {length} |")
        out.append("")
    CATALOG.write_text("\n".join(out), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
