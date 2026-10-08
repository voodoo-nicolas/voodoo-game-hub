# Music library + Viral Music Drop

Owner rule (2026-10-07): **every game takes its music from the shared `Music` autoload**; no game synthesizes or ships its own.

## Music autoload (`scripts/common/music.gd`; header = how-to)
- Styles `calm`/`lively`/`techno`, 4 tracks each. `play(style, owner, index, fade, genre = "")` crossfades (same index = no-op; index -1 = next track), `prepare(style, index)` pre-renders (call from `_ready()`), `stop(fade)`. Fades out when `owner` leaves the tree; dips 10 dB while paused; pauses with the app (`NOTIFICATION_APPLICATION_PAUSED`).
- **Games never reference `Music` directly**: tiny `_music()` helper with `get_node_or_null("/root/Music")` (see Sky Strike; Neon Blast's `_sounds.gd` has `_music_node()`). Older apps just play no music; no `min_build`.
- Player controls: Settings sound group `"music"` (🎵 on/off + volume) on the `Music` bus (feeds Master, so Mute all covers it).
- Synthesized: Neon Blast's instruments + a lead melody in the second half of lively/techno loops. Rendered on a worker thread when first wanted (~0.5-1 s on PC), cached in `user://music_synth/` (~1.3 MB/track). **Bump `SYNTH_VERSION` when `SONGS` or instruments change.** Web works through 4 ms/frame. Listen: `godot --headless --path . --script res://tools/music_preview.gd` -> `builds/music_preview/`.
- Real tracks: `.ogg` in `res://media/common/music/<style>/` (Tier 1) or `res://media/hub/music/<style>/` (APK) replace that style's synth; each needs a `CREDITS.json` entry.
- Ducking under SFX is not built.

## Downloaded tracks (`scripts/common/music_library.gd`, `Music.library`; header = how-to)
- Fetches the list once per launch (`Config.MUSIC_LIST_URL`, cached `user://music/music.json`; synth cache stays separate). Downloads a track when a game wants its pace (+ genre) to `user://music/<file>` (.part, sha256 checked), plays via `AudioStreamOggVorbis.load_from_file`. Folder capped 150 MB, LRU. Up to 4 tracks per style + genres, plus one new per style each app start. Options -> Storage shows/clears it; Credits lists each track's credit from the live list.
- Once one downloaded track of a style is on the phone, those replace the synth. Until then synth plays, a download starts, the real track crossfades in when it lands. Several tracks: each plays once then the next (3 s crossfade); a lone one loops from `loop_start`.
- **`play` map** in `music.json`: `"hub"`, `"category:<English name>"`, `"game:<id>"` -> `{style, genres}`. style `""` = game decides; `calm|lively|techno` = that screen gets music by itself (hub music carries across hub screens); `off` = never. Game entry wins over its category's, field by field. Preset off: `simon`, `voodoo_iq`. **"off" also silences a game's own `Music.play()`**: never set it on a game that plays the library itself (Neon Blast, Sky Strike).
- Web build: reads the list (CORS ok) so the `play` map works with synth, but downloads nothing (release downloads lack CORS).
- Tests: `tools/test_music_library.gd`, `tools/test_music_play.gd` (need `python -m http.server 8899` serving a test list.json + OGGs).

## Viral Music Drop (`tools/music_drop/`)
Owner adds tracks without Claude. Desktop shortcut via `python tools/hub.py music-drop --shortcut`. Runs on 127.0.0.1 in an Edge app window, closes itself 2 min after the window.
- ffmpeg at `%LOCALAPPDATA%\Programs\ffmpeg\bin` (gyan.dev 9.0.2 essentials). Output OGG Vorbis `-q:a 2` (~96 kbps), loudness -16 LUFS with one exact gain (true peak <= -1.5 dB); two-pass loudnorm only when that gain would clip; warns if still quieter. An OGG already <= 128 kbps and within 1 LU is kept.
- Owner fills title, genre, pace (slow/moderate/fast = calm/lively/techno), loop start, licence, author, source, AI tool + plan, proof file, "commercial use OK". "Add to hub" uploads each OGG to **pre-release `music-v1`** (`Config.MUSIC_RELEASE_TAG`; pre-release so `/releases/latest`, read by the update check, never points at it), then one commit on master writes `media/music/music.json` + proof in `media/licenses/music/` (files first, list last). GitHub access = `gh auth token`, never stored. Duplicates detected by picked file's sha256 (`src_sha256`; Vorbis encodes differ per serial). Library tab previews/edits/removes (removing delists; asset stays). "Where it plays" tab edits `play`.
- Licences: own, CC0, CC BY 4.0, CC BY 3.0 (`cc-by-3`), royalty-free, bought, AI. Never NC/ND.
- Freesound auto-fill: file named `<id>__<user>__<name>.<ext>` gets source + link; attaching Freesound's `licenses.txt` as proof fills exact title/author/licence. NC/Sampling+ refused. "Same credit for all" never overwrites a file-derived credit. First three uploads were by hand and need Library -> Edit fixes: Zimmerman (154822) is CC BY 3.0 not 4.0; Robetroid (825878) is by "Robhog"; titles are file names.
- **The tool commits straight to GitHub: `git pull` before pushing; never create `music.json` locally.** `hub.py check` (`lint_music`) reads the local copy: pace, genre, file name, sha256 + size, licence, author, commercial OK, proof file, AI tool + plan, CC BY link, `play` keys name real games/categories.
- Test without GitHub: `python tools/music_drop/music_drop.py --fake <dir>`. Log: `%LOCALAPPDATA%\ViralMusicDrop\music_drop.log`.
