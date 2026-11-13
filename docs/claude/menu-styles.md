# Menu styles (docs/MENU_STYLES.md, built 2026-11-13)

`tools/templates/menu_styles.gd`: ten Landing layouts from MENU_STYLES.md (S1-S4, S6-S11), self-contained (no fx_lib / landing_styles
dependency). `hub.py sync` copies it into each game that names it (like home_kit.gd), so it is a **pack update only**.

Game cfg: `const MenuStyles = preload("res://scripts/games/<id>/menu_styles.gd")`, then in `HomeKit.new({...})`:
`"landing": "ghost|ring|rail|monument|slabs|cinema|split|marquee|bento|stickers"`, `"landing_style": MenuStyles`,
`"title_font": "res://games/<id>/title.ttf"`, `"title_colors": [...]`, `"landing_colors": [top, bottom]`, optional
`"menu_font": true`, `"menu_color"`, `"landing_stars"`. The game's cfg `"logo"` drawing is the hero art (scaled up).

- Title: one colour per letter, thick outline + shadow, gentle bob; biggest size that fits (1 or 2 lines). A translated
  title with a letter the font lacks falls back to the theme font.
- Same actions/order as the stack (Resume, Quick Play, ≤3 solo modes as rows else "Single player", Multiplayer, play/more,
  ❓🏆🏅📊⚙, ← Hub). Rows ≥ 48 high. Motion off when `user://fx.json` reduce (web: always off).
- Fonts: Google Fonts (OFL / Apache), one copy per game in `games/<id>/title.ttf`, credited in media/CREDITS.json,
  licences in media/licenses/fonts/.

| Game | Style | Font |
|---|---|---|
| bubble_pop | slabs (S6) | Luckiest Guy |
| quick_math | slabs (S6) | Bangers |
| blackjack | rail (S3) | Bungee |
| spirit_board | ghost (S1) | Creepster |
| mahjong | ring (S2) | Lobster |
| moon_lander | monument (S4) | Black Ops One |
| hangman | monument (S4) | Cinzel Decorative Black |
| rock_blaster | cinema (S7) | Press Start 2P |
| snake | cinema (S7) | Audiowide |
| g2048 | ring (S2) | Rubik Mono One |
| checkers | rail (S3) | Russo One |
| crossword | rail (S3) | Permanent Marker |
| word_search | slabs (S6) | Chewy |
| trivia | slabs (S6) | Titan One |
| dominoes | monument (S4) | Bowlby One SC |
| liars_dice | ghost (S1) | Rye |
| reversi | split (S8) | Racing Sans One |
| hearts | split (S8) | Shrikhand |
| yacht | marquee (S9) | Monoton |
| simon | marquee (S9) | Bungee Shade |
| minesweeper | bento (S10) | Lilita One |
| word_ladder | bento (S10) | Concert One |
| tictactoe | stickers (S11) | Sniglet ExtraBold |
| emoji_guess | stickers (S11) | Rampart One |
| connect4 | marquee (S9) | LuckiestGuy |
| dots_boxes | stickers (S11) | PermanentMarker |
| mancala | ghost (S1) | Shrikhand |
| backgammon | rail (S3) | CinzelDecorative |
| morris | ring (S2) | Rye |
| peg_solitaire | bento (S10) | Chewy |
| lights_out | cinema (S7) | Monoton |
| box_pusher | slabs (S6) | BowlbyOneSC |
| fifteen_puzzle | split (S8) | RubikMonoOne |
| kakuro | monument (S4) | Bungee |
| nonogram | bento (S10) | PressStart2P |
| code_breaker | cinema (S7) | Audiowide |
| hanoi | monument (S4) | TitanOne |
| calcudoku | rail (S3) | RussoOne |
| pipe_flow | marquee (S9) | RacingSansOne |
| five_in_row | split (S8) | BlackOpsOne |
| flood_it | stickers (S11) | Sniglet |
| same_game | slabs (S6) | Bangers |
| binary_grid | ghost (S1) | BungeeShade |
| hex | ring (S2) | LilitaOne |

Gotcha: after wiring a game run `python tools/hub.py i18n` (the kit strings "Single player", "Menu"... must reach the
game's own `_i18n.gd`); batch 2 first shipped without it.
Sudoku is not on the kit Landing (own screen): no menu style until it is moved to the kit.

Checked by screenshot (tools/shot.gd) at 405x720 and 960x540, Spanish, text size 1.0. NOT checked: text size 1.4, a
real phone. First 8 published 2026-11-13.
