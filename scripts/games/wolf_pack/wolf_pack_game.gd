extends Control

## Stonewater (design: D:/Dev/Minigame Art/wolf/GAME_DESIGN_WOLFPACK.md).
## Landscape, 2D oblique with Y-sort. Two ways to play:
##  - Campaign: ten missions on premade maps. Missions earn renown; renown raises your
##    rank in the pack (Pup > Hunter > Tracker > Warden > Pack Leader > Elder), and each
##    rank brings a new body, new abilities, new orders for the command wheel and a
##    new packmate. Stars: finish, beat the par time, lose no wolf.
##  - Quick Mission: pick a terrain type and a role (Leader, Chaser, Striker, Scout) and
##    the game builds a short mission on a fresh map (same choices + seed = same map).
## The terrain comes from the shared TerrainGen (rolling hills, winding valleys, rain
## erosion); hills slow climbers. Chunks are streamed 3 x 3. The old arcade Wolf Pack is in
## git history.
##
## Landing menu style: S1 Corner Ghost (docs/MENU_STYLES.md): the pack on a ridge at dusk,
## art kept visible. Skin: Classic only for v1 (design §10).

const E = preload("res://scripts/games/wolf_pack/wolf_pack_engine.gd")
const Data = preload("res://scripts/games/wolf_pack/wolf_pack_data.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const MenuStyles = preload("res://scripts/games/wolf_pack/menu_styles.gd")
const HomeKit = preload("res://scripts/games/wolf_pack/home_kit.gd")
const SoundLib = preload("res://scripts/games/wolf_pack/sound_lib.gd")
const SpriteLib = preload("res://scripts/games/wolf_pack/sprite_lib.gd")
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/wolf_pack/wolf_pack_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://wolf_pack_save.json"
const CAMP_PATH := "user://wolf_pack_campaign.json"
const PAD_PATH := "res://scripts/common/pad/pad_controller.gd"

const WORLD_SCALE := 1.0
## Scenery per chunk: [sprite id, scale, count]. Ids are full literals on purpose (sprite_lib sync).
const SCENERY := [
	["forest/pine_tree", 2.6, 9],
	["forest/oak_tree", 2.4, 5],
	["forest/dead_tree", 2.4, 2],
	["forest/boulder_lg", 2.4, 3],
	["forest/boulder_sm", 2.2, 4],
	["forest/fallen_log", 2.2, 3],
	["forest/tree_stump", 2.2, 2],
	["forest/large_bush", 2.2, 4],
	["forest/small_bush", 2.2, 4],
	["forest/fern", 2.2, 5],
	["forest/flower_red", 2.0, 5],
	["forest/flower_yellow", 2.0, 5],
	["forest/mushroom_cluster", 2.0, 2],
]
## How much of each scenery sprite a terrain type gets (1.0 = the list above).
const SCENERY_MIX := {
	"valleys": {"forest/pine_tree": 1.3, "forest/fern": 1.4},
	"highlands": {"forest/pine_tree": 0.5, "forest/oak_tree": 0.2, "forest/boulder_lg": 2.5, "forest/boulder_sm": 2.0,
		"forest/flower_red": 0.4, "forest/flower_yellow": 0.4},
	"marsh": {"forest/pine_tree": 0.3, "forest/oak_tree": 0.5, "forest/fern": 2.5, "forest/large_bush": 1.6,
		"forest/dead_tree": 2.0, "forest/fallen_log": 1.6, "forest/flower_red": 0.3, "forest/flower_yellow": 0.3},
	"badlands": {"forest/pine_tree": 0.15, "forest/oak_tree": 0.1, "forest/dead_tree": 3.0, "forest/boulder_lg": 2.0,
		"forest/boulder_sm": 2.0, "forest/fern": 0.2, "forest/flower_red": 0.2, "forest/flower_yellow": 0.2,
		"forest/large_bush": 0.5, "forest/small_bush": 0.5},
}
const WHEEL := [
	["rally", "Rally"], ["hold", "Hold"], ["scout", "Scout ahead"],
	["drive", "Drive"], ["flank", "Flank"], ["strike", "Strike"], ["guard", "Guard"],
]

var info = null
var home
var engine
var setup := {}                      # how the running mission was built (saved, rebuilds it on Resume)
var camp := {"renown": 0, "done": {}, "quick": {"type": "hills", "role": "leader"}}
var started := false
var result_recorded := false
var over_t: float = 0.0

var field: Control
var hud: Control
var end_dialog: Control
var grass_tex: Texture2D
var relief_tex: ImageTexture        # hill shading over the grass (_rebuild_relief)
var relief_key: String = ""
var chunks := {}                     # Vector2i -> Array of [texture, pos, scale]
var cam := Vector2.ZERO
var zoom: float = 1.0
var puffs: Array = []                # [pos, age, colour]
var banner := ""
var banner_t: float = 0.0
var step_t: float = 0.0
var music_style := ""
var music_t: float = 0.0
var _bed: Node = null                # distant pack howls, a quiet loop while hunting
var touch_pad: Control = null
var fog_tex: ImageTexture
var fog_t: float = 0.0
var wheel_open := false
var wheel_idle: float = 0.0
var howl_down: float = -1.0           # how long Howl has been held (-1 = not held)
var prev_howl := false
var prev_sense := false
var time_scale: float = 1.0
var shake: float = 0.0
var quote_i: int = 0
var quote_t: float = 0.0
var told_leader := false
# Quick Mission setup card state.
var q_type: int = 0                   # index into TYPE_ORDER; TYPE_ORDER.size() = Random
var q_role: int = 0                   # index into ROLE_ORDER
var _q_rows: VBoxContainer
var _q_blurb: Label

func _ready() -> void:
	Orientation.lock_landscape()
	preload("res://scripts/games/wolf_pack/wolf_pack_i18n.gd").install(self)
	engine = E.new()
	_migrate_old_save()
	_camp_load()
	quote_i = randi() % HELP.QUOTES.size()
	grass_tex = SpriteLib.texture("textures/floor_ground_grass")
	_build_ui()
	var m = get_node_or_null("/root/Music")
	if m and m.has_method("prepare"):
		m.prepare("calm", 0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

# ---------- campaign progress ----------

## The first slice saved a hunt without a "setup": it can't be rebuilt now, so drop it.
func _migrate_old_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var d = SaveUtil.read(SAVE_PATH)
		if not (d is Dictionary) or not d.has("setup"):
			SaveUtil.delete(SAVE_PATH)

func _camp_load() -> void:
	var d = SaveUtil.read(CAMP_PATH)
	if d is Dictionary:
		camp.renown = int(d.get("renown", 0))
		camp.done = d.get("done", {})
		var q = d.get("quick", {})
		if q is Dictionary and Data.MAP_TYPES.has(q.get("type", "")) and Data.PLAY_ROLES.has(q.get("role", "")):
			camp.quick = {"type": q.type, "role": q.role}
	var qt: String = camp.quick.type
	q_type = maxi(0, Data.TYPE_ORDER.find(qt))
	q_role = maxi(0, Data.ROLE_ORDER.find(str(camp.quick.role)))

func _camp_save() -> void:
	SaveUtil.write(CAMP_PATH, camp)

func _rank() -> int:
	return Data.rank_for(int(camp.renown))

## Index of the first campaign mission not won yet (the last one once all are).
func _next_mission() -> int:
	for i in Data.MISSIONS.size():
		if not camp.done.has(Data.MISSIONS[i].id):
			return i
	return Data.MISSIONS.size() - 1

func _stars_of(id: String) -> int:
	var d = camp.done.get(id, null)
	return int(d.get("stars", 0)) if d is Dictionary else 0

func _stars_text(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(3 - n)

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	field = Control.new()
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	field.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	field.draw.connect(_draw_field)
	add_child(field)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	add_child(hud)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	add_child(pause_btn)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.offset_left = -96
	pause_btn.offset_right = -16
	pause_btn.offset_top = 28
	pause_btn.offset_bottom = 92
	pause_btn.pressed.connect(_on_pause)
	_add_pad()

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S1 Corner Ghost; colours: dusk and pine.
		"landing": "ghost",
		"landing_style": MenuStyles,
		"title_colors": [Color("eef3f8"), Color("a8c4e0"), Color("eef3f8"), Color("c9d8e8")],
		"landing_colors": [Color("0a1020"), Color("23324a")],
		"landing_stars": 90,
		"menu_color": Color("ffd98a"),
		"help": HELP,
		"info": info,
		"accent": Color("8fb4d8"),
		"solo_heading": "Hunt",
		"subtitle": _quote_line(quote_i),
		"logo": _draw_home_logo,
		# ⚡ Quick Play = one more Quick Mission the way you chose last time.
		"modes": [{"key": "quick", "text": "⚡ Quick Mission", "sub": "A new mission, same map type and role as last time", "action": _quick_start_last}],
		"play": [
			{"text": "🐺 Campaign", "sub": "Rise through the pack, mission by mission", "action": _open_campaign, "card": true},
			{"text": "🗺 Quick Mission setup", "sub": "Pick a map type and a role", "action": _open_quick, "card": true},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"helps": [{"text": "🍖 Meal", "how": "Fills the pack's hunger bar.", "action": _help_meal}],
		"board": "none",
	})
	add_child(home)
	if info:
		add_child(info)

func _add_pad() -> void:
	if not ResourceLoader.exists(PAD_PATH):
		return
	touch_pad = load(PAD_PATH).new()
	touch_pad.layout_override = "stick_4"
	touch_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(touch_pad)
	for part in ["pause", "info"]:
		touch_pad.set_hidden(part, true)
	touch_pad.set_state("a", {"glyph": "bolt", "sub": tr("Bite")})
	touch_pad.set_state("b", {"sub": tr("Sprint")})
	touch_pad.set_state("x", {"sub": tr("Sense")})
	touch_pad.set_state("y", {"sub": tr("Howl")})
	touch_pad.visible = false

# ---------- cards: campaign, briefing, quick mission ----------

func _label(text: String, size_px: int = 22, color: Color = Color(0.9, 0.93, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _open_campaign() -> void:
	var parts: Array = home.card("🐺 " + tr("Campaign"))
	var card: Control = parts[0]
	var body: Control = parts[1]
	var r := _rank()
	var rk: Dictionary = Data.rank(r)
	var head := _label("%s: %s" % [tr("Rank"), tr(rk.name)], 34, Color("ffd98a"))
	body.add_child(head)
	var to_next := Data.renown_to_next(int(camp.renown))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 26)
	bar.show_percentage = false
	if r < Data.RANKS.size() - 1:
		var lo: int = int(rk.renown)
		var hi: int = int(Data.rank(r + 1).renown)
		bar.min_value = lo
		bar.max_value = hi
		bar.value = int(camp.renown)
		body.add_child(bar)
		body.add_child(_label(tr("Renown %d. %d more for %s.") % [int(camp.renown), to_next, tr(Data.rank(r + 1).name)], 20, Color(0.75, 0.82, 0.95)))
		var nxt: Array = []
		for g in Data.rank(r + 1).gain:
			nxt.append("• " + tr(g))
		body.add_child(_label(tr("Next rank brings:") + "\n" + "\n".join(nxt), 19, Color(0.7, 0.9, 0.7)))
	else:
		body.add_child(_label(tr("Renown %d. You are the Elder of the pack.") % int(camp.renown), 20, Color(0.75, 0.82, 0.95)))
	var have: Array = []
	for g in rk.gain:
		have.append("• " + tr(g))
	body.add_child(_label(tr("This rank:") + "\n" + "\n".join(have), 19))
	var roster: Array = []
	for ro in Data.rank(r).roster:
		roster.append(tr(E.ROLES[ro].name) + " (" + tr(_role_label(ro)) + ")")
	body.add_child(_label(tr("Your pack:") + " " + (", ".join(roster) if roster.size() > 0 else tr("Alone")), 19))
	body.add_child(HSeparator.new())
	body.add_child(_label(tr("Missions"), 28, Color("ffd98a")))
	var nxt_i := _next_mission()
	for i in Data.MISSIONS.size():
		var m: Dictionary = Data.MISSIONS[i]
		var unlocked: bool = i <= nxt_i or camp.done.has(m.id)
		var txt := "%d. %s    %s\n%s" % [i + 1, tr(m.title), _stars_text(_stars_of(m.id)) if camp.done.has(m.id) else "", tr(Data.MAPS[m.map].name)]
		if not unlocked:
			txt = "🔒 %d. %s" % [i + 1, tr(m.title)]
		var b: Button = HomeKit.neon_button(txt, HomeKit.BUTTON, 22, 76)
		b.disabled = not unlocked
		b.pressed.connect(_open_briefing.bind(i))
		body.add_child(b)
	home.show_card(card)

func _role_label(ro: String) -> String:
	return {"chaser": "Chaser", "attacker": "Striker", "scout": "Scout", "guardian": "Guardian", "leader": "Leader"}.get(ro, ro)

func _objective_text(o: Dictionary, have: int = -1) -> String:
	var need: int = int(o.get("n", o.get("pct", o.get("secs", 1))))
	var h: String = "" if have < 0 else "%d / %d" % [have, need]
	match str(o.t):
		"hunt":
			var what: String = tr(Data.SPECIES[o.sp].name) if o.has("sp") else tr("prey")
			return tr("Bring down %s: %s") % [what, h if h != "" else str(need)]
		"scout":
			return tr("Explore the land: %s%%") % (h if h != "" else str(need))
		"mark":
			return tr("Scent posts marked: %s") % (h if h != "" else str(need))
		"reach":
			return tr("Reach the Howl Point with your pack")
		"rivals":
			return tr("Drive off rival wolves: %s") % (h if h != "" else str(need))
		"defend":
			return tr("Defend the den for %s s") % (h if h != "" else str(need))
	return str(o.t)

func _open_briefing(i: int) -> void:
	var m: Dictionary = Data.MISSIONS[i]
	var parts: Array = home.card("%d. %s" % [i + 1, tr(m.title)])
	var card: Control = parts[0]
	var body: Control = parts[1]
	var column: Control = parts[2]
	body.add_child(_label(tr(Data.MAPS[m.map].name) + " · " + tr(Data.MAP_TYPES[Data.MAPS[m.map].type].name), 22, Color("a8c4e0")))
	body.add_child(_label(tr(m.brief), 24))
	body.add_child(HSeparator.new())
	body.add_child(_label(tr("Goals"), 26, Color("ffd98a")))
	for o in m.objectives:
		body.add_child(_label("🎯 " + _objective_text(o), 22))
	var par: int = int(m.par)
	body.add_child(HSeparator.new())
	body.add_child(_label("★ " + tr("Finish the mission"), 20))
	body.add_child(_label("★ " + tr("Finish in %d:%02d") % [par / 60, par % 60], 20))
	body.add_child(_label("★ " + tr("No wolf goes down"), 20))
	var rank_now := _rank()
	body.add_child(_label(tr("You go in as: %s") % tr(Data.rank(rank_now).name), 20, Color(0.75, 0.82, 0.95)))
	if camp.done.has(m.id):
		var best: float = float(camp.done[m.id].get("best", 0))
		body.add_child(_label(tr("Best: %s, %d:%02d") % [_stars_text(_stars_of(m.id)), int(best) / 60, int(best) % 60], 20, Color(0.7, 0.9, 0.7)))
	var go: Button = HomeKit.neon_button("▶ " + tr("Start"), HomeKit.GO, 30, 76)
	go.pressed.connect(_begin_campaign.bind(card, m.id))
	column.add_child(go)
	home.show_card(card)

func _begin_campaign(card: Control, id: String) -> void:
	home.close_card(card)
	home.play_now(_start_setup.bind({"kind": "campaign", "mission": id, "rank": _rank()}))

func _open_quick() -> void:
	var parts: Array = home.card("🗺 " + tr("Quick Mission"))
	var card: Control = parts[0]
	var body: Control = parts[1]
	var column: Control = parts[2]
	body.add_child(_label(tr("Pick a map type and a role. The game builds a short mission on a new map."), 22))
	body.add_child(home.section("Map type"))
	_q_rows = VBoxContainer.new()
	_q_rows.add_theme_constant_override("separation", 10)
	body.add_child(_q_rows)
	_q_blurb = _label("", 20, Color(0.75, 0.9, 0.75))
	body.add_child(_q_blurb)
	_q_refresh()
	var go: Button = HomeKit.neon_button("▶ " + tr("Start"), HomeKit.GO, 30, 76)
	go.pressed.connect(_begin_quick.bind(card))
	column.add_child(go)
	home.show_card(card)

## Rebuilds both choice rows (a toggle group per row would leave one selected in each).
func _q_refresh() -> void:
	for c in _q_rows.get_children():
		c.queue_free()
	var names1: Array = []
	var names2: Array = []
	var all_types: Array = []
	for t in Data.TYPE_ORDER:
		all_types.append(Data.MAP_TYPES[t].name)
	all_types.append("Random")
	for i in all_types.size():
		(names1 if i < 3 else names2).append(all_types[i])
	_q_rows.add_child(home.choice_row(names1, q_type if q_type < 3 else -1, _q_pick_type_a))
	_q_rows.add_child(home.choice_row(names2, q_type - 3 if q_type >= 3 else -1, _q_pick_type_b))
	_q_rows.add_child(home.section("Your role"))
	var rn: Array = []
	for ro in Data.ROLE_ORDER:
		rn.append(Data.PLAY_ROLES[ro].name)
	_q_rows.add_child(home.choice_row(rn, q_role, _q_pick_role))
	var tline := tr("Random: a different map type every time.")
	if q_type < Data.TYPE_ORDER.size():
		var ty: Dictionary = Data.MAP_TYPES[Data.TYPE_ORDER[q_type]]
		tline = "%s %s: %s" % [ty.icon, tr(ty.name), tr(ty.blurb)]
	var pr: Dictionary = Data.PLAY_ROLES[Data.ROLE_ORDER[q_role]]
	_q_blurb.text = tline + "\n" + "%s %s: %s" % [pr.icon, tr(pr.name), tr(pr.blurb)]

func _q_pick_type_a(i: int) -> void:
	q_type = i
	_q_refresh()

func _q_pick_type_b(i: int) -> void:
	q_type = i + 3
	_q_refresh()

func _q_pick_role(i: int) -> void:
	q_role = i
	_q_refresh()

func _begin_quick(card: Control) -> void:
	home.close_card(card)
	home.play_now(_start_quick.bind(q_type, q_role))

func _start_quick(type_i: int, role_i: int) -> void:
	var ty: String = Data.TYPE_ORDER[randi() % Data.TYPE_ORDER.size()] if type_i >= Data.TYPE_ORDER.size() else Data.TYPE_ORDER[type_i]
	var ro: String = Data.ROLE_ORDER[role_i]
	# The next ⚡ Quick Mission uses the same choices (a Random type stays Random).
	camp.quick = {"type": Data.TYPE_ORDER[mini(type_i, Data.TYPE_ORDER.size() - 1)], "role": ro}
	_camp_save()
	_start_setup({"kind": "quick", "type": ty, "role": ro, "seed": randi() % 100000 + 1})

## The Landing's ⚡ Quick Play: another Quick Mission with the last choices.
func _quick_start_last() -> void:
	_start_quick(q_type, q_role)

# ---------- flow ----------

func _build_world(s: Dictionary) -> void:
	if str(s.get("kind", "")) == "campaign":
		var m: Dictionary = Data.mission(str(s.mission))
		var rk := int(s.get("rank", 0))
		engine.start(Data.map_for(m), m, rk, "leader", Data.rank(rk).roster)
	else:
		var q: Dictionary = Data.quick_setup(str(s.type), str(s.role), int(s.seed))
		engine.start(q.map, q.mission, q.rank, q.role, Data.quick_roster(str(s.role)))

func _start_setup(s: Dictionary) -> void:
	SaveUtil.delete(SAVE_PATH)
	setup = s
	_build_world(s)
	_begin()

func _restart() -> void:
	if setup.is_empty():
		_quick_start_last()
	else:
		_start_setup(setup.duplicate())

func _begin() -> void:
	started = true
	result_recorded = false
	over_t = 0.0
	puffs.clear()
	wheel_open = false
	howl_down = -1.0
	time_scale = 1.0
	told_leader = false
	if is_instance_valid(end_dialog):
		end_dialog.queue_free()
	end_dialog = null
	cam = engine.hero.p
	zoom = 1.0
	music_style = ""
	music_t = 0.0
	if is_instance_valid(_bed):
		_bed.queue_free()
	_bed = SoundLib.loop(self, "wolf/howl_pack_medium", -22.0)
	chunks.clear()
	relief_key = ""
	if touch_pad:
		touch_pad.release_all()
	quote_i = (quote_i + 1) % HELP.QUOTES.size()
	quote_t = 7.0
	var first: Array = engine.mission.objectives
	var t: String = tr(engine.mission.title)
	if first.size() > 0:
		t += ": " + _objective_text(first[0])
	_show_banner(t, 4.5)

## "text" - Who. The quote is translated, the author's name is kept as it is.
func _quote_line(i: int) -> String:
	var q: Array = HELP.QUOTES[i % HELP.QUOTES.size()]
	return "\"%s\" - %s" % [tr(q[0]), tr(q[1])]

func _show_banner(t: String, secs: float = 2.2) -> void:
	banner = t
	banner_t = secs

# ---------- input ----------

func _pad_down(id: String) -> bool:
	return touch_pad != null and touch_pad.visible and touch_pad.is_down(id)

func _inputs() -> Dictionary:
	var mv := Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	var sprint := Input.is_key_pressed(KEY_SHIFT)
	var bite := Input.is_key_pressed(KEY_SPACE)
	if touch_pad:
		var v: Vector2 = touch_pad.get_vector("move")
		if v.length() > 0.05:
			mv = v
		sprint = sprint or _pad_down("b")
		bite = bite or _pad_down("a")
	if wheel_open:
		mv = Vector2.ZERO
	return {"move": mv.limit_length(1.0), "sprint": sprint, "bite": bite}

## Sense and Howl are edge / hold buttons: read them once per frame.
func _buttons(delta: float) -> void:
	var sense_now := Input.is_key_pressed(KEY_E) or _pad_down("x")
	if sense_now and not prev_sense and not wheel_open:
		if engine.sense():
			SoundLib.play(self, "wolf/snarl_grumble", -10.0)
			_show_banner(tr("Sense"), 1.0)
	prev_sense = sense_now
	var howl_now := Input.is_key_pressed(KEY_Q) or _pad_down("y")
	var leads: bool = engine.role == "leader"
	if howl_now:
		howl_down = maxf(howl_down, 0.0) + delta
		if leads and howl_down > 0.3 and not wheel_open:
			wheel_open = true
			wheel_idle = 0.0
			SoundLib.play(self, "wolf/howl_lone", -8.0)   # the command wheel opens on a howl
	elif prev_howl:
		# A tap on Howl is a Rally (design §3); a hold opened the wheel.
		if howl_down >= 0.0 and howl_down <= 0.3 and not wheel_open:
			if leads:
				_command("rally")
			elif not told_leader:
				told_leader = true
				_show_banner(tr("Sable leads the hunt: follow her calls."), 2.5)
			SoundLib.play(self, "wolf/howl_short", -4.0)
		howl_down = -1.0
	prev_howl = howl_now
	if wheel_open and not howl_now:
		wheel_idle += delta
		if wheel_idle > 4.0:
			wheel_open = false

func _command(c: String) -> void:
	if not engine.has_command(c):
		SoundLib.play(self, "ui/wrong", -8.0)
		_show_banner(tr("Unlocks at rank %s") % tr(_rank_for_command(c)), 2.0)
		return
	engine.set_command(c)
	wheel_open = false
	SoundLib.play(self, "ui/select", -6.0)
	for w in WHEEL:
		if w[0] == c:
			_show_banner(tr(w[1]), 1.4)

func _rank_for_command(c: String) -> String:
	for rk in Data.RANKS:
		if c in rk.cmds:
			return rk.name
	return Data.RANKS.back().name

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or not wheel_open:
		return
	var i: int = event.keycode - KEY_1
	if i >= 0 and i < WHEEL.size():
		_command(WHEEL[i][0])

## The wheel is chosen with a tap or click on a slice (a MouseButton only: phones send taps twice).
func _input(event: InputEvent) -> void:
	if not wheel_open or not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	var s := _wheel_slice(local)
	if s >= 0:
		_command(WHEEL[s][0])
		get_viewport().set_input_as_handled()

func _wheel_centre() -> Vector2:
	return size / 2.0 + Vector2(0, -10)

func _wheel_radius() -> float:
	return clampf(minf(size.x, size.y) * 0.32, 130.0, 230.0)

func _wheel_slice(p: Vector2) -> int:
	var d := p - _wheel_centre()
	if d.length() < _wheel_radius() * 0.28 or d.length() > _wheel_radius() * 1.25:
		return -1
	var a: float = fposmod(d.angle() + PI / 2.0, TAU)
	return int(a / (TAU / WHEEL.size())) % WHEEL.size()

# ---------- loop ----------

func _process(delta: float) -> void:
	var playing: bool = started and not engine.is_over()
	if touch_pad:
		touch_pad.visible = playing
	if not started and not engine.is_over():
		return
	delta = minf(delta, 0.05)
	_buttons(delta)
	time_scale = lerpf(time_scale, 0.3 if wheel_open else 1.0, minf(1.0, delta * 10.0))
	var sd := delta * time_scale
	_handle(engine.step(sd, _inputs()))
	banner_t = maxf(0.0, banner_t - delta)
	quote_t = maxf(0.0, quote_t - delta)
	shake = maxf(0.0, shake - delta * 2.5)
	for p in puffs:
		p[1] += delta
	puffs = puffs.filter(func(p): return p[1] < 0.7)
	var h: Dictionary = engine.hero
	if h.v.length() > 150.0:
		step_t -= delta
		if step_t <= 0.0:
			step_t = 0.3 if h.v.length() < 300.0 else 0.2
			SoundLib.play(self, "impact/footstep_grass", -22.0)
	# Camera: look 120 px ahead, pull out to 0.8 during a chase or a fight.
	var chase := false
	for e in engine.herd:
		if e.alive and e.flee and e.p.distance_to(h.p) < 750.0:
			chase = true
	for r in engine.rivals:
		if r.alive and r.p.distance_to(h.p) < 600.0:
			chase = true
	zoom = lerpf(zoom, 0.8 if chase else 1.0, minf(1.0, delta * 2.0))
	var look: Vector2 = (h.face as Vector2) * 120.0 * clampf(h.v.length() / 230.0, 0.0, 1.0)
	cam = cam.lerp(h.p + look, minf(1.0, delta * 4.0))
	var half := size / zoom / 2.0
	cam.x = clampf(cam.x, minf(half.x, engine.W / 2.0), maxf(engine.W - half.x, engine.W / 2.0))
	cam.y = clampf(cam.y, minf(half.y, engine.H / 2.0), maxf(engine.H - half.y, engine.H / 2.0))
	_stream_chunks()
	_update_music(delta, chase)
	fog_t -= delta
	if fog_t <= 0.0:
		fog_t = 0.5
		_update_fog()
	if engine.is_over():
		over_t += delta
		if over_t > 1.4 and not result_recorded:
			_game_over()
	field.queue_redraw()
	hud.queue_redraw()

func _update_music(delta: float, chase: bool) -> void:
	music_t -= delta
	if music_t > 0.0:
		return
	music_t = 1.0
	var want := "lively" if chase else "calm"
	if want != music_style:
		music_style = want
		_music("play", want, 0, 2.5)

func _handle(evs: Array) -> void:
	for e in evs:
		match e[0]:
			"bite":
				puffs.append([e[1], 0.0, Color("e8d8b0")])
				SoundLib.play(self, "impact/punch_medium", -8.0)
				SoundLib.play(self, "wolf/snarl", -6.0)
			"pounce":
				puffs.append([e[1], 0.0, Color("e8d8b0")])
				SoundLib.play(self, "impact/punch_heavy", -6.0)
				SoundLib.play(self, "wolf/snarl", -4.0)
				_show_banner(tr("Pounce!"), 1.0)
			"kick":
				puffs.append([e[1], 0.0, Color("ffcf7a")])
				SoundLib.play(self, "impact/punch_heavy", -6.0)
				SoundLib.play(self, "creature/hurt", -4.0)   # kicked or bitten
				_vibrate(60)
				shake = minf(1.0, shake + 0.5)
			"kill":
				puffs.append([e[1], 0.0, Color(1, 1, 1)])
				SoundLib.play(self, "impact/soft_heavy", -4.0)
				SoundLib.play(self, "creature/roar", -6.0)
				if info:
					info.add("Prey caught")
				_show_banner(tr("Down! The pack eats."))
			"fed":
				SoundLib.play(self, "reward/coin_short", -10.0)
			"alarm":
				SoundLib.play(self, "creature/grunt", -10.0)   # the herd is alarmed
			"down":
				SoundLib.play(self, "creature/hurt", -4.0)
				_show_banner(tr("You are down. You wake at the den."), 3.0)
				quote_i = (quote_i + 1) % HELP.QUOTES.size()
				quote_t = 6.0
				_vibrate(150)
			"wolf_down":
				SoundLib.play(self, "creature/hurt", -8.0)
				_show_banner(tr("%s is down. Rally to get the pack out.") % e[1], 2.5)
			"rally_howl":
				SoundLib.play(self, "wolf/howl_pack_medium", -6.0)
				_show_banner(tr("Rallying Howl! The pack is stronger."), 2.0)
			"post":
				SoundLib.play(self, "reward/coin_short", -6.0)
				puffs.append([e[1], 0.0, Color("ffd24a")])
				_show_banner(tr("Border marked: %d / %d") % [engine.marked_count(), engine.posts.size()], 1.6)
			"rival_off":
				SoundLib.play(self, "wolf/snarl_grumble", -6.0)
				puffs.append([e[1], 0.0, Color("e8d8b0")])
				if info:
					info.add("Rival wolves driven off")
				_show_banner(tr("A rival flees!"), 1.4)
			"wave":
				SoundLib.play(self, "wolf/howl_lone", -4.0)
				_show_banner(tr("Raiders are coming for the den!"), 2.5)
			"reached":
				SoundLib.play(self, "reward/powerup", -6.0)
				_show_banner(tr("The pack stands at the Howl Point."), 2.5)
			"win":
				SoundLib.play(self, "reward/accomplished")
			"fail":
				SoundLib.play(self, "ui/wrong")

# ---------- result, rank ----------

func _game_over() -> void:
	result_recorded = true
	started = false
	SaveUtil.delete(SAVE_PATH)
	var res: Dictionary = engine.result()
	var win: bool = res.outcome == "win"
	var msg := ""
	var buttons: Array = []
	var secs: int = int(res.time)
	if info:
		info.add("Games played")
		info.result("win" if win else "loss")
	if win:
		SoundLib.play(self, "jingles/win_succeeded")
		msg = tr("Mission complete!") + "\n" + _stars_text(int(res.stars)) + "\n" + tr("Time: %d:%02d") % [secs / 60, secs % 60]
		if str(setup.get("kind", "")) == "campaign":
			msg += _campaign_result(res, buttons)
		else:
			if info:
				info.add("Quick missions won")
			buttons = [{"text": tr("New Quick Mission"), "action": _quick_start_last},
				{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home}]
	else:
		msg = tr("Mission failed.") + "\n" + (tr("The den has fallen.") if engine.fail_reason == "den" else tr("Time ran out."))
		buttons = [{"text": tr("Try Again"), "action": _restart},
			{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home}]
	msg += "\n\n" + _quote_line(quote_i)
	if info:
		msg += "\n" + info.summary(["Prey caught", "Missions won"])
	if is_instance_valid(end_dialog):
		end_dialog.queue_free()
	end_dialog = UI.build_dialog("", buttons, true)
	add_child(end_dialog)
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	_music("stop", "")

## Pays out renown, stores the stars, and reports a promotion. Returns text for the result.
func _campaign_result(res: Dictionary, buttons: Array) -> String:
	var m: Dictionary = Data.mission(str(setup.mission))
	var first: bool = not camp.done.has(m.id)
	var gain := Data.reward_for(m, int(res.stars), first)
	var old_rank := _rank()
	camp.renown = int(camp.renown) + gain
	var prev: Dictionary = camp.done.get(m.id, {}) if camp.done.get(m.id, null) is Dictionary else {}
	var best_t: float = minf(float(prev.get("best", 1e9)), float(res.time))
	camp.done[m.id] = {"stars": maxi(int(prev.get("stars", 0)), int(res.stars)), "best": best_t}
	_camp_save()
	var new_rank := _rank()
	if info:
		info.add("Missions won")
		info.high("Rank", new_rank + 1)
	var out := "\n" + tr("Renown +%d") % gain
	if new_rank > old_rank:
		out += "\n\n" + tr("Promoted to %s!") % tr(Data.rank(new_rank).name)
		for g in Data.rank(new_rank).gain:
			out += "\n• " + tr(g)
	var idx := Data.mission_index(m.id)
	if idx + 1 < Data.MISSIONS.size():
		buttons.append({"text": tr("Next Mission"), "action": _next_from_result.bind(Data.MISSIONS[idx + 1].id)})
	else:
		out += "\n\n" + tr("The valley is yours. The howl carries on.")
	buttons.append({"text": tr("Replay"), "action": _restart})
	buttons.append({"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home})
	return out

func _next_from_result(id: String) -> void:
	_start_setup({"kind": "campaign", "mission": id, "rank": _rank()})

# ---------- map streaming ----------

## Keeps only the 3 x 3 chunks round the camera loaded (design §9). Scenery per chunk is
## generated from the map seed + chunk, so a chunk always looks the same when it comes back.
func _stream_chunks() -> void:
	var want: Array = engine.chunks_around(E.chunk_of(cam))
	for c in chunks.keys():
		if not c in want:
			chunks.erase(c)
	for c in want:
		if not chunks.has(c):
			chunks[c] = _make_chunk(c)

func _make_chunk(c: Vector2i) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector3i(c.x, c.y, engine.seed_used))
	var out: Array = []
	var mix: Dictionary = SCENERY_MIX.get(str(engine.mapd.type), {})
	for s in SCENERY:
		var tex: Texture2D = SpriteLib.texture(s[0])
		if tex == null:
			continue
		var count := int(round(float(s[2]) * float(mix.get(s[0], 1.0))))
		for i in count:
			var p := Vector2(float(c.x) * E.CHUNK + r.randf() * E.CHUNK, float(c.y) * E.CHUNK + r.randf() * E.CHUNK)
			if p.distance_to(engine.den) < 260.0 or p.distance_to(engine.landmark) < 140.0:
				continue
			var near_post := false
			for po in engine.posts:
				if p.distance_to(po.p) < 90.0:
					near_post = true
			if near_post:
				continue
			out.append([tex, p, float(s[1])])
	out.sort_custom(func(a, b): return a[1].y < b[1].y)
	return out

func _update_fog() -> void:
	var img := Image.create(engine.FOG_W, engine.FOG_H, false, Image.FORMAT_RGBA8)
	var ground: Color = Color(0.16, 0.3, 0.14) * (engine.tint as Color)
	ground.a = 1.0
	for y in engine.FOG_H:
		for x in engine.FOG_W:
			var seen: bool = engine.revealed[y * engine.FOG_W + x] == 1
			img.set_pixel(x, y, ground if seen else Color(0.03, 0.04, 0.06))
	for r in engine.mud:
		var rr: Rect2 = r
		for y in range(int(rr.position.y / 32.0), int(rr.end.y / 32.0)):
			for x in range(int(rr.position.x / 32.0), int(rr.end.x / 32.0)):
				if x < engine.FOG_W and y < engine.FOG_H and engine.revealed[y * engine.FOG_W + x] == 1:
					img.set_pixel(x, y, Color(0.35, 0.26, 0.15))
	fog_tex = ImageTexture.create_from_image(img)

# ---------- drawing ----------

## The hill shading picture for the current map: TerrainGen's shade turned into a
## dark / light veil over the grass, blown up 4x with cubic filtering so it's smooth.
func _rebuild_relief() -> void:
	relief_key = "%s:%d" % [str(engine.mapd.get("type", "")), engine.seed_used]
	if engine.hgt.is_empty():
		relief_tex = null
		return
	var gw: int = engine.TGW
	var gh: int = engine.TGH
	var src: Image = E.TerrainGen.shade_image(engine.hgt, gw, gh, engine.relief)
	var img := Image.create(gw, gh, false, Image.FORMAT_RGBA8)
	for y in gh:
		for x in gw:
			var s: float = src.get_pixel(x, y).r
			if s < 0.9:
				img.set_pixel(x, y, Color(0.02, 0.05, 0.03, clampf((0.9 - s) * 0.75, 0.0, 0.55)))
			else:
				img.set_pixel(x, y, Color(1.0, 0.97, 0.82, clampf((s - 0.9) * 0.45, 0.0, 0.22)))
	img.resize(gw * 4, gh * 4, Image.INTERPOLATE_CUBIC)
	relief_tex = ImageTexture.create_from_image(img)

func _w2s(p: Vector2) -> Vector2:
	return (p - cam) * zoom + size / 2.0

func _draw_field() -> void:
	var c := field
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 8.0
	c.draw_set_transform(off)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.08))
	if engine.hgt.is_empty():
		return
	var origin := _w2s(Vector2.ZERO)
	if grass_tex:
		c.draw_set_transform(origin + off, 0.0, Vector2(2, 2) * zoom)
		c.draw_texture_rect(grass_tex, Rect2(Vector2.ZERO, Vector2(engine.W, engine.H) / 2.0), true, engine.tint)
		c.draw_set_transform(off)
	# Hills: sunlit slopes lighter, shaded slopes and valleys darker (engine.hgt).
	if relief_key != "%s:%d" % [str(engine.mapd.get("type", "")), engine.seed_used]:
		_rebuild_relief()
	if relief_tex:
		c.draw_texture_rect(relief_tex, Rect2(origin, Vector2(engine.W, engine.H) * zoom), false)
	# Mud: slows everybody. Brown with a dashed edge, so it isn't colour alone.
	for r in engine.mud:
		var rr: Rect2 = r
		var a := _w2s(rr.position)
		var sz := rr.size * zoom
		c.draw_rect(Rect2(a, sz), Color(0.3, 0.22, 0.12, 0.75))
		var dash := 22.0 * zoom
		var x := 0.0
		while x < sz.x:
			c.draw_line(a + Vector2(x, 0), a + Vector2(minf(x + dash * 0.6, sz.x), 0), Color(0.15, 0.1, 0.05), 3.0)
			c.draw_line(a + Vector2(x, sz.y), a + Vector2(minf(x + dash * 0.6, sz.x), sz.y), Color(0.15, 0.1, 0.05), 3.0)
			x += dash
	_draw_den(c)
	_draw_landmark(c)
	for po in engine.posts:
		_draw_post(c, po)
	# Sense: scent trails behind every animal (age fades them).
	if engine.sense_t > 0.0 or engine.trails.size() > 0:
		for t in engine.trails:
			var q := _w2s(t[1])
			var al: float = clampf(1.0 - t[2] / 6.0, 0.0, 1.0) * (1.0 if engine.sense_t > 0.0 else 0.4)
			c.draw_rect(Rect2(q - Vector2(3, 3), Vector2(6, 6)), Color(1, 0.85, 0.4, 0.5 * al))
	# Y-sorted pass: tall scenery, animals and wolves by their feet.
	var view := Rect2(cam - size / zoom / 2.0 - Vector2(200, 300), size / zoom + Vector2(400, 600))
	var items: Array = []
	for ch in chunks.values():
		for s in ch:
			if view.has_point(s[1]):
				items.append([s[1].y, 0, s])
	for e in engine.herd:
		if e.alive and view.has_point(e.p):
			items.append([e.p.y, 1, e])
	for w in engine.pack:
		if view.has_point(w.p):
			items.append([w.p.y, 2, w])
	for rv in engine.rivals:
		if rv.alive and view.has_point(rv.p):
			items.append([rv.p.y, 4, rv])
	items.append([engine.hero.p.y, 3, engine.hero])
	items.sort_custom(func(a, b): return a[0] < b[0])
	var hs := _w2s(engine.hero.p)
	for it in items:
		match it[1]:
			0:
				_draw_scenery(c, it[2], hs)
			1:
				_draw_animal(c, it[2])
			2:
				var w: Dictionary = it[2]
				_draw_wolf(c, _w2s(w.p), w.v, engine.time + w.p.x * 0.01, 1.3 * zoom, w.role, false)
				if w.down_t > 0.0:
					c.draw_string(ThemeDB.fallback_font, _w2s(w.p) + Vector2(-20, -44) * zoom, "💤", HORIZONTAL_ALIGNMENT_CENTER, 40, 24, Color(1, 1, 1, 0.9))
			3:
				var hr: Dictionary = it[2]
				var sc: float = E.STAGES[engine.stage].scale
				if hr.down_t <= 0.0:
					_draw_wolf(c, _w2s(hr.p), hr.v, engine.time, 1.55 * zoom * sc, engine.role, true)
				else:
					_draw_wolf(c, _w2s(hr.p), Vector2.ZERO, 0.0, 1.55 * zoom * sc, engine.role, true)
			4:
				var rv2: Dictionary = it[2]
				_draw_wolf(c, _w2s(rv2.p), rv2.v, engine.time + rv2.p.y * 0.01, (1.55 if rv2.boss else 1.3) * zoom, "boss" if rv2.boss else "rival", false)
				_hp_bar(c, _w2s(rv2.p) + Vector2(-22, -50) * zoom, 44.0 * zoom, rv2.hp / rv2.max_hp)
	if engine.target_id != -1 and engine.command in ["drive", "flank", "strike"]:
		var tg: Dictionary = engine.animal(engine.target_id)
		if not tg.is_empty() and tg.alive:
			_draw_target(c, _w2s(tg.p))
	for p in puffs:
		var a2: float = 1.0 - p[1] / 0.7
		var sz2: float = (14.0 + p[1] * 50.0) * zoom
		var q2 := _w2s(p[0])
		c.draw_rect(Rect2(q2 - Vector2(sz2, sz2) / 2.0, Vector2(sz2, sz2)), Color(p[2], 0.4 * a2))
	c.draw_set_transform(Vector2.ZERO)
	# A soft edge darkening, and darker while Sense is on.
	if engine.sense_t > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.12, 0.28))
	# The raiders' night: a blue-black veil over the fight for the den.
	if engine.mission.has("waves"):
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.12, 0.22))

func _draw_scenery(c: CanvasItem, s: Array, hero_screen: Vector2) -> void:
	var tex: Texture2D = s[0]
	var sz: Vector2 = tex.get_size() * float(s[2]) * zoom
	var p := _w2s(s[1])
	var rect := Rect2(p - Vector2(sz.x / 2.0, sz.y), sz)
	var a := 1.0
	# Tall things fade when the hero stands behind them (design §2).
	if tex.get_height() > 40 and rect.has_point(hero_screen) and s[1].y > engine.hero.p.y:
		a = 0.4
	c.draw_texture_rect(tex, rect, false, Color(1, 1, 1, a))

func _draw_den(c: CanvasItem) -> void:
	var p := _w2s(engine.den)
	var k := zoom
	c.draw_circle(p, 170.0 * k, Color(0.25, 0.2, 0.12, 0.35))
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-70, 20) * k, p + Vector2(-50, -40) * k, p + Vector2(0, -62) * k,
		p + Vector2(50, -40) * k, p + Vector2(70, 20) * k]), Color(0.32, 0.27, 0.2))
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-26, 20) * k, p + Vector2(-20, -16) * k, p + Vector2(20, -16) * k, p + Vector2(26, 20) * k]), Color(0.06, 0.05, 0.05))
	c.draw_string(ThemeDB.fallback_font, p + Vector2(-70, 52) * k, tr("Den"), HORIZONTAL_ALIGNMENT_CENTER, 140.0 * k, int(22.0 * k), Color(1, 1, 1, 0.85))
	if engine.den_hp < 100.0:
		_hp_bar(c, p + Vector2(-50, -86) * k, 100.0 * k, engine.den_hp / 100.0)

func _draw_landmark(c: CanvasItem) -> void:
	var p := _w2s(engine.landmark)
	var k := zoom
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-90, 30) * k, p + Vector2(-50, -90) * k, p + Vector2(-10, -50) * k,
		p + Vector2(30, -150) * k, p + Vector2(90, 30) * k]), Color(0.45, 0.45, 0.43))
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(30, -150) * k, p + Vector2(60, -60) * k, p + Vector2(90, 30) * k, p + Vector2(40, 30) * k]), Color(0.33, 0.33, 0.32))
	c.draw_string(ThemeDB.fallback_font, p + Vector2(-90, 62) * k, tr("Howl Point"), HORIZONTAL_ALIGNMENT_CENTER, 180.0 * k, int(22.0 * k), Color(1, 1, 1, 0.85))
	if engine.reached:
		c.draw_arc(p + Vector2(0, 10) * k, 130.0 * k, 0, TAU, 32, Color("ffd24a"), 3.0)

## A scent post: a stake with a flag. Unmarked = grey flag with a ring; marked = gold flag with a tick.
func _draw_post(c: CanvasItem, po: Dictionary) -> void:
	var p := _w2s(po.p)
	var k := zoom
	if not Rect2(Vector2(-80, -120), size + Vector2(160, 240)).has_point(p):
		return
	var done: bool = po.marked
	c.draw_circle(p, 26.0 * k, Color(1, 0.85, 0.3, 0.18 if done else 0.1))
	c.draw_line(p, p + Vector2(0, -56) * k, Color("5a4630"), 5.0 * k)
	var flag := Color("ffd24a") if done else Color("b8bcc4")
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(2, -56) * k, p + Vector2(34, -46) * k, p + Vector2(2, -34) * k]), flag)
	if done:
		c.draw_polyline(PackedVector2Array([p + Vector2(8, -46) * k, p + Vector2(14, -41) * k, p + Vector2(24, -50) * k]), Color(0.1, 0.1, 0.1), 2.5 * k)
	else:
		c.draw_arc(p + Vector2(14, -45) * k, 5.0 * k, 0, TAU, 10, Color(0.15, 0.15, 0.15), 2.0 * k)

## A wolf from above: body, head, ears, tail, legs. role marks packmates with a shape.
func _draw_wolf(c: CanvasItem, p: Vector2, v: Vector2, t: float, k: float, role: String, hero: bool) -> void:
	var d: Vector2 = v.normalized() if v.length() > 8.0 else Vector2.RIGHT
	if not hero and v.length() <= 8.0:
		d = (engine.hero.face as Vector2)
		if role == "rival" or role == "boss":
			d = (engine.hero.p - p).normalized() if engine.hero.p != p else Vector2.LEFT
	var sd := d.orthogonal()
	var run := sin(t * 14.0) * clampf(v.length() / 200.0, 0.0, 1.0)
	var body: Color = Color("55585f") if hero else {"chaser": Color("8a6e50"), "attacker": Color("3e4047"), "scout": Color("9a9ca4"),
		"guardian": Color("6a5a48"), "leader": Color("c9c3b4"), "rival": Color("6b4a4a"), "boss": Color("3a2428")}.get(role, Color("55585f"))
	var light := Color("c4c7cf") if role != "boss" and role != "rival" else Color("a88a8a")
	c.draw_line(p + Vector2(4, 6) * k - d * 16.0 * k, p + Vector2(4, 6) * k + d * 14.0 * k, Color(0, 0, 0, 0.28), 13.0 * k)
	for s in [-1.0, 1.0]:
		c.draw_line(p + d * 8.0 * k + sd * s * 5.0 * k, p + d * (14.0 + run * 5.0 * s) * k + sd * s * 8.0 * k, body.darkened(0.3), 3.0 * k)
		c.draw_line(p - d * 9.0 * k + sd * s * 5.0 * k, p - d * (14.0 + run * 5.0 * s) * k + sd * s * 8.0 * k, body.darkened(0.3), 3.0 * k)
	c.draw_line(p - d * 16.0 * k, p + d * 12.0 * k, body, 12.0 * k)
	c.draw_line(p - d * 8.0 * k, p + d * 6.0 * k, light, 5.0 * k)
	c.draw_line(p - d * 16.0 * k, p - d * 30.0 * k + sd * run * 6.0 * k, body, 5.0 * k)
	var head := p + d * 18.0 * k
	c.draw_line(head - d * 4.0 * k, head + d * 8.0 * k, body, 10.0 * k)
	c.draw_line(head + d * 6.0 * k, head + d * 13.0 * k, light, 5.0 * k)
	for s in [-1.0, 1.0]:
		c.draw_line(head - d * 3.0 * k + sd * s * 3.0 * k, head - d * 7.0 * k + sd * s * 6.0 * k, body.darkened(0.2), 3.0 * k)
	# Role mark above the head: leader chevron, chaser triangle, attacker diamond, scout ring,
	# guardian square; rivals get a red cross so they are not told apart by colour alone.
	var m := p + Vector2(0, -34) * k
	var gold := Color("ffd24a")
	var r := 6.0 * k
	match role:
		"leader":
			c.draw_polyline(PackedVector2Array([m + Vector2(-r, -r * 0.5), m + Vector2(0, r * 0.5), m + Vector2(r, -r * 0.5)]), gold if hero else Color.WHITE, 3.0 * k)
		"chaser":
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-r, r), m + Vector2(r, r), m + Vector2(0, -r)]), Color("e8b070"))
		"attacker":
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -r), m + Vector2(r, 0), m + Vector2(0, r), m + Vector2(-r, 0)]), Color("e07a6a"))
		"scout":
			c.draw_arc(m, r, 0, TAU, 12, Color("8ad8ff"), 3.0 * k)
		"guardian":
			c.draw_rect(Rect2(m - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), Color("b0d890"))
		"rival", "boss":
			var rr: float = r * (1.4 if role == "boss" else 1.0)
			c.draw_line(m + Vector2(-rr, -rr), m + Vector2(rr, rr), Color("ff5a4a"), 3.0 * k)
			c.draw_line(m + Vector2(-rr, rr), m + Vector2(rr, -rr), Color("ff5a4a"), 3.0 * k)
	if hero and role != "leader":
		# The hero's own mark is gold in every role.
		c.draw_arc(m, r * 1.6, 0, TAU, 14, gold, 2.0 * k)

func _draw_animal(c: CanvasItem, e: Dictionary) -> void:
	var p := _w2s(e.p)
	var sp: String = e.sp
	var k: float = zoom * float({"deer": 1.15, "elk": 1.5, "bison": 1.85}.get(sp, 1.5))
	var d: Vector2 = (e.v as Vector2).normalized() if e.v.length() > 5.0 else Vector2.RIGHT.rotated(e.wander)
	var sd := d.orthogonal()
	var run := sin(engine.time * 16.0 + e.p.x) * clampf(e.v.length() / 200.0, 0.0, 1.0)
	var col: Color = {"deer": Color("a98a60"), "elk": Color("7a5231"), "bison": Color("45301f")}.get(sp, Color("7a5231"))
	if e.weak:
		col = col.lightened(0.14)
	c.draw_line(p + Vector2(5, 8) * k - d * 22.0 * k, p + Vector2(5, 8) * k + d * 20.0 * k, Color(0, 0, 0, 0.28), 14.0 * k)
	for s in [-1.0, 1.0]:
		c.draw_line(p + d * 10.0 * k + sd * s * 5.0 * k, p + d * (18.0 + run * 6.0 * s) * k + sd * s * 8.0 * k, col.darkened(0.35), 3.0 * k)
		c.draw_line(p - d * 12.0 * k + sd * s * 5.0 * k, p - d * (18.0 + run * 6.0 * s) * k + sd * s * 8.0 * k, col.darkened(0.35), 3.0 * k)
	c.draw_line(p - d * 22.0 * k, p + d * 16.0 * k, col, 14.0 * k)
	var head := p + d * 26.0 * k
	if sp == "bison":
		# A hump over the shoulders and a heavy head held low.
		c.draw_line(p + d * 4.0 * k, p + d * 12.0 * k, col.lightened(0.1), 17.0 * k)
		head = p + d * 24.0 * k
	c.draw_line(p + d * 14.0 * k, head, col.lightened(0.05), 8.0 * k)
	c.draw_line(head, head + d * 8.0 * k, col.lightened(0.15), 6.0 * k)
	var horn := Color("e8dcc0")
	for s in [-1.0, 1.0]:
		var base: Vector2 = head - d * 2.0 * k + sd * s * 3.0 * k
		if sp == "bison":
			c.draw_line(base, base + sd * s * 7.0 * k + d * 3.0 * k, Color("1c1c1c"), 3.0 * k)
		else:
			var tip: Vector2 = base + (sd * s * 0.8 - d * 0.5) * (20.0 if sp == "elk" else 11.0) * k
			c.draw_line(base, tip, horn, 2.5 * k)
			if sp == "elk":
				c.draw_line(base + (tip - base) * 0.5, base + (tip - base) * 0.5 + d * 8.0 * k, horn, 2.0 * k)
	# Weak target marker (Sense): a diamond with an exclamation. Strong ones: a small ring.
	var above := p + Vector2(0, -38) * k
	if engine.sense_t > 0.0:
		if e.weak:
			var r := 9.0 * zoom * 1.5
			c.draw_colored_polygon(PackedVector2Array([above + Vector2(0, -r), above + Vector2(r, 0), above + Vector2(0, r), above + Vector2(-r, 0)]), Color("ffd24a"))
			c.draw_line(above + Vector2(0, -r * 0.55), above + Vector2(0, r * 0.1), Color(0.1, 0.1, 0.1), 2.5 * zoom)
			c.draw_rect(Rect2(above + Vector2(-1.3, r * 0.35) * 1.0, Vector2(2.6, 2.6) * zoom), Color(0.1, 0.1, 0.1))
		else:
			c.draw_arc(above, 6.0 * zoom * 1.5, 0, TAU, 12, Color(1, 1, 1, 0.8), 2.0 * zoom)
		_stam_bar(c, p + Vector2(-22, -26) * k, 44.0 * k, e.stam / e.max_stam, e.stam <= e.max_stam * E.TIRED_AT)
	elif e.flee:
		_stam_bar(c, p + Vector2(-22, -26) * k, 44.0 * k, e.stam / e.max_stam, e.stam <= e.max_stam * E.TIRED_AT)
	if e.id == engine.hold_id:
		c.draw_rect(Rect2(p + Vector2(-30, 28) * k, Vector2(60, 7) * k), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(p + Vector2(-30, 28) * k, Vector2(60 * engine.hold_progress, 7) * k), Color("ff8a4a"))

## Stamina bar over an animal; a notch marks the "tired enough to bite" line (a mark, not just a colour).
func _stam_bar(c: CanvasItem, at: Vector2, w: float, f: float, tired: bool) -> void:
	c.draw_rect(Rect2(at, Vector2(w, 5)), Color(0, 0, 0, 0.55))
	c.draw_rect(Rect2(at, Vector2(w * clampf(f, 0.0, 1.0), 5)), Color("ff8a4a") if tired else Color("8fd8ff"))
	c.draw_line(at + Vector2(w * E.TIRED_AT, -2), at + Vector2(w * E.TIRED_AT, 7), Color.WHITE, 1.5)

func _hp_bar(c: CanvasItem, at: Vector2, w: float, f: float) -> void:
	c.draw_rect(Rect2(at, Vector2(w, 6)), Color(0, 0, 0, 0.6))
	c.draw_rect(Rect2(at, Vector2(w * clampf(f, 0.0, 1.0), 6)), Color("e86a5a"))

func _draw_target(c: CanvasItem, p: Vector2) -> void:
	var r := 34.0 * zoom + sin(engine.time * 6.0) * 3.0
	var col := Color("ffd24a")
	for i in 4:
		var a: float = i * PI / 2.0 + engine.time * 0.8
		c.draw_line(p + Vector2.RIGHT.rotated(a) * r, p + Vector2.RIGHT.rotated(a) * (r + 10.0), col, 3.0)

func _draw_hud() -> void:
	if not started and not engine.is_over():
		return
	var c := hud
	var font := ThemeDB.fallback_font
	var x := 20.0
	var y := 32.0
	var bw := 250.0
	var h: Dictionary = engine.hero
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.08, 0.62)
	sb.set_corner_radius_all(12)
	c.draw_style_box(sb, Rect2(x - 10, y - 10, bw + 20, 144))
	_bar(c, x, y, bw, tr("Health"), h.hp / h.max_hp, Color("e86a5a"))
	_bar(c, x, y + 32, bw, tr("Stamina"), h.stam / h.max_stam, Color("ffd24a"))
	var hf: float = engine.hunger / 100.0
	_bar(c, x, y + 64, bw, tr("Pack hunger"), hf, Color("5be36a") if hf > 0.3 else Color("ff4a3a"))
	var who := tr(Data.rank(engine.rank_i).name) if str(setup.get("kind", "")) == "campaign" else tr(Data.PLAY_ROLES[engine.role].name)
	c.draw_string(font, Vector2(x, y + 108), "🐺 " + who, HORIZONTAL_ALIGNMENT_LEFT, bw, 20, Color("ffd98a"))
	# Goals, top centre.
	var gy := y + 18.0
	var objs: Array = engine.objectives()
	var mo: Array = engine.mission.objectives
	for i in objs.size():
		var o: Dictionary = objs[i]
		var line := ("✔ " if o.done else "🎯 ") + _objective_text(mo[i], int(o.have))
		c.draw_string_outline(font, Vector2(0, gy), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, 8, Color(0.02, 0.04, 0.1, 0.9))
		c.draw_string(font, Vector2(0, gy), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color("8fe08f") if o.done else Color("ffd98a"))
		gy += 28.0
	if engine.mission.has("waves") or engine.den_hp < 100.0:
		var dw := 300.0
		var dx := size.x / 2.0 - dw / 2.0
		c.draw_rect(Rect2(dx, gy - 6, dw, 14), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(dx, gy - 6, dw * clampf(engine.den_hp / 100.0, 0.0, 1.0), 14), Color("e8a24a") if engine.den_hp > 35.0 else Color("ff4a3a"))
		c.draw_string(font, Vector2(dx, gy + 20), "🏠 " + tr("Den"), HORIZONTAL_ALIGNMENT_CENTER, dw, 16, Color.WHITE)
	# Current command and Sense state, bottom centre.
	var cmd_name := ""
	for w in WHEEL:
		if w[0] == engine.command:
			cmd_name = tr(w[1])
	var sense_txt := tr("Sense ready") if engine.sense_cd <= 0.0 else tr("Sense %ds") % int(ceil(engine.sense_cd))
	var cmd_line := tr("Command: %s") % cmd_name if engine.role == "leader" else tr("Sable calls: %s") % cmd_name
	var line2 := cmd_line + "   ·   " + sense_txt
	if engine.has_ability("pounce"):
		line2 += "   ·   " + (tr("Pounce ready") if engine.pounce_cd <= 0.0 else tr("Pounce %ds") % int(ceil(engine.pounce_cd)))
	c.draw_string_outline(font, Vector2(0, size.y - 28), line2, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, 8, Color(0.02, 0.04, 0.1, 0.9))
	c.draw_string(font, Vector2(0, size.y - 28), line2, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(1, 1, 1, 0.95))
	_draw_minimap(c, Vector2(x - 10, y + 146))
	if engine.hold_id != -1:
		var bx := size.x / 2.0 - 130.0
		c.draw_rect(Rect2(bx, size.y - 70, 260, 14), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(bx, size.y - 70, 260.0 * clampf(engine.hold_progress, 0.0, 1.0), 14), Color("ff8a4a"))
		c.draw_string(font, Vector2(bx, size.y - 76), tr("Holding the bite"), HORIZONTAL_ALIGNMENT_CENTER, 260, 18, Color.WHITE)
	if quote_t > 0.0 and not wheel_open:
		var qa := clampf(quote_t, 0.0, 1.0)
		var ql := _quote_line(quote_i)
		c.draw_string_outline(font, Vector2(120, size.y - 120), ql, HORIZONTAL_ALIGNMENT_CENTER, size.x - 240, 22, 10, Color(0.02, 0.04, 0.1, 0.9 * qa))
		c.draw_string(font, Vector2(120, size.y - 120), ql, HORIZONTAL_ALIGNMENT_CENTER, size.x - 240, 22, Color(1, 0.95, 0.8, qa))
	if wheel_open:
		_draw_wheel(c)
	if banner_t > 0.0 and banner != "":
		var a := clampf(banner_t, 0.0, 1.0)
		var by := size.y * 0.36
		c.draw_string_outline(font, Vector2(24, by), banner, HORIZONTAL_ALIGNMENT_CENTER, size.x - 48, 30, 12, Color(0.02, 0.04, 0.1, 0.9 * a))
		c.draw_string(font, Vector2(24, by), banner, HORIZONTAL_ALIGNMENT_CENTER, size.x - 48, 30, Color(1, 1, 1, a))

func _bar(c: CanvasItem, x: float, y: float, bw: float, label: String, f: float, col: Color) -> void:
	c.draw_string(ThemeDB.fallback_font, Vector2(x, y + 14), label, HORIZONTAL_ALIGNMENT_LEFT, 100, 16, Color(0.9, 0.9, 0.9))
	c.draw_rect(Rect2(x + 104, y + 2, bw - 104, 14), Color(1, 1, 1, 0.14))
	c.draw_rect(Rect2(x + 104, y + 2, (bw - 104) * clampf(f, 0.0, 1.0), 14), col)

func _draw_minimap(c: CanvasItem, at: Vector2) -> void:
	var w := 220.0
	var hgt: float = w * float(engine.H) / float(engine.W)
	c.draw_rect(Rect2(at - Vector2(3, 3), Vector2(w + 6, hgt + 6)), Color(0, 0, 0, 0.65))
	if fog_tex:
		c.draw_texture_rect(fog_tex, Rect2(at, Vector2(w, hgt)), false)
	var sc: float = w / float(engine.W)
	# The landmark is visible from the start (design §8); the den too.
	var lm: Vector2 = at + (engine.landmark as Vector2) * sc
	c.draw_colored_polygon(PackedVector2Array([lm + Vector2(0, -7), lm + Vector2(6, 5), lm + Vector2(-6, 5)]), Color.WHITE)
	var dn: Vector2 = at + (engine.den as Vector2) * sc
	c.draw_rect(Rect2(dn - Vector2(4, 4), Vector2(8, 8)), Color("ffd24a"))
	for po in engine.posts:
		var pp := at + (po.p as Vector2) * sc
		c.draw_rect(Rect2(pp - Vector2(2, 2), Vector2(4, 4)), Color("ffd24a") if po.marked else Color(0.8, 0.8, 0.85))
	for e in engine.herd:
		if e.alive and e.p.distance_to(engine.hero.p) < 800.0:
			c.draw_circle(at + e.p * sc, 2.5, Color("ff9a4a"))
	for r in engine.rivals:
		if r.alive and (r.p.distance_to(engine.hero.p) < 1000.0 or r.mode == "raid"):
			var rp: Vector2 = at + r.p * sc
			c.draw_line(rp + Vector2(-3, -3), rp + Vector2(3, 3), Color("ff4a3a"), 2.0)
			c.draw_line(rp + Vector2(-3, 3), rp + Vector2(3, -3), Color("ff4a3a"), 2.0)
	for wl in engine.pack:
		c.draw_circle(at + wl.p * sc, 2.5, Color("8ad8ff"))
	c.draw_circle(at + engine.hero.p * sc, 4.0, Color("ffd24a"))

func _draw_wheel(c: CanvasItem) -> void:
	var ctr := _wheel_centre()
	var rad := _wheel_radius()
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.1, 0.45))
	var mouse := get_local_mouse_position()
	var hover := _wheel_slice(mouse)
	var n := WHEEL.size()
	for i in n:
		var a0 := -PI / 2.0 + TAU * float(i) / n
		var a1 := a0 + TAU / n
		var pts := PackedVector2Array()
		for j in 11:
			pts.append(ctr + Vector2.RIGHT.rotated(lerpf(a0, a1, j / 10.0)) * rad)
		for j in range(10, -1, -1):
			pts.append(ctr + Vector2.RIGHT.rotated(lerpf(a0, a1, j / 10.0)) * rad * 0.3)
		var open: bool = engine.has_command(WHEEL[i][0])
		var on: bool = WHEEL[i][0] == engine.command
		var col := Color(0.12, 0.2, 0.32, 0.92) if open else Color(0.08, 0.09, 0.12, 0.92)
		if i == hover and open:
			col = Color(0.3, 0.45, 0.65, 0.95)
		elif on:
			col = Color(0.4, 0.34, 0.12, 0.95)
		c.draw_colored_polygon(pts, col)
		c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.35), 2.0)
		var mid := ctr + Vector2.RIGHT.rotated((a0 + a1) / 2.0) * rad * 0.65
		var label := "%d  %s" % [i + 1, tr(WHEEL[i][1])] if open else "🔒 " + tr(WHEEL[i][1])
		c.draw_string(font, mid + Vector2(-70, 8), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 20, Color.WHITE if open else Color(1, 1, 1, 0.5))
	c.draw_string(font, ctr + Vector2(-60, 6), tr("Command"), HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(1, 1, 1, 0.85))

## Landing art: a big moon over a pine forest, three wolves howling on a rock.
func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 420.0, c.size.x / 520.0)
	var o := c.size / 2.0
	var moon := Color("f4f1de")
	var mc := o + Vector2(70, -55) * k
	for i in 4:
		c.draw_circle(mc, (64.0 + i * 16.0) * k, Color(moon, 0.06))
	c.draw_circle(mc, 58.0 * k, moon)
	c.draw_circle(mc + Vector2(-16, -12) * k, 9.0 * k, Color(moon.darkened(0.08)))
	c.draw_circle(mc + Vector2(14, 16) * k, 6.0 * k, Color(moon.darkened(0.08)))
	var far := Color("142238")
	var near := Color("070c18")
	for i in 13:
		_pine(c, o + Vector2(-190 + i * 32, 95 + (i % 3) * 6) * k, (50.0 + (i * 37 % 5) * 9.0) * k, far)
	for i in 7:
		_pine(c, o + Vector2(-200 + i * 66 + (i % 2) * 18, 128) * k, (70.0 + (i * 53 % 4) * 12.0) * k, near)
	c.draw_colored_polygon(PackedVector2Array([o + Vector2(-40, 132) * k, o + Vector2(0, 40) * k, o + Vector2(30, 8) * k,
		o + Vector2(70, 2) * k, o + Vector2(118, 10) * k, o + Vector2(150, 60) * k, o + Vector2(190, 132) * k]), near)
	_howler(c, o + Vector2(-4, 34) * k, k * 0.85, near, false)
	_howler(c, o + Vector2(74, 8) * k, k * 1.05, near, false)
	_howler(c, o + Vector2(150, 40) * k, k * 0.8, near, true)
	c.draw_rect(Rect2(o + Vector2(-220, 128) * k, Vector2(440, 40) * k), near)

func _pine(c: CanvasItem, base: Vector2, h: float, col: Color) -> void:
	for j in 3:
		var w := h * (0.42 - j * 0.1)
		var y0 := base.y - h * (0.15 + j * 0.27)
		c.draw_colored_polygon(PackedVector2Array([Vector2(base.x - w, y0), Vector2(base.x, y0 - h * 0.42), Vector2(base.x + w, y0)]), col)
	c.draw_rect(Rect2(base.x - h * 0.04, base.y - h * 0.18, h * 0.08, h * 0.18), col)

func _howler(c: CanvasItem, p: Vector2, k: float, col: Color, flip: bool) -> void:
	var sx := -1.0 if flip else 1.0
	var parts := [
		[Vector2(-18, -6), Vector2(-4, -40), Vector2(8, -44), Vector2(12, -28), Vector2(8, 0), Vector2(-20, 0)],
		[Vector2(-2, -40), Vector2(8, -46), Vector2(20, -70), Vector2(11, -73)],
		[Vector2(10, -72), Vector2(20, -70), Vector2(31, -88), Vector2(27, -90), Vector2(13, -81)],
		[Vector2(10, -75), Vector2(6, -87), Vector2(15, -79)],
		[Vector2(-18, -3), Vector2(-36, -1), Vector2(-40, 3), Vector2(-16, 3)],
		[Vector2(3, -24), Vector2(9, -24), Vector2(10, 0), Vector2(4, 0)],
	]
	c.draw_circle(p + Vector2(-10 * sx, -12) * k, 13.0 * k, col)
	for part in parts:
		var pts := PackedVector2Array()
		for q in part:
			pts.append(p + Vector2(q.x * sx, q.y) * k)
		c.draw_colored_polygon(pts, col)

# ---------- skins ----------

## Classic only for v1 (design §10): a Voodoo "Spirit Hunt" visual mode is a separate art pass.
func _set_skin(_s: String) -> void:
	pass

func _current_skin() -> String:
	return "classic"

# ---------- pause / save ----------

func _on_pause() -> void:
	wheel_open = false
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or engine.is_over() or setup.is_empty():
		return
	SaveUtil.write(SAVE_PATH, {"setup": setup, "engine": engine.to_dict()})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if not (d is Dictionary) or not d.has("engine") or not d.has("setup"):
		return ""
	var s: Dictionary = d.setup
	if str(s.get("kind", "")) == "campaign":
		var m: Dictionary = Data.mission(str(s.get("mission", "")))
		if m.is_empty():
			return ""
		return tr("Campaign") + " · " + tr(m.title)
	if not Data.MAP_TYPES.has(str(s.get("type", ""))):
		return ""
	return tr("Quick Mission") + " · " + tr(Data.MAP_TYPES[s.type].name)

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if not (d is Dictionary) or not d.has("engine") or not d.has("setup"):
		_quick_start_last()
		return
	setup = d.setup
	_build_world(setup)
	engine.from_dict(d.engine)
	_begin()

# ---------- sound / helps ----------

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

## 🍖 help: the pack's hunger back to full.
func _help_meal() -> bool:
	if not started or engine.is_over():
		return false
	if engine.feed():
		SoundLib.play(self, "reward/powerup")
		return true
	return false
