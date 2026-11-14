extends Control

## Hover Duel: two hovercraft, one map, one winner. Top-down 1v1 shooter
## over grass, hills, rivers, sea and rock (an original game; the owner's
## memory of an old 1v1 hover-ship game was the spark, nothing is copied).
## Modes: Campaign (12 rivals over 6 lands), vs Computer (3 levels),
## 2 Players on one phone held sideways (each player gets one half).
##
## Landing menu style: S3 Rail List (docs/MENU_STYLES.md): gritty action,
## and not one of the last two games' styles (Bridge Master slabs, Tilt Maze cinema).

const E = preload("res://scripts/games/hover_duel/hover_duel_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const MenuStyles = preload("res://scripts/games/hover_duel/menu_styles.gd")
const HomeKit = preload("res://scripts/games/hover_duel/home_kit.gd")
const SoundLib = preload("res://scripts/games/hover_duel/sound_lib.gd")
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/hover_duel/hover_duel_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://hover_duel_save.json"
const CAMPAIGN_PATH := "user://hover_duel_campaign.json"
const PAD_PATH := "res://scripts/common/pad/pad_controller.gd"
const Goals = preload("res://scripts/games/hover_duel/hover_duel_goals.gd")
const Story = preload("res://scripts/games/hover_duel/hover_duel_story.gd")
const TERRAIN_SHADER = preload("res://scripts/games/hover_duel/hover_duel_terrain.gdshader")
const LANDING_ART := "res://games/hover_duel/landing_bg.jpg"

const LEVELS := ["Easy", "Normal", "Hard"]
const VS_THEMES := ["valley", "isles", "highlands", "desert", "glacier", "volcano"]
const COLORS := {
	"classic": [Color("2f7dff"), Color("ff4a3a")],
	"voodoo": [Color("29e6ff"), Color("ff2bd6")],
}
## Terrain colours per theme: [deep liquid, shallow liquid, shore, low, high, rock]
const PALETTE := {
	"valley": [Color("173c78"), Color("2f6fb8"), Color("c9b77a"), Color("3f8f2c"), Color("2b5e1f"), Color("7d7f78")],
	"isles": [Color("10305e"), Color("2a5f9a"), Color("9a9a8a"), Color("6f8f4a"), Color("7a7a72"), Color("9a9a94")],
	"highlands": [Color("1b3d66"), Color("3a6c9e"), Color("b9a26a"), Color("6c8a3a"), Color("6e5a3a"), Color("8a7e70")],
	"desert": [Color("135a6e"), Color("2c8fa0"), Color("e8d29a"), Color("d9b46a"), Color("b8864a"), Color("8a6a4a")],
	"glacier": [Color("173a5e"), Color("4a86b0"), Color("cfe3ee"), Color("e8f2f8"), Color("b8cfe0"), Color("7a8a98")],
	"volcano": [Color("7a1a06"), Color("ff6a1a"), Color("3a302c"), Color("5a4c44"), Color("3a302a"), Color("9a8a80")],
}

var info = null
var home
var engine
var skin := "classic"
var mode := "cpu"            # cpu, campaign, duo
var level: int = 1            # cpu level 0..2, or campaign battle 0..11
var started := false
var result_recorded := false
var over_t: float = 0.0
var camp: Dictionary = {"reached": 0, "stars": {}}
var goals = Goals.new()
var tally: Dictionary = {}    # this battle, for the objectives (see hover_duel_goals.gd)
var engine_snd: AudioStreamPlayer = null
var terrain: Control          # the map picture, drawn through the terrain shader
var mask_tex: ImageTexture

var field: Control
var hud: Control
var end_dialog: Control
var next_btn: Button
var brief_dialog: Control
var brief_title: Label
var brief_text: Label
var briefing := false         # a Campaign briefing is up: the battle waits
var terrain_tex: ImageTexture
var cam := Vector2(E.W / 2.0, E.H / 2.0)
var zoom: float = 0.5
var sparks: Array = []        # [pos, vel, life, colour]
var booms: Array = []         # [pos, size, age]
var trails: Array = []        # [pos, age] wakes behind the craft
var shake: float = 0.0
var banner := ""
var banner_t: float = 0.0
var shot_sfx_t: float = 0.0
var wall_sfx_t: float = 0.0

# Touch controls: the shared Pad in 1-player games; own two-half controls in
# 2 Players and on apps without the Pad.
var touch_pad: Control = null
var fingers := {}             # index -> {"side", "kind" ("stick"/"fire"/"missile"/"mine"), "origin", "pos"}
var edge_press := [{}, {}]    # side -> {"missile": true, "mine": true} for this frame

func _ready() -> void:
	preload("res://scripts/games/hover_duel/hover_duel_i18n.gd").install(self)
	Orientation.lock_landscape()
	engine = E.new()
	_load_campaign()
	goals.load_saved(SaveUtil.read(Goals.PATH))
	engine.reset("valley", 1101, ["skimmer", "gnat"], [-1, 0])
	_build_ui()
	_rebuild_terrain()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	terrain = Control.new()
	terrain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	terrain.material = mat
	terrain.draw.connect(_draw_terrain)
	add_child(terrain)
	field = Control.new()
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.draw.connect(_draw_field)
	add_child(field)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	add_child(hud)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(72, 60)
	pause_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	pause_btn.position = Vector2(-36, 24)
	pause_btn.pressed.connect(_on_pause)
	add_child(pause_btn)
	pause_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pause_btn.offset_left = -36
	pause_btn.offset_right = 36
	pause_btn.offset_top = 24
	pause_btn.offset_bottom = 84

	end_dialog = UI.build_dialog("", [
		{"text": tr("Next battle"), "action": _next_battle},
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	next_btn = _find_button(end_dialog, tr("Next battle"))
	_build_briefing()
	_add_pad()

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	modes.append({"text": "⚡ Quick Duel", "sub": "vs Computer (Normal), random land", "action": _new_vs.bind(1)})
	modes.append({"text": "👥 2 Players", "sub": "One phone held sideways, one half each", "multi": true, "action": _new_duo})
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S3 Rail List; colours: sky blue vs signal red.
		"landing": "rail",
		"landing_style": MenuStyles,
		"title_colors": [Color("4ab0ff"), Color("ff5a3a")],
		"landing_colors": [Color("071018"), Color("16301c")],
		"menu_color": Color("4ab0ff"),
		"retro": true,
		"help": HELP,
		"info": info,
		"accent": Color("4ab0ff"),
		"solo_heading": "vs Computer",
		"subtitle": "Hovercraft duel over hills, rivers and rock. High ground wins.",
		"logo": _draw_home_logo,
		"art": LANDING_ART if ResourceLoader.exists(LANDING_ART) else "",
		"landing_art": true,
		"landing_art_alpha": 0.7,
		"modes": modes,
		"play": [
			{"text": "🗺 Campaign", "sub": "12 rivals, 6 lands", "action": _open_campaign, "card": true},
			{"text": "🤖 vs Computer", "sub": "Easy, Normal or Hard", "action": _open_vs, "card": true},
			{"text": "🎯 Objectives", "sub": "Daily, weekly and story goals", "action": _open_goals, "card": true},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"helps": [{"text": "❤ Repair", "how": "Repairs your hovercraft to full armour (Campaign and vs Computer).", "action": _help_repair}],
		"board": "Campaign stars",
		"board_note": "Stars earned in the Campaign: up to 3 per battle, 36 in all.",
	})
	add_child(home)
	if info:
		add_child(info)

func _find_button(n: Node, text: String) -> Button:
	for ch in n.get_children():
		if ch is Button and ch.text == text:
			return ch
		var f := _find_button(ch, text)
		if f:
			return f
	return null

func _add_pad() -> void:
	if not ResourceLoader.exists(PAD_PATH):
		return
	touch_pad = load(PAD_PATH).new()
	touch_pad.layout_override = "stick_4"
	touch_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(touch_pad)
	for part in ["y", "pause", "info"]:
		touch_pad.set_hidden(part, true)
	touch_pad.set_state("a", {"glyph": "bolt", "sub": tr("Fire")})
	touch_pad.set_state("b", {"sub": tr("Missile")})
	touch_pad.set_state("x", {"glyph": "bomb", "sub": tr("Mine")})
	touch_pad.button_pressed.connect(_on_pad_button)
	touch_pad.visible = false

func _on_pad_button(id: String) -> void:
	if id == "b":
		edge_press[0]["missile"] = true
	elif id == "x":
		edge_press[0]["mine"] = true

func _uses_pad() -> bool:
	return touch_pad != null and mode != "duo"

# ---------- flow ----------

func _new_vs(lv: int) -> void:
	mode = "cpu"
	level = lv
	_restart()

func _new_duo() -> void:
	mode = "duo"
	level = 0
	_restart()

func _start_campaign(n: int) -> void:
	mode = "campaign"
	level = n
	_restart()

func _restart() -> void:
	SaveUtil.delete(SAVE_PATH)
	match mode:
		"campaign":
			var b: Dictionary = E.CAMPAIGN[level]
			engine.reset(b.theme, b.seed, ["skimmer", b.foe], [-1, b.ai])
		"duo":
			engine.reset(VS_THEMES[randi() % VS_THEMES.size()], randi() % 100000, ["skimmer", "skimmer"], [-1, -1])
		_:
			engine.reset(VS_THEMES[randi() % VS_THEMES.size()], randi() % 100000, ["skimmer", ["gnat", "hornet", "stingray"][level]], [-1, [0, 1, 2][level]])
	_begin()

func _begin() -> void:
	_rebuild_terrain()
	started = true
	result_recorded = false
	over_t = 0.0
	sparks.clear()
	booms.clear()
	trails.clear()
	fingers.clear()
	end_dialog.visible = false
	tally = {"battles": 1}
	briefing = false
	brief_dialog.visible = false
	if mode == "campaign" and engine.time <= 0.0:
		briefing = true
		var ch: Dictionary = Story.CHAPTERS[level]
		var head := tr("Battle %d") % (level + 1) + " · " + tr(E.CAMPAIGN[level].rival)
		var txt := ""
		if level == 0:
			txt = tr(Story.INTRO) + "\n\n"
		txt += "🎯 " + tr(ch.goal) + "\n\n" + tr(ch.brief)
		brief_title.text = head
		brief_text.text = txt
		brief_dialog.visible = true
	_engine_sound(true)
	cam = (engine.crafts[0].p + engine.crafts[1].p) / 2.0
	zoom = 0.0
	if touch_pad:
		touch_pad.release_all()
	_show_banner(_battle_name())
	_music("play", "techno", (level if mode == "campaign" else randi() % 4))

## The Campaign briefing: a wide dark panel, story text that scrolls, ▶ Fight!
func _build_briefing() -> void:
	brief_dialog = ColorRect.new()
	brief_dialog.color = Color(0, 0, 0, 0.55)
	brief_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brief_dialog.visible = false
	add_child(brief_dialog)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.anchor_left = 0.12
	m.anchor_right = 0.88
	m.anchor_top = 0.08
	m.anchor_bottom = 0.92
	m.offset_left = 0
	m.offset_right = 0
	m.offset_top = 0
	m.offset_bottom = 0
	brief_dialog.add_child(m)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.09, 0.94)
	sb.border_color = Color("4ab0ff")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	m.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	brief_title = Label.new()
	brief_title.add_theme_font_size_override("font_size", 30)
	brief_title.add_theme_color_override("font_color", Color("ff9a6a"))
	col.add_child(brief_title)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	brief_text = Label.new()
	brief_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brief_text.add_theme_font_size_override("font_size", 22)
	sc.add_child(brief_text)
	var go := HomeKit.neon_button("▶ " + tr("Fight!"), HomeKit.LIME, 28, 70)
	go.pressed.connect(_end_briefing)
	col.add_child(go)

func _end_briefing() -> void:
	briefing = false
	brief_dialog.visible = false
	_show_banner(_battle_name())

func _battle_name() -> String:
	if mode == "campaign":
		var b: Dictionary = E.CAMPAIGN[level]
		return tr("Battle %d") % (level + 1) + ": " + tr(E.THEMES[b.theme].name)
	return tr(E.THEMES[engine.theme_id].name)

func _name(i: int) -> String:
	if mode == "duo":
		return tr("Player %d") % (i + 1)
	if i == 0:
		return tr("You")
	if mode == "campaign":
		return tr(E.CAMPAIGN[level].rival)
	return tr("Computer")

func _show_banner(t: String) -> void:
	banner = t
	banner_t = 2.0

func _next_battle() -> void:
	if mode == "campaign" and level + 1 < E.CAMPAIGN.size():
		level += 1
	_restart()

# ---------- campaign ----------

func _load_campaign() -> void:
	var d = SaveUtil.read(CAMPAIGN_PATH)
	if d is Dictionary:
		camp.reached = int(d.get("reached", 0))
		camp.stars = d.get("stars", {})

func _total_stars() -> int:
	var n := 0
	for k in camp.stars:
		n += int(camp.stars[k])
	return n

func _open_campaign() -> void:
	var parts: Array = home.card("🗺 " + tr("Campaign"))
	var body: VBoxContainer = parts[1]
	var note := Label.new()
	note.text = tr("Beat each rival to unlock the next. Stars: %d / %d") % [_total_stars(), E.CAMPAIGN.size() * 3]
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(note)
	var story := Label.new()
	story.text = tr(Story.ENDING) if camp.get("done", false) else tr(Story.INTRO)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.add_theme_font_size_override("font_size", 18)
	story.modulate = Color(1, 1, 1, 0.8)
	body.add_child(story)
	for n in E.CAMPAIGN.size():
		var b: Dictionary = E.CAMPAIGN[n]
		var open: bool = n <= camp.reached
		var st := int(camp.stars.get(str(n), 0))
		var btn := Button.new()
		var line := "%d. %s · %s (%s)" % [n + 1, tr(E.THEMES[b.theme].name), tr(b.rival), tr(E.CRAFTS[b.foe].name)]
		if b.get("boss", false):
			line = "💀 " + line
		btn.text = (line + "   " + "★".repeat(st) + "☆".repeat(3 - st)) if open else "🔒 " + line
		btn.disabled = not open
		btn.custom_minimum_size = Vector2(0, 62)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.pressed.connect(_pick_battle.bind(n, parts[0]))
		body.add_child(btn)
	home.show_card(parts[0])

func _pick_battle(n: int, c: Control) -> void:
	home.close_card(c)
	home.play_now(_start_campaign.bind(n))

func _open_vs() -> void:
	var parts: Array = home.card("🤖 " + tr("vs Computer"))
	var body: VBoxContainer = parts[1]
	for i in LEVELS.size():
		var b := HomeKit.neon_button(tr(["🙂 Easy", "😐 Normal", "😈 Hard"][i]) + "  ·  " + tr(E.CRAFTS[["gnat", "hornet", "stingray"][i]].name),
			[HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i], 26, 76)
		b.pressed.connect(_pick_vs.bind(i, parts[0]))
		body.add_child(b)
	var note := Label.new()
	note.text = tr("A new random land every battle.")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(note)
	home.show_card(parts[0])

func _pick_vs(i: int, c: Control) -> void:
	home.close_card(c)
	home.play_now(_new_vs.bind(i))

# ---------- objectives ----------

func _open_goals() -> void:
	goals.roll()
	var parts: Array = home.card("🎯 " + tr("Objectives"))
	var body: VBoxContainer = parts[1]
	var medals := Label.new()
	medals.text = "🏅 " + tr("Medals: %d") % int(goals.data.medals)
	medals.add_theme_font_size_override("font_size", 26)
	medals.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(medals)
	# Story objective: the next Campaign battle.
	var nxt: int = mini(int(camp.reached), E.CAMPAIGN.size() - 1)
	var story_line: String
	if camp.get("done", false):
		story_line = tr("Campaign complete! Every rival beaten.")
	else:
		story_line = tr("Battle %d") % (nxt + 1) + ": " + tr(Story.CHAPTERS[nxt].goal) + " (" + tr(E.CAMPAIGN[nxt].rival) + ")"
	_goal_row(body, "📖 " + tr("Story"), story_line, 1.0 if camp.get("done", false) else float(nxt) / E.CAMPAIGN.size(), "")
	var d: Dictionary = goals.daily()
	_goal_row(body, "📅 " + tr("Daily"), tr(d.text), minf(1.0, float(goals.data.day_n) / d.need),
		("✔ " + tr("Done")) if goals.data.day_done else "%d / %d  ·  +%d 🏅" % [mini(int(goals.data.day_n), d.need), d.need, Goals.DAILY_MEDALS])
	var w: Dictionary = goals.weekly()
	_goal_row(body, "🗓 " + tr("Weekly"), tr(w.text), minf(1.0, float(goals.data.week_n) / w.need),
		("✔ " + tr("Done")) if goals.data.week_done else "%d / %d  ·  +%d 🏅" % [mini(int(goals.data.week_n), w.need), w.need, Goals.WEEKLY_MEDALS])
	var ph := Label.new()
	ph.text = "🎨 " + tr("Hull paint (medals unlock more)")
	ph.add_theme_font_size_override("font_size", 22)
	body.add_child(ph)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for i in Goals.PAINTS.size():
		var pt: Array = Goals.PAINTS[i]
		var ok: bool = goals.paint_unlocked(i)
		var b := HomeKit.neon_button(("✔ " if int(goals.data.paint) == i else "") + tr(pt[0]) if ok else "🔒 %d 🏅" % pt[2], pt[1], 22, 62)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not ok
		b.pressed.connect(_pick_paint.bind(i, parts[0]))
		grid.add_child(b)
	home.show_card(parts[0])

func _goal_row(body: Control, head: String, text: String, frac: float, right: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	body.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var h := Label.new()
	h.text = head
	h.add_theme_font_size_override("font_size", 22)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(h)
	var r := Label.new()
	r.text = right
	top.add_child(r)
	var t := Label.new()
	t.text = text
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(t)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = frac
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	box.add_child(bar)

func _pick_paint(i: int, c: Control) -> void:
	goals.data.paint = i
	SaveUtil.write(Goals.PATH, goals.to_dict())
	home.close_card(c)
	_open_goals()

func _player_colors() -> Array:
	var cols: Array = COLORS[skin].duplicate()
	if int(goals.data.paint) > 0:
		cols[0] = goals.paint_color()
	return cols

## Finished a battle (not 2 Players): feed the objectives, celebrate what got done.
func _feed_goals(won: bool) -> String:
	tally["won"] = 1 if won else 0
	var c: Dictionary = engine.crafts[0]
	if won and c.hp >= c.max:
		tally["flawless"] = 1
	if won and mode == "cpu" and level == 2:
		tally["hard"] = 1
	if won and engine.time < 60.0:
		tally["fast"] = 1
	var done: Array = goals.add_battle(tally)
	SaveUtil.write(Goals.PATH, goals.to_dict())
	var out := ""
	for k in done:
		out += "\n🏅 " + (tr("Daily objective done!") if k == "daily" else tr("Weekly objective done!"))
		if info:
			info.add("Objectives done")
	if not done.is_empty():
		SoundLib.play(self, "reward/coin_plingy")
	return out

# ---------- input ----------

func _gather_inputs() -> Array:
	var out := [{"move": Vector2.ZERO, "fire": false, "missile": false, "mine": false},
		{"move": Vector2.ZERO, "fire": false, "missile": false, "mine": false}]
	# Keyboard. 1 player: WASD or arrows, Space / K fire, L missile, J mine.
	# 2 players: P1 WASD + Space/F/G, P2 arrows + Enter/. /,
	var duo := mode == "duo"
	var k1 := Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	var k2 := Vector2(float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP)))
	if duo:
		out[0].move = k1
		out[0].fire = Input.is_key_pressed(KEY_SPACE)
		out[1].move = k2
		out[1].fire = Input.is_key_pressed(KEY_ENTER)
	else:
		out[0].move = k1 if k1 != Vector2.ZERO else k2
		out[0].fire = Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_K)
	if _uses_pad():
		var v: Vector2 = touch_pad.get_vector("move")
		if v.length() > 0.05:
			out[0].move = v
		out[0].fire = out[0].fire or touch_pad.is_down("a")
	# Own touch halves.
	for f in fingers.values():
		var s: int = f.side
		if f.kind == "stick":
			var d: Vector2 = (f.pos - f.origin) / (_stick_r())
			if d.length() > 0.12:
				out[s].move = d.limit_length(1.0)
		elif f.kind == "fire":
			out[s].fire = true
	for s in 2:
		out[s].missile = edge_press[s].get("missile", false)
		out[s].mine = edge_press[s].get("mine", false)
		edge_press[s] = {}
	return out

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or not started:
		return
	var duo := mode == "duo"
	match event.keycode:
		KEY_L, KEY_F:
			edge_press[0]["missile"] = true
		KEY_J, KEY_G:
			edge_press[0]["mine"] = true
		KEY_PERIOD:
			if duo:
				edge_press[1]["missile"] = true
		KEY_COMMA:
			if duo:
				edge_press[1]["mine"] = true

## Own touch controls: each player's half of the screen; a finger anywhere
## in it is a floating stick, except on the three buttons at the outer edge.
func _input(event: InputEvent) -> void:
	if not started or engine.is_over() or home.is_home_visible() or get_tree().paused:
		return
	if _uses_pad() and not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	var idx := -1
	var pos := Vector2.ZERO
	var pressed := false
	var moved := false
	if event is InputEventScreenTouch:
		idx = event.index
		pos = event.position
		pressed = event.pressed
	elif event is InputEventScreenDrag:
		idx = event.index
		pos = event.position
		moved = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
		idx = 99
		pos = event.position
		pressed = event.pressed
	elif event is InputEventMouseMotion and fingers.has(99):
		idx = 99
		pos = event.position
		moved = true
	else:
		return
	if _uses_pad():
		return   # the Pad reads touches itself
	pos = get_global_transform_with_canvas().affine_inverse() * pos
	if moved:
		if fingers.has(idx):
			fingers[idx].pos = pos
		return
	if not pressed:
		fingers.erase(idx)
		return
	if pos.y < 90.0:
		return   # top strip: pause button and the bars
	var side := 0 if mode != "duo" or pos.x < size.x / 2.0 else 1
	for b in _buttons(side):
		if pos.distance_to(b.c) < b.r * 1.15:
			if b.kind == "fire":
				fingers[idx] = {"side": side, "kind": "fire", "origin": pos, "pos": pos}
			else:
				edge_press[side][b.kind] = true
			hud.queue_redraw()
			get_viewport().set_input_as_handled()
			return
	fingers[idx] = {"side": side, "kind": "stick", "origin": pos, "pos": pos}
	get_viewport().set_input_as_handled()

func _stick_r() -> float:
	return clampf(minf(size.x, size.y) * 0.14, 50.0, 110.0)

## The fire / missile / mine buttons of one side, at its outer bottom corner.
func _buttons(side: int) -> Array:
	var r := clampf(minf(size.x, size.y) * 0.075, 34.0, 60.0)
	var inset := _safe()
	var right: bool = mode != "duo" or side == 1
	var x0: float = size.x - inset.z - r * 1.4 if right else inset.x + r * 1.4
	var dx: float = -1.0 if right else 1.0
	var yb: float = size.y - inset.w - r * 1.4
	return [
		{"kind": "fire", "c": Vector2(x0, yb), "r": r * 1.15},
		{"kind": "missile", "c": Vector2(x0 + dx * r * 2.4, yb + r * 0.2), "r": r * 0.85},
		{"kind": "mine", "c": Vector2(x0 - dx * r * 0.1, yb - r * 2.4), "r": r * 0.85},
	]

func _safe() -> Vector4:
	var s := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or s.size.x <= 0:
		return Vector4(12, 12, 12, 12)
	var kx := size.x / float(win.x)
	var ky := size.y / float(win.y)
	return Vector4(maxf(12.0, s.position.x * kx), maxf(12.0, s.position.y * ky),
		maxf(12.0, (win.x - s.end.x) * kx), maxf(12.0, (win.y - s.end.y) * ky))

# ---------- loop ----------

func _process(delta: float) -> void:
	if touch_pad:
		touch_pad.visible = started and _uses_pad() and not engine.is_over() and not briefing
	if not started and not engine.is_over():
		return
	delta = minf(delta, 0.05)
	if briefing:
		_update_camera(delta)
		terrain.queue_redraw()
		field.queue_redraw()
		return
	var inputs := _gather_inputs()
	var evs: Array = engine.step(delta, inputs)
	_handle_events(evs)
	banner_t = maxf(0.0, banner_t - delta)
	shake = maxf(0.0, shake - delta * 2.5)
	shot_sfx_t = maxf(0.0, shot_sfx_t - delta)
	wall_sfx_t = maxf(0.0, wall_sfx_t - delta)
	_engine_tick()
	for s in sparks:
		s[0] += s[1] * delta
		s[1] *= 0.92
		s[2] -= delta
	sparks = sparks.filter(func(s): return s[2] > 0.0)
	for b in booms:
		b[2] += delta
	booms = booms.filter(func(b): return b[2] < 0.8)
	for t in trails:
		t[1] += delta
	trails = trails.filter(func(t): return t[1] < 0.9)
	for c in engine.crafts:
		if c.alive and c.v.length() > 60.0 and randf() < 0.5:
			trails.append([c.p - Vector2.RIGHT.rotated(c.a) * E.CRAFT_R, 0.0])
	_update_camera(delta)
	if engine.is_over():
		over_t += delta
		if over_t > 1.4 and not result_recorded:
			_game_over()
	terrain.queue_redraw()
	field.queue_redraw()
	hud.queue_redraw()

func _handle_events(evs: Array) -> void:
	for e in evs:
		match e[0]:
			"shot":
				if shot_sfx_t <= 0.0:
					SoundLib.play(self, "scifi/laser_small", -14.0)
					shot_sfx_t = 0.09
			"hit":
				if mode != "duo" and e[1] == 1 and e.size() > 3:
					tally[e[3]] = int(tally.get(e[3], 0)) + 1
				_burst(e[2], Color("ffd27a"), 6)
				SoundLib.play(self, "scifi/impact_metal", -10.0)
				if mode != "duo" and e[1] == 0:
					_vibrate(30)
			"wall":
				_burst(e[1], Color(0.8, 0.75, 0.6), 3)
				if wall_sfx_t <= 0.0:
					SoundLib.play(self, "impact/metal_light", -12.0)
					wall_sfx_t = 0.25
			"boom":
				booms.append([e[1], e[2], 0.0])
				_burst(e[1], Color("ff8a2a"), int(10 * e[2]))
				shake = minf(1.0, shake + e[2] * 0.35)
				SoundLib.play(self, "scifi/explosion_crunch" if e[2] < 2.0 else "scifi/low_frequency_explosion", -4.0)
			"missile":
				SoundLib.play(self, "scifi/laser_large", -8.0)
			"mine":
				SoundLib.play(self, "impact/plate_light", -6.0)
			"pick":
				if e[1] == 0:
					tally["crates"] = int(tally.get("crates", 0)) + 1
				SoundLib.play(self, "reward/powerup", -6.0)
				_show_banner(tr({"repair": "Repaired!", "missiles": "+2 missiles", "mines": "+2 mines", "shield": "Shield!"}[e[2]]))
			"dead":
				_vibrate(120)

func _burst(at: Vector2, col: Color, n: int) -> void:
	for i in n:
		sparks.append([at, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 260.0), randf_range(0.25, 0.7), col])

func _update_camera(delta: float) -> void:
	var a: Vector2 = engine.crafts[0].p
	var b: Vector2 = engine.crafts[1].p
	var mid := (a + b) / 2.0
	var span := Vector2(absf(a.x - b.x), absf(a.y - b.y)) + Vector2(420, 360)
	var want := clampf(minf(size.x / span.x, size.y / span.y), minf(size.x / E.W, size.y / E.H), 1.1 * minf(size.y, size.x) / 600.0)
	if zoom <= 0.0:
		zoom = want
		cam = mid
	zoom = lerpf(zoom, want, minf(1.0, delta * 2.0))
	cam = cam.lerp(mid, minf(1.0, delta * 4.0))
	# Keep the view inside the map when it can be.
	var half := size / zoom / 2.0
	cam.x = E.W / 2.0 if half.x * 2.0 >= E.W else clampf(cam.x, half.x, E.W - half.x)
	cam.y = E.H / 2.0 if half.y * 2.0 >= E.H else clampf(cam.y, half.y, E.H - half.y)

func _game_over() -> void:
	result_recorded = true
	started = false
	SaveUtil.delete(SAVE_PATH)
	var w: int = engine.winner
	var msg := ""
	var won := w == 0
	next_btn.visible = false
	if mode == "duo":
		msg = tr("Both craft destroyed — a draw!") if w == 2 else tr("%s wins!") % _name(w)
		if info:
			info.add("2-player games")
			info.celebrate(msg)
	else:
		msg = tr("Both craft destroyed — a draw!") if w == 2 else (tr("You win!") if won else tr("%s wins!") % _name(1))
		if info:
			info.result("draw" if w == 2 else ("win" if won else "loss"))
		if won:
			var c: Dictionary = engine.crafts[0]
			var stars := 3 if c.hp >= c.max * 0.6 else (2 if c.hp >= c.max * 0.3 else 1)
			msg += "\n" + "★".repeat(stars) + "☆".repeat(3 - stars)
			if mode == "campaign":
				var key := str(level)
				tally["stars"] = maxi(0, stars - int(camp.stars.get(key, 0)))
				camp.stars[key] = maxi(int(camp.stars.get(key, 0)), stars)
				camp.reached = maxi(camp.reached, mini(level + 1, E.CAMPAIGN.size() - 1))
				if level + 1 >= E.CAMPAIGN.size():
					camp["done"] = true
					msg += "\n" + tr("Campaign complete! Every rival beaten.")
				SaveUtil.write(CAMPAIGN_PATH, camp)
				next_btn.visible = level + 1 < E.CAMPAIGN.size()
				if info:
					info.high("Campaign stars", _total_stars())
					info.high("Campaign battles won", camp.reached + (1 if camp.get("done", false) else 0))
			elif info:
				info.add("Wins (%s)" % LEVELS[level])
			if info and c.hp >= c.max:
				info.add("Flawless wins")
		msg += _feed_goals(won)
		if info:
			msg += "\n" + info.summary(["Wins", "Losses", "Best streak"])
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	_engine_sound(false)
	SoundLib.play(self, "reward/accomplished" if (w == 0 or (mode == "duo" and w < 2)) else "ui/wrong", -2.0)
	_music("play", "calm", level % 3, 2.0)

# ---------- terrain picture ----------

func _rebuild_terrain() -> void:
	var pal: Array = PALETTE[engine.theme_id]
	var img := Image.create(E.GW, E.GH, false, Image.FORMAT_RGB8)
	var sea: float = engine.theme.sea
	var rock: float = engine.theme.rock
	var r := RandomNumberGenerator.new()
	r.seed = engine.map_seed
	var neon := skin == "voodoo"
	var mask := Image.create(E.GW, E.GH, false, Image.FORMAT_RGB8)
	var lava: bool = engine.theme.liquid == "lava"
	for y in E.GH:
		for x in E.GW:
			var h: float = engine.cell(x, y)
			var col: Color
			if h < sea:
				col = pal[1].lerp(pal[0], clampf((sea - h) / 0.12, 0.0, 1.0))
			elif h < sea + 0.025:
				col = pal[2]
			elif h < rock:
				col = pal[3].lerp(pal[4], clampf((h - sea) / (rock - sea), 0.0, 1.0))
			else:
				col = pal[5]
				# Cliff edge: a dark rim where rock meets open ground.
				if engine.cell(x - 1, y) < rock or engine.cell(x + 1, y) < rock or engine.cell(x, y - 1) < rock or engine.cell(x, y + 1) < rock:
					col = col.darkened(0.45)
			# Light from the top-left: slopes facing it are brighter.
			var hs := maxf(engine.cell(x - 1, y - 1), sea) - maxf(engine.cell(x + 1, y + 1), sea)
			col = col.lightened(clampf(hs * 6.0, 0.0, 0.35)) if hs > 0.0 else col.darkened(clampf(-hs * 6.0, 0.0, 0.45))
			col = col.darkened(r.randf() * 0.08)
			if neon:
				col = Color(col.r * 0.35 + 0.04, col.g * 0.3, col.b * 0.45 + 0.08)
				if h >= rock - 0.01 and h < rock + 0.01 or (h >= sea and h < sea + 0.012):
					col = Color("9b4dff") if h >= rock - 0.01 else Color("29e6ff")
			img.set_pixel(x, y, col)
			# Shader mask: R = liquid, G = lava, B = rock.
			mask.set_pixel(x, y, Color(1.0 if h < sea else 0.0, 1.0 if lava and h < sea else 0.0, 1.0 if h >= rock else 0.0))
	terrain_tex = ImageTexture.create_from_image(img)
	mask_tex = ImageTexture.create_from_image(mask)
	if terrain:
		terrain.queue_redraw()

# ---------- drawing ----------

## The map picture through the terrain shader (moving water / lava, fine grain,
## drifting cloud shadows, a soft vignette): hover_duel_terrain.gdshader.
func _draw_terrain() -> void:
	terrain.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05))
	if terrain_tex == null:
		return
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 10.0
	var mat: ShaderMaterial = terrain.material
	mat.set_shader_parameter("mask", mask_tex)
	mat.set_shader_parameter("t", float(Time.get_ticks_msec() % 1000000) / 1000.0)
	mat.set_shader_parameter("grid", Vector2(E.GW, E.GH))
	mat.set_shader_parameter("neon", 1.0 if skin == "voodoo" else 0.0)
	terrain.draw_texture_rect(terrain_tex, Rect2(_w2s(Vector2.ZERO) + off, Vector2(E.W, E.H) * zoom), false)

func _w2s(p: Vector2) -> Vector2:
	return (p - cam) * zoom + size / 2.0

func _draw_field() -> void:
	var c := field
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 10.0
	c.draw_set_transform(off)
	var k := zoom
	var cols: Array = _player_colors()
	# Wakes.
	for t in trails:
		var a: float = 1.0 - t[1] / 0.9
		c.draw_rect(Rect2(_w2s(t[0]) - Vector2(2, 2) * k, Vector2(4, 4) * k * (1.0 + t[1] * 2.0)), Color(1, 1, 1, 0.25 * a))
	# Pickups.
	for pk in engine.pickups:
		var p := _w2s(pk.p)
		var bob := sin(engine.time * 4.0 + pk.p.x) * 3.0 * k
		var col: Color = {"repair": Color("5be36a"), "missiles": Color("ffb02e"), "mines": Color("c070ff"), "shield": Color("4ad8ff")}[pk.kind]
		c.draw_rect(Rect2(p + Vector2(-13, -13 + bob) * k, Vector2(26, 26) * k), Color(0, 0, 0, 0.5))
		c.draw_rect(Rect2(p + Vector2(-11, -15 + bob) * k, Vector2(22, 22) * k), col)
		c.draw_string(ThemeDB.fallback_font, p + Vector2(-11, 2 + bob) * k, {"repair": "+", "missiles": "M", "mines": "X", "shield": "S"}[pk.kind],
			HORIZONTAL_ALIGNMENT_CENTER, 22 * k, int(18 * k), Color(0.05, 0.05, 0.05))
	# Mines.
	for mn in engine.mines:
		var p := _w2s(mn.p)
		var armed: bool = mn.t >= E.MINE_ARM
		var blink := armed and int(engine.time * 4.0) % 2 == 0
		c.draw_rect(Rect2(p - Vector2(7, 7) * k, Vector2(14, 14) * k), Color(0.15, 0.15, 0.15))
		c.draw_rect(Rect2(p - Vector2(3, 3) * k, Vector2(6, 6) * k), cols[mn.o].lightened(0.3) if blink else Color(0.4, 0.4, 0.4))
	# Craft (shadow first, then hull).
	for i in 2:
		var cr: Dictionary = engine.crafts[i]
		if cr.alive:
			_draw_craft(c, _w2s(cr.p), cr.a, k, cols[i], engine.time + i, cr.hit_t > 0.0, cr.shield > 0.0, true)
	for i in 2:
		var cr: Dictionary = engine.crafts[i]
		if cr.alive:
			_draw_craft(c, _w2s(cr.p), cr.a, k, cols[i], engine.time + i, cr.hit_t > 0.0, cr.shield > 0.0, false)
	# Shots and missiles.
	for s in engine.shots:
		var p := _w2s(s.p)
		var col: Color = cols[s.o].lightened(0.6)
		c.draw_line(p, p - s.v.normalized() * 14.0 * k, col, maxf(2.0, 4.0 * k))
	for m in engine.missiles:
		var p := _w2s(m.p)
		var d: Vector2 = m.v.normalized()
		c.draw_line(p - d * 16.0 * k, p, Color(1, 0.9, 0.7), maxf(3.0, 6.0 * k))
		c.draw_line(p - d * 30.0 * k, p - d * 16.0 * k, Color(1, 0.5, 0.1, 0.7), maxf(2.0, 4.0 * k))
	for b in booms:
		var t: float = b[2] / 0.8
		var rad: float = 40.0 * b[1] * (0.4 + t) * k
		c.draw_rect(Rect2(_w2s(b[0]) - Vector2(rad, rad), Vector2(rad, rad) * 2.0), Color(1.0, 0.55 - t * 0.4, 0.1, 0.45 * (1.0 - t)))
		c.draw_rect(Rect2(_w2s(b[0]) - Vector2(rad, rad) * 0.5, Vector2(rad, rad)), Color(1, 0.95, 0.7, 0.6 * (1.0 - t)))
	for s in sparks:
		var p := _w2s(s[0])
		c.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(s[3], clampf(s[2] * 2.5, 0.0, 1.0)))
	c.draw_set_transform(Vector2.ZERO)

## A hovercraft from above: rounded skirt, deck, cabin, two fans at the back.
## Drawn with chunky polygons to match the pixel terrain.
func _draw_craft(c: CanvasItem, p: Vector2, a: float, k: float, col: Color, t: float, flash: bool, shield: bool, shadow: bool) -> void:
	var s := maxf(k, 0.8) * 1.3
	var bob := sin(t * 5.0) * 1.5
	if shadow:
		var sp := p + Vector2(10, 13) * s
		c.draw_colored_polygon(_shape([Vector2(22, 0), Vector2(14, 15), Vector2(-16, 16), Vector2(-22, 8), Vector2(-22, -8), Vector2(-16, -16), Vector2(14, -15)], sp, a, s), Color(0, 0, 0, 0.35))
		return
	p += Vector2(0, -bob) * s
	var skirt := Color(0.12, 0.12, 0.14)
	c.draw_colored_polygon(_shape([Vector2(22, 0), Vector2(14, 15), Vector2(-16, 16), Vector2(-22, 8), Vector2(-22, -8), Vector2(-16, -16), Vector2(14, -15)], p, a, s), skirt)
	var body := Color.WHITE if flash else col
	c.draw_colored_polygon(_shape([Vector2(19, 0), Vector2(12, 12), Vector2(-14, 12), Vector2(-18, 6), Vector2(-18, -6), Vector2(-14, -12), Vector2(12, -12)], p, a, s), body)
	c.draw_colored_polygon(_shape([Vector2(10, 0), Vector2(4, 7), Vector2(-6, 7), Vector2(-6, -7), Vector2(4, -7)], p, a, s), body.lightened(0.35))
	c.draw_colored_polygon(_shape([Vector2(9, 0), Vector2(5, 4), Vector2(1, 4), Vector2(1, -4), Vector2(5, -4)], p, a, s), Color(0.55, 0.85, 1.0))
	for fy in [-7.0, 7.0]:
		var fc := p + Vector2(-15, fy).rotated(a) * s
		var spin := t * 30.0
		c.draw_line(fc + Vector2(0, 5).rotated(spin) * s, fc - Vector2(0, 5).rotated(spin) * s, Color(0.85, 0.85, 0.85), maxf(1.0, 2.0 * s))
	if shield:
		c.draw_arc(p, 30.0 * s, 0.0, TAU, 20, Color(0.4, 0.85, 1.0, 0.5 + 0.3 * sin(t * 10.0)), maxf(2.0, 3.0 * s))

func _shape(pts: Array, p: Vector2, a: float, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(p + (q as Vector2).rotated(a) * s)
	return out

func _draw_hud() -> void:
	if not started and not engine.is_over():
		return
	var c := hud
	var font := ThemeDB.fallback_font
	var inset := _safe()
	var cols: Array = _player_colors()
	var bw := clampf(size.x * 0.28, 160.0, 360.0)
	for i in 2:
		var cr: Dictionary = engine.crafts[i]
		var x: float = inset.x if i == 0 else size.x - inset.z - bw
		var y: float = inset.y + 4.0
		c.draw_rect(Rect2(x - 4, y - 4, bw + 8, 66), Color(0, 0, 0, 0.55))
		var al := HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		c.draw_string(font, Vector2(x, y + 20), _name(i) + "  ·  " + tr(E.CRAFTS[cr.type].name), al, bw, 20, cols[i].lightened(0.45))
		c.draw_rect(Rect2(x, y + 28, bw, 12), Color(1, 1, 1, 0.15))
		var f: float = cr.hp / cr.max
		var hc := Color("5be36a") if f > 0.5 else (Color("ffb02e") if f > 0.25 else Color("ff4a3a"))
		c.draw_rect(Rect2(x if i == 0 else x + bw * (1.0 - f), y + 28, bw * f, 12), hc)
		c.draw_string(font, Vector2(x, y + 60), "🚀 %d   💣 %d" % [cr.missiles, cr.mines] + ("   🛡" if cr.shield > 0.0 else ""), al, bw, 18, Color(0.9, 0.9, 0.9))
	# Own touch controls.
	if not _uses_pad() and started and not engine.is_over():
		var sides := [0, 1] if mode == "duo" else [0]
		for side in sides:
			for b in _buttons(side):
				var held := false
				for f in fingers.values():
					if f.side == side and f.kind == b.kind:
						held = true
				var ammo := ""
				if b.kind == "missile":
					ammo = str(engine.crafts[side].missiles)
				elif b.kind == "mine":
					ammo = str(engine.crafts[side].mines)
				c.draw_circle(b.c, b.r, Color(cols[side], 0.45 if held else 0.22))
				c.draw_arc(b.c, b.r, 0, TAU, 28, Color(cols[side], 0.8), 2.0)
				var lbl: String = {"fire": tr("Fire"), "missile": "🚀 " + ammo, "mine": "💣 " + ammo}[b.kind]
				c.draw_string(font, b.c + Vector2(-b.r, 7), lbl, HORIZONTAL_ALIGNMENT_CENTER, b.r * 2.0, 20, Color.WHITE)
		for f in fingers.values():
			if f.kind == "stick":
				c.draw_arc(f.origin, _stick_r(), 0, TAU, 32, Color(1, 1, 1, 0.35), 2.0)
				var d: Vector2 = (f.pos - f.origin).limit_length(_stick_r())
				c.draw_circle(f.origin + d, _stick_r() * 0.42, Color(cols[f.side], 0.4))
		if mode == "duo" and engine.time < 4.0:
			c.draw_line(Vector2(size.x / 2.0, 100), Vector2(size.x / 2.0, size.y), Color(1, 1, 1, 0.25), 2.0)
	if banner_t > 0.0 and banner != "":
		var a := clampf(banner_t, 0.0, 1.0)
		c.draw_string(font, Vector2(0, size.y * 0.32), banner, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, Color(1, 1, 1, a))

func _draw_home_logo(c: Control) -> void:
	if ResourceLoader.exists(LANDING_ART):
		return   # the Landing picture already shows the duel
	var k := minf(c.size.y / 260.0, 0.9)
	var o := c.size / 2.0
	c.draw_rect(Rect2(o + Vector2(-170, 30) * k, Vector2(340, 26) * k), Color(0.25, 0.55, 0.85, 0.5))
	var cols: Array = _player_colors()
	_draw_craft(c, o + Vector2(-80, 0) * k, -0.3, k * 1.6, cols[0], 0.0, false, false, true)
	_draw_craft(c, o + Vector2(90, -10) * k, PI + 0.25, k * 1.6, cols[1], 1.0, false, false, true)
	_draw_craft(c, o + Vector2(-80, 0) * k, -0.3, k * 1.6, cols[0], 0.0, false, false, false)
	_draw_craft(c, o + Vector2(90, -10) * k, PI + 0.25, k * 1.6, cols[1], 1.0, false, false, false)
	for j in 4:
		var p := o + Vector2(-30 + j * 22, -16 - j * 1.5) * k
		c.draw_line(p, p + Vector2(12, -0.8) * k, cols[0].lightened(0.6), 3.0)

# ---------- skins ----------

func _set_skin(s: String) -> void:
	skin = "voodoo" if s == "voodoo" else "classic"
	_rebuild_terrain()
	field.queue_redraw()
	hud.queue_redraw()

func _current_skin() -> String:
	return skin

# ---------- pause / save ----------

func _on_pause() -> void:
	fingers.clear()
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or engine.is_over():
		return
	SaveUtil.write(SAVE_PATH, {"engine": engine.to_dict(), "mode": mode, "level": level})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var m := str(d.get("mode", "cpu"))
	var lv := int(d.get("level", 0))
	if m == "campaign":
		return tr("Campaign") + " · " + tr("Battle %d") % (lv + 1)
	if m == "duo":
		return tr("2 Players")
	return tr("vs Computer") + " (" + tr(LEVELS[clampi(lv, 0, 2)]) + ")"

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not d.has("engine"):
		_new_vs(1)
		return
	mode = str(d.get("mode", "cpu"))
	level = int(d.get("level", 0))
	engine.from_dict(d.engine)
	_begin()

# ---------- sound / helps ----------

## Your craft's fans: a quiet loop whose pitch follows your speed.
func _engine_sound(on: bool) -> void:
	if engine_snd and is_instance_valid(engine_snd):
		engine_snd.queue_free()
	engine_snd = null
	if on:
		engine_snd = SoundLib.loop(self, "scifi/engine_circular", -26.0)

func _engine_tick() -> void:
	if engine_snd == null or not is_instance_valid(engine_snd):
		return
	var c: Dictionary = engine.crafts[0]
	var f: float = clampf(c.v.length() / 380.0, 0.0, 1.0) if c.alive else 0.0
	engine_snd.pitch_scale = 0.7 + f * 0.6
	engine_snd.volume_db = -30.0 + f * 10.0

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

func _vibrate(ms: int) -> void:
	var st = get_node_or_null("/root/Settings")
	if st and st.has_method("buzz"):
		st.buzz(ms)

func _music(what: String, style: String, index: int = 0, fade: float = 1.5) -> void:
	var m = get_node_or_null("/root/Music")
	if m == null:
		return
	match what:
		"play":
			m.play(style, self, index, fade)
		"stop":
			if m.has_method("stop"):
				m.stop(fade)

## ❤ help (Campaign and vs Computer): armour back to full.
func _help_repair() -> bool:
	if not started or mode == "duo" or engine.is_over():
		return false
	if engine.repair(0):
		SoundLib.play(self, "reward/powerup")
		return true
	return false
