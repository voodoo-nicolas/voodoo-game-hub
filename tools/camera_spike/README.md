# Camera spike (Step 0 for "Trace It" / "Calcá")

A throwaway, separate Godot project (its own `project.godot`; `tools/` is
ignored by the hub project). It answers one question before any game code
is written: **can Godot 4.7.2's built-in CameraServer carry a live
camera-tracing game on a real Android phone?** Never shipped.

Package `com.viral.voodoo.camspike`, debug-signed, so it installs next to
the real app without touching it.

## Build and install

```
godot --headless --path tools/camera_spike --export-debug Android <abs path>/camera_spike.apk
adb install -r tools/camera_spike/camera_spike.apk
```

(Or copy the APK to the phone and open it. `*.apk` is gitignored here.)

## What to test on the phone (then "Copy report" and paste it back)

1. First launch: the camera permission prompt appears; allow it. The back
   camera fills the screen with a test picture drawn over it as line art.
2. **Is the picture upright and not mirrored?** If not, tap "Rot +90" /
   "Mirror" until it is (the report records what it took).
3. In BRIGHT light (daylight or a lamp over the paper), leave it 10 s on a still scene and read CAMERA fps / RENDER fps. Tap
   "Format ▶" through 640x480 / 1280x720 / 1920x1080 and note the fps
   for each.
4. "Capture ×10" (reads a frame back as grayscale, as the accuracy check
   will) and "Distance" (the accuracy math in plain GDScript at 320 px).
5. Latency: tap "Camera ⇄" for the front camera, dim the room, hold a white
   sheet of paper ~5 cm over the screen, tap "Latency" (8 flashes).
   Back camera by eye: wave a hand under it and judge the lag, or film the
   phone and a stopwatch together with a second phone.
6. Home button, wait 5 s, reopen: the report shows how long until frames
   flow again.
7. "Pick image" (gallery picker), "Save image" (which of the 4 files show in the
   gallery app under TraceIt?), "Overlay" / "Opacity" (shader styles).
8. Deny path: in Android settings revoke the camera permission, reopen,
   deny, then "App settings" must open this app's settings page.

## Findings

- **v1 on a Galaxy A52 (Adreno 618, Android 14)**: the "camera" was green and
  cyan blobs -- Godot's placeholder texture. `ShaderMaterial` stores a
  texture's RID when the parameter is set (`material.cpp`), and a
  `CameraTexture` whose feed doesn't exist yet returns a placeholder RID. Bind
  the camera textures to the material *after* setting `camera_feed_id` (the
  real game must do the same). Camera fps read 10 at every size up to 1440x1080
  (7.7 at 1080p): rerun in bright light, the auto exposure may cap it in a dim
  room. Resume: frames back ~650 ms after returning to the app. Saving into
  Pictures/ failed (it goes through Godot's MediaStore path); v2 tries four
  places.
- v2 adds: "View" (color / Y plane / CbCr, for debugging), a light reading,
  and the save variants.
- **v2 on the A52 -- verdict: Godot's own CameraServer is good enough, no
  plugin.** Real image, correct colors (BT.601 full-range shader, no UV
  swap).
  - fps is set by the light, not by Godot: main back camera (feed id 0)
    30.0 fps at 1280x720 in a normally lit room (mean Y ~110); the second
    back camera (id 2) 24-26; front 19-20; a dark room (mean Y ~70) drops
    every camera to 10. Render stays 58-60 with the overlay shader. So the
    game picks the **first** back camera (lowest id -- the spike wrongly put
    the last one first), asks for good light in the tutorial, and shows a
    "more light" hint when the feed is dark/slow.
  - **Orientation**: upright needed `feed_transform`'s rotation *inverted*
    (back: feed 90°, needed +180° on top = -90°; front: -90° -> +90°, plus a
    horizontal mirror). In the game: `basis = feed_transform basis inverse`,
    then mirror X for FRONT.
  - 1088x1088 once dropped render to 34 fps; stay at 1280x720 (or 960x720).
  - Resume after Home: frames back in ~650-690 ms, no code needed.
  - The flash latency test strobes the whole screen -- don't use it in the
    game. Not measured; lag looked fine by eye.
  - Not yet run on the phone: Capture, Distance, Pick image, Save image,
    App settings (checked again in the Free mode milestone).
