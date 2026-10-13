extends RefCounted

## One-time "free up space" notice after an app update (APK-side only).
##
## Updating means downloading voodoo-vX.Y.Z.apk in the browser; Chrome keeps
## every one in Downloads (~100 MB each, "(1)" copies too). Android (11+) won't
## let the app delete a file the browser saved, so all it can do is tell the
## player and open the Downloads screen. Shown once per app version, on the
## first hub visit after the version changes (a fresh sideload counts too:
## the installer they just ran is still there).

const SaveUtil = preload("res://scripts/common/save_util.gd")
const Version = preload("res://scripts/common/version.gd")

const SEEN_PATH := "user://old_apk_notice.json"
## Chrome/Samsung names (voodoo-v0.37.0.apk, "voodoo-v0.37.0 (1).apk").
const FILE_HINT := "voodoo-v*.apk"

## True on Android when this app version hasn't shown the notice yet.
static func should_show() -> bool:
	if not OS.has_feature("android"):
		return false
	var data = SaveUtil.read(SEEN_PATH)
	return data == null or str(data.get("version", "")) != Version.VERSION

## Called when the player answers the dialog (either button), so it doesn't
## come back until the next version.
static func mark_seen() -> void:
	SaveUtil.write(SEEN_PATH, {"version": Version.VERSION})

## Opens the system Downloads screen. Returns false if it couldn't (the dialog
## text already says where to look). Every call into Android is guarded: this
## must never break the hub on a phone/ROM that answers differently.
static func open_downloads() -> bool:
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"):
		return false
	var runtime = Engine.get_singleton("AndroidRuntime")
	var activity = runtime.getActivity() if runtime else null
	var intent_class = JavaClassWrapper.wrap("android.content.Intent")
	if activity == null or intent_class == null:
		return false
	var intent = intent_class.Intent("android.intent.action.VIEW_DOWNLOADS")
	if intent == null:
		return false
	activity.startActivity(intent)
	return true
