extends Control

const Version = preload("res://scripts/common/version.gd")
const Orientation = preload("res://scripts/common/orientation.gd")

## Game catalog, grouped into sections. Add an entry whenever a new game scene is
## dropped in. "scene" empty string means "coming soon" (tile shows but is disabled).
const CATEGORIES: Array = [
	{
		"name": "Puzzle & Board",
		"color": Color(0.16, 0.45, 0.4),
		"games": [
			{"title": "Sudoku", "scene": "res://scenes/games/sudoku/sudoku.tscn"},
			{"title": "Minesweeper", "scene": ""},
			{"title": "Tic-Tac-Toe", "scene": "res://scenes/games/tictactoe/tictactoe.tscn"},
			{"title": "Connect Four", "scene": "res://scenes/games/connect4/connect4.tscn"},
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
			{"title": "2048", "scene": "res://scenes/games/g2048/g2048.tscn"},
			{"title": "Kakuro", "scene": ""},
			{"title": "Picross / Nonogram", "scene": ""},
			{"title": "Mastermind", "scene": ""},
			{"title": "Tower of Hanoi", "scene": ""},
			{"title": "KenKen", "scene": ""},
		],
	},
	{
		"name": "Cards",
		"color": Color(0.2, 0.3, 0.5),
		"games": [
			{"title": "Solitaire", "scene": "res://scenes/games/solitaire/solitaire.tscn"},
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
		"color": Color(0.5, 0.2, 0.45),
		"games": [
			{"title": "Geometry Wars", "scene": "res://scenes/games/geometry_wars/geometry_wars.tscn"},
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
		"color": Color(0.5, 0.4, 0.15),
		"games": [
			{"title": "Yahtzee", "scene": ""},
			{"title": "Farkle", "scene": ""},
			{"title": "Liar's Dice", "scene": ""},
		],
	},
	{
		"name": "Drinking Games",
		"color": Color(0.6, 0.2, 0.25),
		"games": [
			{"title": "Kings Cup", "scene": ""},
			{"title": "Higher or Lower", "scene": ""},
		],
	},
	{
		"name": "Other",
		"color": Color(0.35, 0.35, 0.4),
		"games": [
			{"title": "Twister Spinner", "scene": ""},
		],
	},
]

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

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 20)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.add_child(list)
	scroll.add_child(margin)

	for category in CATEGORIES:
		list.add_child(_make_section_header(category.name))
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 10)
		list.add_child(section)
		for game in category.games:
			section.add_child(_make_tile(game, category.color))

func _make_section_header(name: String) -> Label:
	var l := Label.new()
	l.text = name
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	return l

func _make_tile(game: Dictionary, accent: Color) -> Control:
	var available: bool = game.scene != ""

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

	if not available:
		var soon := Label.new()
		soon.text = "Coming soon"
		soon.add_theme_font_size_override("font_size", 13)
		soon.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		soon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(soon)

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.disabled = not available
	button.focus_mode = Control.FOCUS_NONE
	if available:
		button.pressed.connect(func(): _launch(game.scene))
	panel.add_child(button)

	return panel

func _launch(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
