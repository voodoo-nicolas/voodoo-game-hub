"""Builds games/chess/puzzles.json from the Lichess puzzle database (CC0).

    python tools/chess_puzzles.py path/to/lichess_db_puzzle.csv.zst

Source: https://database.lichess.org/#puzzles (CC0 1.0). Columns:
PuzzleId,FEN,Moves,Rating,RatingDeviation,Popularity,NbPlays,Themes,GameUrl,OpeningTags.
FEN is the position BEFORE the opponent's move; Moves = that move, then the
solution, alternating (UCI).

Keeps well-tested, popular puzzles (popularity >= 85, >= 1000 plays, rating
deviation <= 80), spread evenly over rating bands 600-2400 (100 wide) and, in
each band, round-robin over the game's themes so every theme shows up.
Deterministic (ordered by a hash of the id). Output, compact:
    {"source": ..., "licence": "CC0-1.0", "puzzles": [[id, fen, "moves", rating, "themes"], ...]}
"""
import csv
import hashlib
import io
import json
import sys
from pathlib import Path

import zstandard

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "games/chess/puzzles.json"
PER_BAND = 170
BANDS = list(range(600, 2400, 100))
# The game's theme list (Lichess theme names), in the order the picker fills.
THEMES = ["mateIn1", "mateIn2", "mateIn3", "mateIn4", "mateIn5", "fork", "pin", "skewer",
          "discoveredAttack", "doubleCheck", "deflection", "attraction", "clearance", "interference",
          "zugzwang", "defensiveMove", "endgame", "opening", "hangingPiece", "trappedPiece",
          "sacrifice", "promotion", "backRankMate", "smotheredMate", "quietMove", "intermezzo"]


def main(src: str) -> None:
    pools = {b: {t: [] for t in THEMES} for b in BANDS}
    seen = 0
    with open(src, "rb") as fh:
        reader = io.TextIOWrapper(zstandard.ZstdDecompressor().stream_reader(fh), encoding="utf-8")
        for row in csv.DictReader(reader):
            seen += 1
            try:
                rating = int(row["Rating"])
                if int(row["Popularity"]) < 85 or int(row["NbPlays"]) < 1000 or int(row["RatingDeviation"]) > 80:
                    continue
            except (ValueError, KeyError):
                continue
            band = (rating // 100) * 100
            if band not in pools:
                continue
            tags = row["Themes"].split()
            mine = [t for t in tags if t in THEMES]
            if not mine:
                continue
            moves = row["Moves"].split()
            if len(moves) < 2 or len(moves) > 12:
                continue
            key = hashlib.md5(row["PuzzleId"].encode()).hexdigest()
            entry = (key, [row["PuzzleId"], row["FEN"], " ".join(moves), rating, " ".join(mine)])
            # Pooled under its rarest theme in our list order (mates first).
            pool = pools[band][mine[0]]
            pool.append(entry)
            if len(pool) > PER_BAND * 3:  # keep the smallest hashes only
                pool.sort()
                del pool[PER_BAND * 2:]
    out = []
    used = set()
    for b in BANDS:
        for t in THEMES:
            pools[b][t].sort()
        picked = 0
        i = 0
        while picked < PER_BAND:
            took = False
            for t in THEMES:
                p = pools[b][t]
                if i < len(p) and p[i][1][0] not in used:
                    out.append(p[i][1])
                    used.add(p[i][1][0])
                    picked += 1
                    took = True
                    if picked >= PER_BAND:
                        break
            if not took:
                break
            i += 1
    out.sort(key=lambda e: e[3])
    data = {"source": "Lichess puzzle database, https://database.lichess.org/#puzzles",
            "licence": "CC0-1.0", "puzzles": out}
    OUT.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    themes = {}
    for e in out:
        for t in e[4].split():
            themes[t] = themes.get(t, 0) + 1
    print(f"read {seen} rows, kept {len(out)} puzzles, {OUT.stat().st_size // 1024} KB -> {OUT}")
    print("themes:", json.dumps(themes))


if __name__ == "__main__":
    main(sys.argv[1])
