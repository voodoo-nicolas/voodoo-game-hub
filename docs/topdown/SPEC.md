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

### 1.2 Speed table (13 pairs of bytes: straight, diagonal-per-axis)
The speed index is a game-state byte (even values). The entry used is `index + (1 if diagonal)`.

| Index | Straight (px/f) | Diagonal per axis (px/f) | Diagonal true speed | Meaning (confidence) |
|---|---|---|---|---|
| `$00` | 1.5 (90 px/s) | 1.0 | 1.41 (94 % of straight) | normal walk (**confirmed**) |
| `$02` | 0.625 | 1.5 | — | set in one state; pair looks odd, unconfirmed |
| `$04` | 1.0 | 0.5 | 0.71 | set when a hole/edge state starts (unconfirmed) |
| `$06` | 0.5 | 0.25 | 0.35 | set while holding a direction in one action state; likely pushing (unconfirmed) |
| `$08` | 0.75 | 1.0 | — | unconfirmed |
| `$0A` | 0.5625 | 1.5625 | — | used by a slow-start ramp (1.3) |
| `$0C` | 1.25 | 0.8125 | 1.15 | **slow walk while charging the sword** (confirmed, 2.2); also set when an object is lifted (carrying, likely) |
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

### 1.5 Dash
- **Start:** the dash button starts a wind-up counter at 29, and it counts down once a frame. The dash can't start while the hero is carrying something.
- **Wind-up = 30 frames (0.5 s).** The hero runs on the spot (not yet checked in play). A footstep sound plays every 16 frames for the first half and every 8 frames for the second half, so the steps speed up just before the dash.
- **Release during the wind-up cancels it:** when the counter runs out, the dash only starts if the button is still held. Otherwise the hero goes back to normal walking.
- **Direction:** the stick direction at that moment, or the facing direction if the stick is centred. The dash speed row (`$10`, 4 px/f) is then used.
- **Running:** the button no longer matters once the dash has started. The dash keeps going until **the player pushes any direction other than the dash direction** (the hero then goes into a stopping state). Hitting a wall also ends it (that code path is not traced yet; there is probably a bounce-back).
- **Sword out while dashing:** if the hero owns a sword, a sword hitbox is placed in front of the hero every frame of the dash, and the hero is drawn holding the sword forward. So the dash is also an attack.
- A second counter starts at 64 when the dash begins, goes down 1 a frame, and stops at 32. It looks like a dash-dust or animation timer (unconfirmed).

## 2. Sword

### 2.1 Swing
- Pressing the sword button stops walking for the length of the swing (the direction input is cleared each frame). The facing direction stays fixed.
- The swing is **9 poses** with these lengths in frames: **2, 1, 1, 1, 1, 4, 1, 1, 2 = 14 frames (0.23 s)**. Pose 5 is the long one (4 frames), when the blade is fully out in front.
- **Re-swing (button mashing):** from pose 4 (after 5 frames), if the button was released and pressed again, the swing restarts from pose 0. Mashing gives a swing about every 5–6 frames.
- **Sword beam:** at pose 5, a projectile is fired along the facing direction if (a) the sword is level 2 or better and (b) health is **less than half a heart below full** (health counts in 1/8 hearts, and the test is current > max − 4). Only one beam may exist at a time.
- **Poking a wall:** while holding the charge, if the blade touches a wall a "tink" sound plays and a short hitbox is placed. Two different sounds play depending on the wall side or type (unconfirmed which).

### 2.2 Charge and spin
- If the button is **still held when the swing ends**, the hero holds the sword out and **walks slowly** (speed row `$0C`, 1.25 px/f; in grass, row `$0E`).
- A charge counter goes up 1 a frame, stopping at 64. From 6 onward, a sparkle appears on the blade every 4th frame. At **48 frames a "charged" sound plays**. Total from the first press: 14 + 48 = **62 frames (about 1.03 s)**.
- **Release before 48** → the sword is simply put away. **Release at 48 or more** → spin attack.
- **Spin attack:** the hero is rooted and goes through 12 poses, starting from the facing direction and going all the way round. Their lengths are **4, 10, 4, 2, 2, 2, 2, 2, 2, 2, 2, 6 = 40 frames (0.67 s)**. There is a sound at pose 2. The long 10-frame pose is the wind-back before the sweep. (A second table with faster lengths, 2/6/2/2…, exists for another variant; unconfirmed which.)
- There's no charging without a sword, and no charging while a beam is still in flight.

### 2.3 Still to find
- Hitbox rectangles per pose (sword reach), sword damage per sword level, and the spin's damage multiplier.

## 3. Still to find (next steps)
- Taking damage: knockback speed and length, invincibility frames.
- Pushing: how many frames before a block moves.
- Collision box size and corner-sliding (the hero slides round corners when slightly off a gap).
- Health: hearts, damage units, how health is refilled.
- Enemies, items, room/dungeon structure, game loop: later sections.

## 9. Our game (rules taken from the sections above, in our units)

| Rule | Value for the prototype |
|---|---|
| Frame model | fixed 60 Hz physics, no acceleration, instant stop |
| Walk | 90 px/s straight, 60 px/s per axis diagonal |
| Dash | 240 px/s straight, 157.5 px/s per axis diagonal |
| Slow walk (carrying, charging) | 75 px/s straight, 48.75 px/s per axis diagonal |
| Grass / shallow water | walk 75 px/s, dash 180 px/s |
| Sub-pixel | keep float positions; snap the drawn sprite to whole pixels |
| Dash wind-up | 0.5 s on the spot, steps speeding up; release cancels |
| Dash end | any other direction pushed, or a wall; sword hitbox out while dashing |
| Swing | 9 poses, 14 frames (0.23 s), rooted; blade fully out on frames 7–10 |
| Re-swing | release + press again after 5 frames restarts the swing |
| Beam | sword level 2+, health within half a heart of full; one at a time |
| Charge | hold past the swing: slow walk, ready after 48 more frames (0.8 s), sparkles |
| Spin | 12 poses, 40 frames (0.67 s), rooted, full circle from facing |
