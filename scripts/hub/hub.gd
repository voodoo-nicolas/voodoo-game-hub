extends Control

const Version = preload("res://scripts/common/version.gd")
const Orientation = preload("res://scripts/common/orientation.gd")

const RELEASE_BASE := "https://github.com/voodoo-nicolas/voodoo-game-hub/releases/download/packs-v1/"

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
			{"title": "Sudoku", "pack_id": "sudoku", "scene": "res://scenes/games/sudoku/sudoku.tscn"},
			{"title": "Minesweeper", "scene": ""},
			{"title": "Tic-Tac-Toe", "pack_id": "tictactoe", "scene": "res://scenes/games/tictactoe/tictactoe.tscn"},
			{"title": "Connect Four", "pack_id": "connect4", "scene": "res://scenes/games/connect4/connect4.tscn"},
			{"title": "Checkers", "scene": ""},
			{"title": "Reversi / Othello", "scene": ""},
			{"title": "Battleship", "scene": ""},
			{"title": "Dots and Boxes", "scene": ""},
			{"title": "Mancala", "scene": ""},
			{"title": "Backgammon", "scene": ""},
			{"title": "Nine Men's Morris", "scene": ""},
			{"title": "Peg Solitaire", "scene": ""},
			{"title": "Lights Out", "scene": ""},
			{"title": "Sokoban", "scene": ""},
			{"title": "Sliding 15-Puzzle", "scene": ""},
			{"title": "2048", "pack_id": "g2048", "scene": "res://scenes/games/g2048/g2048.tscn"},
			{"title": "Kakuro", "scene": ""},
			{"title": "Picross / Nonogram", "scene": ""},
			{"title": "Mastermind", "scene": ""},
			{"title": "Tower of Hanoi", "scene": ""},
			{"title": "KenKen", "scene": ""},
		],
	},
	{
		"name": "Cards",
		"icon": "🃏",
		"color": Color(0.2, 0.3, 0.5),
		"games": [
			{"title": "Solitaire", "pack_id": "solitaire", "scene": "res://scenes/games/solitaire/solitaire.tscn"},
			{"title": "Blackjack", "scene": ""},
			{"title": "War", "scene": ""},
			{"title": "Crazy Eights", "scene": ""},
			{"title": "Go Fish", "scene": ""},
			{"title": "Rummy", "scene": ""},
			{"title": "Spider Solitaire", "scene": ""},
			{"title": "FreeCell", "scene": ""},
			{"title": "Pyramid Solitaire", "scene": ""},
			{"title": "Speed / Spit", "scene": ""},
			{"title": "Memory Match", "scene": ""},
		],
	},
	{
		"name": "Word",
		"icon": "🔤",
		"color": Color(0.45, 0.35, 0.15),
		"games": [
			{"title": "Hangman", "scene": ""},
			{"title": "Wordle", "scene": ""},
			{"title": "Word Search", "scene": ""},
			{"title": "Crossword", "scene": ""},
			{"title": "Anagrams", "scene": ""},
			{"title": "Boggle", "scene": ""},
		],
	},
	{
		"name": "Arcade",
		"icon": "🕹️",
		"color": Color(0.5, 0.2, 0.45),
		"games": [
			{"title": "Geometry Wars", "pack_id": "geometry_wars", "scene": "res://scenes/games/geometry_wars/geometry_wars.tscn"},
			{"title": "Snake", "scene": ""},
			{"title": "Tetris", "scene": ""},
			{"title": "Pong", "scene": ""},
			{"title": "Breakout", "scene": ""},
			{"title": "Flappy Bird", "scene": ""},
			{"title": "Space Invaders", "scene": ""},
			{"title": "Frogger", "scene": ""},
			{"title": "Match-3", "scene": ""},
			{"title": "Simon", "scene": ""},
			{"title": "Whack-a-Mole", "scene": ""},
			{"title": "Reaction Test", "scene": ""},
		],
	},
	{
		"name": "Dice & Party",
		"icon": "🎲",
		"color": Color(0.5, 0.4, 0.15),
		"games": [
			{"title": "Yahtzee", "scene": ""},
			{"title": "Farkle", "scene": ""},
			{"title": "Liar's Dice", "scene": ""},
		],
	},
	{
		"name": "Drinking Games",
		"icon": "🍹",
		"color": Color(0.6, 0.2, 0.25),
		"games": [
			{"title": "Kings Cup", "scene": ""},
			{"title": "Higher or Lower", "scene": ""},
		],
	},
	{
		"name": "Other",
		"icon": "🎯",
		"color": Color(0.35, 0.35, 0.4),
		"games": [
			{"title": "Twister Spinner", "scene": ""},
		],
	},
]

var list_container: VBoxContainer
var expanded_index: int = -1

func _ready() -> void:
	Orientation.lock_portrait()
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)

	var header := MarginContainer.new()
	header.add_theme_constant_override("margin_top", 40)
	header.add_theme_constant_override("margin_bottom", 20)
	header.add_theme_constant_override("margin_left", 24)
	header.add_theme_constant_override("margin_right", 24)
	root.add_child(header)

	var title := Label.new()
	title.text = "Voodoo"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	header.add_child(title)

	var version_label := Label.new()
	version_label.text = "v%s (build %d)" % [Version.VERSION, Version.BUILD_NUMBER]
	version_label.add_theme_font_size_override("font_size", 12)
	version_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.56))
	header.add_child(version_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	list_container = VBoxContainer.new()
	list_container.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.add_child(list_container)
	scroll.add_child(margin)

	_rebuild_list()

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
	panel.custom_minimum_size = Vector2(0, 56)
	var sb := StyleBoxFlat.new()
	sb.bg_color = category.color if is_open else Color(0.16, 0.16, 0.2)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(row)

	var icon_label := Label.new()
	icon_label.text = category.icon
	icon_label.add_theme_font_size_override("font_size", 22)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon_label)

	var name_label := Label.new()
	name_label.text = category.name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)

	var count_label := Label.new()
	count_label.text = "%d/%d" % [available_count, category.games.size()]
	count_label.add_theme_font_size_override("font_size", 13)
	count_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85) if is_open else Color(0.6, 0.6, 0.65))
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count_label)

	var chevron := Label.new()
	chevron.text = "▾" if is_open else "▸"
	chevron.add_theme_font_size_override("font_size", 18)
	chevron.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95) if is_open else Color(0.6, 0.6, 0.65))
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
	panel.custom_minimum_size = Vector2(0, 68)
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent if available else Color(0.16, 0.16, 0.18)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(row)

	var label := Label.new()
	label.text = game.title
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 1) if available else Color(0.55, 0.55, 0.55))
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var tag := Label.new()
	tag.add_theme_font_size_override("font_size", 13)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not available:
		tag.text = "Coming soon"
		tag.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	elif has_pack and not downloaded:
		tag.text = "⬇ Download"
		tag.add_theme_color_override("font_color", Color(1, 1, 1))
	row.add_child(tag)

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.disabled = not available
	button.focus_mode = Control.FOCUS_NONE
	if playable:
		button.pressed.connect(func(): _launch(game))
	elif has_pack:
		button.pressed.connect(func(): _start_download(game))
	panel.add_child(button)

	return panel

## ---------- download-on-demand ----------

func _packs_dir() -> String:
	if not DirAccess.dir_exists_absolute("user://packs"):
		DirAccess.make_dir_absolute("user://packs")
	return "user://packs"

func _local_pack_path(pack_id: String) -> String:
	return "%s/%s.pck" % [_packs_dir(), pack_id]

func _is_downloaded(pack_id: String) -> bool:
	return FileAccess.file_exists(_local_pack_path(pack_id))

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

func _start_download(game: Dictionary) -> void:
	var overlay := _build_download_overlay(game.title)
	add_child(overlay)

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		_on_download_completed(result, response_code, body, game, overlay, http)
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
		_on_download_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray(), game, overlay, http)

func _on_download_completed(result: int, response_code: int, body: PackedByteArray, game: Dictionary, overlay: Control, http: HTTPRequest) -> void:
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
