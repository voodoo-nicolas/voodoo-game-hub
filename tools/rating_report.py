#!/usr/bin/env python3
"""Age ratings + content descriptors for every game (compliance pack, Task 4).

Each game in manifest.json carries
    "content": {"min_age": 3|7|12|16|18, "descriptors": [...], "notes": ""}
A game WITHOUT a content block is treated as min_age 18 and hidden by the app (fail
closed), so every live game needs one. This tool prints each game's rating, flags the
ones that need the owner's decision, and computes
    hub_rating = max(min_age of every downloadable game)
which is what the Google Play (IARC) questionnaire must be answered for.

  python tools/rating_report.py                 report (also run by `hub.py check`)
  python tools/rating_report.py --apply         add the default content block to games that
                                                lack one (never changes an existing block)
Defaults (RULES below) follow the compliance brief: puzzle/word/intelligence/most arcade
3+, online play adds online_interaction, shooters get cartoon violence (7+), casino-style
card games simulated_gambling (12+). The owner confirms them; they are only starting values.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "manifest.json"
AGES = (3, 7, 12, 16, 18)
DESCRIPTORS = ("violence_cartoon", "violence_realistic", "blood", "horror", "simulated_gambling",
               "alcohol_reference", "drug_reference", "crude_humor", "strong_language", "sexual_content",
               "online_interaction", "user_generated_content")
# What each descriptor means for the Landing badge (English; the app translates).
DESCRIPTOR_LABELS = {
    "violence_cartoon": "Cartoon violence", "violence_realistic": "Realistic violence", "blood": "Blood",
    "horror": "Horror themes", "simulated_gambling": "Simulated gambling", "alcohol_reference": "Alcohol references",
    "drug_reference": "Drug references", "crude_humor": "Crude humour", "strong_language": "Strong language",
    "sexual_content": "Sexual content", "online_interaction": "Online interaction",
    "user_generated_content": "User-generated content",
}

# id -> (min_age, extra descriptors, notes). Everything else: 3, [] (+ online_interaction if it has online play).
RULES = {
    "geometry_wars": (7, ["violence_cartoon"], "Abstract neon shooter with boss fights"),
    "sky_raider": (7, ["violence_cartoon"], "Arcade aircraft shooter"),
    "alien_attack": (7, ["violence_cartoon"], "Shoot aliens, no blood"),
    "rock_blaster": (7, ["violence_cartoon"], "Shoot asteroids"),
    "city_defense": (7, ["violence_cartoon"], "Defend cities from missiles"),
    "cannon_duel": (7, ["violence_cartoon"], "Artillery duel, no people shown"),
    "crypt_crawler": (7, ["violence_cartoon"], "Dungeon crawler, fantasy combat"),
    "blackjack": (12, ["simulated_gambling"], "Casino card game with chips, no real money"),
    "video_poker": (12, ["simulated_gambling"], "Casino card game with chips, no real money"),
    "spirit_board": (12, ["horror"], "Ouija-style spirit board (occult theme): owner to confirm the rating"),
    "truth_or_dare": (7, [], "Party prompts and dares: mild; owner to confirm"),
}


def default_content(gid: str, game: dict) -> dict:
    age, extra, notes = RULES.get(gid, (3, [], ""))
    desc = list(extra)
    if "online" in str(game.get("modes", "")).split(","):
        desc.append("online_interaction")
    return {"min_age": age, "descriptors": desc, "notes": notes}


def live_games(m: dict) -> list[dict]:
    out = []
    for c in m.get("categories", []):
        for g in c.get("games", []):
            if "id" in g:
                g = dict(g)
                g["_category"] = c.get("name", "")
                g["_archived"] = bool(c.get("archived") or g.get("archived"))
                out.append(g)
    return out


def problems(m: dict) -> tuple[list[str], list[str]]:
    """(errors, flags): errors fail `hub.py check`; flags are for the owner."""
    errors, flags = [], []
    for g in live_games(m):
        gid = g["id"]
        if g["_archived"]:
            errors.append(f"{gid}: archived games must not be in the served manifest (alcohol/18+ content)")
            continue
        c = g.get("content")
        if not isinstance(c, dict):
            errors.append(f'{gid}: no "content" block (the app treats it as 18+ and hides it)')
            continue
        if c.get("min_age") not in AGES:
            errors.append(f"{gid}: content.min_age must be one of {AGES}")
        bad = [d for d in c.get("descriptors", []) if d not in DESCRIPTORS]
        if not isinstance(c.get("descriptors"), list) or bad:
            errors.append(f"{gid}: bad content.descriptors {bad or ''}")
        if "online" in str(g.get("modes", "")).split(",") and "online_interaction" not in c.get("descriptors", []):
            errors.append(f"{gid}: has online play but no online_interaction descriptor")
        if c.get("min_age", 0) >= 12 and c.get("notes", "") != "":
            flags.append(f"{gid}: {c['min_age']}+ {c.get('descriptors')} -- {c['notes']}")
    return errors, flags


def hub_rating(m: dict) -> int:
    ages = [g["content"]["min_age"] for g in live_games(m)
            if not g["_archived"] and isinstance(g.get("content"), dict) and g["content"].get("min_age") in AGES]
    return max(ages) if ages else 18


def apply_defaults() -> int:
    """Adds the default content block to every live game without one (text edit: the
    manifest keeps its one-game-per-line layout)."""
    raw = MANIFEST.read_text(encoding="utf-8")
    m = json.loads(raw)
    games = {g["id"]: g for g in live_games(m)}
    out, added = [], 0
    for line in raw.split("\n"):
        mt = re.match(r'^(\s*\{"id": "([a-z0-9_]+)",)(.*?)(\}\]?,?\r?)$', line)
        if mt and mt.group(2) in games and '"content"' not in line and not games[mt.group(2)]["_archived"]:
            gid = mt.group(2)
            block = json.dumps(default_content(gid, games[gid]), ensure_ascii=False)
            line = f'{mt.group(1)}{mt.group(3)}, "content": {block}{mt.group(4)}'
            added += 1
        out.append(line)
    MANIFEST.write_text("\n".join(out), encoding="utf-8", newline="")
    json.loads(MANIFEST.read_text(encoding="utf-8"))  # still valid
    return added


def report(m: dict) -> int:
    errors, flags = problems(m)
    print(f"{'game':20} {'age':>4}  descriptors")
    for g in live_games(m):
        if g["_archived"]:
            continue
        c = g.get("content") or {}
        print(f"{g['id']:20} {str(c.get('min_age', '?')) + '+':>4}  {', '.join(c.get('descriptors', []))}")
    hub = hub_rating(m)
    print(f"\nhub_rating = {hub}+ (max min_age of every downloadable game): answer the IARC questionnaire for this.")
    if flags:
        print("\nOwner to confirm:")
        for f in flags:
            print("  -", f)
    for e in errors:
        print("ERROR:", e)
    return 1 if errors else 0


def main() -> int:
    if "--apply" in sys.argv:
        print(f"added content to {apply_defaults()} games")
    return report(json.loads(MANIFEST.read_text(encoding="utf-8")))


if __name__ == "__main__":
    sys.exit(main())
