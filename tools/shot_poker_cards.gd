extends SceneTree

## Draws every Poker card (all 52, the back, an empty slot) in the current art
## and look at three sizes and saves pictures, to check cards without a phone.
## Needs a window (not --headless):
##   godot --path . --resolution 540x960 --script res://tools/shot_poker_cards.gd -- <out_dir> [classic|voodoo] [four]
## Output: <look>_cards_small.png (every card), <look>_cards_big.png (hero and board sizes).

const Cards = preload("res://scripts/games/video_poker/video_poker_cards.gd")
const Look = preload("res://scripts/games/video_poker/video_poker_look.gd")

var pane: Control
var mode := "small"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <out_dir> [classic|voodoo] [four]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(args[0])
	Cards.four_color = "four" in args
	_run(args[0], args[1] if args.size() > 1 and args[1] != "four" else "")

func _run(out_dir: String, only: String) -> void:
	for i in 3:
		await process_frame
	pane = Control.new()
	pane.set_anchors_preset(Control.PRESET_FULL_RECT)
	pane.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pane.draw.connect(_draw)
	root.add_child(pane)
	for look in ["classic", "voodoo"]:
		if only != "" and only != look:
			continue
		Look.set_skin(look)
		for m in ["small", "big"]:
			mode = m
			pane.queue_redraw()
			for i in 3:
				await process_frame
			root.get_texture().get_image().save_png(out_dir.path_join("%s_cards_%s.png" % [look, m]))
			print("SHOT ", look, "_cards_", m)
	quit()

func _draw() -> void:
	pane.draw_rect(Rect2(Vector2.ZERO, pane.size), Look.c("felt"))
	if mode == "small":
		var w := (pane.size.x - 14.0) / 13.0 - 4.0
		var h := w * 1.42
		for s in 4:
			for r in 13:
				var card: int = s * 13 + r
				Cards.draw_card(pane, Rect2(7 + r * (w + 4), 10 + s * (h + 8), w, h), card)
		var y := 10 + 4 * (h + 8)
		Cards.draw_card(pane, Rect2(7, y, w, h), 0, false)
		Cards.draw_card(pane, Rect2(7 + (w + 4), y, w, h), -1)
		Cards.draw_card(pane, Rect2(7 + 2 * (w + 4), y, w, h), 12, true, true)
		Cards.draw_card(pane, Rect2(7 + 3 * (w + 4), y, w, h), 20, true, false, true)
	else:
		var big := 150.0
		var picks := [0, 12, 13 + 11, 26 + 9, 39 + 6]
		for i in picks.size():
			Cards.draw_card(pane, Rect2(10 + i * (big * 0.66 + 6), 10, big * 0.66, big * 0.66 * 1.42), picks[i])
		var mid := 96.0
		var picks2 := [3, 13 + 8, 26 + 12, 39, 5, 13 + 9, 26 + 10, 11]
		for i in picks2.size():
			Cards.draw_card(pane, Rect2(10 + (i % 5) * (mid + 8), 160 + (i / 5) * (mid * 1.42 + 8), mid, mid * 1.42), picks2[i])
		Cards.draw_card(pane, Rect2(10, 470, 150, 213), 25)
		Cards.draw_card(pane, Rect2(180, 470, 150, 213), 13 + 12)
		Cards.draw_card(pane, Rect2(350, 470, 150, 213), 0, false)
