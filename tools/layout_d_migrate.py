"""One-off migration for Layout D (owner 2026-11-20). Run from the repo root:

    python tools/layout_d_migrate.py            # writes manifest.json, prints the review lists

Adds to every game in manifest.json (old "categories" groups stay for apps before 0.43):
  "category": new id from the old group (scripts/hub/categories.gd FROM_OLD)
  "tags":     lowercase, from fields the game already has (modes, quick, original)
  "added":    the date the game first appeared in manifest.json (git history)
and to each "games" entry "updated": the date its pack version last changed (git history).
Top level: "featured" and "starter" (owner edits them; no app update needed).
Safe to run again: existing values are kept.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import hub  # noqa: E402  (save_manifest keeps the one-line-per-game layout)

FROM_OLD = {"Puzzle & Board": "board", "Intelligence": "brain", "Cards": "cards", "Word": "word",
            "Arcade": "arcade", "Adventure": "adventure", "Dice": "dice", "Party": "party"}
FEATURED = ["ink_ninja", "wilson", "hesperia", "hover_duel", "bridge_master"]
STARTER = ["solitaire", "sudoku", "chess", "g2048", "wordle", "connect4"]


def git_dates() -> tuple[dict, dict]:
    """First date each game id appears, last date each games-entry version line changed."""
    log = subprocess.run(["git", "log", "--reverse", "--format=@@@ %cs", "-p", "--", "manifest.json"],
                         cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
    first, updated = {}, {}
    date = ""
    id_re = re.compile(r'"id": "([a-z0-9_]+)"')
    ver_re = re.compile(r'^\+\s+"([a-z0-9_]+)": \{"version"')
    for line in log.splitlines():
        if line.startswith("@@@ "):
            date = line[4:].strip()
            continue
        if not line.startswith("+") or line.startswith("+++"):
            continue
        for gid in id_re.findall(line):
            first.setdefault(gid, date)
        m = ver_re.match(line)
        if m:
            updated[m.group(1)] = date
    return first, updated


def tags_for(g: dict) -> list:
    modes = [m.strip() for m in str(g.get("modes", "")).split(",") if m.strip()]
    tags = []
    if any(m in modes for m in ("local", "online", "party")):
        tags.append("multiplayer")
    if "online" in modes:
        tags.append("online")
    if not modes or any(m != "online" for m in modes):
        tags.append("offline")   # something here plays with no connection
    if g.get("quick"):
        tags.append("quick")
    if g.get("original"):
        tags.append("original")
    return tags


def main() -> None:
    m = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    first, updated = git_dates()
    today = "2026-11-20"
    review_board, backfilled, no_history = [], [], []
    for cat in m["categories"]:
        new_id = FROM_OLD.get(cat.get("name", ""), "arcade")
        for g in cat["games"]:
            gid = g.get("id", "")
            if not gid:
                continue
            g.setdefault("category", new_id)
            if g["category"] == "board" and cat.get("name") == "Puzzle & Board":
                review_board.append(gid)
            g.setdefault("tags", tags_for(g))
            if "added" not in g:
                g["added"] = first.get(gid, today)
                (backfilled if gid in first else no_history).append((gid, g["added"]))
    for gid, entry in m["games"].items():
        entry.setdefault("updated", updated.get(gid, first.get(gid, today)))
    live = {g["id"] for c in m["categories"] if not c.get("archived") for g in c["games"] if g.get("id") and not g.get("archived")}
    # Top level, before "categories" (save_manifest writes the other keys first).
    new = {}
    for k, v in m.items():
        if k == "categories":
            new.setdefault("featured", [x for x in FEATURED if x in live])
            new.setdefault("starter", [x for x in STARTER if x in live])
        new[k] = v
    for k in ("featured", "starter"):
        if k in m:
            new[k] = m[k]
    hub.save_manifest(new)
    print("Puzzle & Board -> board (%d) -- pick the ~10 that are puzzles:" % len(review_board))
    print("  " + ", ".join(review_board))
    print("added from git history (%d):" % len(backfilled))
    for gid, d in sorted(backfilled, key=lambda x: (x[1], x[0])):
        print("  %s %s" % (d, gid))
    if no_history:
        print("added = today, not in git history yet (%d): %s" % (len(no_history), ", ".join(g for g, _ in no_history)))
    print("featured:", new["featured"])
    print("starter:", new["starter"])


if __name__ == "__main__":
    main()
