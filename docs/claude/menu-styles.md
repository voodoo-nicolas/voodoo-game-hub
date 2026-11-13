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
| memory_grid | bento (S10) | LilitaOne (complementary blue/orange) |
| color_clash | stickers (S11) | Bangers (triadic red/yellow/blue) |
| number_series | rail (S3) | RussoOne (analogous greens) |
| digit_recall | cinema (S7) | PressStart2P (complementary cyan/coral) |
| sketch_it | ghost (S1) | PermanentMarker (analogous magenta/purple/pink) |
| trace_it | monument (S4) | ConcertOne (complementary teal/amber) |
| trivia_battle | split (S8) | BowlbyOneSC (complementary red/blue) |
| color_sort | marquee (S9) | LuckiestGuy (4-colour test-tube palette) |
| hidato | ring (S2) | TitanOne (triadic gold/green/violet) |
| rectangles | slabs (S6) | BlackOpsOne (analogous blues) |
| solitaire | monument (S4) | CinzelDecorative (palette felt green/gold/ivory) |
| war | split (S8) | BlackOpsOne (complementary red/cyan) |
| crazy_eights | stickers (S11) | LuckiestGuy (triadic magenta/yellow/cyan) |
| go_fish | ring (S2) | Chewy (analogous blues/teal) |
| gin_rummy | rail (S3) | Lobster (complementary coral/teal) |
| spider | ghost (S1) | Creepster (complementary purple/lime) |
| freecell | cinema (S7) | RussoOne (analogous cyan/blue/indigo) |
| pyramid | monument (S4) | BowlbyOneSC (analogous sand/gold/orange) |
| speed | marquee (S9) | RacingSansOne (complementary orange/blue) |
| memory | bento (S10) | Sniglet (triadic green/orange/violet) |
| tri_peaks | slabs (S6) | TitanOne (analogous yellow/lime/green) |
| sevens | ghost (S1) | Shrikhand (complementary red/green) |
| rummy | stickers (S11) | ConcertOne (palette: four suit colours) |
| farkle | bento (S10) | LilitaOne (complementary gold/indigo) |
| shut_the_box | monument (S4) | CinzelDecorative (analogous amber/orange/cream) |
| pig | slabs (S6) | Chewy (analogous pinks) |
| bunco | marquee (S9) | LuckiestGuy (triadic orange/green/violet) |
| ship_captain_crew | rail (S3) | Rye (complementary gold/blue) |
| party_spinner | ring (S2) | Bungee (triadic red/yellow/blue) |
| charades | cinema (S7) | Shrikhand (complementary purple/yellow) |
| truth_or_dare | split (S8) | BowlbyOneSC (complementary pink/green) |
| fortune_ball | ghost (S1) | Lobster (analogous violet/blue/indigo) |
| fastest_finger | stickers (S11) | RacingSansOne (analogous yellow/orange/red) |
| who_am_i | bento (S10) | ConcertOne (analogous lime/green/teal) |
| geometry_wars | split (S8) | Audiowide (complementary cyan/red; key art kept dimmed) |
| star_runner | monument (S4) | RacingSansOne (triadic magenta/cyan/yellow; key art dimmed) |
| sky_raider | slabs (S6) | BlackOpsOne (complementary orange/blue; key art dimmed) |
| crypt_crawler | ghost (S1) | Creepster (analogous amber/orange/red torchlight) |
| turned | cinema (S7) | CinzelDecorative (palette crimson/bone/moonlight blue; key art dimmed) |
| block_drop | bento (S10) | RubikMonoOne (triadic red/yellow/blue) |
| paddle_ball | cinema (S7) | PressStart2P (complementary cyan/coral) |
| brick_breaker | marquee (S9) | Bungee (analogous orange/red/magenta) |
| bird_hop | slabs (S6) | LuckiestGuy (complementary gold/sky blue) |
| alien_attack | ghost (S1) | Audiowide (complementary lime/purple) |
| frog_crossing | stickers (S11) | Chewy (analogous green/lime/yellow) |
| gem_match | ring (S2) | TitanOne (triadic red/green/blue gems) |
| whack_a_mole | stickers (S11) | Bangers (palette mole brown/grass green/gold) |
| reaction_test | split (S8) | RacingSansOne (complementary red/green) |
| city_defense | monument (S4) | BlackOpsOne (complementary blue/orange) |
| maze_muncher | marquee (S9) | BungeeShade (palette yellow/blue/pink/cyan) |
| stack_tower | monument (S4) | BowlbyOneSC (analogous orange/amber/yellow) |
| sky_hop | ring (S2) | Sniglet (analogous sky blue/blue/aqua) |
| air_hockey | split (S8) | RussoOne (complementary red/cyan) |
| barrel_climb | rail (S3) | Rye (palette rust/gold/steel blue) |
| cannon_duel | slabs (S6) | LilitaOne (complementary red/teal) |
| mini_golf | bento (S10) | ConcertOne (analogous green/sea green/lime) |
| pool | rail (S3) | Lobster (triadic yellow/red/blue balls) |
| tilt_maze | cinema (S7) | Monoton (analogous violet/indigo/blue) |
| bug_chain | ghost (S1) | PermanentMarker (complementary yellow/violet) |

Gotcha: after wiring a game run `python tools/hub.py i18n` (the kit strings "Single player", "Menu"... must reach the
game's own `_i18n.gd`); batch 2 first shipped without it.
Intelligence batch (2026-11-13): each game's colours follow one rule (complementary, analogous, triadic or a
set palette), 2-4 colours. Creation and Evolution keep their key-art Landing (menu styles draw no "art"); IQ Test
has its own screen. Cards batch (same day): Video Poker keeps its key-art Landing. Arcade batch (same day): the other 20 arcade games; `"landing_art": true` keeps a game's own `art` picture dimmed
under the backdrop (block_drop, bird_hop, frog_crossing, whack_a_mole, barrel_climb, pool, tilt_maze). Sudoku is not on the kit Landing (own screen): no menu style until it is moved to the kit. Dice + Party batch (same day): Tarot keeps its own "list" Landing prototype (landing-styles.md).
Adventure batch (same day): "landing_art": true keeps each game's key art, dimmed, behind the style. The Runner
and Beached keep their key-art Landing (title painted in the art); Last Shift keeps the owner's key-art column layout.

Checked by screenshot (tools/shot.gd) at 405x720 and 960x540, Spanish, text size 1.0. NOT checked: text size 1.4, a
real phone. First 8 published 2026-11-13.
