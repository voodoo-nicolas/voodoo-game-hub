# MENU_STYLES.md — Main-menu / Landing layout library

Purpose: stop every game having the same menu. Pick **one** style per game, build the Landing (STANDARDS §3) in that layout.
Source images: `D:\Dev\Minigame Art\styles\` (`1,2,3,4,5,7,9.jpg`). Each style below names its reference image.

> Measurements are **% of screen** (x = from left edge of width, y = from top edge of height), eyeballed from low-res screenshots. Accuracy ±2–3%. Use as targets, not pixel law.

---

## 0. How to use (Claude Code: read this first)

1. User/prompt names a style: `Use MENU_STYLES S4 for <game>`. If none named, pick the style **not used by the last 2 games** in `manifest.json` and write the choice into the game's `<id>_game.gd` header comment.
2. **Layout style and color palette are independent.** Never reuse the previous game's layout *and* palette. Style = where things sit, how big, how selected looks. Palette/fonts come from the game's own art.
3. **Forbidden default** (this is what every game looks like today — do not produce it unless told): centered stack of equal-width rounded-rect buttons over a dark scrim, title centered at top.
4. **Also forbidden:** left dark rail panel holding small boxed buttons (this is the "BEFORE" half of `2.jpg`).
5. The hero art is the star. Menu uses ≤ 45% of the screen area in every style. Keep the art's focal point **out** of the menu zone.

### 0.1 Mandatory content (STANDARDS §3) → three tiers
Every style must expose all of these. Tiers decide *where* they go in each layout:

| Tier | Items | Treatment |
|---|---|---|
| **T1 main list** | Resume (if save) · Quick Play · Single player · Multiplayer | The big/primary menu list. Max 4–5 rows. |
| **T2 utility** | 🏆 Leaderboards · 🏅 Achievements · ❓ How to Play · ⚙ Options | Icon cluster, small row, or secondary list (style says which). |
| **T3 exit** | ← Hub (Landing only, rule N1) · trial/purchase badge | Small, corner, low emphasis. |

Keep **same item order and same icons across all styles** (T1 → T2 → T3). Only layout changes. Reason: players learn the hub once; a new layout must not hide *what* a button does (Nielsen "consistency & standards" — the real counter-argument to this whole exercise).

### 0.2 Phone rules (references are mostly desktop/landscape)
- Visual text may be small, but **hit area ≥ 48dp** per row (extend an invisible Control). Row pitch in the specs below is *visual*; if it gives < 48dp, enlarge hit area and keep the look.
- Respect safe area (notch, gesture bar). Text scale 1.0–1.4 must not break the list (rows reflow, never overlap).
- Landscape-first styles (S1,S2,S3,S4,S6,S7): in portrait, keep the **same alignment/anchor idea**, stack title above list, push art to lower 50%. Portrait-native: S5.
- Use anchors/ratios (`anchor_left = 0.22`) — never absolute pixels.

---

## S1 — Corner Ghost *(ref `1.jpg`, Duelyst)*
Mood: epic, quiet, painterly. Art is 100% of the screen; UI whispers.

```
+--------------------------------------------------------+
|  D U E L Y S T                        [⬡][⬡][⬡][⬡]     |
|                                        T2 hex icons    |
|    ◇ PLAY                                              |
|    ◇ SANDBOX          (hero art, no panel,             |
|    ◇ COLLECTION        no box behind menu)             |
|                                                        |
|  ▲ tiny figure in landscape                            |
+--------------------------------------------------------+
```
- **Title:** top-left. x 10–26% (≈16% W — *small*), y ≈14%. Thin serif caps, **wide tracking (+0.2em)**, light weight. Not a logo-slab.
- **Menu (T1):** left-aligned text, label x ≈22%, icon at x ≈17.5%. Rows y ≈ 28 / 36 / 44%. Pitch ≈ 8% H. Text height ≈ 3.6% H, caps, white 90%. **No boxes, no fills.** 3 rows ideal, 4 max.
- **Utility (T2):** top-right cluster of hexagonal icon buttons, x 78–96%, y ≈5%, each ≈5% W, tiny label under each. (Put 🏆🏅❓⚙ here.)
- **Decor:** faint thin circle/arc (radius ≈25% H) around a small emblem at x ≈41%, y ≈33% — optional status chip ("0 booster packs"-style) sits there.
- **Selected:** brighter text + small icon glow. No outline.
- **Art:** menu block occupies x 17–40%, y 26–47%. Keep the glow/focal point right of x 45%. Small figure/silhouette bottom-left (≈17%, 66%) gives scale.
- **T3 ← Hub:** tiny, bottom-left corner or inside top-right cluster.
- Best for: card/strategy, atmospheric, art-heavy games (Tarot, Duel-type). Weak for: 6+ modes.

## S2 — Center Ring *(ref `2.jpg` right half "AFTER", Skorecery)*
Mood: mystic, ritual, elegant. Centered symmetric menu inside a faint sigil.

```
+----------------------------------+
|                          v1.2.4  |
|          S K O R E C E R Y       |  y≈10%
|                                  |
|        ╭──── faint ring ────╮    |
|        │   ── PLAY ◉ ──     │    |  selected: gold, 1.3x
|        │    SETTINGS        │    |
|        │     STATS          │    |
|        │      QUIT          │    |
|        ╰────────────────────╯    |
|   (night sky / tree silhouettes) |
+----------------------------------+
```
- **Title:** centered x 50%, y ≈10%, width ≈28% W, display-serif with one swapped/decorated glyph (an "O" replaced by a small orb/emblem).
- **Menu (T1):** **centered**, rows y ≈ 36 / 47 / 56.5 / 66%. Pitch ≈ 9.5–10% H. Caps, tracking +0.08em.
- **Selected row:** **gold**, **≈1.3× size**, a small gamepad/confirm glyph to its right (+3% W), hairline gold rule above and below. Unselected: white, ≈0.8× of selected, 85% opacity.
- **Ring:** one big thin translucent circle (≈65% H diameter, 20–25% opacity) centered on the menu (x 50%, y ≈50%), slightly cropped by menu text — sits *behind* text, never a clickable frame.
- **Version:** top-right, tiny (≈1.5% H), 50% opacity.
- **T2:** small icon row under the list (y ≈ 76–80%) or as extra lines of the list (Options/Stats). **T3:** bottom corner.
- **Art:** gradient sky + horizon silhouette on bottom 20% (dark, so ring/list stay readable).
- Best for: puzzle/zen/magic, short menus (4–5 items). Weak for: busy hero art.

## S3 — Rail List *(ref `3.jpg`, "MAIN MENU" 主目録)*
Mood: gritty, noir, arcade-action. Dense flush-left list with one glowing selection box.

```
+----------------------------------------------------+
| 主目録 MAIN MENU                                    |  y≈10%
|  ┌────────────────────┐                            |
|  │ NEW GAME           │  ← selected: glow outline  |
|  └────────────────────┘                            |
|   CONTINUE GAME            (blurred warm bokeh     |
|   LOAD                      + black ornament art   |
|   DOWNLOADABLE CONTENT      at left, vignette)     |
|   OPTIONS                                          |
|   CREDITS                                          |
|   EXIT GAME                                        |
+----------------------------------------------------+
```
- **Title:** top-left, x 8–43%, y ≈10%, cap height ≈7% H. **Two-tone / bilingual:** native-language script in gold + Latin "MAIN MENU" bold orange-gold with a soft glow. (For our games: game name in gold + section word in accent colour.)
- **Menu (T1+T2 together — this style holds 7 rows):** flush-left at x 8%, rows y ≈ 28→88%, **pitch ≈10% H**, 7 rows. Text ≈3.6% H, caps, small, 0.05em tracking, white.
- **Selected:** rounded-rect (≈4px radius), **1px accent outline + outer glow**, translucent dark fill, box x 6.5–41% (≈34% W), text stays at x 8%. Others: no box.
- **T3:** last row ("EXIT GAME" → "← HUB"). Badges (trial) go right of the box end.
- **Art:** warm duotone (red/orange) **blurred** city/bokeh + one **black ornamental illustration** on the left (dragon/lattice) with strong left vignette for legibility. Brightest area at right.
- Best for: action, racing, fighting, anything with many entries. Handles the full T1+T2 list as plain rows.

## S4 — Monument *(ref `4.jpg`, God of War)*
Mood: heavy, cinematic, confident. Giant logo, almost no menu.

```
+--------------------------------------------------------+
| ╔══ G O D  O F  W A R ══╗               ▓▓▓▓▓▓          |  logo y 4–23%
|        New Game                         ▓ HERO ▓          |  y≈30%
|        Options                          ▓ low  ▓          |  y≈36%
|                                         ▓ angle▓          |
|  (tree / landmark left)                 ▓▓▓▓▓▓▓▓          |
+--------------------------------------------------------+
```
- **Title/logo:** top-left, x 5–49% (**≈44% W — huge**), y 4–23%. Textured/stone/metal wordmark, custom lettering, one coloured accent word ("OF").
- **Menu:** **centered under the logo block** (center x ≈27%, *not* left-aligned to logo edge), rows y ≈ 30 / 36%, pitch ≈6% H. **Tiny** text ≈3% H, **Title Case, not caps**, no icons, no boxes. Selected = white; others ≈60% grey. Only 2–3 rows visible.
- **T1 → rows** (Resume/Play, Multiplayer). **T2 → ONE row "Extras"** or a single small icon strip at bottom-left (y ≈92%). **T3** tiny bottom-left.
- **Hero:** character/object at x 55–95%, y 8–100%, **low camera angle, cropped by bottom edge**, ≈80% H. Left 25%: a textured landmark (tree/wall) with one accent-colour mark.
- Negative space is the feature. Don't fill it.
- Best for: single-hero narrative games (Turned, Runner). Weak for: games with many modes.

## S5 — Ornate Scroll *(ref `5.jpg`, Hogwarts III — portrait)*
Mood: fantasy, magical, premium. **Native portrait.** Icon-in-diamond list with hairline rules.

```
+---------------------------+
|        ✦ flame ✦          |
|        H O G W A R T S    |  y≈12.5%, w≈60%
|    ─── ✦ III ✦ ───        |
|                           |
|  ◇─┐                  ✦✦✦ |  hero (glowing
|  │ ◈ START GAME ─────  ✦✦ |  creature) at
|  │ ◈ CONTINUE ───────   ✦ |  right 50%, y 20–80%
|  │ ◈ LOAD CHAPTER ═══ ✺   |  ← selected: lit frame
|  │ ◈ OPTIONS ────────     |
|  ◇─┘ ◈ QUIT ──────────     |
|       ✧─✦─✧ bottom ornament|  y≈87%
+---------------------------+
```
- **Title:** centered x 50%, y ≈12.5%, **≈60% W**, gold metallic serif, ornament lines either side + subtitle/numeral glyph centered below. A small emblem/flame above the first letter.
- **Menu (T1+T2):** **left-aligned**, diamond-framed icon at x ≈14%, label at x ≈22%. Rows y ≈ 44 / 53 / 62.5 / 71 / 79%, **pitch ≈8.7% H** (5 rows). Label caps ≈2.1% H, tracking +0.12em, warm-white.
- **Hairline under every label:** thin gold line from label start, ≈30% W long.
- **Left rail:** vertical hairline at x ≈7%, y 38–82%, diamond end-caps — visually ties the rows.
- **Selected:** icon frame fills with glow colour (blue/cyan in ref), a brighter flare streak on its underline. No big box.
- **Bottom ornament:** small divider (gem/stars) y ≈87%, x 12–55% — the "end" of the menu.
- **Art:** dark, low-key; glowing hero object **right half**, figure/ground bottom-right. Menu never overlaps the glow.
- Best for: fantasy/mystic/collection games on phone (Tarot, Spirit Board). Natural for **portrait**. 5 rows ideal.

## S6 — Stone Slabs *(ref `7.jpg`, SpaceShip / Kizi)*
Mood: casual, chunky, kid-friendly, mobile-arcade.

```
+----------------------------------------+
| 🔊 🎵                         ◢ sprite  |
|      S P A C E S H I P   (tone-on-tone)|  y 8–26%, w≈61%
|                                        |
|            ┌──────────┐                |
|            │▶  Play    │   w≈31%       |  y≈41%
|            └──────────┘                |
|           ┌────────────┐               |
|           │🔧 Options  │   w≈29%       |  y≈60%
|           └────────────┘                |
|             ┌────────┐                 |
|  ┌──────┐   │? Tips  │  w≈23%  [mascot]|  y≈76%
|  │Credits│  └────────┘          [brand]|
+----------------------------------------+
```
- **Title:** top-center, x 19–80% (**≈61% W**), y 8–26%. Chunky angular display face, **tone-on-tone**: a slightly darker shade of the background (≈15% darker), **no outline, no gloss**. Deliberately low contrast — it's a poster, buttons carry readability.
- **Buttons (T1):** 3 centered **stone-slab** buttons, x center 50%, **widths taper top→bottom** (≈31 / 29 / 23% W), height ≈14–15% H, y centers ≈ 41 / 60 / 76%, gap ≈5% H. Each: **coloured icon at left inside the slab**, chunky rounded cartoon label (≈7% H), bevel + darker outline + subtle texture.
- **Corner pieces (T2/T3):** sound & music toggles top-left (x 4–14%, y ≈5%); small "Credits"-size slab bottom-left (x 4–21%, y 86–97%) → use for ← Hub / Options; brand/mascot bottom-right (x 70–97%, y 72–97%); one floating game sprite top-right (≈88%, 25%).
- **Art:** flat vector, 2–3 layered parallax shapes (mountains), sparse stars. No photo, no painting.
- Best for: hyper-casual, kids, arcade, tap games (Bop the Mole, Road Hopper, Bird Hop). Weak for: dark/serious tone.

## S7 — Diegetic Cinema *(ref `9.jpg`, Half-Life 2)*
Mood: immersive, grounded, "the world IS the menu". Live scene behind, tiny text menu in the dark corner.

```
+----------------------------------------+
|▓▓▓▓▓▓▓▓▓▓▓▓ letterbox bar ▓▓▓▓▓▓▓▓▓▓▓▓▓▓|  top 12.5%
|                                        |
|        H Λ L F - L I F E ²             |  x 22–41%, y≈46% (of picture)
|  NEW GAME                              |  x≈6%
|  LOAD GAME      (live 3D / parallax    |
|  ACHIEVEMENTS    scene, game's world)  |
|  OPTIONS                               |
|  QUIT                                  |
|▓▓▓▓▓▓▓▓▓▓▓▓ letterbox bar ▓▓▓▓▓▓▓▓▓▓▓▓▓|  bottom 12.5%
+----------------------------------------+
```
- **Frame:** black bars top & bottom, each ≈12.5% of screen height (picture = 16:9 inside). Positions below are % of the *picture* area.
- **Title:** mid-left, x 22–41%, y ≈46%. **Wide, light, geometric** logotype, sits **just above the menu and offset right** of the menu's left edge (not aligned to it).
- **Menu (T1+T2):** x ≈6%, rows y ≈ 52→68%, **tight pitch ≈4% H**, text ≈2.5% H, **tiny uppercase**, white, no icons/boxes/lines. 5 rows. Selection = brighter/colour shift only.
- **Scene:** the game world idling (animated: wind, camera drift, parallax, particles). Menu sits on the **darkest part** of the frame (bottom-left buildings).
- **Touch note:** text is tiny — use ≥48dp invisible hit areas; consider +20% size on phones. Don't shrink below 12sp.
- Best for: atmospheric/world games (Runner space ports, Turned streets), one-hero-scene games. Weak for: games without a nice idle scene.

## S8 — Diagonal Split *(own design, 2026-11-13; code `"split"`)*
Mood: sporty, fast, bold. A slanted colour band across the top holds a huge title; the menu is a staircase of
slanted (skewed) tab buttons on the right, each in a palette colour, the chosen one with a white border.
- Band: top 28% (portrait) / 40% (landscape) of the screen, its lower edge sloping ±7% H, a light rule along it.
- Rows right-aligned, each next row shifted left a little (follows the slant); utilities = small tiles bottom-left.
- Best for: sports/racing/versus games (Reversi, Hearts). Weak for: soft/zen games.

## S9 — Arcade Marquee *(own design; `"marquee"`)*
Mood: fairground, neon, arcade cabinet. The title sits inside a sign framed by chasing light bulbs.
- Sign: centred, ≈17% H (portrait) / 24% (landscape). Buttons: neon pill outlines (filled when chosen), 1 or 2
  columns. Utilities: round glowing tokens in a centred bottom row. Art under the buttons if room.
- Best for: dice, casino-free arcade, party games (Generala, Memory Lights).

## S10 — Bento Grid *(own design; `"bento"`)*
Mood: modern, tidy, app-like. Coloured rounded tiles of different sizes: the first action is a big full-width
tile, the rest two per row, the utilities a row of small square tiles at the bottom; the game art fills any gap.
- Landscape: title + art left, the grid in the right half.
- Best for: puzzle and word games with 2-5 modes (Mines, Word Ladder).

## S11 — Sticker Board *(own design; `"stickers"`)*
Mood: playful, crafty, kid-friendly. Thick white-outlined stickers stuck on a dotted board at slight angles
(±4°), the title tilted too; utilities = round stickers.
- Best for: casual, party, kids (Tic-Tac-Toe, Emoji Guess). Weak for: dark/serious tone.

---

## 1. Quick comparison

| Style | Title | Menu align | Menu look | Rows | Art ownership | Mood |
|---|---|---|---|---|---|---|
| S1 Corner Ghost | tiny, top-left, tracked | left, y 28–44% | text + icon, no box | 3–4 | 100% | epic/quiet |
| S2 Center Ring | center top, 28% W | **center**, y 36–66% | text, gold 1.3× selected | 4–5 | ~85% + faint ring | mystic/zen |
| S3 Rail List | top-left, 2-tone | flush-left, y 28–88% | text + glow-outline selected | up to 7 | 70% | gritty/action |
| S4 Monument | **huge** top-left 44% W | centered under logo | tiny Title Case, no icons | 2–3 | 85% | cinematic |
| S5 Ornate Scroll | center, 60% W, ornaments | left, icons in diamonds | hairline under each | 5 | 70% | fantasy/premium |
| S6 Stone Slabs | huge tone-on-tone | **center** buttons, tapered | chunky slabs + icons | 3 | 60% flat vector | casual/kids |
| S7 Diegetic Cinema | mid-left, wide light | left x 6%, bottom-left | tiny caps, no UI chrome | 5 | 95% live scene | immersive |

**Orientation:** portrait-native = S5. Others landscape-first, adapt per §0.2.
**Distinctive axes (rotate at least 2 between consecutive games):** title size (tiny ↔ huge), menu alignment (left ↔ center ↔ under-logo), selection indicator (color/size ↔ outline glow ↔ icon frame ↔ none), chrome (none ↔ slabs ↔ ornaments), frame (full-bleed ↔ letterbox).

## 2. Suggested starting assignments *(opinion — change freely)*

| Game | Style | Why |
|---|---|---|
| Tarot | S5 Ornate Scroll | Mystic/premium, portrait-friendly |
| Turned | S4 Monument | Single dark hero image, minimal menu |
| The Runner | S7 Diegetic Cinema (or S3 for many modes) | Idle space-port scene as backdrop |
| Evolution | S2 Center Ring | Organic/radial, fits a cell/ring motif |
| Bop the Mole / Road Hopper / Bird Hop | S6 Stone Slabs | Casual, chunky |
| Spirit Board / Creation | S1 Corner Ghost | Art is the experience |
| Poker / Casino-type | S3 Rail List | Dense list, warm bokeh felt |

## 3. Prompt snippet (paste to Claude Code)

> Build the Landing for `<game>` using **MENU_STYLES.md → S<N>**. Follow the spec's positions as anchor ratios, include every T1/T2/T3 item from §0.1 in the order given, keep ≥48dp hit areas, safe area, text scale 1.4. Use the game's own palette/fonts/hero art (do **not** reuse another game's palette). Do not fall back to the centered rounded-button stack.

## 4. Open items (for the user to decide)
- Confirm the missing numbers in `styles/` (6, 8) were not meant to exist; only 7 references analysed.
- If a style isn't working on phone, add a portrait-specific sketch to its section — don't edit the others.
