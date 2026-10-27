# Owner-provided game art (Viral) — licence record

Covers every `media/CREDITS.json` entry whose `proof` is this file.

- **Owner**: Viral (the developer of Viral Game Hub). All rights reserved.
- **Made with AI**: ChatGPT, Free plan (owner, 2026-10-07). OpenAI's Terms of
  Use give the user ownership of outputs ("we hereby assign to you all our
  right, title, and interest, if any, in and to Output") on every plan,
  free included, so commercial use is allowed (STANDARDS §10). AI output may
  not be protectable by copyright everywhere -- the art is ours to use, not
  necessarily exclusive.
- **Sources** kept unchanged in `reference/art/games/` (never shipped):
  - `neon_blast_bg_src.jpg` (1266x832): cyan / red nebula with a black hole.
    Shipped as the Landing background of Neon Blast
    (`games/geometry_wars/landing_bg.jpg`) and Sky Strike
    (`games/sky_raider/landing_bg.jpg`), re-saved as JPEG quality 84.
  - `neon_blast_map_sun_src.webp` (1547x1017) and
    `neon_blast_map_blackhole_src.webp` (1672x941): the Campaign's two star
    maps, `games/geometry_wars/map_sun.jpg` / `map_blackhole.jpg` (JPEG q84).
    Star positions measured by bright-spot detection (OpenCV).
  - `neon_blast_ship_src.png` (274x396): the horned demon skull. Not shipped
    as an image: its outline was traced (OpenCV contours) into vector data in
    `scripts/games/geometry_wars/geometry_wars_ship.gd`, drawn in code.
- Processing by Claude Code, 2026-10-06/07.

## Last Shift (2026-10-14)
- `last_shift_key_art_src.jpg` (1200x896): Nash Kovac with a coolant sprayer in
  front of the burning Ascend office building (comic style). The key art of the
  standalone prototype (`D:/Dev/claudius_prequel/assets/art/key_art.jpg`).
  Shipped as the Landing background of Last Shift
  (`games/last_shift/landing_bg.jpg`), re-saved as JPEG quality 84.
  AI-generated for the owner; **the tool and plan were not recorded -- owner to
  confirm** (if it is not ChatGPT, the terms quoted above may not apply).
  Fictional character, no real person or company.

## Turned (2026-10-23)
- `turned_landing_src.webp` (1024x1536): close-up of a neck with two bite marks
  in front of a gothic city at night (the mirror moment of the story). Shipped as
  the Landing background of Turned (`games/turned/landing_bg.jpg`): cropped to a
  1024x576 landscape band and mirrored (so the marks sit right of the Landing's
  text column), JPEG quality 86. AI-generated for the owner; **the tool and plan
  were not recorded -- owner to confirm**. Fictional, no real person.

## Turned paintings, cards, player bust (2026-10-24)
- Made by the owner with **Google Gemini** (his own account; **plan not stated --
  owner to confirm**) from the prompts in `docs/turned/ART_PROMPTS_V2_READY.md`;
  originals in `D:/dev/RPG/turned`, copies as `reference/art/turned/gen/<id>.jpg`
  (1264x848 scenes, 1024x1024 cards and busts). Google's terms for Gemini do not
  claim ownership of generated images; they carry Google's invisible SynthID mark
  (no visible watermark on these). Fictional places and people, no real person,
  no brand, no readable text.
- Shipped, re-saved as WebP: `games/turned/art/scenes/SC-01..SC-05.webp`,
  `games/turned/art/cards/CD-01.webp`, `CD-02.webp`, `CD-05.webp`, and
  `games/turned/art/ui/portrait_player.webp` (a 320x320 crop of the neutral bust
  in `CS-01_busts.jpg`, 256x256).
- Kept unshipped in `gen/`: the player's sheets (`CS-01a_v1`..`e_v1` in the first
  look, outfits `CS-01f`..`j`), the bust sheet, and redo candidates
  (`SC-06_v1`, `SC-07_v1`, `CD-03_v1`).

## Chess (2026-10-24)
- `chess_landing_src.png` (992x1586, owner's `D:/dev/Minigame Art/chess.png`,
  also sent in chat): dark and ivory Staunton pieces facing off on a polished
  stone board in a candle-lit gothic hall, a castle in the moonlit window.
  Shipped as the Landing background of Chess (`games/chess/landing_bg.jpg`) and,
  under a dark veil, its play background in the Classic look; JPEG quality 86.
  AI-generated for the owner; **the tool and plan were not recorded -- owner to
  confirm**. IP check (owner, 2026-10-24): the red banner with a gold lion is
  ordinary heraldry (a lion rampant); no name, logo or crest of any franchise --
  kept as is.

## Poker (2026-10-27)
- Made by the owner with **Google Gemini** (his own account; **plan not stated --
  owner to confirm**) from short prompts written in chat. Originals in
  `D:/dev/minigame art/poker/<look>/game art/` and Google Drive > Viral Game Hub >
  poker (never shipped, not in the repo: ~1 MB each). Google's terms for Gemini do not
  claim ownership of generated images; they carry Google's invisible SynthID mark.
  Fictional people and symbols, no real person, no brand.
- Shipped (Classic look), cut out of the photos and re-saved as WebP by
  `tools/poker_art_import.py`: `games/video_poker/art/classic/` -- `card_back`,
  `card_face` (the card back with its crest painted out), 16 court-card and ace faces
  `face_<A|J|Q|K>_<s|h|d|c>`, 6 chips `chip_1..6`, `dealer`, `table_portrait`.
- Not used: `ERROR TREBLE CLEF QUEEN` (the owner's reject), `queen spades2` (an alternate
  Queen of Spades; `queen spades` is used), the third row of the chip sheet (spares).
- The text inside the art (banners, rings) is decoration made up by the AI, not meant to be read.
