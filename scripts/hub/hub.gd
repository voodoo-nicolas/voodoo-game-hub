extends Control

const Version = preload("res://scripts/common/version.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")

const RELEASE_BASE := "https://github.com/voodoo-nicolas/voodoo-game-hub/releases/download/packs-v1/"
const LATEST_RELEASE_API := "https://api.github.com/repos/voodoo-nicolas/voodoo-game-hub/releases/latest"
const MANIFEST_URL := "https://raw.githubusercontent.com/voodoo-nicolas/voodoo-game-hub/master/manifest.json"
const PACK_VERSIONS_PATH := "user://pack_versions.json"

## Game catalog, grouped into sections. "scene" empty string with no "pack_id" means
## "coming soon" (tile disabled). A game with "pack_id" is downloadable-on-demand: its
## code/scenes live in a separately-hosted .pck, not bundled into the hub app itself.
## The tile shows "Download" until user://packs/<pack_id>.pck exists, at which point it
## mounts on demand and plays like any other game.
const CATEGORIES: Array = [
	{
		"name": "Puzzle & Board",
		"icon": "🧩",
		"color": Color(0.16, 0.45, 0.4),
		"games": [
			{"title": "Sudoku", "icon": "🔢", "pack_id": "sudoku", "scene": "res://scenes/games/sudoku/sudoku.tscn"},
			{"title": "Minesweeper", "icon": "💣", "scene": ""},
			{"title": "Tic-Tac-Toe", "icon": "⭕", "pack_id": "tictactoe", "scene": "res://scenes/games/tictactoe/tictactoe.tscn"},
			{"title": "Connect Four", "icon": "🔴", "pack_id": "connect4", "scene": "res://scenes/games/connect4/connect4.tscn"},
			{"title": "Checkers", "icon": "⚫", "scene": ""},
			{"title": "Reversi / Othello", "icon": "⚪", "scene": ""},
			{"title": "Battleship", "icon": "🚢", "scene": ""},
			{"title": "Dots and Boxes", "icon": "▫️", "scene": ""},
			{"title": "Mancala", "icon": "🌰", "scene": ""},
			{"title": "Backgammon", "icon": "🎲", "scene": ""},
			{"title": "Nine Men's Morris", "icon": "✳️", "scene": ""},
			{"title": "Peg Solitaire", "icon": "📌", "scene": ""},
			{"title": "Lights Out", "icon": "💡", "scene": ""},
			{"title": "Sokoban", "icon": "📦", "scene": ""},
			{"title": "Sliding 15-Puzzle", "icon": "🔲", "scene": ""},
			{"title": "2048", "icon": "🔷", "pack_id": "g2048", "scene": "res://scenes/games/g2048/g2048.tscn"},
			{"title": "Kakuro", "icon": "➗", "scene": ""},
			{"title": "Picross / Nonogram", "icon": "🖼️", "scene": ""},
			{"title": "Mastermind", "icon": "🧠", "scene": ""},
			{"title": "Tower of Hanoi", "icon": "🗼", "scene": ""},
			{"title": "KenKen", "icon": "🔟", "scene": ""},
		],
	},
	{
		"name": "Cards",
		"icon": "🃏",
		"color": Color(0.2, 0.3, 0.5),
		"games": [
			{"title": "Solitaire", "icon": "🂡", "pack_id": "solitaire", "scene": "res://scenes/games/solitaire/solitaire.tscn"},
			{"title": "Blackjack", "icon": "🂱", "scene": ""},
			{"title": "War", "icon": "⚔️", "scene": ""},
			{"title": "Crazy Eights", "icon": "8️⃣", "scene": ""},
			{"title": "Go Fish", "icon": "🐟", "scene": ""},
			{"title": "Rummy", "icon": "🃁", "scene": ""},
			{"title": "Spider Solitaire", "icon": "🕷️", "scene": ""},
			{"title": "FreeCell", "icon": "🆓", "scene": ""},
			{"title": "Pyramid Solitaire", "icon": "🔺", "scene": ""},
			{"title": "Speed / Spit", "icon": "⚡", "scene": ""},
			{"title": "Memory Match", "icon": "🧠", "pack_id": "memory", "scene": "res://scenes/games/memory/memory.tscn"},
		],
	},
	{
		"name": "Word",
		"icon": "🔤",
		"color": Color(0.45, 0.35, 0.15),
		"games": [
			{"title": "Hangman", "icon": "💀", "pack_id": "hangman", "scene": "res://scenes/games/hangman/hangman.tscn"},
			{"title": "Wordle", "icon": "🟩", "scene": ""},
			{"title": "Word Search", "icon": "🔍", "scene": ""},
			{"title": "Crossword", "icon": "📝", "scene": ""},
			{"title": "Anagrams", "icon": "🔀", "scene": ""},
			{"title": "Boggle", "icon": "🎲", "scene": ""},
		],
	},
	{
		"name": "Arcade",
		"icon": "🕹️",
		"color": Color(0.5, 0.2, 0.45),
		"games": [
			{"title": "Geometry Wars", "icon": "🚀", "pack_id": "geometry_wars", "scene": "res://scenes/games/geometry_wars/geometry_wars.tscn"},
			{"title": "Snake", "icon": "🐍", "scene": ""},
			{"title": "Tetris", "icon": "🧱", "scene": ""},
			{"title": "Pong", "icon": "🏓", "scene": ""},
			{"title": "Breakout", "icon": "🎯", "scene": ""},
			{"title": "Flappy Bird", "icon": "🐦", "scene": ""},
			{"title": "Space Invaders", "icon": "👾", "scene": ""},
			{"title": "Frogger", "icon": "🐸", "scene": ""},
			{"title": "Match-3", "icon": "💎", "scene": ""},
			{"title": "Simon", "icon": "🎵", "pack_id": "simon", "scene": "res://scenes/games/simon/simon.tscn"},
			{"title": "Whack-a-Mole", "icon": "🔨", "scene": ""},
			{"title": "Reaction Test", "icon": "⏱️", "scene": ""},
		],
	},
	{
		"name": "Dice & Party",
		"icon": "🎲",
		"color": Color(0.5, 0.4, 0.15),
		"games": [
			{"title": "Yahtzee", "icon": "🎲", "scene": ""},
			{"title": "Farkle", "icon": "🎯", "scene": ""},
			{"title": "Liar's Dice", "icon": "🤥", "scene": ""},
		],
	},
	{
		"name": "Drinking Games",
		"icon": "🍹",
		"color": Color(0.6, 0.2, 0.25),
		"games": [
			{"title": "Kings Cup", "icon": "👑", "pack_id": "kings_cup", "scene": "res://scenes/games/kings_cup/kings_cup.tscn"},
			{"title": "Red or Black", "icon": "🎴", "pack_id": "red_or_black", "scene": "res://scenes/games/red_or_black/red_or_black.tscn"},
		],
	},
	{
		"name": "Other",
		"icon": "🎯",
		"color": Color(0.35, 0.35, 0.4),
		"games": [
			{"title": "Twister Spinner", "icon": "🌀", "scene": ""},
		],
	},
]

const NEON_GREEN := Color(0.15, 1.0, 0.55)
const NEON_GREEN_DIM := Color(0.08, 0.45, 0.28)
const BG_BLACK := Color(0.015, 0.035, 0.03)

var list_container: VBoxContainer
var expanded_index: int = -1

func _ready() -> void:
	Orientation.lock_portrait()
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var bg := ColorRect.new()
	bg.color = BG_BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)

	var header := MarginContainer.new()
	header.add_theme_constant_override("margin_top", 36)
	header.add_theme_constant_override("margin_bottom", 20)
	header.add_theme_constant_override("margin_left", 14)
	header.add_theme_constant_override("margin_right", 14)
	root.add_child(header)

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 2)
	header.add_child(header_box)

	var title := Label.new()
	title.text = "VOODOO"
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", NEON_GREEN)
	title.add_theme_color_override("font_outline_color", Color(NEON_GREEN.r, NEON_GREEN.g, NEON_GREEN.b, 0.5))
	title.add_theme_constant_override("outline_size", 10)
	header_box.add_child(title)

	var version_label := Label.new()
	version_label.text = "v%s (build %d)" % [Version.VERSION, Version.BUILD_NUMBER]
	version_label.add_theme_font_size_override("font_size", 13)
	version_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.5))
	header_box.add_child(version_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	list_container = VBoxContainer.new()
	list_container.add_theme_constant_override("separation", 14)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.add_child(list_container)
	scroll.add_child(margin)

	_rebuild_list()
	_check_for_update()

## Shared neon-glow panel style: bright border + a blurred shadow of the same hue
## behind it (Godot's StyleBoxFlat shadow is a real soft blur, not a flat drop shadow),
## which is what actually reads as "glowing" rather than just "outlined."
func _neon_style(fill: Color, border: Color, glow_strength: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = border
	sb.shadow_color = Color(border.r, border.g, border.b, glow_strength)
	sb.shadow_size = 10
	return sb

## Accordion: rebuilds the whole category list from scratch each time it's toggled.
## Only expanded_index's games are shown, so opening one category collapses any other.
func _rebuild_list() -> void:
	for child in list_container.get_children():
		list_container.remove_child(child)
		child.free()

	for i in range(CATEGORIES.size()):
		var category: Dictionary = CATEGORIES[i]
		list_container.add_child(_make_section_header(category, i))
		if expanded_index == i:
			var section := VBoxContainer.new()
			section.add_theme_constant_override("separation", 10)
			var section_margin := MarginContainer.new()
			section_margin.add_theme_constant_override("margin_top", 10)
			section_margin.add_child(section)
			list_container.add_child(section_margin)
			for game in category.games:
				section.add_child(_make_tile(game, category.color))

func _toggle_category(index: int) -> void:
	expanded_index = -1 if expanded_index == index else index
	_rebuild_list()

func _make_section_header(category: Dictionary, index: int) -> Control:
	var is_open: bool = expanded_index == index
	var available_count := 0
	for game in category.games:
		if game.scene != "":
			available_count += 1

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 96)
	var sb: StyleBoxFlat
	if is_open:
		sb = _neon_style(Color(category.color.r, category.color.g, category.color.b, 0.35), NEON_GREEN, 0.9)
	else:
		sb = _neon_style(Color(0.06, 0.1, 0.09), NEON_GREEN_DIM, 0.35)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(row)

	var icon_label := Label.new()
	icon_label.text = category.icon
	icon_label.add_theme_font_size_override("font_size", 42)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon_label)

	var name_label := Label.new()
	name_label.text = category.name.to_upper()
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1) if is_open else NEON_GREEN)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)

	var count_label := Label.new()
	count_label.text = "%d/%d" % [available_count, category.games.size()]
	count_label.add_theme_font_size_override("font_size", 17)
	count_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.9) if is_open else Color(0.5, 0.7, 0.6))
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count_label)

	var chevron := Label.new()
	chevron.text = "▾" if is_open else "▸"
	chevron.add_theme_font_size_override("font_size", 28)
	chevron.add_theme_color_override("font_color", Color(1, 1, 1) if is_open else NEON_GREEN)
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(chevron)

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_toggle_category.bind(index))
	panel.add_child(button)

	return panel

func _make_tile(game: Dictionary, accent: Color) -> Control:
	var has_pack: bool = game.has("pack_id")
	var bundled: bool = not has_pack and game.scene != ""
	var downloaded: bool = has_pack and _is_downloaded(game.pack_id)
	var playable: bool = bundled or downloaded
	var available: bool = bundled or has_pack  # tile is interactive either way

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 108)
	var sb: StyleBoxFlat
	if available:
		sb = _neon_style(Color(accent.r, accent.g, accent.b, 0.4), NEON_GREEN, 0.55)
	else:
		sb = _neon_style(Color(0.05, 0.06, 0.06), Color(0.25, 0.3, 0.28), 0.0)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(row)

	var icon_label := Label.new()
	icon_label.text = game.get("icon", "🎮")
	icon_label.add_theme_font_size_override("font_size", 36)
	icon_label.modulate = Color(1, 1, 1) if available else Color(1, 1, 1, 0.35)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon_label)

	var label := Label.new()
	label.text = game.title
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 1, 1) if available else Color(0.5, 0.55, 0.53))
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(label)

	var tag := Label.new()
	tag.add_theme_font_size_override("font_size", 16)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not available:
		tag.text = "Coming soon"
		tag.add_theme_color_override("font_color", Color(0.5, 0.55, 0.53))
	elif has_pack and not downloaded:
		tag.text = "⬇ Download"
		tag.add_theme_color_override("font_color", NEON_GREEN)
	row.add_child(tag)

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.disabled = not available
	button.focus_mode = Control.FOCUS_NONE
	if has_pack:
		button.pressed.connect(func(): _check_and_launch(game))
	elif bundled:
		button.pressed.connect(func(): _launch(game))
	panel.add_child(button)

	return panel

## ---------- app self-update check ----------

## Fires once per hub load; silently does nothing on failure (offline, rate-limited,
## etc.) so a flaky network never blocks using the app.
func _check_for_update() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		_on_update_check_completed(result, response_code, body)
		http.queue_free()
	)
	var headers := ["User-Agent: Voodoo-App"]
	http.request(LATEST_RELEASE_API, headers)

func _on_update_check_completed(result: int, response_code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("tag_name"):
		return

	var remote_version: String = str(parsed.tag_name).lstrip("v")
	if not _is_newer_version(remote_version, Version.VERSION):
		return

	var apk_url := ""
	for asset in parsed.get("assets", []):
		var name: String = str(asset.get("name", ""))
		if name.ends_with(".apk"):
			apk_url = str(asset.get("browser_download_url", ""))
			break
	if apk_url == "":
		return

	_show_update_dialog(remote_version, apk_url)

## Compares dotted version strings ("0.4.0" vs "0.3.0") numerically, segment by segment.
func _is_newer_version(remote: String, local: String) -> bool:
	var r: PackedStringArray = remote.split(".")
	var l: PackedStringArray = local.split(".")
	for i in range(max(r.size(), l.size())):
		var rv: int = int(r[i]) if i < r.size() else 0
		var lv: int = int(l[i]) if i < l.size() else 0
		if rv != lv:
			return rv > lv
	return false

func _show_update_dialog(remote_version: String, apk_url: String) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _neon_style(Color(0.06, 0.1, 0.09), NEON_GREEN, 0.7))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(260, 0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Update Available"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", NEON_GREEN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "v%s is out (you have v%s)" % [remote_version, Version.VERSION]
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.85, 0.82))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var update_btn := Button.new()
	update_btn.text = "Update Now"
	update_btn.custom_minimum_size = Vector2(200, 48)
	update_btn.pressed.connect(func():
		OS.shell_open(apk_url)
		overlay.queue_free()
	)
	box.add_child(update_btn)

	var later_btn := Button.new()
	later_btn.text = "Later"
	later_btn.custom_minimum_size = Vector2(200, 44)
	later_btn.pressed.connect(func(): overlay.queue_free())
	box.add_child(later_btn)

## ---------- download-on-demand ----------

func _packs_dir() -> String:
	if not DirAccess.dir_exists_absolute("user://packs"):
		DirAccess.make_dir_absolute("user://packs")
	return "user://packs"

func _local_pack_path(pack_id: String) -> String:
	return "%s/%s.pck" % [_packs_dir(), pack_id]

func _is_downloaded(pack_id: String) -> bool:
	return FileAccess.file_exists(_local_pack_path(pack_id))

func _local_pack_version(pack_id: String) -> int:
	var data = SaveUtil.read(PACK_VERSIONS_PATH)
	if data == null:
		return 0
	return int(data.get(pack_id, 0))

func _save_pack_version(pack_id: String, version: int) -> void:
	var data = SaveUtil.read(PACK_VERSIONS_PATH)
	if data == null:
		data = {}
	data[pack_id] = version
	SaveUtil.write(PACK_VERSIONS_PATH, data)

## Mounts a game's pack if needed. Returns true once the scene is actually loadable
## (whether it was already bundled, already mounted this session, or just mounted now).
func _ensure_mounted(game: Dictionary) -> bool:
	if ResourceLoader.exists(game.scene):
		return true
	if not game.has("pack_id") or not _is_downloaded(game.pack_id):
		return false
	ProjectSettings.load_resource_pack(_local_pack_path(game.pack_id))
	return ResourceLoader.exists(game.scene)

func _launch(game: Dictionary) -> void:
	if _ensure_mounted(game):
		get_tree().change_scene_to_file(game.scene)

## Entry point for every downloadable game tile. Always pings the manifest first
## (small, fast file) to decide: first-time download, silent re-download because a
## newer version is published, or just launch the copy already on disk. If the
## manifest is unreachable (offline) and the game is already downloaded, it just
## launches with what's local rather than blocking play on a network check.
func _check_and_launch(game: Dictionary) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		http.queue_free()
		var remote_version := -1
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			var parsed = JSON.parse_string(body.get_string_from_utf8())
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("games") and parsed.games.has(game.pack_id):
				remote_version = int(parsed.games[game.pack_id].get("version", 1))

		var local_version: int = _local_pack_version(game.pack_id)
		var downloaded: bool = _is_downloaded(game.pack_id)

		if not downloaded:
			_start_download(game, max(remote_version, 1))
		elif remote_version > local_version:
			_start_download(game, remote_version)
		else:
			_launch(game)
	)
	http.request(MANIFEST_URL)

func _start_download(game: Dictionary, version: int) -> void:
	var overlay := _build_download_overlay(game.title)
	add_child(overlay)

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		_on_download_completed(result, response_code, body, game, version, overlay, http)
	)

	var progress_bar: ProgressBar = overlay.get_meta("progress_bar")
	var poll_timer := Timer.new()
	poll_timer.wait_time = 0.1
	poll_timer.timeout.connect(func():
		if not is_instance_valid(http):
			poll_timer.queue_free()
			return
		var total: int = http.get_body_size()
		var downloaded: int = http.get_downloaded_bytes()
		if total > 0:
			progress_bar.value = (float(downloaded) / float(total)) * 100.0
	)
	overlay.add_child(poll_timer)
	poll_timer.start()

	var url: String = RELEASE_BASE + game.pack_id + ".pck"
	var err := http.request(url)
	if err != OK:
		_on_download_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray(), game, version, overlay, http)

func _on_download_completed(result: int, response_code: int, body: PackedByteArray, game: Dictionary, version: int, overlay: Control, http: HTTPRequest) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var status_label: Label = overlay.get_meta("status_label")
		status_label.text = "Download failed. Check your connection and try again."
		var retry_btn: Button = overlay.get_meta("retry_button")
		retry_btn.visible = true
		var progress_bar: ProgressBar = overlay.get_meta("progress_bar")
		progress_bar.visible = false
		return

	var f := FileAccess.open(_local_pack_path(game.pack_id), FileAccess.WRITE)
	f.store_buffer(body)
	f.close()
	_save_pack_version(game.pack_id, version)

	overlay.queue_free()
	_launch(game)

func _build_download_overlay(title: String) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.14, 0.18)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(260, 0)
	panel.add_child(box)

	var status_label := Label.new()
	status_label.text = "Downloading %s..." % title
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(1, 1, 1))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(status_label)

	var progress_bar := ProgressBar.new()
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	box.add_child(progress_bar)

	var retry_btn := Button.new()
	retry_btn.text = "Close"
	retry_btn.visible = false
	retry_btn.pressed.connect(func(): overlay.queue_free())
	box.add_child(retry_btn)

	overlay.set_meta("status_label", status_label)
	overlay.set_meta("progress_bar", progress_bar)
	overlay.set_meta("retry_button", retry_btn)
	return overlay
