extends SceneTree

## Contact sheet of the code-drawn game art (logo + teaser per game). Needs a window, not --headless:
##   godot --path . --resolution 1080x720 --script res://tools/shot_art.gd -- <out_dir> [id,id,...]
## No ids = every game with code-drawn art (keep sheets small: pass a category's ids). Writes <out_dir>/art_sheet.png.

const GameArt = preload("res://scripts/common/game_art.gd")
const GameLogos = preload("res://scripts/common/game_logos.gd")
const GameLogosArcade = preload("res://scripts/common/game_logos_arcade.gd")
const GameLogosPuzzle = preload("res://scripts/common/game_logos_puzzle.gd")
const GameTeasersPuzzle = preload("res://scripts/common/game_teasers_puzzle.gd")
const GameLogosCards = preload("res://scripts/common/game_logos_cards.gd")
const CELL := Vector2(360, 160)
const COLS := 3

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shots"
	var ids: Array = Array(args[1].split(",", false)) if args.size() > 1 else (GameLogos.IDS + GameLogosArcade.IDS + GameTeasersPuzzle.IDS + GameLogosCards.IDS)
	DirAccess.make_dir_recursive_absolute(out)
	var rows := ceili(ids.size() / float(COLS))
	var sheet := Vector2i(int(CELL.x) * COLS, int(CELL.y) * rows)
	root.size = sheet
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.12)
	bg.size = Vector2(sheet)
	root.add_child(bg)
	for i in ids.size():
		var id: String = ids[i]
		var o := Vector2((i % COLS) * CELL.x, (i / COLS) * CELL.y)
		var logo := Control.new()
		logo.position = o + Vector2(8, 26)
		logo.size = Vector2(100, 100)
		logo.draw.connect(GameArt.draw_logo.bind(logo, id))
		root.add_child(logo)
		var teaser := Control.new()
		teaser.position = o + Vector2(116, 8)
		teaser.size = Vector2(240, 135)
		teaser.draw.connect(GameArt.draw_teaser.bind(teaser, id))
		root.add_child(teaser)
		var l := Label.new()
		l.text = id
		l.position = o + Vector2(8, 130)
		root.add_child(l)
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/art_sheet.png")
	quit()
