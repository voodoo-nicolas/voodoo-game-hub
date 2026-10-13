# Old installer files piling up in Downloads (found 2026-10-13)

## What happens
"Update Now" (`hub.gd` `_show_update_dialog`, Options > Check for updates) calls
`OS.shell_open(apk_url)`: Chrome downloads `voodoo-vX.Y.Z.apk` into the phone's
Downloads folder, and Chrome owns that file. Every update (and every re-download,
as `voodoo-v0.10.0 (1).apk`) stays there, ~100 MB each. Owner's phone, 2026-10-13:
658 MB in Downloads (v0.5.0, v0.10.0 x2, v0.34.0, v0.36.0, v0.37.0 ...).

Not the cause: game packs. `user://packs/<id>.pck` is downloaded to `.part` and
swapped over the old file, so there is one file per game.

## Why the app can't just delete them
Android 11+ scoped storage: an app can't delete another app's file (Chrome's)
without a per-file system prompt, or the all-files-access permission, which Play
restricts and which is an alarming prompt for a game. Not worth it.

## Shipped (ready for the next app bump)
`scripts/common/old_apk_notice.gd` + `hub.gd` `_on_no_app_update`: once per app
version, on Android, when the launch update check finds nothing newer (or is
offline), a dialog "Free up space" says the old `voodoo-v*.apk` files are safe to
delete and offers **Open Downloads** (system Downloads screen via
`JavaClassWrapper` intent `android.intent.action.VIEW_DOWNLOADS`) or **Not now**.
Either button marks the version as seen (`user://old_apk_notice.json`).
Skipped when an update is available (the update dialog wins) and off Android.
EN + ES in `tools/i18n/es.json`.
**Not tested on a phone**: the Open Downloads call is guarded and does nothing if
Android answers differently; the dialog text still says where the files are.
Check on the first APK that contains it. Fresh sideloads also see it once (the
installer they just ran is still in Downloads), which is right.
TODO when the app is on Google Play: skip the notice for Play installs.

## Feasibility: in-app updater (no leftovers at all)
Idea: the app downloads the new APK into its own storage, opens the installer,
and deletes the file on next launch.
- Godot 4.7 standard export (no Gradle) has `AndroidRuntime` + `JavaClassWrapper`,
  so Java calls from GDScript are possible without a plugin.
- No custom AndroidManifest without Gradle, so no FileProvider. Workaround:
  `DownloadManager` (system service) downloads to the app's external files dir,
  `getUriForDownloadedFile(id)` gives the installer a readable `content://` URI,
  `ACTION_VIEW` + `application/vnd.android.package-archive` +
  `FLAG_GRANT_READ_URI_PERMISSION`, then `DownloadManager.remove(id)` on next
  launch (app-owned file, so deletable).
- Needs the `REQUEST_INSTALL_PACKAGES` permission (export preset
  `permissions/install_packages`, currently false) and the player allowing
  "Install unknown apps" for the hub once.
- No broadcast receivers from GDScript: completion must be polled (`query` + Cursor).
- Risks: untestable without a physical phone; Cursor/Intent overload resolution
  through `JavaClassWrapper` is fiddly; Play restricts `REQUEST_INSTALL_PACKAGES`
  (moot if Play distribution updates the app itself); Google developer
  verification (Limited distribution) may affect sideloaded installs.
- Verdict: probably feasible, roughly one session plus phone testing. Not
  shippable blind. Google Play distribution removes the problem entirely.
