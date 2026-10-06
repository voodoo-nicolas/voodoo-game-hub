#!/usr/bin/env python3
"""Viral Game Hub project tool (repo voodoo-game-hub) -- one command per
chore that used to be a hand-edit across several files.

    python tools/hub.py check                 validate everything, change nothing
    python tools/hub.py sync                  regenerate derived config from the sources of truth
    python tools/hub.py new-game ID --title "Title" --icon "🎲" --category "Cards"
    python tools/hub.py bump-pack ID [ID...]  a game changed: publish it as a new version
    python tools/hub.py bump-app [patch|minor|major]
    python tools/hub.py test [ID...]          headless-boot the hub, account screen and games
    python tools/hub.py export [ID...|--all]  build game .pck files into builds/packs/
    python tools/hub.py apk                   build the release Android APK (signed with the private key) into builds/
    python tools/hub.py pc                    build the Windows version (every game built in) + desktop shortcut
    python tools/hub.py pc-zip                the same, zipped into builds/ to copy to other PCs
    python tools/hub.py i18n                  regenerate translation files from tools/i18n/es.json; list untranslated text
    python tools/hub.py verify                check live release assets match local builds
    python tools/hub.py export-media [NAME...|--all]  build media packs into builds/media/ (+ size/sha256 into manifest)
    python tools/hub.py bump-media NAME...    a media pack changed: new version = new file name
    python tools/hub.py publish-packs ID...   upload game / media packs to the GitHub pack release
    python tools/hub.py release               create the GitHub release for the current APK

Sources of truth (edit these by hand):
    manifest.json               the game catalog: categories, titles, icons, pack versions
    scripts/common/version.gd   VERSION + BUILD_NUMBER
    scripts/common/config.gd    repo / release / Supabase addresses
    scripts/common/brand.gd     the app's visible name (Brand.NAME)

Derived (never edit by hand -- `sync` rewrites them):
    export_presets.cfg          one "<Name>Pack" preset per game, one "<Name>Media" preset per
                                media pack; Android version fields + filters; the app name
                                shown by Android / Windows (from Brand.NAME)
    manifest.json "games"       entries for new ids are filled in from the categories

Godot is located via the GODOT environment variable, then the known portable
install path, then PATH.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "manifest.json"
PRESETS = ROOT / "export_presets.cfg"
VERSION_GD = ROOT / "scripts/common/version.gd"
CONFIG_GD = ROOT / "scripts/common/config.gd"
BRAND_GD = ROOT / "scripts/common/brand.gd"
MEDIA = ROOT / "media"
CREDITS = MEDIA / "CREDITS.json"
TEMPLATES = ROOT / "tools/templates"
PACKS_OUT = ROOT / "builds/packs"
MEDIA_OUT = ROOT / "builds/media"
MEDIA_NAME_RE = re.compile(r"^media-(common|cat-[a-z][a-z0-9_]*)$")
KNOWN_GODOT = Path(os.path.expandvars(
    r"%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
    r"\Godot_v4.7.2-stable_win64_console.exe"))
KNOWN_GH = Path(r"C:\Program Files\GitHub CLI\gh.exe")
ANDROID_PRESET = "Android"
APK_ARCHES = ["arm64-v8a", "armeabi-v7a", "x86_64"]
ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")


class ToolError(Exception):
    pass


# ---------------------------------------------------------------- sources

def read_config() -> dict[str, str]:
    text = CONFIG_GD.read_text(encoding="utf-8")
    return dict(re.findall(r'^const (\w+) := "([^"]*)"\s*$', text, re.M))


def read_version() -> tuple[str, int]:
    text = VERSION_GD.read_text(encoding="utf-8")
    v = re.search(r'^const VERSION := "([\d.]+)"', text, re.M)
    b = re.search(r'^const BUILD_NUMBER := (\d+)', text, re.M)
    if not v or not b:
        raise ToolError(f"couldn't find VERSION / BUILD_NUMBER in {VERSION_GD}")
    return v.group(1), int(b.group(1))


def read_brand() -> str:
    """Brand.NAME -- the app's visible name (internal ids keep "voodoo")."""
    m = re.search(r'^const NAME := "([^"]+)"', BRAND_GD.read_text(encoding="utf-8"), re.M)
    if not m:
        raise ToolError(f"couldn't find NAME in {BRAND_GD}")
    return m.group(1)


def write_version(version: str, build: int) -> None:
    text = VERSION_GD.read_text(encoding="utf-8")
    text = re.sub(r'^const VERSION := "[\d.]+"', f'const VERSION := "{version}"', text, flags=re.M)
    text = re.sub(r'^const BUILD_NUMBER := \d+', f'const BUILD_NUMBER := {build}', text, flags=re.M)
    VERSION_GD.write_text(text, encoding="utf-8", newline="\n")


def load_manifest() -> dict:
    try:
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise ToolError(f"manifest.json is not valid JSON: {e}") from e


def save_manifest(m: dict) -> None:
    """Hand-editable layout: one line per game, so diffs stay one line too."""
    dumps = lambda v: json.dumps(v, ensure_ascii=False)
    out = ["{"]
    for key in m:
        if key in ("categories", "games"):
            continue
        if key == "media_packs" and isinstance(m[key], dict) and m[key]:
            out.append('  "media_packs": {')
            packs = list(m[key].items())
            for i, (name, entry) in enumerate(packs):
                out.append(f"    {dumps(name)}: {dumps(entry)}" + ("," if i < len(packs) - 1 else ""))
            out.append("  },")
            continue
        out.append(f"  {dumps(key)}: {dumps(m[key])},")
    out.append('  "categories": [')
    cats = m["categories"]
    for ci, cat in enumerate(cats):
        head = {k: v for k, v in cat.items() if k != "games"}
        out.append("    {" + ", ".join(f"{dumps(k)}: {dumps(v)}" for k, v in head.items()) + ', "games": [')
        games = cat["games"]
        for gi, g in enumerate(games):
            out.append("      " + dumps(g) + ("," if gi < len(games) - 1 else ""))
        out.append("    ]}" + ("," if ci < len(cats) - 1 else ""))
    out.append("  ],")
    out.append('  "games": {')
    items = list(m["games"].items())
    for i, (gid, entry) in enumerate(items):
        out.append(f"    {dumps(gid)}: {dumps(entry)}" + ("," if i < len(items) - 1 else ""))
    out.append("  }")
    out.append("}")
    MANIFEST.write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")


def catalog_ids(m: dict) -> list[str]:
    return [g["id"] for c in m.get("categories", []) for g in c.get("games", []) if g.get("id")]


def archived_ids(m: dict) -> set[str]:
    """Games hidden from the hub (HUB_V2_PLAN §6): "archived": true on the
    game or its category. They keep their presets, packs and saves."""
    return {g["id"] for c in m.get("categories", []) for g in c.get("games", [])
            if g.get("id") and (c.get("archived") is True or g.get("archived") is True)}


def live_ids(m: dict) -> list[str]:
    """Games the hub shows: the ones `export --all`, `test`, `i18n` and `verify` cover."""
    hidden = archived_ids(m)
    return [gid for gid in catalog_ids(m) if gid not in hidden]


def scene_path(gid: str) -> str:
    return f"res://scenes/games/{gid}/{gid}.tscn"


def res_to_disk(res: str) -> Path:
    return ROOT / res.removeprefix("res://")


def camel(gid: str) -> str:
    return "".join(p.capitalize() for p in gid.split("_"))


# ---------------------------------------------------------------- media packs (STANDARDS §10)

def media_dir(name: str) -> str:
    """media-common -> media/common, media-cat-cards -> media/cat/cards."""
    if name.startswith("media-cat-"):
        return "media/cat/" + name.removeprefix("media-cat-")
    return "media/" + name.removeprefix("media-")


def media_packs(m: dict) -> dict:
    packs = m.get("media_packs", {})
    return packs if isinstance(packs, dict) else {}


def media_file_name(name: str, version: int) -> str:
    # A new file per version: a mounted pack must never be overwritten.
    return f"{name}.v{version}.pck"


def parse_requirement(req: str) -> tuple[str, int]:
    name, _, minimum = str(req).partition(">=")
    return name.strip(), int(minimum) if minimum.strip().isdigit() else 1


# ---------------------------------------------------------------- export_presets.cfg

def split_presets(text: str) -> list[dict]:
    """Returns [{index, name, export_path, body}] where body is the full text of
    [preset.N] + [preset.N.options] exactly as written."""
    parts = re.split(r"(?m)^(?=\[preset\.\d+\]\s*$)", text)
    presets = []
    for part in parts:
        m = re.match(r"\[preset\.(\d+)\]", part)
        if not m:
            if part.strip():
                raise ToolError("unexpected text before the first [preset.N] in export_presets.cfg")
            continue
        name = re.search(r'(?m)^name="([^"]*)"', part)
        path = re.search(r'(?m)^export_path="([^"]*)"', part)
        presets.append({
            "index": int(m.group(1)),
            "name": name.group(1) if name else "",
            "export_path": path.group(1) if path else "",
            "body": part.rstrip("\n") + "\n",
        })
    return presets


def is_pack_preset(p: dict) -> bool:
    return p["export_path"].startswith("builds/packs/")


def is_media_preset(p: dict) -> bool:
    return p["export_path"].startswith("builds/media/")


# Godot drags the project icon and autoload scripts into every pack. The icon
# alone was ~1.1 MB of each ~1.1 MB pack; the scripts already ship in the APK.
# media/ is the hub's own art (and later the shared media packs).
PACK_EXCLUDE = "assets/*, media/*, scripts/common/*, scripts/hub/*, scripts/account/*"
# Media packs carry only their own folder; everything shared stays in the APK.
MEDIA_EXCLUDE = "assets/*, media/hub/*, media/licenses/*, scripts/*, scenes/*, games/*"
# The APK leaves out every game (its pack) and every downloadable media tier.
ANDROID_EXCLUDE = "scenes/games/*, scripts/games/*, games/*, media/common/*, media/cat/*"
# Non-resource files the app reads at runtime: the offline catalog and the
# credits list (📜 Credits screen).
APP_INCLUDE = "manifest.json, media/CREDITS.json"


def pack_preset_text(index: int, name: str, gid: str) -> str:
    return f'''[preset.{index}]

name="{name}"
platform="Windows Desktop"
runnable=false
advanced_options=false
dedicated_server=false
custom_features="game_pack"
export_filter="resources"
export_files=PackedStringArray()
include_filter="scenes/games/{gid}/*, scripts/games/{gid}/*, games/{gid}/*"
exclude_filter="{PACK_EXCLUDE}"
export_path="builds/packs/{gid}.pck"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.{index}.options]

custom_template/debug=""
custom_template/release=""
binary_format/architecture="x86_64"
'''


def media_preset_text(index: int, name: str) -> str:
    return f'''[preset.{index}]

name="{media_preset_name(name)}"
platform="Windows Desktop"
runnable=false
advanced_options=false
dedicated_server=false
custom_features="game_pack"
export_filter="resources"
export_files=PackedStringArray()
include_filter="{media_dir(name)}/*"
exclude_filter="{MEDIA_EXCLUDE}"
export_path="builds/media/{name}.pck"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.{index}.options]

custom_template/debug=""
custom_template/release=""
binary_format/architecture="x86_64"
'''


def media_preset_name(name: str) -> str:
    return camel(name.removeprefix("media-").replace("-", "_")) + "Media"


def pack_preset_names() -> dict[str, str]:
    """pack id -> preset name, from the current export_presets.cfg."""
    names = {}
    for p in split_presets(PRESETS.read_text(encoding="utf-8")):
        if is_pack_preset(p):
            names[Path(p["export_path"]).stem] = p["name"]
    return names


def render_presets(ids: list[str], media: list[str] | None = None) -> str:
    """export_presets.cfg with every pack preset regenerated from `ids`, the
    Android preset's version fields synced to version.gd, and the app name
    every platform shows synced to Brand.NAME (package ids never change)."""
    version, build = read_version()
    brand = read_brand()
    if media is None:
        media = list(media_packs(load_manifest()))
    presets = split_presets(PRESETS.read_text(encoding="utf-8"))
    base = [p for p in presets if not is_pack_preset(p) and not is_media_preset(p)]
    old_names = {Path(p["export_path"]).stem: p["name"] for p in presets if is_pack_preset(p)}

    chunks = []
    for i, p in enumerate(base):
        body = re.sub(r"(?m)^\[preset\.\d+\]", f"[preset.{i}]", p["body"])
        body = re.sub(r"(?m)^\[preset\.\d+\.options\]", f"[preset.{i}.options]", body)
        if p["name"] == ANDROID_PRESET:
            body = re.sub(r"(?m)^version/code=.*$", f"version/code={build}", body)
            body = re.sub(r'(?m)^version/name=.*$', f'version/name="{version}"', body)
            # The bundled manifest.json is the offline fallback catalog.
            body = re.sub(r'(?m)^include_filter=.*$', f'include_filter="{APP_INCLUDE}"', body)
            body = re.sub(r'(?m)^exclude_filter=.*$', f'exclude_filter="{ANDROID_EXCLUDE}"', body)
        if p["name"] == PC_PRESET and "media/CREDITS.json" not in body:
            body = re.sub(r'(?m)^include_filter="(.*)"$', lambda mm: f'include_filter="{mm.group(1)}, media/CREDITS.json"', body)
        # The name players see: Android's app label, Windows' product name.
        suffix = " Dev" if p["name"].endswith("Dev") else ""
        body = re.sub(r'(?m)^package/name=.*$', f'package/name="{brand}{suffix}"', body)
        body = re.sub(r'(?m)^application/product_name=.*$', f'application/product_name="{brand}"', body)
        chunks.append(body)
    # Existing presets keep their order (stable diffs); new games go last.
    ordered = [gid for gid in old_names if gid in ids] + [gid for gid in ids if gid not in old_names]
    for j, gid in enumerate(ordered):
        chunks.append(pack_preset_text(len(base) + j, old_names.get(gid, camel(gid) + "Pack"), gid))
    for k, name in enumerate(media):
        chunks.append(media_preset_text(len(base) + len(ordered) + k, name))
    return "\n".join(chunks)


# ---------------------------------------------------------------- home kit

# Every game that uses the Home screen kit carries its own copy of it
# (scripts/games/<id>/home_kit.gd), so its pack runs on any app version.
# The template is the only one ever edited; `sync` copies it out.
HOME_KIT = TEMPLATES / "home_kit.gd"


def home_kit_users(ids: list[str]) -> list[str]:
    users = []
    for gid in ids:
        game_dir = ROOT / "scripts/games" / gid
        if any("home_kit.gd" in f.read_text(encoding="utf-8")
               for f in game_dir.glob("*.gd") if f.name != "home_kit.gd"):
            users.append(gid)
    return users


def stale_home_kits(ids: list[str]) -> list[Path]:
    want = HOME_KIT.read_text(encoding="utf-8")
    stale = []
    for gid in home_kit_users(ids):
        kit = ROOT / "scripts/games" / gid / "home_kit.gd"
        if not kit.is_file() or kit.read_text(encoding="utf-8") != want:
            stale.append(kit)
    return stale


def sync_home_kits(ids: list[str]) -> None:
    text = HOME_KIT.read_text(encoding="utf-8")
    for kit in stale_home_kits(ids):
        kit.write_text(text, encoding="utf-8", newline="\n")
        print(f"  {kit.relative_to(ROOT)} updated from the template")


# ---------------------------------------------------------------- validation

def validate() -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    m = load_manifest()
    cats = m.get("categories")
    games = m.get("games")
    if not isinstance(cats, list) or not cats:
        errors.append('manifest.json: "categories" must be a non-empty list')
        cats = []
    if not isinstance(games, dict):
        errors.append('manifest.json: "games" must be an object')
        games = {}

    seen: set[str] = set()
    for cat in cats:
        cname = cat.get("name", "?")
        if not cat.get("name") or not cat.get("icon"):
            errors.append(f'category {cname!r}: needs "name" and "icon"')
        for g in cat.get("games", []):
            label = g.get("title", "?")
            if not g.get("title") or not g.get("icon"):
                errors.append(f'{cname} / {label}: needs "title" and "icon"')
            gid = g.get("id")
            if not gid:
                continue
            if not ID_RE.match(gid):
                errors.append(f"{label}: id {gid!r} must be lowercase letters, digits, underscores")
            if gid in seen:
                errors.append(f"{gid}: listed in more than one place")
            seen.add(gid)
            entry = games.get(gid)
            if entry is None:
                errors.append(f'{gid}: in categories but missing from "games" (run sync)')
                continue
            if not isinstance(entry.get("version"), int) or entry["version"] < 1:
                errors.append(f"{gid}: version must be an integer >= 1")
            scene = entry.get("scene", "")
            if not res_to_disk(scene).is_file():
                errors.append(f"{gid}: scene {scene} does not exist")
            if not (ROOT / "scripts/games" / gid).is_dir():
                errors.append(f"{gid}: scripts/games/{gid}/ does not exist")
            if not str(entry.get("url", "")).endswith(f"/{gid}.pck"):
                errors.append(f"{gid}: url should end in /{gid}.pck")
    for gid in games:
        if gid not in seen:
            warnings.append(f'{gid}: in "games" but not in any category, so the hub never shows it')

    errors += lint_media(m)

    for kit in stale_home_kits(catalog_ids(m)):
        errors.append(f"{kit.relative_to(ROOT)} differs from tools/templates/home_kit.gd -- run sync")

    current = PRESETS.read_text(encoding="utf-8")
    if render_presets(catalog_ids(m)) != current:
        errors.append("export_presets.cfg is out of date (pack presets, Android version or app name) -- run sync")
    errors += lint_credits()
    errors += lint_hub_name()
    return errors, warnings


AUDIO_EXTS = {".wav", ".mp3", ".flac", ".aiff", ".aif", ".m4a", ".ogg", ".opus"}


def lint_media(m: dict) -> list[str]:
    """STANDARDS §10: media_packs entries, each game's requires_media, OGG only,
    looping music."""
    errors = []
    packs = media_packs(m)
    for name, e in packs.items():
        if not MEDIA_NAME_RE.match(name):
            errors.append(f"media pack {name!r}: name must be media-common or media-cat-<category>")
            continue
        v = e.get("version") if isinstance(e, dict) else None
        if not isinstance(v, int) or v < 1:
            errors.append(f"media pack {name}: version must be an integer >= 1")
            continue
        if not str(e.get("url", "")).endswith("/" + media_file_name(name, v)):
            errors.append(f"media pack {name}: url should end in /{media_file_name(name, v)} -- run sync")
        if not (ROOT / media_dir(name)).is_dir():
            errors.append(f"media pack {name}: folder {media_dir(name)}/ does not exist")
        if not isinstance(e.get("size"), int) or not re.fullmatch(r"[0-9a-f]{64}", str(e.get("sha256", ""))):
            errors.append(f"media pack {name}: no size/sha256 yet -- run export-media {name}")
    for folder in [MEDIA / "common", *sorted((MEDIA / "cat").glob("*"))]:
        if folder.is_dir() and any(f.is_file() and f.suffix not in (".import", ".uid") for f in folder.rglob("*")):
            rel = folder.relative_to(ROOT).as_posix()
            name = "media-common" if rel == "media/common" else "media-cat-" + folder.name
            if name not in packs:
                errors.append(f'{rel}/ has files but no "media_packs" entry {name!r} in manifest.json')
    for gid, entry in m.get("games", {}).items():
        reqs = entry.get("requires_media", [])
        if not isinstance(reqs, list):
            errors.append(f'{gid}: "requires_media" must be a list like ["media-common>=1"]')
            continue
        for req in reqs:
            name, minimum = parse_requirement(req)
            if name not in packs:
                errors.append(f"{gid}: requires {name}, which isn't in media_packs")
            elif isinstance(packs[name].get("version"), int) and minimum > packs[name]["version"]:
                errors.append(f"{gid}: requires {name}>={minimum}, but it is at version {packs[name]['version']}")
    if MEDIA.is_dir():
        for f in sorted(MEDIA.rglob("*")):
            if f.suffix.lower() in AUDIO_EXTS and f.suffix.lower() != ".ogg":
                errors.append(f"{f.relative_to(ROOT).as_posix()}: audio must be OGG Vorbis (STANDARDS §10)")
            if f.suffix == ".ogg" and "music" in f.relative_to(MEDIA).parts:
                imp = f.with_name(f.name + ".import")
                if imp.is_file() and not re.search(r"(?m)^loop=true", imp.read_text(encoding="utf-8")):
                    errors.append(f"{f.relative_to(ROOT).as_posix()}: music must loop -- set loop=true in its .import")
    return errors


NOT_ALLOWED_LICENCE = re.compile(r"\bNC\b|\bND\b|non-?commercial|no-?deriv", re.I)


def lint_credits() -> list[str]:
    """STANDARDS §10: every file under media/ has a media/CREDITS.json entry."""
    if not MEDIA.is_dir():
        return []
    try:
        credits = json.loads(CREDITS.read_text(encoding="utf-8")) if CREDITS.is_file() else {}
    except json.JSONDecodeError as e:
        return [f"media/CREDITS.json is not valid JSON: {e}"]
    listed = {str(e.get("file", "")) for e in credits.get("assets", [])}
    errors = []
    for e in credits.get("assets", []):
        if NOT_ALLOWED_LICENCE.search(str(e.get("licence", ""))):
            errors.append(f"{e.get('file')}: licence {e.get('licence')!r} is NC/ND -- not allowed (STANDARDS §10)")
    for f in sorted(MEDIA.rglob("*")):
        rel = f.relative_to(ROOT).as_posix()
        if (f.is_dir() or f.suffix in (".import", ".uid") or f.name in (".gdignore", "CREDITS.json")
                or rel.startswith("media/licenses/")):
            continue
        if rel not in listed:
            errors.append(f"{rel}: no entry in media/CREDITS.json (STANDARDS §10)")
    for rel in sorted(listed - {""}):
        if not (ROOT / rel).is_file():
            errors.append(f"media/CREDITS.json lists {rel}, which doesn't exist")
    return errors


# Text the APK shows that may say "Voodoo": the skin's own labels. Anything
# else naming the app must use Brand.NAME (CLAUDE.md "Rename safety" -- ids
# and paths keep "voodoo"; only visible text changed).
VOODOO_TEXT_OK = {
    "💀 Voodoo: On", "💀 Voodoo: Off",
    "Skulls, crossbones and voodoo dolls in Tic-Tac-Toe, Connect Four and Reversi.",
}


def lint_hub_name() -> list[str]:
    # es.json already sorts literals into UI text and not-UI text (null), so
    # internal strings like the User-Agent are skipped.
    master = json.loads(I18N_MASTER.read_text(encoding="utf-8")) if I18N_MASTER.is_file() else {}
    errors = []
    for d in ("scripts/common", "scripts/hub", "scripts/account"):
        for f in sorted((ROOT / d).glob("*.gd")):
            if f.name == "strings_es.gd":
                continue
            for text in _display_literals(f):
                if (re.search(r"voodoo", text, re.I) and text not in VOODOO_TEXT_OK
                        and not (text in master and master[text] is None)):
                    errors.append(f"{f.relative_to(ROOT).as_posix()}: {text!r} names Voodoo -- use "
                                  "Brand.NAME (Voodoo is only the skin's name)")
    return errors


# ---------------------------------------------------------------- commands

def cmd_sync(_args=None) -> None:
    m = load_manifest()
    cfg = read_config()
    base_url = (f"https://github.com/{cfg['GITHUB_OWNER']}/{cfg['GITHUB_REPO']}"
                f"/releases/download/{cfg['PACK_RELEASE_TAG']}/")
    ids = catalog_ids(m)
    for gid in ids:
        if gid not in m["games"]:
            m["games"][gid] = {"version": 1, "url": f"{base_url}{gid}.pck", "scene": scene_path(gid)}
            print(f"  added manifest entry for {gid}")
        else:
            entry = m["games"][gid]
            entry.setdefault("scene", scene_path(gid))
            wanted = f"{base_url}{gid}.pck"
            if entry.get("url") != wanted:
                entry["url"] = wanted
                print(f"  {gid}: url -> {wanted}")
    for name, e in media_packs(m).items():
        if isinstance(e, dict) and isinstance(e.get("version"), int):
            wanted = base_url + media_file_name(name, e["version"])
            if e.get("url") != wanted:
                e["url"] = wanted
                print(f"  {name}: url -> {wanted}")
    save_manifest(m)
    sync_home_kits(ids)
    new = render_presets(ids)
    if new != PRESETS.read_text(encoding="utf-8"):
        PRESETS.write_text(new, encoding="utf-8", newline="\n")
        print("  export_presets.cfg regenerated")
    cmd_check()


def cmd_check(_args=None) -> None:
    errors, warnings = validate()
    for w in warnings:
        print(f"  warning: {w}")
    for e in errors:
        print(f"  ERROR: {e}")
    if errors:
        raise ToolError(f"{len(errors)} problem(s) found")
    version, build = read_version()
    m = load_manifest()
    print(f"OK -- v{version} (build {build}), {len(live_ids(m))} games live"
          f" (+{len(archived_ids(m))} archived)")


def cmd_new_game(args) -> None:
    gid = args.id
    if not ID_RE.match(gid):
        raise ToolError("id must be lowercase letters, digits and underscores, starting with a letter")
    m = load_manifest()
    if gid in catalog_ids(m) or gid in m["games"]:
        raise ToolError(f"{gid} already exists")
    cats = {c["name"].lower(): c for c in m["categories"]}
    cat = cats.get(args.category.lower())
    if cat is None:
        raise ToolError(f"no category {args.category!r}; pick one of: " + ", ".join(c["name"] for c in m["categories"]))

    subs = {"{{ID}}": gid, "{{CLASS}}": camel(gid), "{{TITLE}}": args.title, "{{ICON}}": args.icon}
    targets = {
        "engine.gd.tmpl": ROOT / f"scripts/games/{gid}/{gid}_engine.gd",
        "game.gd.tmpl": ROOT / f"scripts/games/{gid}/{gid}_game.gd",
        "help.gd.tmpl": ROOT / f"scripts/games/{gid}/{gid}_help.gd",
        "scene.tscn.tmpl": ROOT / f"scenes/games/{gid}/{gid}.tscn",
    }
    for dest in targets.values():
        if dest.exists():
            raise ToolError(f"{dest.relative_to(ROOT)} already exists")
    for tmpl, dest in targets.items():
        text = (TEMPLATES / tmpl).read_text(encoding="utf-8")
        for k, v in subs.items():
            text = text.replace(k, v)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text, encoding="utf-8", newline="\n")
        print(f"  created {dest.relative_to(ROOT)}")

    # Replace a "coming soon" placeholder of the same title if there is one.
    for g in cat["games"]:
        if not g.get("id") and g.get("title", "").lower() == args.title.lower():
            g.clear()
            g.update({"id": gid, "title": args.title, "icon": args.icon})
            break
    else:
        cat["games"].append({"id": gid, "title": args.title, "icon": args.icon})
    save_manifest(m)
    cmd_sync()
    print(f"\nNext: build the game in scripts/games/{gid}/, then `python tools/hub.py test {gid}`.")


def cmd_bump_pack(args) -> None:
    m = load_manifest()
    for gid in args.ids:
        if gid not in m["games"]:
            raise ToolError(f"unknown game {gid}")
        m["games"][gid]["version"] += 1
        print(f"  {gid}: version {m['games'][gid]['version']}")
    save_manifest(m)


def cmd_bump_media(args) -> None:
    m = load_manifest()
    packs = media_packs(m)
    for name in args.names:
        if name not in packs:
            raise ToolError(f"unknown media pack {name}")
        packs[name]["version"] += 1
        packs[name].pop("size", None)
        packs[name].pop("sha256", None)  # export-media fills them for the new file
        print(f"  {name}: version {packs[name]['version']}")
    save_manifest(m)
    cmd_sync()


def cmd_bump_app(args) -> None:
    version, build = read_version()
    major, minor, patch = (int(x) for x in version.split("."))
    if args.part == "major":
        major, minor, patch = major + 1, 0, 0
    elif args.part == "minor":
        minor, patch = minor + 1, 0
    else:
        patch += 1
    new_version = f"{major}.{minor}.{patch}"
    write_version(new_version, build + 1)
    print(f"  v{version} (build {build}) -> v{new_version} (build {build + 1})")
    cmd_sync()


# ---- godot-driven commands

def godot() -> str:
    for candidate in (os.environ.get("GODOT"), str(KNOWN_GODOT), shutil.which("godot")):
        if candidate and Path(candidate).is_file():
            return candidate
    raise ToolError("Godot not found -- set the GODOT environment variable to the console .exe")


def run_godot(*args: str, timeout: int = 300, env: dict | None = None) -> tuple[int, str]:
    proc = subprocess.run([godot(), "--headless", "--path", str(ROOT), *args],
                          capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout,
                          env={**os.environ, **(env or {})})
    return proc.returncode, proc.stdout + proc.stderr


ERROR_RE = re.compile(r"SCRIPT ERROR|Parse Error|^ERROR:|Failed to load", re.M)


def cmd_test(args) -> None:
    m = load_manifest()
    ids = args.ids or live_ids(m)
    scenes = [] if args.ids else ["res://scenes/hub/hub.tscn", "res://scenes/hub/options.tscn", "res://scenes/account/account.tscn",
              "res://scenes/hub/leaderboards.tscn", "res://scenes/hub/achievements.tscn",
              "res://scenes/hub/friends.tscn", "res://scenes/hub/multiplayer.tscn"]
    scenes += [m["games"][gid]["scene"] for gid in ids]
    # First run imports any new files so the boots below see them.
    run_godot("--import", timeout=600)
    failed = 0
    for scene in scenes:
        _, out = run_godot(scene, "--quit-after", "60")
        problems = [line for line in out.splitlines() if ERROR_RE.search(line)]
        print(("  FAIL " if problems else "  ok   ") + scene)
        for line in problems[:8]:
            print("         " + line)
        failed += bool(problems)
    if failed:
        raise ToolError(f"{failed} scene(s) printed errors")


def cmd_export(args) -> None:
    m = load_manifest()
    ids = live_ids(m) if args.all else args.ids
    if not ids:
        raise ToolError("name the games to export, or pass --all")
    names = pack_preset_names()
    PACKS_OUT.mkdir(parents=True, exist_ok=True)
    for gid in ids:
        if gid not in names:
            raise ToolError(f"no export preset for {gid} -- run sync")
        out_path = PACKS_OUT / f"{gid}.pck"
        # The CLI path always wins over the preset's export_path; pass it explicitly.
        code, log = run_godot("--export-pack", names[gid], str(out_path))
        if code != 0 or not out_path.is_file():
            print(log)
            raise ToolError(f"export of {gid} failed")
        print(f"  {gid}: {out_path.relative_to(ROOT)} ({out_path.stat().st_size:,} bytes)")


def cmd_export_media(args) -> None:
    import hashlib
    m = load_manifest()
    packs = media_packs(m)
    names = list(packs) if args.all else args.names
    if not names:
        raise ToolError("name the media packs to export, or pass --all")
    MEDIA_OUT.mkdir(parents=True, exist_ok=True)
    for name in names:
        if name not in packs:
            raise ToolError(f"unknown media pack {name} -- add it to manifest.json \"media_packs\"")
        out_path = MEDIA_OUT / media_file_name(name, packs[name]["version"])
        code, log = run_godot("--export-pack", media_preset_name(name), str(out_path))
        if code != 0 or not out_path.is_file():
            print(log)
            raise ToolError(f"export of {name} failed")
        data = out_path.read_bytes()
        packs[name]["size"] = len(data)
        packs[name]["sha256"] = hashlib.sha256(data).hexdigest()
        print(f"  {name}: {out_path.relative_to(ROOT)} ({len(data):,} bytes)")
    # The manifest now names exactly these bytes: upload THIS build.
    save_manifest(m)


# The release signing key lives OUTSIDE the repo, with its password in a
# small JSON file next to it. Losing it means installed apps can never be
# updated again (Android only accepts updates signed by the same key), so
# the user keeps a backup copy. Never commit either file.
RELEASE_KEY_INFO = Path(os.environ.get(
    "VOODOO_RELEASE_KEY", str(Path.home() / "Android" / "keystore" / "voodoo-release.json")))
BUILD_TOOLS = Path.home() / "Android" / "sdk" / "build-tools" / "34.0.0"


def release_signing_env() -> dict:
    if not RELEASE_KEY_INFO.is_file():
        raise ToolError(f"release key info not found at {RELEASE_KEY_INFO} -- see CLAUDE.md 'App signing'")
    info = json.loads(RELEASE_KEY_INFO.read_text(encoding="utf-8"))
    # Godot reads these instead of the (committed) export_presets.cfg, so the
    # password never lands in the repo.
    return {
        "GODOT_ANDROID_KEYSTORE_RELEASE_PATH": info["keystore"],
        "GODOT_ANDROID_KEYSTORE_RELEASE_USER": info["alias"],
        "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD": info["password"],
    }


def cmd_apk(args) -> None:
    cmd_check()
    version, _ = read_version()
    apk = ROOT / "builds/game-hub.apk"
    if args.debug:
        code, log = run_godot("--export-debug", ANDROID_PRESET, str(apk), timeout=900)
    else:
        code, log = run_godot("--export-release", ANDROID_PRESET, str(apk), timeout=900, env=release_signing_env())
    if code != 0 or not apk.is_file():
        print(log)
        raise ToolError("APK export failed")
    aapt = BUILD_TOOLS / "aapt.exe"
    if not args.debug and aapt.is_file():
        badging = subprocess.run([str(aapt), "dump", "badging", str(apk)], capture_output=True, text=True).stdout
        if "application-debuggable" in badging:
            raise ToolError("release APK is still marked debuggable")
    with zipfile.ZipFile(apk) as z:
        names = z.namelist()
    missing = [a for a in APK_ARCHES if not any(n.startswith(f"lib/{a}/") for n in names)]
    if missing:
        raise ToolError(f"APK is missing native libs for: {', '.join(missing)}")
    if not any(n.endswith("manifest.json") for n in names) and "assets/manifest.json" not in names:
        print("  warning: couldn't spot manifest.json inside the APK (it may be inside the .pck)")
    versioned = ROOT / f"builds/voodoo-v{version}.apk"
    shutil.copyfile(apk, versioned)
    print(f"  built {versioned.relative_to(ROOT)} ({versioned.stat().st_size:,} bytes), arches OK")


PC_DIR = Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "VoodooGameHub"
PC_PRESET = "WindowsTest"  # all_resources: every game bundled, no downloads


def cmd_pc(_args) -> None:
    """Windows build for playtesting on this PC. Games are bundled, so it
    always runs the current source -- including changes not yet published."""
    PC_DIR.mkdir(parents=True, exist_ok=True)
    exe = PC_DIR / "Voodoo.exe"
    code, log = run_godot("--export-debug", PC_PRESET, str(exe), timeout=900)
    if code != 0 or not exe.is_file():
        print(log)
        raise ToolError("Windows export failed")
    # Ask Windows: the Desktop is often redirected (e.g. into OneDrive)
    desktop = subprocess.run(
        ["powershell", "-NoProfile", "-Command", "[Environment]::GetFolderPath('Desktop')"],
        capture_output=True, text=True).stdout.strip()
    brand = read_brand()
    shortcut = Path(desktop or Path.home() / "Desktop") / f"{brand}.lnk"
    icon = PC_DIR / "icon.ico"
    try:  # the exported .exe carries Godot's icon; give the shortcut ours
        from PIL import Image
        Image.open(ROOT / "assets" / "icon.png").save(icon, sizes=[(256, 256), (64, 64), (32, 32), (16, 16)])
    except Exception:  # noqa: BLE001 -- Pillow missing: fall back to the exe icon
        pass
    ps = (
        "$s = (New-Object -ComObject WScript.Shell).CreateShortcut('{lnk}');"
        "$s.TargetPath = '{exe}'; $s.WorkingDirectory = '{dir}';"
        "$s.Description = '{brand} (PC test build)';"
        "{icon_line}$s.Save()"
    ).format(lnk=shortcut, exe=exe, dir=PC_DIR, brand=brand,
             icon_line=f"$s.IconLocation = '{icon}';" if icon.is_file() else f"$s.IconLocation = '{exe},0';")
    subprocess.run(["powershell", "-NoProfile", "-Command", ps], check=True)
    print(f"  built {exe}")
    print(f"  shortcut: {shortcut}")


PC_README = """{title} - PC test build v{version}
=========================================

1. Unzip this whole folder anywhere (Desktop, USB stick...). Keep
   Voodoo.exe and Voodoo.pck together.
2. Double-click Voodoo.exe.
   Windows may say "Windows protected your PC" (the file isn't signed):
   click "More info" -> "Run anyway".

Every game is built in, so nothing downloads. Sign-in, leaderboards,
friends and online play need an internet connection.

Saves and settings live on each PC in
   %APPDATA%\\Godot\\app_userdata\\Voodoo
Delete that folder to start fresh.

"Voodoo.exe needs SSE4.2" or a CPU error? That PC is older: run
Voodoo-older-PCs.exe instead (the same game, 32-bit, works on any PC).

Voodoo.console.exe is the same game with a log window, for reporting
problems. The window is phone-shaped; drag its edges to resize, or use
the in-game settings tab to rotate.
"""


def _template_dir() -> Path:
    """Godot's export templates for the engine version hub.py runs."""
    base = Path(os.environ.get("APPDATA", "")) / "Godot" / "export_templates"
    out = subprocess.run([godot(), "--version"], capture_output=True, text=True).stdout.strip()
    m = re.match(r"(\d+\.\d+(?:\.\d+)?)\.(\w+)", out)
    d = base / f"{m.group(1)}.{m.group(2)}" if m else None
    if d is None or not d.is_dir():
        raise ToolError(f"export templates not found for Godot '{out}' in {base}")
    return d


def cmd_pc_zip(_args) -> None:
    """The PC build as a zip to copy to other Windows PCs for testing.

    Godot 4.5+ 64-bit builds refuse CPUs without SSE4.2 (roughly pre-2011);
    its 32-bit build only needs SSE2. The .pck holds no CPU code, so the zip
    also carries the 32-bit engine as Voodoo-older-PCs.exe beside a copy of
    the same .pck (an exe loads the .pck with its own name)."""
    cmd_pc(_args)
    shutil.copyfile(_template_dir() / "windows_debug_x86_32.exe", PC_DIR / "Voodoo-older-PCs.exe")
    shutil.copyfile(PC_DIR / "Voodoo.pck", PC_DIR / "Voodoo-older-PCs.pck")
    version, _ = read_version()
    out_dir = ROOT / "builds"
    out_dir.mkdir(exist_ok=True)
    folder = read_brand().replace(" ", "")
    zip_path = out_dir / f"{folder}-PC-v{version}.zip"
    import zipfile
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for name in ["Voodoo.exe", "Voodoo.pck", "Voodoo.console.exe", "Voodoo-older-PCs.exe",
                     "Voodoo-older-PCs.pck", "icon.ico"]:
            f = PC_DIR / name
            if f.is_file():
                z.write(f, f"{folder}/{name}")
        z.writestr(f"{folder}/README.txt", PC_README.format(title=read_brand().upper(), version=version))
    print(f"  zip: {zip_path} ({zip_path.stat().st_size // (1024 * 1024)} MB)")


# ---- translations

I18N_MASTER = ROOT / "tools/i18n/es.json"
COMMON_STRINGS_GD = ROOT / "scripts/common/strings_es.gd"
_LITERAL_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')
# Obviously-not-UI literals: paths, identifiers, theme keys, formats with no words.
_NOT_TEXT_RE = re.compile(r'^(res://|user://|https?://|wss://|/|[a-z_0-9./:-]+$|[A-ZÑ]{2,}$|[A-Z][a-z]+[A-Z][A-Za-z]*$|[^A-Za-z]*$)')


def _gd_unescape(lit: str) -> str:
    return lit.encode("latin-1", "backslashreplace").decode("unicode_escape") if "\\" in lit else lit


def _display_literals(path: Path) -> list[str]:
    out: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        code = line.strip()
        if code.startswith("#") or code.startswith("const ") and "preload(" in code:
            continue
        for raw in _LITERAL_RE.findall(line):
            text = _gd_unescape(raw)
            if not _NOT_TEXT_RE.match(text) and re.search(r"[A-Za-z]{2,}", text) and text not in out:
                out.append(text)
    return out


def _gd_string(s: str) -> str:
    return json.dumps(s, ensure_ascii=False)


def _write_strings_gd(path: Path, header: str, strings: dict[str, str], with_install: bool) -> None:
    lines = ["extends RefCounted", "", header, "",
             "const %s := {" % ("STRINGS" if with_install else "ES")]
    if with_install:
        lines.append('\t"es": {')
        indent = "\t\t"
    else:
        indent = "\t"
    for k in sorted(strings):
        lines.append(f"{indent}{_gd_string(k)}: {_gd_string(strings[k])},")
    if with_install:
        lines.append("\t},")
    lines.append("}")
    if with_install:
        lines += ["",
                  "## Adds these translations for as long as `owner` (the game scene) lives.",
                  "## Goes straight to TranslationServer rather than the Lang autoload, so it",
                  "## also works on app versions from before Lang existed.",
                  "static func install(owner: Node) -> void:",
                  "\tfor locale in STRINGS:",
                  "\t\tvar t := Translation.new()",
                  "\t\tt.locale = locale",
                  "\t\tfor key in STRINGS[locale]:",
                  "\t\t\tt.add_message(key, STRINGS[locale][key])",
                  "\t\tTranslationServer.add_translation(t)",
                  "\t\towner.tree_exiting.connect(TranslationServer.remove_translation.bind(t))"]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def cmd_i18n(_args) -> None:
    """tools/i18n/es.json maps every English UI string to Spanish (null = not
    UI text, ignore). This regenerates the per-game <id>_i18n.gd files and
    scripts/common/strings_es.gd from it, and lists any text in the code that
    the master file doesn't know yet."""
    master: dict = json.loads(I18N_MASTER.read_text(encoding="utf-8")) if I18N_MASTER.is_file() else {}
    missing: dict[str, list[str]] = {}

    def collect(files: list[Path]) -> dict[str, str]:
        found: dict[str, str] = {}
        for f in files:
            for text in _display_literals(f):
                if text not in master:
                    missing.setdefault(text, []).append(str(f.relative_to(ROOT)))
                elif master[text] is not None:
                    found[text] = master[text]
        return found

    shared_dirs = ["scripts/common", "scripts/hub", "scripts/account"]
    shared_files = [f for d in shared_dirs for f in sorted((ROOT / d).glob("*.gd")) if f.name != "strings_es.gd"]
    shared = collect(shared_files)
    _write_strings_gd(COMMON_STRINGS_GD,
                      "## Generated by `python tools/hub.py i18n` from tools/i18n/es.json -- edit there.\n"
                      "## Spanish for the hub and shared screens (ships in the APK; loaded by Lang).",
                      shared, with_install=False)
    games = 0
    # Only games in the catalog: a folder someone is still building (not in
    # manifest.json yet) is theirs to generate when they register the game.
    for gid in live_ids(load_manifest()):
        game_dir = ROOT / "scripts/games" / gid
        if not game_dir.is_dir():
            continue
        files = [f for f in sorted(game_dir.glob("*.gd")) if not f.name.endswith("_i18n.gd")]
        strings = collect(files)
        # Shared dialog/online text the game shows, so it's translated even on
        # older apps whose common strings predate it.
        strings.update({k: master[k] for k in COMMON_IN_GAMES if master.get(k)})
        _write_strings_gd(game_dir / f"{gid}_i18n.gd",
                          "## Generated by `python tools/hub.py i18n` from tools/i18n/es.json -- edit there.",
                          strings, with_install=True)
        games += 1
    print(f"  wrote strings_es.gd ({len(shared)} strings) and {games} game translation files")
    out = ROOT / "tools/i18n/untranslated.json"
    if out.exists():
        out.unlink()
    if missing:
        out.write_text(json.dumps({k: v for k, v in sorted(missing.items())}, ensure_ascii=False, indent=1),
                       encoding="utf-8", newline="\n")
        print(f"  {len(missing)} string(s) not in es.json yet -- listed in {out.relative_to(ROOT)}")


# Text from shared scripts that appears inside game screens.
COMMON_IN_GAMES = {
    "Opponent disconnected — waiting...", "Your turn (%s)", "Opponent's turn (%s)", "You win!", "You lose!",
    # difficulty names built with .capitalize() from lowercase ids
    "Easy", "Medium", "Hard", "Expert",
}


# ---- GitHub

def gh() -> str:
    for candidate in (str(KNOWN_GH), shutil.which("gh")):
        if candidate and Path(candidate).is_file():
            return candidate
    raise ToolError("GitHub CLI (gh) not found")


def cmd_publish_packs(args) -> None:
    tag = read_config()["PACK_RELEASE_TAG"]
    packs = media_packs(load_manifest())
    files = []
    for gid in args.ids:
        if gid in packs:
            f = MEDIA_OUT / media_file_name(gid, packs[gid]["version"])
        else:
            f = PACKS_OUT / f"{gid}.pck"
        if not f.is_file():
            raise ToolError(f"{f.relative_to(ROOT)} not built -- run export / export-media first")
        files.append(str(f))
    subprocess.run([gh(), "release", "upload", tag, *files, "--clobber"], cwd=ROOT, check=True)
    print("  uploaded. Remember: commit + push manifest.json so apps see the new versions.")


def cmd_release(args) -> None:
    version, _ = read_version()
    apk = ROOT / f"builds/voodoo-v{version}.apk"
    if not apk.is_file():
        raise ToolError(f"{apk.relative_to(ROOT)} not built -- run apk first")
    subprocess.run([gh(), "release", "create", f"v{version}", str(apk), "--title", f"v{version}",
                    "--notes", args.notes or f"{read_brand()} v{version}"], cwd=ROOT, check=True)


def fetch_size(url: str) -> tuple[int, int]:
    req = urllib.request.Request(url, headers={"User-Agent": "voodoo-hub-tool"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.status, len(r.read())


def cmd_verify(_args) -> None:
    cfg = read_config()
    m = load_manifest()
    bad = 0
    raw = f"https://raw.githubusercontent.com/{cfg['GITHUB_OWNER']}/{cfg['GITHUB_REPO']}/{cfg['GITHUB_BRANCH']}/manifest.json"
    try:
        req = urllib.request.Request(raw, headers={"User-Agent": "voodoo-hub-tool"})
        live = json.loads(urllib.request.urlopen(req, timeout=30).read())
        if live.get("games") != m["games"] or live.get("media_packs") != m.get("media_packs"):
            print("  WARN live manifest.json differs from local (not pushed yet? raw GitHub caches ~5 min)")
    except Exception as e:  # noqa: BLE001 -- report and carry on
        print(f"  FAIL live manifest: {e}")
        bad += 1
    for name, e in media_packs(m).items():
        try:
            status, size = fetch_size(e["url"])
        except Exception as ex:  # noqa: BLE001
            print(f"  FAIL {name}: {ex}")
            bad += 1
            continue
        ok = status == 200 and size == e.get("size")
        print(f"  {'ok  ' if ok else 'FAIL'} {name}: {status}, {size:,} bytes (manifest says {e.get('size')})")
        bad += not ok
    for gid in live_ids(m):
        url = m["games"][gid]["url"]
        local = PACKS_OUT / f"{gid}.pck"
        try:
            status, size = fetch_size(url)
        except Exception as e:  # noqa: BLE001
            print(f"  FAIL {gid}: {e}")
            bad += 1
            continue
        note = ""
        if local.is_file() and local.stat().st_size != size:
            note = f" (local build is {local.stat().st_size:,} bytes -- not uploaded yet?)"
        print(f"  {'ok  ' if status == 200 and not note else 'WARN'} {gid}: {status}, {size:,} bytes{note}")
    if bad:
        raise ToolError(f"{bad} check(s) failed")


# ---------------------------------------------------------------- main

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("check").set_defaults(fn=cmd_check)
    sub.add_parser("sync").set_defaults(fn=cmd_sync)
    p = sub.add_parser("new-game")
    p.add_argument("id")
    p.add_argument("--title", required=True)
    p.add_argument("--icon", required=True)
    p.add_argument("--category", required=True)
    p.set_defaults(fn=cmd_new_game)
    p = sub.add_parser("bump-pack")
    p.add_argument("ids", nargs="+")
    p.set_defaults(fn=cmd_bump_pack)
    p = sub.add_parser("bump-app")
    p.add_argument("part", nargs="?", default="patch", choices=["patch", "minor", "major"])
    p.set_defaults(fn=cmd_bump_app)
    p = sub.add_parser("test")
    p.add_argument("ids", nargs="*")
    p.set_defaults(fn=cmd_test)
    p = sub.add_parser("export")
    p.add_argument("ids", nargs="*")
    p.add_argument("--all", action="store_true")
    p.set_defaults(fn=cmd_export)
    p = sub.add_parser("apk")
    p.add_argument("--debug", action="store_true", help="test build signed with the shared debug key (never ship this)")
    p.set_defaults(fn=cmd_apk)
    sub.add_parser("verify").set_defaults(fn=cmd_verify)
    sub.add_parser("pc").set_defaults(fn=cmd_pc)
    sub.add_parser("pc-zip").set_defaults(fn=cmd_pc_zip)
    sub.add_parser("i18n").set_defaults(fn=cmd_i18n)
    p = sub.add_parser("export-media")
    p.add_argument("names", nargs="*")
    p.add_argument("--all", action="store_true")
    p.set_defaults(fn=cmd_export_media)
    p = sub.add_parser("bump-media")
    p.add_argument("names", nargs="+")
    p.set_defaults(fn=cmd_bump_media)
    p = sub.add_parser("publish-packs")
    p.add_argument("ids", nargs="+")
    p.set_defaults(fn=cmd_publish_packs)
    p = sub.add_parser("release")
    p.add_argument("--notes", default="")
    p.set_defaults(fn=cmd_release)

    args = parser.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")  # emoji in titles on Windows consoles
    try:
        args.fn(args)
    except ToolError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
