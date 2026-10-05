# Trace It / Calcá — roadmap

The user's vision (2026-10-05): "this could be a huge game!" — a real
learn-to-draw course, not just a tracing tool. Every teaching aid is a
player option (step by step, lessons, coaching, help that fades).

## Milestones (the order the user set)

1. ✅ Step 0 — camera spike (`tools/camera_spike/`): Godot's own CameraServer is enough.
2. ✅ Free mode — overlay over the live camera, move/pinch/turn, lock, opacity,
   looks, line colour, flips, grid, step by step (photos and drawings),
   permission screens, set-up tutorial, Done, Resume.
3. ✅ (built 2026-10-05, not yet phone-tested) Accuracy check — baseline frame, movement watch, final frame, ink mask vs
   the template lines (`TraceItArt.line_art` masks), F1, heatmap, debug view.
   Then **coaching feedback** from it ("you missed the small details",
   "lines drift right"), not just a %.
4. Guide levels — full / half / fading / no guide; help that fades as the
   player gets good (the levels become a path to climb).
5. Courses + lessons — short illustrated lessons before the drawings that
   practise them; placeholder art in `trace_it_drawings.json`.
6. Progress + achievements (personal only). The spec's completion and
   accuracy tiers, plus the user's (2026-10-05):
   - finishing training sessions / lessons (each one, each course, all);
   - keeping a set accuracy % on line drills (e.g. 5 lines in a row ≥ 80%);
   - N drawings finished at each guide level (full / half / fading / none),
     with the no-guide tier as the "real progress" badges.
   They go in `trace_it_help.gd`'s `ACHIEVEMENTS` (GameInfo already gives
   generic counter badges for free — "Photos traced" unlocked one in testing).
7. Supabase sync (data only, never images; merge by max / union).
8. Store / manifest (trial, $1, hub subscription; the funnel question).
9. Polish.

## Done in round 2 (2026-10-05, after the user's first phone test)

- Zoom fixes: the overlay's size is fixed when the picture loads (only a
  pinch changes it); only the first two fingers move it; 📷 steps through
  every camera (a wide fixed-focus lens doesn't "breathe" while refocusing).
- **Studies** in the Free mode picker, each with a 📖 lesson (shown first
  the first time, a player option): Warm-up, The golden ratio (golden
  rectangle, golden spiral, nautilus), Perspective (1-point road, 2-point
  box), Ornament (S-scroll, filigree corner, acanthus leaf), Shading
  techniques (sphere with cross-hatching, apple with stippling), Drawing
  styles (doodle, geometric mandala, cartoon robot, water-cycle diagram).
- Looks: hatching and dots on any photo; the Shading step can shade with
  tones / hatching / dots. Guides: 3x3, 4x4, golden ratio lines, golden spiral.

## Content ideas from the user (not scheduled yet)

**Courses** (original or CC0 art only):
- The spec's six: lines & curves, basic shapes, simple objects, animals,
  faces & figures, lettering.
- **Drawing styles**: doodling, diagrams, geometric, cartoon, realistic.
- **Perspective**: 1-, 2- and 3-point; the overlay can draw the horizon and
  vanishing-point guide lines over the paper.
- **Ornament study**: the acanthus leaf, scrollwork, filigree, swirls.
- **The golden ratio**: golden rectangles and the spiral, as drawings and as
  an overlay guide (like the grid) to compose any picture with.

**Overlay looks / shading techniques** (shaders over the Shading step's
tones, so the player traces the technique itself):
- Cross-hatching (tone -> 1-4 layers of hatch lines), contour hatching.
- Pointillism / stippling (tone -> dot density).
- Possibly: scribble, charcoal-like blocks.
Each one comes with a short lesson on how to do it by hand.

## Technical notes

- Photo line finding (`TraceItArt.line_art`) leaves dashed lines on dark,
  noisy photos; hysteresis linking (Canny's second threshold) would join
  them — worth doing with the accuracy check, which compares against these
  masks. A "fewer / more lines" control is cheap (it's the `keep` share).
- EXIF rotation isn't read; the ⟳90° tool covers sideways phone photos.
- **Focus lock + torch** need a native camera plugin (Kotlin + CameraX
  replacing Godot's CameraServer for this game): Godot exposes neither. Only
  worth it if the wide-camera workaround isn't enough on players' phones.
- Still to add from the user's list: perspective guides you can drag
  (horizon + vanishing points over any picture), more ornament (Greek key,
  rosettes), more styles drawings, contour hatching / scribble looks.
