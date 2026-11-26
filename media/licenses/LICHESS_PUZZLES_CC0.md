# Lichess puzzle database (CC0)

Used for: `games/chess/puzzles.json` (Chess 🧩 Puzzles, 3,060 puzzles), built by
`tools/chess_puzzles.py` from `lichess_db_puzzle.csv.zst` (downloaded 2026-11-25,
file dated 2026-11-01).

Source: https://database.lichess.org/#puzzles

Checked 2026-11-25 on https://database.lichess.org/ : the page header says the
database exports are released under the Creative Commons CC0 license, for any
use including commercial, to download, modify and redistribute without asking.
The only exception on that page is the broadcast games (CC BY-SA 4.0), which
are NOT used here. The puzzle file falls under the CC0 header.
CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/ . Credit is not
required; the game still names Lichess as the source.

Kept from each puzzle: id, FEN, moves (UCI), rating, themes. Nothing else
(no player names, no game links).
