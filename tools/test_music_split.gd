extends SceneTree

## Headless test: hub music and game music never mix (STANDARDS §10, owner 2026-11-20).
##   godot --headless --path . --script res://tools/test_music_split.gd
## Hub screen -> hub track; Beached / Ink Ninja -> the hub track is gone within HUB_FADE and the
## game plays only its own files; back in the hub -> the same hub track resumes; a game asking
## the shared library never gets the hub's track; nobody can ask for the "hub" style.

const HUB_SCENE := "res://scenes/hub/options.tscn"
const HUB_DIR := "res://media/hub/music/"

var fails := 0
var M: Node

func _initialize() -> void:
	_run()

func ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _go(path: String) -> void:
	change_scene_to_file(path)
	await _frames(12)

func _hub_audible() -> bool:
	for p in M._players:
		if p.playing and p.stream and p.stream.resource_path.begins_with(HUB_DIR):
			return true
	return false

## What the intro film's end does: the Landing's music.
func scene_by_id_landing() -> void:
	if current_scene and current_scene.has_method("_menu_music"):
		current_scene._menu_music()

func _run() -> void:
	await process_frame
	M = root.get_node("Music")

	await _go(HUB_SCENE)
	ok(M._style == M.HUB_STYLE and M.is_playing(), "a hub screen plays the hub's own music (style %s)" % M._style)
	ok(_hub_audible(), "the hub track is a file from res://media/hub/music/hub/")
	var hub_key: String = M._key

	await _go("res://scenes/games/wilson/wilson.tscn")
	ok(M._style != M.HUB_STYLE, "Beached: the hub style is gone (style %s)" % M._style)
	ok(M._key.begins_with("file:res://games/wilson/music/"), "Beached plays its own track (%s)" % M._key)
	ok(not M._hub_resume.is_empty(), "the hub's place is remembered")
	await create_timer(M.HUB_FADE + 0.3).timeout
	ok(not _hub_audible(), "Beached: no hub track playing after HUB_FADE")

	await _go(HUB_SCENE)
	ok(M._key == hub_key, "back in the hub: the same hub track resumes (%s)" % M._key)

	await _go("res://scenes/games/ink_ninja/ink_ninja.tscn")
	await create_timer(M.HUB_FADE + 0.3).timeout
	ok(not _hub_audible(), "Ink Ninja: no hub track playing")
	ok(M._style != M.HUB_STYLE, "Ink Ninja: not the hub style (%s)" % M._key)
	# The film plays first; then the Landing's dojo theme.
	scene_by_id_landing()
	await create_timer(0.3).timeout
	ok(M._key.begins_with("file:res://games/ink_ninja/music/"), "Ink Ninja Landing plays its own track (%s)" % M._key)

	# A game that still uses the shared library: never the hub's track.
	await _go(HUB_SCENE)
	var game := Node.new()
	current_scene.add_child(game)
	M.play("calm", game)
	await create_timer(M.HUB_FADE + 0.3).timeout
	ok(M._style == "calm" and not _hub_audible(), "a library game gets library music, not the hub's")
	M.play(M.HUB_STYLE, game)
	ok(M._style != M.HUB_STYLE, "no game can ask for the hub style")
	game.queue_free()

	print("music split: %d failure(s)" % fails)
	quit(fails)
