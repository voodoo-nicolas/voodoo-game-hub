extends SceneTree

## PC overlay (Catalog._pc_overlay, docs/claude/build-ship.md "PC build game
## updates"): on the Windows build a bundled game whose published pack is newer
## is downloaded and laid over the bundled copy.
##   godot --headless --path . --script res://tools/test_pc_overlay.gd
## 1. The version logic, with a made-up bundled game (no network).
## 2. write_overlay on a real pack (builds/packs/turned.pck, skipped if
##    missing): only game-owned entries are kept, and mounting it with
##    replace_files leaves the build's shared files alone.
## Restores pack_versions.json and removes every file it writes.

const FAKE := "zz_test_overlay"

var fails := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL: " + msg)
		fails += 1

func _initialize() -> void:
	var catalog = root.get_node("Catalog")
	await process_frame
	var vpath: String = catalog.PACK_VERSIONS_PATH
	var versions_backup = FileAccess.get_file_as_bytes(vpath) if FileAccess.file_exists(vpath) else null

	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")   # the strings below are the English ones

	# ---- 1. version logic
	_check(not catalog._pc_overlay, "the editor never overlays")
	catalog._pc_overlay = true
	var fake := {"id": FAKE, "title": "Overlay Test", "icon": "🎮", "scene": "res://nope.tscn", "version": 5}
	catalog._games_by_id[FAKE] = fake
	catalog._bundled[FAKE] = true
	catalog._bundled_version[FAKE] = 3
	DirAccess.remove_absolute(catalog._pack_path(FAKE))
	_check(catalog.installed_version(FAKE) == 3, "bundled copy is v3")
	_check(catalog.needs_download(FAKE), "newer published pack: download")
	_check(catalog.has_update(FAKE), "tile shows 🔄")
	_check(catalog.updates_available().has(FAKE), "listed in Game updates")
	_check(catalog.version_text(fake).begins_with("Version 3 · update to version 5"), "version line: " + catalog.version_text(fake))
	var f := FileAccess.open(catalog._pack_path(FAKE), FileAccess.WRITE)
	f.store_string("GDPC fake")
	f.close()
	catalog._set_local_version(FAKE, 5)
	_check(catalog.installed_version(FAKE) == 5, "downloaded v5 is installed")
	_check(not catalog.needs_download(FAKE), "up to date: no download")
	_check(catalog._overlay_wanted(FAKE), "v5 pack over a v3 bundle is laid over it")
	catalog._bundled_version[FAKE] = 7
	_check(not catalog._overlay_wanted(FAKE), "a pack older than the bundle is ignored")
	_check(catalog.installed_version(FAKE) == 7, "...and the bundle's version counts")
	catalog._bundled_version[FAKE] = 3
	fake.version = 6
	catalog._mounted[FAKE] = true
	_check(not catalog.needs_download(FAKE), "in use this session: waits for a restart")
	_check(not catalog.updates_available().has(FAKE) and catalog.updates_available(true).has(FAKE), "in use: only with include_mounted")
	catalog._mounted.erase(FAKE)
	DirAccess.remove_absolute(catalog._pack_path(FAKE))
	catalog._games_by_id.erase(FAKE)
	catalog._bundled.erase(FAKE)
	catalog._pc_overlay = false

	# ---- 2. a real pack
	var src := ProjectSettings.globalize_path("res://builds/packs/turned.pck")
	if not FileAccess.file_exists(src):
		print("skip: builds/packs/turned.pck missing (run hub.py export turned)")
	else:
		var dst := "user://zz_test_overlay.pck"
		var error: String = catalog.write_overlay(src, dst)
		_check(error == "", "write_overlay: " + error)
		var all := _list(src)
		var kept := _list(dst)
		_check(all.size() > 100 and kept.size() > 100 and kept.size() < all.size(), "kept %d of %d entries" % [kept.size(), all.size()])
		for p in ["project.binary", ".godot/global_script_class_cache.cfg"]:
			_check(all.has(p) and not kept.has(p), "drops " + p)
		_check(kept.has(".godot/uid_cache.bin"), "keeps uid_cache.bin")
		for p in kept:
			_check(p.begins_with("games/turned/") or p.begins_with(".godot/") or p.begins_with("scenes/games/turned/") \
				or p.begins_with("scripts/games/turned/") or p.begins_with("media/common/"), "game-owned entry: " + p)
		var shared := 0
		for p in all:
			if p.begins_with("media/common/") and p.ends_with(".import"):
				shared += 1
				_check(not kept.has(p), "shared media the build has stays the build's: " + p)
		_check(shared > 0, "pack carries shared media (test is meaningful)")
		var classes_before := ProjectSettings.get_global_class_list().size()
		_check(ProjectSettings.load_resource_pack(dst, true), "overlay mounts with replace_files")
		_check(ProjectSettings.get_global_class_list().size() == classes_before, "global classes untouched")
		var scene = load(catalog.get_game("turned").scene)
		_check(scene is PackedScene, "Turned's scene loads from the overlay")
		DirAccess.remove_absolute(dst)

	# restore
	TranslationServer.set_locale(locale)
	if versions_backup == null:
		DirAccess.remove_absolute(vpath)
	else:
		var w := FileAccess.open(vpath, FileAccess.WRITE)
		w.store_buffer(versions_backup)
		w.close()
	print("test_pc_overlay: %s" % ("OK" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)

## The paths in a pack's directory (format 3/4).
func _list(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	f.seek(32)
	f.seek(f.get_64())
	for i in f.get_32():
		var raw := f.get_buffer(f.get_32())
		var nul := raw.find(0)
		out.append((raw.slice(0, nul) if nul >= 0 else raw).get_string_from_utf8())
		f.seek(f.get_position() + 36)
	return out
