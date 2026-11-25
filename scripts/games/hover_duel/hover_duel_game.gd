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
const CLOUD_SAVE := "res://scripts/common/cloud_save.gd"  # [NEW 2026-11-24] STANDARDS §18; APK-side, load() guarded
var cloud: Node = null
const HANGAR_PATH := "user://hover_duel_hangar.json"   # credits, owned ships, upgrades, ship flown
const PAD_PATH := "res://scripts/common/pad/pad_controller.gd"
const Goals = preload("res://scripts/games/hover_duel/hover_duel_goals.gd")
const Story = preload("res://scripts/games/hover_duel/hover_duel_story.gd")
const TERRAIN_SHADER = preload("res://scripts/games/hover_duel/hover_duel_terrain.gdshader")
const LANDING_ART := "res://games/hover_duel/landing_bg.jpg"

const LEVELS := ["Easy", "Normal", "Hard"]
const CRAFT_SCALE := 1.6     # ship drawing size (world units per hull unit)
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
var hangar: Dictionary = {"credits": 0, "owned": ["skimmer"], "ups": {}, "ship": "skimmer"}
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
var glow_tex: Texture2D       # soft disc for smoke / glow / blasts (see _soft)
var cam := Vector2(E.W / 2.0, E.H / 2.0)
var zoom: float = 0.5
var scorches: Array = []      # [pos, radius, rot] burnt ground marks
var sparks: Array = []        # [pos, vel, life, colour]
var booms: Array = []         # [pos, size, age]
var trails: Array = []        # [pos, age] wakes behind the craft
var shake: float = 0.0
var banner := ""
var banner_t: float = 0.0
var shot_sfx_t: float = 0.0
var wall_sfx_t: float = 0.0
# Look layer (2026-11-17 visual pass): additive glow over the field, then the HUD.
var fx: Control               # glows, shock rings, spark streaks, drifting motes (additive)
var ring_tex: Texture2D       # thin soft ring, for shock waves and shields
var rings: Array = []         # [pos, max radius, age, colour, life] expanding shock rings
var flashes: Array = []       # [pos, angle, age] muzzle flashes
var motes: Array = []         # [pos, vel, phase, size] drifting dust / snow / embers
var hp_trail := [1.0, 1.0]    # the pale "damage just taken" part of each health bar
var punch: float = 0.0        # short camera zoom-in on big blasts
var banner_len: float = 2.0
var hud_box: StyleBoxFlat = null
var end_title: Label = null     # VICTORY / DEFEAT above the end-of-battle message

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
	if ResourceLoader.exists(CLOUD_SAVE):
		cloud = load(CLOUD_SAVE).new()
		cloud.setup("hover_duel", CAMPAIGN_PATH, _progress_score, _load_campaign)
		add_child(cloud)
	_load_hangar()
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
	var backdrop := ColorRect.new()    # beyond the map edge
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.color = Color(0.02, 0.03, 0.05)
	add_child(backdrop)
	terrain = Control.new()
	terrain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	terrain.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	fx = Control.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.clip_contents = true
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx.material = add_mat
	fx.draw.connect(_draw_fx)
	add_child(fx)
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
	_dress_end_dialog()
	_dress_pause(pause_btn)
	_build_briefing()
	_add_pad()

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	modes.append({"text": "⚡ Quick Duel", "sub": "vs Computer (Normal), random land", "action": _new_vs.bind(1)})
	modes.append({"text": "👥 2 Players", "sub": "One phone held sideways, one half each", "multi": true, "action": _new_duo})
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S3 Rail List; colours: sky blue vs signal red.
		"landing": "monument",
		"landing_style": MenuStyles,
		"title_colors": [Color("4ab0ff"), Color("ff5a3a")],
		"landing_colors": [Color("071018"), Color("16301c")],
		"menu_color": Color("4ab0ff"),
		# "retro": true,   # (pixel look dropped: it made the Landing art blocky, 2026-11-16)
		"help": HELP,
		"info": info,
		"accent": Color("4ab0ff"),
		"solo_heading": "vs Computer",
		"subtitle": "Fast one-on-one hovercraft duels over hills, rivers and rock.",
		"logo": _draw_home_logo,
		"art": LANDING_ART if ResourceLoader.exists(LANDING_ART) else "",
		"landing_art": true,
		"landing_art_alpha": 0.7,
		"modes": modes,
		"play": [
			{"text": "🗺 Campaign", "sub": "12 rivals, 6 lands", "action": _open_campaign, "card": true},
			{"text": "🤖 vs Computer", "sub": "Easy, Normal or Hard", "action": _open_vs, "card": true},
			{"text": "🎯 Objectives", "sub": "Daily, weekly and story goals", "action": _open_goals, "card": true},
			{"text": "🛠 Hangar", "sub": "Earn credits, buy and upgrade ships", "action": _open_hangar, "card": true},
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

## Glass pause button: dark rounded plate, cyan edge, brighter when pressed.
func _dress_pause(b: Button) -> void:
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.07, 0.12, 0.7 if st != "pressed" else 0.95)
		sb.set_corner_radius_all(18)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.4, 0.85, 1.0, 0.9 if st == "pressed" else 0.6)
		sb.shadow_size = 6
		sb.shadow_color = Color(0.2, 0.7, 1.0, 0.25)
		b.add_theme_stylebox_override(st, sb)
	b.pivot_offset = Vector2(36, 30)

## End-of-battle panel: a big coloured title and a glass panel edge.
func _dress_end_dialog() -> void:
	var panel := end_dialog.get_child(0).get_child(0) as PanelContainer
	var box := panel.get_child(0)
	end_title = Label.new()
	end_title.add_theme_font_size_override("font_size", 56)
	end_title.add_theme_constant_override("outline_size", 10)
	end_title.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.1, 0.9))
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(end_title)
	box.move_child(end_title, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.12, 0.94)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.4, 0.85, 1.0, 0.7)
	sb.shadow_size = 14
	sb.shadow_color = Color(0.2, 0.7, 1.0, 0.3)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)

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
	for part in ["pause", "info"]:
		touch_pad.set_hidden(part, true)
	touch_pad.set_state("y", {"sub": tr("Boost")})
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
			engine.reset(b.theme, b.seed, [_my_ship(), b.foe], [-1, b.ai], [_my_ups(), {}], [false, bool(b.get("boss", false))], _campaign_abilities(level))
		"duo":
			engine.reset(VS_THEMES[randi() % VS_THEMES.size()], randi() % 100000, ["skimmer", "skimmer"], [-1, -1])
		_:
			engine.reset(VS_THEMES[randi() % VS_THEMES.size()], randi() % 100000, [_my_ship(), ["gnat", "hornet", "stingray"][level]], [-1, [0, 1, 2][level]], [_my_ups(), {}])
	_begin()

## The Campaign hands out one ability per battle: guns first, then missiles, mines, boost.
func _campaign_abilities(battle: int) -> Array:
	return E.ABILITIES.slice(0, clampi(battle + 1, 1, E.ABILITIES.size()))

const ABILITY_NEW := ["", "🚀 New ability: Missiles! (L, or the 🚀 button) They chase the other craft.", "💣 New ability: Mines! (J, or the 💣 button) Drop one behind you.", "⚡ New ability: Boost! (Shift, or the ⚡ button) A burst of speed, back after 5 seconds."]

func _begin() -> void:
	_rebuild_terrain()
	started = true
	result_recorded = false
	over_t = 0.0
	sparks.clear()
	scorches.clear()
	booms.clear()
	trails.clear()
	rings.clear()
	flashes.clear()
	motes.clear()
	hp_trail = [1.0, 1.0]
	punch = 0.0
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
		if level >= 1 and level < ABILITY_NEW.size():
			txt += "\n\n" + tr(ABILITY_NEW[level])
		if E.CAMPAIGN[level].get("boss", false):
			txt += "\n\n" + tr("⚠ Boss: it launches small attack drones. Shoot them down.")
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
	banner_len = 2.0
	banner_t = banner_len

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

## Cards (Campaign, vs Computer, Objectives, Hangar) get the battle map as a
## dimmed backdrop instead of flat black.
func _dress_card(card: Control) -> void:
	if terrain_tex == null or terrain == null:
		return
	var bg := Control.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat: ShaderMaterial = (terrain.material as ShaderMaterial).duplicate()
	mat.set_shader_parameter("height_tex", terrain_tex)
	mat.set_shader_parameter("t", 3.0)
	bg.material = mat
	bg.draw.connect(func(): bg.draw_texture_rect(terrain_tex, Rect2(Vector2.ZERO, bg.size), false))
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Color(0.015, 0.03, 0.06, 0.8)
	card.color = Color(0, 0, 0, 1)
	card.add_child(bg)
	card.add_child(dim)
	card.move_child(dim, 0)
	card.move_child(bg, 0)

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
	_dress_card(parts[0])
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
	_dress_card(parts[0])
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
	_dress_card(parts[0])
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
	# Keyboard, ship-relative: W thrust, S brake, A / D turn. 1 player: WASD or arrows,
	# Space / K fire, L missile, J mine, Shift / B boost.
	# 2 players: P1 WASD + Space/F/G, P2 arrows + Enter/. /,
	var duo := mode == "duo"
	var k1 := Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S)))
	var k2 := Vector2(float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_DOWN)))
	if duo:
		_key_drive(out[0], k1)
		out[0].fire = Input.is_key_pressed(KEY_SPACE)
		_key_drive(out[1], k2)
		out[1].fire = Input.is_key_pressed(KEY_ENTER)
		out[0].boost = Input.is_key_pressed(KEY_SHIFT)
		out[1].boost = Input.is_key_pressed(KEY_SLASH)
	else:
		_key_drive(out[0], k1 if k1 != Vector2.ZERO else k2)
		out[0].fire = Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_K)
		out[0].boost = Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_B)
	if _uses_pad():
		# The Pad also binds WASD to its stick (pad_move_*), which would turn W into
		# "fly north". While a drive key is held, the keys steer ship-relative.
		var keys_held := k1 != Vector2.ZERO or k2 != Vector2.ZERO
		var v: Vector2 = Vector2.ZERO if keys_held else touch_pad.get_vector("move")
		if v.length() > 0.05:
			out[0].move = v
			out[0].erase("turn")
			out[0].erase("thrust")
		out[0].fire = out[0].fire or touch_pad.is_down("a")
		out[0].boost = out[0].get("boost", false) or touch_pad.is_down("y")
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

## Keys give turn / thrust (the engine's tank-style steering); a stick gives "move".
func _key_drive(inp: Dictionary, k: Vector2) -> void:
	if k != Vector2.ZERO:
		inp["turn"] = k.x
		inp["thrust"] = k.y

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
	var all := _all_buttons(side)
	return all.filter(func(b): return b.kind == "fire" or engine.abilities.has(b.kind))

func _all_buttons(side: int) -> Array:
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
		touch_pad.set_hidden("b", not engine.abilities.has("missile"))
		touch_pad.set_hidden("x", not engine.abilities.has("mine"))
		touch_pad.set_hidden("y", not engine.abilities.has("boost"))
	if not started and not engine.is_over():
		return
	delta = minf(delta, 0.05)
	if briefing:
		_update_camera(delta)
		terrain.queue_redraw()
		field.queue_redraw()
		fx.queue_redraw()
		_tick_fx(delta)
		return
	var inputs := _gather_inputs()
	# The final blow plays in slow motion that eases back to full speed (the
	# battle is already decided, so this is presentation only).
	var sim := delta
	if engine.is_over():
		sim = delta * clampf(0.22 + over_t * 0.6, 0.22, 1.0)
	var evs: Array = engine.step(sim, inputs)
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
	# Exhaust smoke: puffs leave both nozzles, drift back, swell and fade.
	for t in trails:
		t[1] += delta
		t[0] += t[2] * delta
		t[2] *= 0.94
	trails = trails.filter(func(t): return t[1] < 1.1)
	for c in engine.crafts:
		var th: float = c.get("thrust", 0.0)
		if c.alive and th > 0.08 and randf() < 0.35 + th * 0.65:
			var back := Vector2.LEFT.rotated(c.a)
			for q in _design(c.type).noz:
				var nz: Vector2 = c.p + (q as Vector2).rotated(c.a) * CRAFT_SCALE
				var vel: Vector2 = c.v * 0.3 + back.rotated(randf_range(-0.25, 0.25)) * (60.0 + 140.0 * th)
				trails.append([nz + back * 18.0 * th, 0.0, vel, 0.6 + th])
	# Missile smoke: a fiery, then grey, puff every other frame.
	if Engine.get_process_frames() % 2 == 0:
		for m in engine.missiles:
			trails.append([m.p, 0.25, -(m.v as Vector2) * 0.05 + Vector2(randf_range(-12, 12), randf_range(-12, 12)), 0.5])
	_tick_fx(delta)
	_update_camera(delta)
	if engine.is_over():
		over_t += delta
		if over_t > 1.4 and not result_recorded:
			_game_over()
	terrain.queue_redraw()
	field.queue_redraw()
	fx.queue_redraw()
	hud.queue_redraw()

## Timers of the look layer: shock rings, muzzle flashes, drifting motes, the
## pale damage part of the health bars, the camera punch.
func _tick_fx(delta: float) -> void:
	for r in rings:
		r[2] += delta
	rings = rings.filter(func(r): return r[2] < r[4])
	for f in flashes:
		f[2] += delta
	flashes = flashes.filter(func(f): return f[2] < 0.09)
	punch = maxf(0.0, punch - delta * 3.0)
	for i in 2:
		var fr: float = clampf(engine.crafts[i].hp / engine.crafts[i].max, 0.0, 1.0)
		hp_trail[i] = fr if fr >= hp_trail[i] else maxf(fr, hp_trail[i] - delta * 0.35)
	if motes.is_empty():
		for i in 44:
			motes.append([Vector2(randf() * E.W, randf() * E.H), Vector2.ZERO, randf() * TAU, randf_range(0.6, 1.5)])
	var lava: bool = engine.theme.liquid == "lava"
	var snowy: bool = engine.theme.ice or engine.theme_id == "highlands"
	for m in motes:
		m[2] += delta
		var drift := Vector2(18.0, 6.0)
		if lava:
			drift = Vector2(6.0, -26.0)
		elif snowy:
			drift = Vector2(-10.0, 22.0)
		m[0] += (drift + Vector2(sin(m[2] * 0.9) * 10.0, cos(m[2] * 0.7) * 8.0)) * delta * m[3]
		m[0].x = fposmod(m[0].x, float(E.W))
		m[0].y = fposmod(m[0].y, float(E.H))

func _handle_events(evs: Array) -> void:
	for e in evs:
		match e[0]:
			"shot":
				var sc: Dictionary = engine.crafts[e[1]]
				flashes.append([sc.p + Vector2.RIGHT.rotated(sc.a) * 30.0 * CRAFT_SCALE, sc.a, 0.0])
				if shot_sfx_t <= 0.0:
					SoundLib.play(self, "scifi/laser_small", -14.0)
					shot_sfx_t = 0.09
			"hit":
				if mode != "duo" and e[1] == 1 and e.size() > 3:
					tally[e[3]] = int(tally.get(e[3], 0)) + 1
				_burst(e[2], Color("ffd27a"), 10)
				rings.append([e[2], 34.0, 0.0, Color(1.0, 0.85, 0.5), 0.22])
				SoundLib.play(self, "scifi/impact_metal", -10.0)
				if mode != "duo" and e[1] == 0:
					_vibrate(30)
			"ground":
				_scorch(e[1], 7.0)
				_burst(e[1], Color(0.8, 0.75, 0.6), 2)
			"splash":
				_burst(e[1], Color(0.75, 0.9, 1.0), 2)
			"boost":
				if e[1] == 0:
					SoundLib.play(self, "scifi/laser_large", -10.0)
					_show_banner(tr("Boost!"))
			"drone":
				_burst(e[1], Color(1.0, 0.4, 0.3), 6)
			"dronedead":
				_scorch(e[1], 9.0)
			"wall":
				_scorch(e[1], 8.0)
				_burst(e[1], Color(0.8, 0.75, 0.6), 3)
				if wall_sfx_t <= 0.0:
					SoundLib.play(self, "impact/metal_light", -12.0)
					wall_sfx_t = 0.25
			"boom":
				booms.append([e[1], e[2], 0.0])
				_scorch(e[1], 22.0 * e[2])
				_burst(e[1], Color("ff8a2a"), int(14 * e[2]))
				_burst(e[1], Color(1.0, 0.9, 0.6), int(6 * e[2]))
				rings.append([e[1], 120.0 * e[2], 0.0, Color(1.0, 0.7, 0.35), 0.5])
				punch = minf(1.0, punch + e[2] * 0.4)
				shake = minf(1.0, shake + e[2] * 0.35)
				SoundLib.play(self, "scifi/explosion_crunch" if e[2] < 2.0 else "scifi/low_frequency_explosion", -4.0)
			"missile":
				SoundLib.play(self, "scifi/laser_large", -8.0)
			"mine":
				SoundLib.play(self, "impact/plate_light", -6.0)
			"pick":
				if e[1] == 0:
					tally["crates"] = int(tally.get("crates", 0)) + 1
				var pcol: Color = {"repair": Color("5be36a"), "missiles": Color("ffb02e"), "mines": Color("c070ff"), "shield": Color("4ad8ff")}[e[2]]
				rings.append([engine.crafts[e[1]].p, 70.0, 0.0, pcol, 0.45])
				_burst(engine.crafts[e[1]].p, pcol, 12)
				SoundLib.play(self, "reward/powerup", -6.0)
				_show_banner(tr({"repair": "Repaired!", "missiles": "+2 missiles", "mines": "+2 mines", "shield": "Shield!"}[e[2]]))
			"dead":
				var dc: Dictionary = engine.crafts[e[1]]
				rings.append([dc.p, 220.0, 0.0, Color(1.0, 0.95, 0.8), 0.8])
				rings.append([dc.p, 140.0, 0.0, Color(1.0, 0.5, 0.2), 0.6])
				_burst(dc.p, Color(0.85, 0.88, 0.95), 26)
				punch = 1.0
				shake = 1.0
				_vibrate(120)

## A burnt mark on the ground that stays for the rest of the battle.
func _scorch(at: Vector2, r: float) -> void:
	scorches.append([at, r * randf_range(0.85, 1.15), randf() * TAU])
	if scorches.size() > 260:
		scorches.pop_front()

func _burst(at: Vector2, col: Color, n: int) -> void:
	for i in n:
		sparks.append([at, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 260.0), randf_range(0.25, 0.7), col])

func _update_camera(delta: float) -> void:
	var a: Vector2 = engine.crafts[0].p
	var b: Vector2 = engine.crafts[1].p
	var mid := (a + b) / 2.0
	var span := Vector2(absf(a.x - b.x), absf(a.y - b.y)) + Vector2(420, 360)
	var want := clampf(minf(size.x / span.x, size.y / span.y), minf(size.x / E.W, size.y / E.H), 1.1 * minf(size.y, size.x) / 600.0)
	want *= 1.0 + punch * 0.07
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
		var earned := _award(won)
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
				if cloud:
					cloud.saved()
					cloud.report_completion(camp.stars.size(), E.CAMPAIGN.size())
				next_btn.visible = level + 1 < E.CAMPAIGN.size()
				if info:
					info.high("Campaign stars", _total_stars())
					info.high("Campaign battles won", camp.reached + (1 if camp.get("done", false) else 0))
			elif info:
				info.add("Wins (%s)" % LEVELS[level])
			if info and c.hp >= c.max:
				info.add("Flawless wins")
		msg += _feed_goals(won)
		if earned > 0:
			msg += "\n💰 " + tr("+%d credits (Hangar: %d)") % [earned, int(hangar.credits)]
		if info:
			msg += "\n" + info.summary(["Wins", "Losses", "Best streak"])
	end_dialog.get_meta("message_label").text = msg
	var win_title := w == 0 or (mode == "duo" and w < 2)
	end_title.text = tr("VICTORY") if win_title else (tr("DRAW") if w == 2 else tr("DEFEAT"))
	end_title.add_theme_color_override("font_color", Color("5be36a") if win_title else (Color("ffd27a") if w == 2 else Color("ff5a3a")))
	end_dialog.visible = true
	end_title.pivot_offset = end_title.size / 2.0
	end_title.scale = Vector2(1.6, 1.6)
	end_title.modulate.a = 0.0
	var tw := end_title.create_tween().set_parallel(true)
	tw.tween_property(end_title, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(end_title, "modulate:a", 1.0, 0.25)
	_engine_sound(false)
	SoundLib.play(self, "reward/accomplished" if (w == 0 or (mode == "duo" and w < 2)) else "ui/wrong", -2.0)
	_music("play", "calm", level % 3, 2.0)

# ---------- terrain picture ----------

func _rebuild_terrain() -> void:
	# A height map (one float per cell), blown up 4x with cubic filtering so the
	# shader sees smooth hills; colour, light and shadow are all done there.
	# Two soft blur passes first: carved rivers and cliffs are stepped cell by
	# cell, and the eye should see banks and slopes, not stairs.
	var hm := PackedFloat32Array()
	hm.resize(E.GW * E.GH)
	for y in E.GH:
		for x in E.GW:
			hm[y * E.GW + x] = engine.cell(x, y)
	for pass_i in 2:
		var nb := hm.duplicate()
		for y in E.GH:
			for x in E.GW:
				var sum := 0.0
				var wsum := 0.0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var xx := clampi(x + dx, 0, E.GW - 1)
						var yy := clampi(y + dy, 0, E.GH - 1)
						var w := 4.0 if dx == 0 and dy == 0 else (2.0 if dx == 0 or dy == 0 else 1.0)
						sum += hm[yy * E.GW + xx] * w
						wsum += w
				nb[y * E.GW + x] = sum / wsum
		hm = nb
	var img := Image.create_from_data(E.GW, E.GH, false, Image.FORMAT_RF, hm.to_byte_array())
	img.resize(E.GW * 4, E.GH * 4, Image.INTERPOLATE_CUBIC)
	terrain_tex = ImageTexture.create_from_image(img)
	if terrain:
		var pal: Array = PALETTE[engine.theme_id]
		var mat: ShaderMaterial = terrain.material
		for i in 6:
			mat.set_shader_parameter(["c_deep", "c_shallow", "c_shore", "c_low", "c_high", "c_rock"][i], pal[i])
		mat.set_shader_parameter("sea", float(engine.theme.sea))
		mat.set_shader_parameter("rock", float(engine.theme.rock))
		mat.set_shader_parameter("lava", 1.0 if engine.theme.liquid == "lava" else 0.0)
		mat.set_shader_parameter("snow", 1.0 if engine.theme.ice or engine.theme_id == "highlands" else 0.0)
		terrain.queue_redraw()

# ---------- drawing ----------

## The map picture through the terrain shader (moving water / lava, fine grain,
## drifting cloud shadows, a soft vignette): hover_duel_terrain.gdshader.
func _draw_terrain() -> void:
	if terrain_tex == null:
		return
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 10.0
	var mat: ShaderMaterial = terrain.material
	mat.set_shader_parameter("height_tex", terrain_tex)
	mat.set_shader_parameter("t", float(Time.get_ticks_msec() % 1000000) / 1000.0)
	mat.set_shader_parameter("neon", 1.0 if skin == "voodoo" else 0.0)
	terrain.draw_texture_rect(terrain_tex, Rect2(_w2s(Vector2.ZERO) + off, Vector2(E.W, E.H) * zoom), false)

func _w2s(p: Vector2) -> Vector2:
	return (p - cam) * zoom + size / 2.0

func _pick_box(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = col.lightened(0.55)
	sb.shadow_color = Color(col, 0.35)
	sb.shadow_size = 5
	return sb

func _ring(c: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	if ring_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.68, 0.86, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		ring_tex = gt
	c.draw_texture_rect(ring_tex, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, col)

## Additive light over the field: shot / missile glow, muzzle flashes, blasts and
## shock rings, spark streaks, pickup halos, shields, drifting motes.
func _draw_fx() -> void:
	var c := fx
	var k := zoom
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 10.0
	c.draw_set_transform(off)
	var cols: Array = _player_colors()
	var tt: float = engine.time
	# Drifting motes (dust, snow or embers), brighter near the screen centre.
	var snowy: bool = engine.theme.ice or engine.theme_id == "highlands"
	var mc := Color(1.0, 0.55, 0.2, 0.5) if engine.theme.liquid == "lava" else (Color(0.9, 0.95, 1.0, 0.4) if snowy else Color(1.0, 0.95, 0.75, 0.22))
	for m in motes:
		var mp := _w2s(m[0])
		if mp.x < -8 or mp.y < -8 or mp.x > size.x + 8 or mp.y > size.y + 8:
			continue
		var tw := 0.6 + 0.4 * sin(m[2] * 2.0)
		_soft(c, mp, (2.2 + 1.6 * m[3]) * maxf(k, 0.7), Color(mc, mc.a * tw))
	# Pickup halos and rings.
	for pk in engine.pickups:
		var p := _w2s(pk.p)
		var col: Color = {"repair": Color("5be36a"), "missiles": Color("ffb02e"), "mines": Color("c070ff"), "shield": Color("4ad8ff")}[pk.kind]
		var pulse := 0.5 + 0.5 * sin(tt * 3.0 + pk.p.x)
		_soft(c, p + Vector2(0, -4) * k, 34.0 * k, Color(col, 0.25 + 0.15 * pulse))
		_ring(c, p + Vector2(0, -4) * k, (26.0 + 6.0 * pulse) * k, Color(col, 0.7))
	# Armed mines blink red-hot.
	for mn in engine.mines:
		if mn.t >= E.MINE_ARM and int(tt * 4.0) % 2 == 0:
			_soft(c, _w2s(mn.p), 22.0 * k, Color(cols[mn.o], 0.5))
	# Shields as a bubble.
	for i in 2:
		var cr: Dictionary = engine.crafts[i]
		if cr.alive and cr.shield > 0.0:
			var sp := _w2s(cr.p)
			var pu := 0.7 + 0.3 * sin(tt * 9.0 + i)
			_soft(c, sp, 44.0 * k * 1.6, Color(0.3, 0.8, 1.0, 0.16 * pu))
			_ring(c, sp, 46.0 * k * 1.6, Color(0.5, 0.9, 1.0, 0.8 * pu))
	# Shots: a long soft streak and a hot head.
	for s in engine.shots:
		var p := _w2s(s.p)
		var d: Vector2 = s.v.normalized()
		var col: Color = cols[s.o].lightened(0.35)
		c.draw_line(p, p - d * 30.0 * k, Color(col, 0.35), maxf(5.0, 9.0 * k))
		_soft(c, p, 13.0 * maxf(k, 0.8), Color(col, 0.75))
	# Missiles: bright head, long flame.
	for m in engine.missiles:
		var p := _w2s(m.p)
		var d: Vector2 = m.v.normalized()
		c.draw_line(p, p - d * 44.0 * k, Color(1.0, 0.45, 0.1, 0.45), maxf(6.0, 11.0 * k))
		_soft(c, p, 24.0 * maxf(k, 0.8), Color(1.0, 0.7, 0.3, 0.8))
	# Muzzle flashes.
	for f in flashes:
		var fp := _w2s(f[0])
		var fa: float = 1.0 - f[2] / 0.09
		var fd := Vector2.RIGHT.rotated(f[1])
		_soft(c, fp, 20.0 * maxf(k, 0.8) * fa, Color(1.0, 0.9, 0.6, 0.9 * fa))
		c.draw_line(fp, fp + fd * 34.0 * k * fa, Color(1.0, 0.95, 0.8, fa), maxf(2.0, 4.0 * k))
	# Blasts: white-hot core, orange bloom.
	for b in booms:
		var t: float = b[2] / 0.8
		var rad: float = 40.0 * b[1] * (0.4 + t) * k
		_soft(c, _w2s(b[0]), rad * 2.4, Color(1.0, 0.45 - t * 0.3, 0.08, 0.5 * (1.0 - t)))
		_soft(c, _w2s(b[0]), rad * 1.1, Color(1.0, 0.8, 0.4, 0.9 * (1.0 - t)))
		_soft(c, _w2s(b[0]), rad * 0.5, Color(1, 1, 0.9, 1.0 * (1.0 - t)))
	# Shock rings.
	for r in rings:
		var t: float = r[2] / r[4]
		var e := 1.0 - (1.0 - t) * (1.0 - t)
		_ring(c, _w2s(r[0]), maxf(4.0, r[1] * e * k), Color(r[3], 0.85 * (1.0 - t)))
	# Sparks as streaks along their motion.
	for s in sparks:
		var p := _w2s(s[0])
		var tail := _w2s(s[0] - (s[1] as Vector2) * 0.05)
		var al := clampf(s[2] * 2.5, 0.0, 1.0)
		c.draw_line(p, tail, Color(s[3], al), 2.5)
		c.draw_line(p, p + (tail - p) * 0.25, Color(1, 1, 1, al * 0.8), 2.5)
	c.draw_set_transform(Vector2.ZERO)

func _draw_field() -> void:
	var c := field
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 10.0
	c.draw_set_transform(off)
	var k := zoom
	var cols: Array = _player_colors()
	# Exhaust smoke (hot and orange when fresh, grey and wide as it cools).
	for t in trails:
		var age: float = t[1] / 1.1
		var a: float = (1.0 - age) * (1.0 - age)
		var rad: float = (5.0 + 26.0 * age) * float(t[3]) * k
		var sc := Color(1.0, 0.55, 0.2).lerp(Color(0.45, 0.45, 0.48), clampf(age * 4.0, 0.0, 1.0))
		_soft(c, _w2s(t[0]), rad * 1.3, Color(sc, 0.4 * a))
	# Burnt marks on the ground (a dark soft core and a ragged halo).
	for sc in scorches:
		var sp := _w2s(sc[0])
		var sr: float = sc[1] * k
		_soft(c, sp, sr * 1.5, Color(0.0, 0.0, 0.0, 0.22))
		_soft(c, sp, sr * 0.9, Color(0.04, 0.03, 0.02, 0.5))
		for q in 3:
			var ang: float = sc[2] + q * 2.1
			_soft(c, sp + Vector2.RIGHT.rotated(ang) * sr * 0.7, sr * 0.45, Color(0.03, 0.02, 0.02, 0.3))
	# Pickups.
	for pk in engine.pickups:
		var p := _w2s(pk.p)
		var bob := sin(engine.time * 4.0 + pk.p.x) * 3.0 * k
		var col: Color = {"repair": Color("5be36a"), "missiles": Color("ffb02e"), "mines": Color("c070ff"), "shield": Color("4ad8ff")}[pk.kind]
		_soft(c, p + Vector2(4, 9) * k, 16.0 * k, Color(0, 0, 0, 0.35))   # ground shadow
		var pb := _pick_box(col)
		var pr := Rect2(p + Vector2(-12, -16 + bob) * k, Vector2(24, 24) * k)
		c.draw_style_box(pb, pr)
		c.draw_rect(Rect2(pr.position + Vector2(3, 3) * k, Vector2(pr.size.x - 6 * k, pr.size.y * 0.3)), Color(1, 1, 1, 0.22))
		c.draw_string_outline(ThemeDB.fallback_font, p + Vector2(-12, 2 + bob) * k, {"repair": "+", "missiles": "M", "mines": "X", "shield": "S"}[pk.kind],
			HORIZONTAL_ALIGNMENT_CENTER, 24 * k, int(19 * k), 3, Color(1, 1, 1, 0.5))
		c.draw_string(ThemeDB.fallback_font, p + Vector2(-12, 2 + bob) * k, {"repair": "+", "missiles": "M", "mines": "X", "shield": "S"}[pk.kind],
			HORIZONTAL_ALIGNMENT_CENTER, 24 * k, int(19 * k), Color(0.04, 0.05, 0.07))
	# Mines.
	for mn in engine.mines:
		var p := _w2s(mn.p)
		var armed: bool = mn.t >= E.MINE_ARM
		var blink := armed and int(engine.time * 4.0) % 2 == 0
		_soft(c, p + Vector2(2, 3) * k, 11.0 * k, Color(0, 0, 0, 0.4))
		for q in 4:
			var sa := q * PI / 4.0
			c.draw_line(p - Vector2.RIGHT.rotated(sa) * 9.5 * k, p + Vector2.RIGHT.rotated(sa) * 9.5 * k, Color(0.3, 0.31, 0.34), maxf(2.0, 2.5 * k))
		_soft(c, p, 8.0 * k, Color(0.12, 0.13, 0.15))
		_soft(c, p - Vector2(1.5, 2) * k, 4.0 * k, Color(0.5, 0.52, 0.58, 0.8))
		_soft(c, p, 3.2 * k, cols[mn.o].lightened(0.3) if blink else Color(0.3, 0.3, 0.32))
	# Craft (shadow first, then hull).
	for i in 2:
		var cr: Dictionary = engine.crafts[i]
		if cr.alive:
			_draw_craft(c, _w2s(cr.p), cr.a, k, cols[i], engine.time + i, cr.hit_t > 0.0, cr.shield > 0.0, true, 0.0, cr.type)
	for i in 2:
		var cr: Dictionary = engine.crafts[i]
		if cr.alive:
			_draw_craft(c, _w2s(cr.p), cr.a, k, cols[i], engine.time + i, cr.hit_t > 0.0, cr.shield > 0.0, false, cr.get("thrust", 0.0), cr.type)
	# Boss drones: small red darts.
	for d in engine.drones:
		var dp := _w2s(d.p)
		var fw := Vector2.RIGHT.rotated(d.a)
		var sd := fw.orthogonal()
		var ds := 11.0 * maxf(k, 0.8)
		c.draw_colored_polygon(PackedVector2Array([dp + fw * ds * 1.4, dp - fw * ds + sd * ds * 0.9, dp - fw * ds * 0.5, dp - fw * ds - sd * ds * 0.9]), Color(0.78, 0.2, 0.18))
		c.draw_colored_polygon(PackedVector2Array([dp + fw * ds * 0.7, dp - fw * ds * 0.2 + sd * ds * 0.35, dp - fw * ds * 0.2 - sd * ds * 0.35]), Color(1.0, 0.85, 0.5))
		_soft(c, dp - fw * ds * 1.1, ds * 0.9, Color(1.0, 0.5, 0.15, 0.6))
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
	c.draw_set_transform(Vector2.ZERO)

## Ship designs, one per craft type: the top half of the outline (nose at +x,
## from the nose round to the tail centre; mirrored for the other half) and
## the engine nozzles on the top half (mirrored too). Hull units, x -30..30.
const DESIGNS := {
	"skimmer": {"half": [[26, 0], [14, 5], [3, 7], [-8, 20], [-19, 23], [-24, 15], [-22, 6], [-22, 0]], "noz": [[-22, 9]]},
	"gnat": {"half": [[30, 0], [10, 4], [-6, 6], [-14, 14], [-20, 14], [-18, 5], [-20, 0]], "noz": [[-19, 4]]},
	"hornet": {"half": [[24, 0], [12, 4], [4, 6], [2, 16], [20, 18], [22, 21], [-2, 22], [-20, 20], [-22, 14], [-14, 10], [-18, 4], [-18, 0]], "noz": [[-21, 17]]},
	"comet": {"half": [[28, 0], [18, 8], [0, 12], [-14, 12], [-22, 6], [-24, 0]], "noz": [[-23, 4]]},
	"stingray": {"half": [[26, 0], [18, 6], [4, 20], [-6, 28], [-14, 24], [-16, 10], [-22, 5], [-22, 0]], "noz": [[-22, 5]]},
	"barge": {"half": [[22, 0], [20, 10], [12, 18], [-18, 20], [-24, 14], [-24, 0]], "noz": [[-24, 5], [-24, 14]]},
	"viper": {"half": [[30, 0], [20, 3], [22, 10], [8, 8], [-4, 18], [-20, 24], [-16, 8], [-22, 5], [-22, 0]], "noz": [[-22, 4]]},
	"bulwark": {"half": [[24, 0], [18, 14], [2, 22], [-16, 22], [-26, 12], [-26, 0]], "noz": [[-26, 5], [-24, 15]]},
	"aegis": {"half": [[22, 0], [20, 10], [12, 18], [0, 22], [-12, 20], [-20, 14], [-24, 6], [-24, 0]], "noz": [[-24, 5], [-21, 13]]},
	"wraith": {"half": [[22, 0], [10, 5], [14, 16], [20, 24], [4, 22], [-12, 14], [-20, 8], [-20, 0]], "noz": [[-20, 5]]},
	"warden": {"half": [[30, 0], [16, 6], [6, 8], [2, 26], [-6, 28], [-10, 10], [-22, 10], [-26, 18], [-30, 16], [-26, 0]], "noz": [[-26, 5], [-28, 15]]},
	"phantom": {"half": [[26, 0], [8, 8], [10, 18], [-2, 30], [-10, 20], [-16, 26], [-22, 14], [-18, 6], [-22, 0]], "noz": [[-21, 4], [-18, 15]]},
}
const SUN_2D := Vector2(-0.6, -0.8)   # light from the top-left, like the terrain
var _design_cache: Dictionary = {}

## The design's full outline and its nozzle points (both halves).
func _design(type: String) -> Dictionary:
	if _design_cache.has(type):
		return _design_cache[type]
	var d: Dictionary = DESIGNS.get(type, DESIGNS.skimmer)
	var half: Array = d.half
	var hull: Array = []
	for q in half:
		hull.append(Vector2(q[0], q[1]))
	for i in range(half.size() - 2, 0, -1):
		hull.append(Vector2(half[i][0], -half[i][1]))
	var noz: Array = []
	for q in d.noz:
		noz.append(Vector2(q[0], q[1]))
		noz.append(Vector2(q[0], -q[1]))
	var inner: Array = []
	for v in hull:
		inner.append(Vector2(v.x * 0.72 - 2.0, v.y * 0.62))
	var out := {"hull": hull, "noz": noz, "inner": inner, "nose": float(half[0][0])}
	_design_cache[type] = out
	return out

## A polygon in brushed metal: each corner lit by how much it faces the sun,
## so the shine slides across the hull as the ship turns.
func _metal(c: CanvasItem, pts: Array, p: Vector2, a: float, s: float, base: Color, shine: float) -> void:
	var out := PackedVector2Array()
	var cols := PackedColorArray()
	for q in pts:
		var v: Vector2 = (q as Vector2).rotated(a)
		out.append(p + v * s)
		var l := v.normalized().dot(SUN_2D) if v.length() > 0.01 else 0.0
		cols.append(base.lightened(clampf(l, 0.0, 1.0) * shine) if l > 0.0 else base.darkened(clampf(-l, 0.0, 1.0) * shine * 0.9))
	c.draw_polygon(out, cols)

## The ship from above in its own design: chrome hull, a team-coloured inner
## panel, glass canopy, and engines whose flame, glow and smoke grow with
## thrust (0..1).
func _draw_craft(c: CanvasItem, p: Vector2, a: float, k: float, col: Color, t: float, flash: bool, shield: bool, shadow: bool, thrust: float = 0.0, type: String = "skimmer") -> void:
	var s := maxf(k, 0.8) * CRAFT_SCALE
	var d := _design(type)
	var hull: Array = d.hull
	var bob := sin(t * 5.0) * 1.2
	if shadow:
		c.draw_colored_polygon(_shape(hull, p + Vector2(9, 12) * s, a, s), Color(0, 0, 0, 0.32))
		return
	p += Vector2(0, -bob) * s
	var fwd := Vector2.RIGHT.rotated(a)
	var side := Vector2(0, 1).rotated(a)
	var flick := 0.85 + 0.15 * sin(t * 47.0) + 0.08 * sin(t * 83.0)
	var noz: Array = d.noz
	var nk := 1.0 / sqrt(noz.size() / 2.0)   # more engines = smaller flames each
	# Engine light on the ground and the flame plumes (drawn under the hull).
	if thrust > 0.02:
		var gl := (18.0 + 40.0 * thrust) * s * flick
		var gp := p - fwd * (30.0 + 20.0 * thrust) * s
		_soft(c, gp, gl * 1.8, Color(1.0, 0.5, 0.12, 0.35 * thrust))
		_soft(c, gp, gl * 0.8, Color(1.0, 0.8, 0.4, 0.3 * thrust))
		for q in noz:
			var nz: Vector2 = p + (q as Vector2).rotated(a) * s
			var ln := (10.0 + 46.0 * thrust) * flick * s * nk
			var wd := (3.5 + 2.5 * thrust) * s * nk
			var wob := side * sin(t * 31.0 + q.y) * 1.2 * s
			c.draw_colored_polygon(PackedVector2Array([nz + side * wd * 1.3, nz - fwd * ln * 0.55 + side * wd * 1.1, nz - fwd * ln + wob, nz - fwd * ln * 0.55 - side * wd * 1.1, nz - side * wd * 1.3]), Color(1.0, 0.4, 0.06, 0.6))
			c.draw_colored_polygon(PackedVector2Array([nz + side * wd * 0.7, nz - fwd * ln * 0.5 + wob * 0.5, nz - side * wd * 0.7]), Color(1.0, 0.93, 0.7, 0.95))
	# Hull: chrome body, team panel, engine bells, canopy.
	var metal := Color(0.66, 0.69, 0.74)
	if flash:
		metal = Color.WHITE
	_metal(c, hull, p, a, s, metal.darkened(0.12), 0.55)
	_metal(c, d.inner, p, a, s, metal.lerp(col, 0.65), 0.5)
	for q in noz:
		var nz: Vector2 = p + (q as Vector2).rotated(a) * s
		_soft(c, nz, 4.5 * s, Color(0.08, 0.08, 0.1, 0.95))
		if thrust > 0.02:
			_soft(c, nz, 3.0 * s, Color(1.0, 0.75, 0.3, thrust))
	var nose: float = d.nose
	var cx := nose * 0.45
	_metal(c, [Vector2(cx + 6, 0), Vector2(cx + 2, 3.2), Vector2(cx - 6, 3.4), Vector2(cx - 9, 0), Vector2(cx - 6, -3.4), Vector2(cx + 2, -3.2)], p, a, s, Color(0.15, 0.35, 0.55), 0.7)
	_soft(c, p + Vector2(cx, 0).rotated(a) * s + SUN_2D * 1.6 * s, 2.0 * s, Color(1, 1, 1, 0.85))
	# Rim light and a sliding specular glint on the hull.
	var rim := _shape(hull, p, a, s)
	rim.append(rim[0])
	c.draw_polyline(rim, Color(1, 1, 1, 0.28), maxf(1.0, 0.7 * s), true)
	_soft(c, p + SUN_2D * 6.0 * s, 4.0 * s, Color(1, 1, 1, 0.55))
	if shield:
		c.draw_arc(p, 38.0 * s, 0.0, TAU, 40, Color(0.4, 0.85, 1.0, 0.5 + 0.3 * sin(t * 10.0)), maxf(2.0, 3.0 * s), true)

## A soft round blob (one textured quad: draw_circle costs ~100 us per call
## in Godot 4.7, a texture rect ~0.5 us). Used for smoke, glow, explosions.
func _soft(c: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	if glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.45))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		glow_tex = gt
	c.draw_texture_rect(glow_tex, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, col)

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
	var tt := float(Time.get_ticks_msec()) / 1000.0
	for i in 2:
		var cr: Dictionary = engine.crafts[i]
		var x: float = inset.x if i == 0 else size.x - inset.z - bw
		var y: float = inset.y + 4.0
		var al := HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var f: float = clampf(cr.hp / cr.max, 0.0, 1.0)
		var low: bool = f <= 0.25 and cr.alive
		var chips: Array = []
		if engine.abilities.has("missile"):
			chips.append(["missile", str(cr.missiles)])
		if engine.abilities.has("mine"):
			chips.append(["mine", str(cr.mines)])
		if engine.abilities.has("boost"):
			chips.append(["boost", ("%.0f" % ceilf(cr.boost_cd)) if cr.boost_cd > 0.0 else tr("ready")])
		if cr.shield > 0.0:
			chips.append(["shield", ""])
		# Glass panel with a team-coloured edge (red pulse when armour is low).
		if hud_box == null:
			hud_box = StyleBoxFlat.new()
			hud_box.set_corner_radius_all(12)
			hud_box.set_border_width_all(2)
			hud_box.shadow_size = 6
			hud_box.shadow_color = Color(0, 0, 0, 0.35)
		hud_box.bg_color = Color(0.03, 0.05, 0.09, 0.62)
		hud_box.border_color = Color("ff4a3a", 0.5 + 0.4 * sin(tt * 8.0)) if low else Color(cols[i].lightened(0.2), 0.7)
		var ph := 84.0 if chips.size() > 0 else 56.0
		c.draw_style_box(hud_box, Rect2(x - 10, y - 4, bw + 20, ph))
		# Team colour stripe on the outer edge.
		c.draw_rect(Rect2(x - 10 if i == 0 else x + bw + 4, y + 4, 6, ph - 20), Color(cols[i], 0.9))
		var nm := _name(i) + "  ·  " + tr(E.CRAFTS[cr.type].name)
		c.draw_string_outline(font, Vector2(x, y + 18), nm, al, bw, 19, 5, Color(0, 0, 0, 0.8))
		c.draw_string(font, Vector2(x, y + 18), nm, al, bw, 19, cols[i].lightened(0.55))
		# Health bar: dark track, pale damage trail, coloured fill with gloss.
		var bx := x
		var by := y + 26.0
		var track := StyleBoxFlat.new()
		track.bg_color = Color(0, 0, 0, 0.6)
		track.set_corner_radius_all(6)
		c.draw_style_box(track, Rect2(bx - 2, by - 2, bw + 4, 18))
		var tr_w: float = bw * hp_trail[i]
		if tr_w > f * bw + 1.0:
			var tb := StyleBoxFlat.new()
			tb.bg_color = Color(1, 1, 1, 0.75)
			tb.set_corner_radius_all(5)
			c.draw_style_box(tb, Rect2(bx if i == 0 else bx + bw - tr_w, by, maxf(10.0, tr_w), 14))
		var hc := Color("5be36a") if f > 0.5 else (Color("ffb02e") if f > 0.25 else Color("ff4a3a"))
		var fw := maxf(10.0, bw * f) if f > 0.0 else 0.0
		if fw > 0.0:
			var fb := StyleBoxFlat.new()
			fb.bg_color = hc
			fb.set_corner_radius_all(5)
			var fr := Rect2(bx if i == 0 else bx + bw - fw, by, fw, 14)
			c.draw_style_box(fb, fr)
			c.draw_rect(Rect2(fr.position + Vector2(4, 2), Vector2(maxf(0.0, fr.size.x - 8), 4)), Color(1, 1, 1, 0.3))
		# Ability chips drawn as small icons (no emoji: they differ per phone).
		var cx := x + 2 if i == 0 else x + bw - 2
		var cy := y + 62.0
		var dir := 1.0 if i == 0 else -1.0
		for ch in chips:
			var ic := Vector2(cx + dir * 9.0, cy)
			match ch[0]:
				"missile":
					var fd := Vector2.RIGHT
					c.draw_colored_polygon(PackedVector2Array([ic + fd * 10, ic + Vector2(-2, -4), ic + Vector2(-8, -6), ic + Vector2(-6, 0), ic + Vector2(-8, 6), ic + Vector2(-2, 4)]), Color("ffb02e"))
				"mine":
					_soft(c, ic, 9.0, Color(0.7, 0.45, 1.0, 0.9))
					_soft(c, ic, 5.0, Color(0.15, 0.1, 0.25))
				"boost":
					var rdy: bool = cr.boost_cd <= 0.0
					c.draw_colored_polygon(PackedVector2Array([ic + Vector2(2, -10), ic + Vector2(-5, 2), ic + Vector2(-1, 2), ic + Vector2(-3, 10), ic + Vector2(6, -3), ic + Vector2(1, -3)]), Color("ffe14a") if rdy else Color(0.6, 0.6, 0.6))
				"shield":
					c.draw_arc(ic, 8.0, 0, TAU, 20, Color(0.5, 0.9, 1.0), 2.5)
			var lw := 0.0
			if ch[1] != "":
				var lx := cx + dir * 22.0 if i == 0 else cx + dir * 22.0 - 60.0
				c.draw_string_outline(font, Vector2(lx, cy + 7), ch[1], HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT, 60.0, 18, 5, Color(0, 0, 0, 0.8))
				c.draw_string(font, Vector2(lx, cy + 7), ch[1], HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT, 60.0, 18, Color(0.95, 0.95, 0.95))
				lw = font.get_string_size(ch[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			cx += dir * (30.0 + lw + 14.0)
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
		var age := banner_len - banner_t
		var pop := 1.0 + 0.55 * exp(-age * 9.0)
		var fade := clampf(banner_t / 0.5, 0.0, 1.0)
		var slide := (1.0 - clampf(age / 0.25, 0.0, 1.0)) * 24.0
		var ctr := Vector2(size.x / 2.0, size.y * 0.3 + slide)
		var bwid := minf(size.x * 0.8, font.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x + 160.0)
		if glow_tex:
			c.draw_texture_rect(glow_tex, Rect2(ctr - Vector2(bwid, 44.0), Vector2(bwid * 2.0, 88.0)), false, Color(0.02, 0.05, 0.1, 0.55 * fade))
		c.draw_set_transform(ctr, 0.0, Vector2(pop, pop))
		c.draw_string_outline(font, Vector2(-size.x / 2.0, 14), banner, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, 10, Color(0.02, 0.06, 0.12, 0.9 * fade))
		c.draw_string(font, Vector2(-size.x / 2.0, 14), banner, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, Color(1, 1, 1, fade))
		c.draw_set_transform(Vector2.ZERO)

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

# ---------- hangar: credits, ships, upgrades ----------

const STAT_NAMES := {"attack": "Attack", "armor": "Armor", "accel": "Acceleration", "speed": "Top speed", "handling": "Handling"}

func _load_hangar() -> void:
	var d = SaveUtil.read(HANGAR_PATH)
	if not d is Dictionary:
		return
	hangar.credits = maxi(0, int(d.get("credits", 0)))
	var owned: Array = ["skimmer"]
	for t in d.get("owned", []):
		if E.CRAFTS.has(str(t)) and not owned.has(str(t)):
			owned.append(str(t))
	hangar.owned = owned
	var u = d.get("ups", {})
	hangar.ups = u if u is Dictionary else {}
	var sh := str(d.get("ship", "skimmer"))
	hangar.ship = sh if owned.has(sh) else "skimmer"

func _save_hangar() -> void:
	SaveUtil.write(HANGAR_PATH, hangar)

func _my_ship() -> String:
	return hangar.ship

func _my_ups(type: String = "") -> Dictionary:
	if type == "":
		type = hangar.ship
	var u = hangar.ups.get(type, {})
	return u if u is Dictionary else {}

## Credits for a finished battle (Campaign and vs Computer; 2 Players earns none).
## Campaign: win 60 + 30 per star, +100 the first time a rival falls (+100 more
## for a boss); loss 15. vs Computer: win 40 / 70 / 110 by difficulty; loss 10.
## Called before the Campaign stars are updated (first-win check).
func _award(won: bool) -> int:
	var n := 0
	if mode == "campaign":
		if won:
			var c: Dictionary = engine.crafts[0]
			var stars := 3 if c.hp >= c.max * 0.6 else (2 if c.hp >= c.max * 0.3 else 1)
			n = 60 + 30 * stars
			if int(camp.stars.get(str(level), 0)) == 0:
				n += 100 + (100 if E.CAMPAIGN[level].get("boss", false) else 0)
		else:
			n = 15
	elif mode == "cpu":
		n = [40, 70, 110][clampi(level, 0, 2)] if won else 10
	hangar.credits = int(hangar.credits) + n
	_save_hangar()
	if info and n > 0:
		info.add("Credits earned", n)
	return n

func _open_hangar() -> void:
	var parts: Array = home.card("🛠 " + tr("Hangar"))
	var body: VBoxContainer = parts[1]
	var head := Label.new()
	head.text = "💰 " + tr("Credits: %d") % int(hangar.credits)
	head.add_theme_font_size_override("font_size", 28)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(head)
	var note := Label.new()
	note.text = tr("Win battles to earn credits. Better ratings cost more. Each rating takes up to 3 upgrades.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate = Color(1, 1, 1, 0.8)
	body.add_child(note)
	for type in E.HANGAR:
		_hangar_row(body, type, parts[0])
	_dress_card(parts[0])
	home.show_card(parts[0])

## One ship: name and price, picture + five rating bars, then Buy, or Fly and upgrades.
func _hangar_row(body: Control, type: String, card: Control) -> void:
	var owned: bool = hangar.owned.has(type)
	var flying: bool = hangar.ship == type
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.1, 0.9)
	sb.border_color = Color("5be36a") if flying else (Color("4ab0ff") if owned else Color(0.3, 0.35, 0.42))
	sb.set_border_width_all(3 if flying else 2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	body.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var title := Label.new()
	var tag := ""
	if flying:
		tag = "  ·  ✔ " + tr("Flying")
	elif owned:
		tag = "  ·  " + tr("Owned")
	else:
		tag = "  ·  💰 %d" % E.price(type)
	title.text = tr(E.CRAFTS[type].name) + tag
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(0, 170)
	pic.draw.connect(_draw_hangar_pic.bind(pic, type))
	col.add_child(pic)
	if not owned:
		var price: int = E.price(type)
		var b := HomeKit.neon_button(tr("Buy") + "  💰 %d" % price, HomeKit.LIME, 22, 60)
		b.disabled = int(hangar.credits) < price
		b.pressed.connect(_buy_ship.bind(type, card))
		col.add_child(b)
		return
	if not flying:
		var f := HomeKit.neon_button("🚀 " + tr("Fly this ship"), HomeKit.LIME, 22, 60)
		f.pressed.connect(_fly_ship.bind(type, card))
		col.add_child(f)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	var ups := _my_ups(type)
	for st in E.STATS:
		var lv := int(ups.get(st, 0))
		var txt := "⬆ " + tr(STAT_NAMES[st]) + "  " + tr("Lv %d/%d") % [lv, E.UP_MAX]
		var cost := 0
		if lv < E.UP_MAX:
			cost = E.upgrade_cost(type, lv)
			txt += "  💰 %d" % cost
		var u := HomeKit.neon_button(txt, HomeKit.CYAN, 18, 54)
		u.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		u.disabled = lv >= E.UP_MAX or int(hangar.credits) < cost
		u.pressed.connect(_upgrade.bind(type, st, card))
		grid.add_child(u)

## Ship picture (engines lit) on the left; rating bars on the right: blue =
## the ship's own rating, green = what upgrades added. Ratings run 1..10.
func _draw_hangar_pic(c: Control, type: String) -> void:
	var w := c.size.x
	var h := c.size.y
	var cols: Array = _player_colors()
	var pw := minf(w * 0.36, 220.0)
	c.draw_rect(Rect2(0, 0, pw, h), Color(0.02, 0.04, 0.06, 0.8))
	_soft(c, Vector2(pw * 0.5, h * 0.4), pw * 0.55, Color(0.25, 0.55, 0.95, 0.28))   # a pool of light behind the ship
	_draw_craft(c, Vector2(pw * 0.5, h * 0.36), -PI / 2.0, 0.8, cols[0], 0.3, false, false, false, 0.6, type)
	var s := E.spec_for(type, _my_ups(type))
	var base := E.spec_for(type)
	var font := ThemeDB.fallback_font
	var x0 := pw + 14.0
	var bw := maxf(40.0, w - x0 - 50.0)
	var rh := h / 5.0
	for i in E.STATS.size():
		var st: String = E.STATS[i]
		var y := rh * i
		var r: float = E.rating(s, st)
		var r0: float = E.rating(base, st)
		c.draw_string(font, Vector2(x0, y + rh * 0.42), tr(STAT_NAMES[st]), HORIZONTAL_ALIGNMENT_LEFT, bw, 16, Color(0.85, 0.9, 1.0))
		var by := y + rh * 0.52
		c.draw_rect(Rect2(x0, by, bw, rh * 0.32), Color(1, 1, 1, 0.1))
		c.draw_rect(Rect2(x0, by, bw * r0 / 10.0, rh * 0.32), Color("4ab0ff"))
		if r > r0:
			c.draw_rect(Rect2(x0 + bw * r0 / 10.0, by, bw * (r - r0) / 10.0, rh * 0.32), Color("5be36a"))
		var num := ("%.1f" % r) if fmod(r, 1.0) != 0.0 else str(int(r))
		c.draw_string(font, Vector2(x0 + bw + 8, by + rh * 0.3), num, HORIZONTAL_ALIGNMENT_LEFT, 44, 18, Color.WHITE)

func _buy_ship(type: String, card: Control) -> void:
	var price: int = E.price(type)
	if hangar.owned.has(type) or int(hangar.credits) < price:
		return
	hangar.credits = int(hangar.credits) - price
	hangar.owned.append(type)
	hangar.ship = type
	_save_hangar()
	SoundLib.play(self, "reward/accomplished", -4.0)
	_reopen_hangar(card)

func _fly_ship(type: String, card: Control) -> void:
	if hangar.owned.has(type):
		hangar.ship = type
		_save_hangar()
	_reopen_hangar(card)

func _upgrade(type: String, st: String, card: Control) -> void:
	var ups: Dictionary = _my_ups(type).duplicate()
	var lv := int(ups.get(st, 0))
	if lv >= E.UP_MAX:
		return
	var cost: int = E.upgrade_cost(type, lv)
	if int(hangar.credits) < cost:
		return
	hangar.credits = int(hangar.credits) - cost
	ups[st] = lv + 1
	hangar.ups[type] = ups
	_save_hangar()
	SoundLib.play(self, "reward/accomplished", -6.0)
	_reopen_hangar(card)

func _reopen_hangar(card: Control) -> void:
	home.close_card(card)
	_open_hangar()

## Cloud vs device (STANDARDS §18): the copy further along the campaign (then more stars) wins.
func _progress_score(d: Dictionary) -> int:
	var n := 0
	var st = d.get("stars", {})
	if st is Dictionary:
		for k in st:
			n += int(st[k])
	return int(d.get("reached", 0)) * 1000 + n
