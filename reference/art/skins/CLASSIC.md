# Classic skin — the default (STANDARDS §9)

Every game's default look: **the game's traditional colours**, the way the
physical game or the classic computer version looks. Classic does not follow
the app's light/dark theme (only menus do), and it is never neon: no glow,
no faint grid, plain drop shadows.

## Shared colours — `HomeKit.CLASSIC` (tools/templates/home_kit.gd)

| Token | Colour | Use |
|---|---|---|
| `felt` / `felt_dark` | `#1f6b3a` / `#17532c` | card tables (Solitaire...) |
| `wood_light` / `wood_dark` / `wood_frame` | `#f0d9b5` / `#b58863` / `#6b4423` | chess / checkers boards |
| `paper` / `ink` / `pencil` | `#f7f3e8` / `#1d2433` / `#5b6478` | pencil-and-paper games (Tic-Tac-Toe, Dots...) |
| `red` / `yellow` / `blue` | `#d62828` / `#f6c90e` / `#1e5bd8` | Four in a Row discs and board |
| `red_piece` / `white_piece` / `black_piece` | `#c1272d` / `#f4efe4` / `#232323` | counters, checkers, reversi |
| `card_face` / `card_back` | `#fbf8ef` / `#1a3d9e` | playing cards |
| `table` | `#12161f` | the dark surround around a classic board |

## Rules
- Text keeps ≥ 4.5:1 against what it sits on; colour is never the only cue
  (pieces also differ by shape or a mark).
- Use the IP checklist (docs/IP_AUDIT.md): traditional ≠ copied. No famous
  product's exact trade dress (e.g. not the falling-block game's per-piece
  palette, not the Magic 8 Ball).
- Pilots (2026-10-06): Four in a Row, Tic-Tac-Toe, Checkers, Solitaire.
- Phase 5 (2026-10-06), category by category, each pack published as it was done:
  - Puzzle & Board: Chess, Reversi, Mancala, Backgammon, Morris, Five in a Row,
    Hex, Peg Solitaire, Mines, Light Flip, Sliding 15, Tower of Hanoi, 2048,
    Color Flood, Block Collapse, Code Breaker, Sea Battle, Box Pusher, Pipe
    Flow, Mahjong, Kakuro, Nonogram, Calcudoku, Dots and Boxes. (Sudoku keeps
    its own look.)
  - Cards: the ten `<id>_cards.gd` copies share a `classic` static (ivory face,
    blue back, plain shadow; the game's `_set_skin` flips it) -- Crazy Eights,
    FreeCell, Gin Rummy, Go Fish, Hearts, Pyramid, Speed, Spider, Tri-Peaks,
    Video Poker; plus Blackjack, War, Memory. Green felt table.
  - Dice & Party: ivory dice with black pips -- Yacht, Farkle, Liar's Dice,
    Shut the Box (wood tiles), Dominoes.
  - Word: paper / cream tiles -- Five Letters (blue / orange marks, on
    purpose not the famous green / yellow), Word Search, Crossword, Word Hunt,
    Anagrams, Hangman (wooden gallows).
  - Retro-arcade Classic for neon-native games (33: 25 Arcade, 6 Intelligence,
    Party Spinner, Charades, Truth or Dare): no per-game code. `"retro": true`
    in the game's HomeKit config makes the kit add a screen filter
    (`RETRO_SHADER` in home_kit.gd): glow halos and tinted glass fall to the
    background, saturated colours snap to flat primaries. Voodoo = plain neon.
  - Left neon-only on purpose: Neon Blast, IQ Test, Trace It, Sketch It,
    Fortune Ball, Spirit Board, Gem Match / Bop the Mole (own skins), and the
    8 archived Drinking Games.
- Pattern: `var skin`, `_set_skin(name)` (bg colour + hide the faint grid +
  redraw), `_is_classic()`, and a classic branch where each thing is drawn.
