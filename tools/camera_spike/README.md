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
3. Leave it 10 s on a still scene and read CAMERA fps / RENDER fps. Tap
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
7. "Pick image" (gallery picker), "Save image" (does it show in the
   gallery app under TraceIt?), "Overlay" / "Opacity" (shader styles).
8. Deny path: in Android settings revoke the camera permission, reopen,
   deny, then "App settings" must open this app's settings page.

## Findings so far (from the 4.7.2 source and docs, before device numbers)

See the Step 0 report in the conversation; the device results get added
here when they come back.
