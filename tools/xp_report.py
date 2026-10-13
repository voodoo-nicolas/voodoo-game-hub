#!/usr/bin/env python3
"""Which live games can earn Viral XP, and how (docs/ADDING_A_GAME.md).
  stats        counters in <id>_help.gd STATS -> generic badge tiers (Achievements.defs_for)
  own          the game's ACHIEVEMENTS (optional "xp")
  challenges   CHALLENGES declared (report_challenge / on_event)
Games with none of the three can't earn anything yet: listed at the end.
  python tools/xp_report.py
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main() -> int:
    m = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    live = [g["id"] for c in m["categories"] if not c.get("archived") for g in c["games"] if "id" in g]
    rows, none = [], []
    for gid in live:
        help_path = ROOT / "scripts" / "games" / gid / f"{gid}_help.gd"
        text = help_path.read_text(encoding="utf-8") if help_path.is_file() else ""
        stats = re.search(r"const STATS\s*:?=\s*\[(.*?)\]", text, re.S)
        n_stats = len(re.findall(r'"', stats.group(1))) // 2 if stats else 0
        own = len(re.findall(r'"id"\s*:', re.search(r"const ACHIEVEMENTS\s*:?=\s*\[(.*?)\n\]", text, re.S).group(1))) \
            if re.search(r"const ACHIEVEMENTS\s*:?=\s*\[(.*?)\n\]", text, re.S) else 0
        chal = len(re.findall(r'"id"\s*:', re.search(r"const CHALLENGES\s*:?=\s*\[(.*?)\n\]", text, re.S).group(1))) \
            if re.search(r"const CHALLENGES\s*:?=\s*\[(.*?)\n\]", text, re.S) else 0
        rows.append((gid, n_stats, own, chal))
        if n_stats == 0 and own == 0 and chal == 0:
            none.append(gid)
    print(f"{'game':22} stats own challenges")
    for gid, a, b, c in rows:
        print(f"{gid:22} {a:5} {b:3} {c:10}")
    print(f"\n{len(live)} live games; {len(live) - len(none)} can earn Viral XP; cannot yet: {', '.join(none) or 'none'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
