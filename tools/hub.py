#!/usr/bin/env python3
"""Voodoo Game Hub project tool -- one command per chore that used to be a
hand-edit across several files.

    python tools/hub.py check                 validate everything, change nothing
    python tools/hub.py sync                  regenerate derived config from the sources of truth
    python tools/hub.py new-game ID --title "Title" --icon "🎲" --category "Cards"
    python tools/hub.py bump-pack ID [ID...]  a game changed: publish it as a new version
    python tools/hub.py bump-app [patch|minor|major]
    python tools/hub.py test [ID...]          headless-boot the hub, account screen and games
    python tools/hub.py export [ID...|--all]  build game .pck files into builds/packs/
    python tools/hub.py apk                   build the Android APK into builds/
    python tools/hub.py verify                check live release assets match local builds
    python tools/hub.py publish-packs ID...   upload packs to the GitHub pack release
    python tools/hub.py release               create the GitHub release for the current APK

Sources of truth (edit these by hand):
    manifest.json               the game catalog: categories, titles, icons, pack versions
    scripts/common/version.gd   VERSION + BUILD_NUMBER
    scripts/common/config.gd    repo / release / Supabase addresses

Derived (never edit by hand -- `sync` rewrites them):
    export_presets.cfg          one "<Name>Pack" preset per game; Android version fields
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
TEMPLATES = ROOT / "tools/templates"
PACKS_OUT = ROOT / "builds/packs"
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


def scene_path(gid: str) -> str:
    return f"res://scenes/games/{gid}/{gid}.tscn"


def res_to_disk(res: str) -> Path:
    return ROOT / res.removeprefix("res://")


def camel(gid: str) -> str:
    return "".join(p.capitalize() for p in gid.split("_"))


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


# Godot drags the project icon and autoload scripts into every pack. The icon
# alone was ~1.1 MB of each ~1.1 MB pack; the scripts already ship in the APK.
PACK_EXCLUDE = "assets/*, scripts/common/*, scripts/hub/*, scripts/account/*"


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
include_filter="scenes/games/{gid}/*, scripts/games/{gid}/*"
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


def pack_preset_names() -> dict[str, str]:
    """pack id -> preset name, from the current export_presets.cfg."""
    names = {}
    for p in split_presets(PRESETS.read_text(encoding="utf-8")):
        if is_pack_preset(p):
            names[Path(p["export_path"]).stem] = p["name"]
    return names


def render_presets(ids: list[str]) -> str:
    """export_presets.cfg with every pack preset regenerated from `ids` and the
    Android preset's version fields synced to version.gd."""
    version, build = read_version()
    presets = split_presets(PRESETS.read_text(encoding="utf-8"))
    base = [p for p in presets if not is_pack_preset(p)]
    old_names = {Path(p["export_path"]).stem: p["name"] for p in presets if is_pack_preset(p)}

    chunks = []
    for i, p in enumerate(base):
        body = re.sub(r"(?m)^\[preset\.\d+\]", f"[preset.{i}]", p["body"])
        body = re.sub(r"(?m)^\[preset\.\d+\.options\]", f"[preset.{i}.options]", body)
        if p["name"] == ANDROID_PRESET:
            body = re.sub(r"(?m)^version/code=.*$", f"version/code={build}", body)
            body = re.sub(r'(?m)^version/name=.*$', f'version/name="{version}"', body)
            # The bundled manifest.json is the offline fallback catalog.
            body = re.sub(r'(?m)^include_filter=.*$', 'include_filter="manifest.json"', body)
        chunks.append(body)
    # Existing presets keep their order (stable diffs); new games go last.
    ordered = [gid for gid in old_names if gid in ids] + [gid for gid in ids if gid not in old_names]
    for j, gid in enumerate(ordered):
        chunks.append(pack_preset_text(len(base) + j, old_names.get(gid, camel(gid) + "Pack"), gid))
    return "\n".join(chunks)


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

    current = PRESETS.read_text(encoding="utf-8")
    if render_presets(catalog_ids(m)) != current:
        errors.append("export_presets.cfg is out of date (pack presets or Android version) -- run sync")
    return errors, warnings


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
    save_manifest(m)
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
    print(f"OK -- v{version} (build {build}), {len(catalog_ids(load_manifest()))} games")


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


def run_godot(*args: str, timeout: int = 300) -> tuple[int, str]:
    proc = subprocess.run([godot(), "--headless", "--path", str(ROOT), *args],
                          capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
    return proc.returncode, proc.stdout + proc.stderr


ERROR_RE = re.compile(r"SCRIPT ERROR|Parse Error|^ERROR:|Failed to load", re.M)


def cmd_test(args) -> None:
    m = load_manifest()
    ids = args.ids or catalog_ids(m)
    scenes = [] if args.ids else ["res://scenes/hub/hub.tscn", "res://scenes/account/account.tscn"]
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
    ids = catalog_ids(m) if args.all else args.ids
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


def cmd_apk(_args) -> None:
    cmd_check()
    version, _ = read_version()
    apk = ROOT / "builds/game-hub.apk"
    code, log = run_godot("--export-debug", ANDROID_PRESET, str(apk), timeout=900)
    if code != 0 or not apk.is_file():
        print(log)
        raise ToolError("APK export failed")
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


# ---- GitHub

def gh() -> str:
    for candidate in (str(KNOWN_GH), shutil.which("gh")):
        if candidate and Path(candidate).is_file():
            return candidate
    raise ToolError("GitHub CLI (gh) not found")


def cmd_publish_packs(args) -> None:
    tag = read_config()["PACK_RELEASE_TAG"]
    files = []
    for gid in args.ids:
        f = PACKS_OUT / f"{gid}.pck"
        if not f.is_file():
            raise ToolError(f"{f.relative_to(ROOT)} not built -- run export first")
        files.append(str(f))
    subprocess.run([gh(), "release", "upload", tag, *files, "--clobber"], cwd=ROOT, check=True)
    print("  uploaded. Remember: commit + push manifest.json so apps see the new versions.")


def cmd_release(args) -> None:
    version, _ = read_version()
    apk = ROOT / f"builds/voodoo-v{version}.apk"
    if not apk.is_file():
        raise ToolError(f"{apk.relative_to(ROOT)} not built -- run apk first")
    subprocess.run([gh(), "release", "create", f"v{version}", str(apk), "--title", f"v{version}",
                    "--notes", args.notes or f"Voodoo v{version}"], cwd=ROOT, check=True)


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
        if live.get("games") != m["games"]:
            print("  WARN live manifest.json differs from local (not pushed yet? raw GitHub caches ~5 min)")
    except Exception as e:  # noqa: BLE001 -- report and carry on
        print(f"  FAIL live manifest: {e}")
        bad += 1
    for gid in catalog_ids(m):
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
    sub.add_parser("apk").set_defaults(fn=cmd_apk)
    sub.add_parser("verify").set_defaults(fn=cmd_verify)
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
