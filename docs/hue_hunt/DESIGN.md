# Camera Hunter (id `hue_hunt`) — design decisions

Display name **Camera Hunter** (owner, 2026-11-26). The id `hue_hunt` never changes.
Briefs: the owner's first prompt + addendum (2026-11-26, in the session log).

## Decided (owner, 2026-11-26)
1. Camera: Godot's CameraServer, no native plugin. Shared `scripts/common/camera_service.gd`
   (copy of Trace It's camera), app bump minor, game entry `"min_build"` = new build.
2. Manifest key is `min_build` (not `min_app`).
3. Id `hue_hunt` (snake_case).
4. Helps (§17) are **solo only**. Solo helps: Hot/Cold, Peek, Second Chance, **More Time (+30 s)**.
   Multiplayer uses match power-ups (max 3 per match, catch-up) instead; kit helps off in matches.
5. Timing: host clock + each player's measured offset (no trusted server time).
6. Shared photos: Flag vote + "Hide this player's photos" for the match. Never stored.
7. Menu style named in the game file header.
8. Android only; ignore iPhone/web.

## Themes (owner, 2026-11-26: "different themes of stuff to search for, not just colours")
The round engine is theme-based. A Theme = a prompt pool + a judge:

| Theme | Example prompt | Judge |
|---|---|---|
| Colours | "Teal" | automatic (CIEDE2000 on the tapped patch) |
| Shapes | "a circle", "a pentagon", "a star" | peer vote (like Object rounds) |
| Objects | "a teacup", "something round" | peer vote |
| later: letters/numbers, textures, "something older than you" | | peer vote |

- Only Colours can be scored by the phone in v1. Shape detection on-device is possible later
  (edge/contour check) behind the same `ObjectJudge` interface; v1 is honest peer vote.
- Peer-vote themes are multiplayer only (solo has no one to vote): solo = Colours.
  OPEN: solo Shapes with self-confirm and no ranking?
- Host picks themes for the match (Colours / Shapes / Objects / Mixed).
