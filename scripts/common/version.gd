extends RefCounted

## Single source of truth for the app version, shown in the hub UI.
## Bump PATCH for small fixes/content adds, MINOR for new games/features,
## MAJOR once this leaves early testing. Keep export_presets.cfg's
## version/name and version/code in sync with this by hand on each build
## (Godot's exporter doesn't read version info from GDScript).
const VERSION := "0.9.1"

## Android requires an integer versionCode that strictly increases with every
## release build, or installs of a newer APK over an older one will be rejected.
## Bump this every time a new APK is built for testers, independent of VERSION.
const BUILD_NUMBER := 16
