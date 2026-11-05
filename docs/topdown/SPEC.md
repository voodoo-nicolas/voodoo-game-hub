# Top-down adventure (working title): mechanics spec

Study notes for an original top-down action-adventure (PC-only hub game, kept out of `manifest.json`).
The numbers come from reading the code of a SNES game the owner owns. They are written in our own words and our own units.
Only these mechanics carry over to our game. Its art, maps, music, code, names, enemy roster and item list do not.

## 0. Source

| Field | Value |
|---|---|
| Release | USA, version 1.0 |
| Size / map | 1 MB (8 Mbit), LoROM, SlowROM (`$20`), no copier header |
| Cartridge | ROM + battery-backed save RAM (type `$02`), 8 KB of save RAM |
| Checksum | `$AF0D` (its complement `$50F2` matches) |
| SHA-1 / CRC32 | `6d4f10a8b10e10dbe624cb23cf03b88bb8252973` / `777aac2f` |

The ROM stays outside the repo. Method: static disassembly with a small 65816 disassembler in the session scratchpad (not committed). No emulator debugger was used yet, so every value below is **read from code, not measured in play**.

Units: the original runs at 60 frames/s. A speed of 1 px/frame = 60 px/s in Godot at the same pixel scale. The original screen is 256×224 px, and the hero is about 16 px wide.

## 1. Hero movement

### 1.1 How a frame of movement works
- Each frame the hero's two velocity bytes (vertical, horizontal) are **cleared, then set straight from the joypad** to a speed read from a table. There is **no acceleration and no friction** in normal walking: full speed on the first frame, a dead stop the frame the stick is released.
- A velocity byte is signed and counts **1/16 px per frame**. The low 4 bits go into a sub-pixel counter per axis (carry adds 1 px). The high 4 bits, sign-extended, move whole pixels. So speeds are multiples of 0.0625 px/frame.
- 8 directions. The input bits are up 8, down 4, left 2, right 1. The facing direction is taken from the velocity signs after moving.
- **Diagonals use their own table entry; the speed is not normalised.** Holding two directions picks the next table entry, which is lower than straight speed × 0.707 in most rows (see 1.2).
- After moving, the per-frame pixel delta (new position − old) is kept for collision and camera code.

### 1.2 Speed table (16 bytes of pairs: straight, diagonal-per-axis)
The speed index is a game-state byte (even values). The entry used is `index + (1 if diagonal)`.

| Index | Straight (px/f) | Diagonal per axis (px/f) | Diagonal true speed | Meaning (confidence) |
|---|---|---|---|---|
| `$00` | 1.5 (90 px/s) | 1.0 | 1.41 (94 % of straight) | normal walk (**confirmed**) |
| `$02` | 0.625 | 1.5 | — | set in one state; pair looks odd, unconfirmed |
| `$04` | 1.0 | 0.5 | 0.71 | set when a hole/edge state starts (unconfirmed) |
| `$06` | 0.5 | 0.25 | 0.35 | set while holding a direction in one action state; likely pushing (unconfirmed) |
| `$08` | 0.75 | 1.0 | — | unconfirmed |
| `$0A` | 0.5625 | 1.5625 | — | used by a slow-start ramp (1.3) |
| `$0C` | 1.25 | 0.8125 | 1.15 | set when the sword level is read and when an object is lifted: **slow walk while charging the sword / carrying** (likely) |
| `$0E` | 1.0 | 0.5 | 0.71 | charging/carrying while in grass/shallow water (1.4) |
| `$10` | 4.0 (240 px/s) | 2.625 | 3.71 | **dash** (confirmed: set right after the dash timer starts) |
| `$12` | 1.0 | 0.5 | 0.71 | unconfirmed |
| `$14` | 0.25 | 0.125 | 0.18 | very slow; set in one action state (unconfirmed) |
| `$16` | 3.0 | 1.5 | 2.12 | dash in grass/shallow water (1.4) |
| `$18` | 2.0 | 1.3125 | 1.86 | unconfirmed |

Design takeaways:
- Walk 1.5 px/f, dash 4 px/f: dash is about **2.7× walk**.
- Diagonals are a little slower than straight lines (94 % when walking, 93 % when dashing). This is part of the feel; copy it as a rule, not as these exact bytes.
- Carrying or charging slows the hero to about 83 % of walk.

### 1.3 Slow-start ramp
A separate path (taken when a ramp counter is non-zero) adds the counter to the table speed. The counter climbs 1 per frame up to 16, then resets and puts the speed index back to normal. When a certain edge state is 3, the counter instead climbs 8 per frame up to `$30`, and when it is over that it is set to `$20`.
**Unconfirmed:** which situations start it (it looks like recovering after being pulled toward a hole). Not needed for the first prototype.

### 1.4 Terrain
A terrain flag (grass / shallow water, by its use) swaps the speed for these rows: walking → `$0C` row (1.25 px/f), charging → `$0E` row (1.0), dash → `$16` row (3.0 px/f).

### 1.5 Still to find (next steps)
- Dash: wind-up time before moving (the dash timer starts at `$40` = 64 frames?), how a dash ends, and damage on contact.
- Sword: swing frames, hitbox, charge time for the spin attack.
- Taking damage: knockback speed and length, invincibility frames.
- Pushing: how many frames before a block moves.
- Collision box size and corner-sliding (the hero slides round corners when slightly off a gap).
- Health: hearts, damage units, how health is refilled.
- Enemies, items, room/dungeon structure, game loop: later sections.

## 2. Our game (rules taken from section 1, in our units)

| Rule | Value for the prototype |
|---|---|
| Frame model | fixed 60 Hz physics, no acceleration, instant stop |
| Walk | 90 px/s straight, 60 px/s per axis diagonal |
| Dash | 240 px/s straight, 157.5 px/s per axis diagonal |
| Slow walk (carrying, charging) | 75 px/s straight, 48.75 px/s per axis diagonal |
| Grass / shallow water | walk 75 px/s, dash 180 px/s |
| Sub-pixel | keep float positions; snap the drawn sprite to whole pixels |
