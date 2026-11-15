extends SceneTree
# Thrust (hover_duel) quick renders: one battle, the Hangar card, or all ship designs.
# godot --path . --resolution 1280x720 -s tools/shot_hover_duel_hangar.gd -- <theme|hangar|ships> <out.png>
# Does not save the Hangar; a battle may leave a hover_duel save (Resume).
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var theme: String = args[0] if args.size() > 0 else "valley"
	var out: String = args[1] if args.size() > 1 else "user://thrust.png"
	root.size = Vector2i(1280, 720)
	var g = load("res://scenes/games/hover_duel/hover_duel.tscn").instantiate()
	root.add_child(g)
	for i in 5: await process_frame
	if theme == "ships":
		var sheet := Control.new()
		sheet.size = Vector2(1280, 720)
		sheet.draw.connect(func():
			sheet.draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.07, 0.1))
			var E = g.E
			for i in E.HANGAR.size():
				var at := Vector2(160 + (i % 6) * 192, 200 + (i / 6) * 330)
				g._draw_craft(sheet, at, -PI / 2.0, 1.5, g._player_colors()[i % 2], 0.4, false, false, false, 0.6, E.HANGAR[i])
				sheet.draw_string(ThemeDB.fallback_font, at + Vector2(-80, 150), E.CRAFTS[E.HANGAR[i]].name, HORIZONTAL_ALIGNMENT_CENTER, 160, 22))
		root.add_child(sheet)
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out)
		print("saved ", out)
		quit()
		return
	if theme == "hangar":
		g.hangar.credits = 2600
		g.hangar.owned = ["skimmer", "viper"]
		g.hangar.ups = {"skimmer": {"attack": 2, "speed": 1}}
		g._open_hangar()
		for i in 10: await process_frame
		var sc = g.home.get_viewport().gui_get_focus_owner()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out)
		print("saved ", out)
		quit()
		return
	g.engine.reset(theme, 1207, ["skimmer", "gnat"], [-1, 0])
	g._begin()
	if g.home: g.home.visible = false
	g.size = Vector2(1280, 720)
	for c in g.engine.crafts:
		c.thrust = 1.0
	g.cam = g.engine.crafts[0].p
	g.zoom = 1.0
	for i in 20:
		for c in g.engine.crafts: c.thrust = 1.0
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
