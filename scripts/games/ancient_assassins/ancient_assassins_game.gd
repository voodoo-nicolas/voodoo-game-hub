extends Control

## Amazonia (was Ancient Assassins; renamed 2026-11-23, the id stays
## ancient_assassins): turn-based throwing duels in 3D, over the shoulder (portrait).
## Since the rename: aim locked on the rival (drag up / down only), power always
## the weapon's own, wind along the line, and a see-through ghost arc + angle of
## your previous throw to correct from.
## Your assassin stands on a rock island in the foreground; the rival waits on
## another island across the lagoon. Hold, drag to aim (up / down = elevation,
## sideways = direction), release: javelin, throwing axe or chakram fly in an arc
## that gravity bends and the crosswind pushes. Head ×2, body ×1, legs ×0.6.
## Six assassins, 8 Contracts, vs Computer (Easy-Expert), 2 Players on one
## phone, Online. A finishing blow plays in slow motion beside the victim.
##
## Landing (2026-11-26): own animated Landing, aa_landing.gd (owner: Single player /
## Multiplayer drawers, Shop, Game Options). Was: S4 Monument (docs/MENU_STYLES.md) -- not used by the last
## 2 games (Arrow Pop and Block Escape use S10 Bento); the hero art is a render
## of the game (games/ancient_assassins/landing_bg.jpg, tools/shot_ancient_assassins.gd).
## Shared pieces: Landing kit, GameInfo, OnlineMatch, SoundLib, Music. Own 3D:
## aa_world.gd (arena, camera, effects) + aa_character.gd (the assassins, from
## Quaternius' CC0 base characters and animations); Kenney's CC0 Retro Fantasy
## Kit for columns and trees (STANDARDS §16: no shared 3D library exists yet).

const AaEngine = preload("res://scripts/games/ancient_assassins/ancient_assassins_engine.gd")
const AaWorld = preload("res://scripts/games/ancient_assassins/aa_world.gd")
const AaCharacter = preload("res://scripts/games/ancient_assassins/aa_character.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const MenuStyles = preload("res://scripts/games/ancient_assassins/menu_styles.gd")
const HomeKit = preload("res://scripts/games/ancient_assassins/home_kit.gd")
const SoundLib = preload("res://scripts/games/ancient_assassins/sound_lib.gd")
## Not preloaded: older apps don't have them (packs run on any app version).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"
const HELP := preload("res://scripts/games/ancient_assassins/ancient_assassins_help.gd")
const SAVE_PATH := "user://ancient_assassins_save.json"
const PROGRESS_PATH := "user://ancient_assassins_progress.json"
const CLOUD_SAVE := "res://scripts/common/cloud_save.gd"  # [NEW 2026-11-24] STANDARDS §18; APK-side, load() guarded
var cloud: Node = null
const LANDING_ART := "res://games/ancient_assassins/landing_bg.jpg"

const LEVELS := ["Easy", "Normal", "Hard", "Expert"]
## The six assassins (original characters; names are data, never translated).
## c1 = her colour (outfit), c2 = trim (bracers, headband), hair3d = hairstyle,
## skin3d = skin tint over the base texture.
## Amazonia (2026-11-23): jungle warriors after the owner's reference sheet --
## red / spear, blue / blonde braid, gold / curls, green / red hair, purple / bun,
## teal / feathers; no capes, leather headbands.
const CHARS := [
	{"name": "Yara", "c1": Color("b8262c"), "c2": Color("7a4a24"), "hair3d": "long", "hair_col": Color("140e0c"), "skin3d": Color(0.86, 0.66, 0.5), "circlet": false, "cape": false},
	{"name": "Ilka", "c1": Color("2a5d9a"), "c2": Color("7a5a3a"), "hair3d": "long", "hair_col": Color("e2c06a"), "skin3d": Color(1.05, 0.93, 0.84), "circlet": false, "cape": false},
	{"name": "Amani", "c1": Color("e0a020"), "c2": Color("6a4020"), "hair3d": "short", "hair_col": Color("100a08"), "skin3d": Color(0.45, 0.32, 0.25), "circlet": true, "cape": false},
	{"name": "Rubí", "c1": Color("4f7a2a"), "c2": Color("6a4a26"), "hair3d": "long", "hair_col": Color("b8441a"), "skin3d": Color(1.0, 0.86, 0.76), "circlet": false, "cape": false},
	{"name": "Nayra", "c1": Color("5e2e86"), "c2": Color("5a3a24"), "hair3d": "buns", "hair_col": Color("1a120e"), "skin3d": Color(0.9, 0.72, 0.58), "circlet": false, "cape": false},
	{"name": "Tainá", "c1": Color("1f9a96"), "c2": Color("e0b040"), "hair3d": "parted", "hair_col": Color("120c0a"), "skin3d": Color(0.8, 0.6, 0.45), "circlet": true, "cape": false},
]
## The 8 Contracts: place, computer level, distance (m), strongest crosswind (m/s²), map style, rival health.
const CONTRACTS := [
	{"place": "The Lagoon", "level": 0, "dist": 22.0, "wind": 0.8, "style": 0, "hp": 70},
	{"place": "The Tall Grass", "level": 1, "dist": 23.0, "wind": 1.1, "style": 1, "hp": 80},
	{"place": "The Red Cliffs", "level": 1, "dist": 24.0, "wind": 1.3, "style": 2, "hp": 90},
	{"place": "The River Bend", "level": 2, "dist": 25.0, "wind": 1.5, "style": 1, "hp": 100},
	{"place": "The Stone Islands", "level": 2, "dist": 26.0, "wind": 1.7, "style": 0, "hp": 100},
	{"place": "The Sun Hills", "level": 2, "dist": 27.0, "wind": 1.9, "style": 2, "hp": 100},
	{"place": "The Waterfall", "level": 3, "dist": 28.0, "wind": 2.0, "style": 1, "hp": 100},
	{"place": "The Great Falls", "level": 3, "dist": 30.0, "wind": 2.2, "style": 2, "hp": 100},
]
## The Shop (2026-11-25): wins pay ⭐ stars (the wallet, not the Contract ★ ratings),
## spent on outfits, hair dyes and upgrades. Upgrades count only against the computer
## (Contracts and vs Computer), never in 2 Players or online; looks are yours everywhere.
## Stars per win vs the computer by level; a flawless win adds FLAWLESS_BONUS.
const WIN_STARS := [3, 5, 7, 9]
const ONLINE_WIN_STARS := 5
const LOSS_STARS := 1
const FLAWLESS_BONUS := 2
## Outfits (owner 2026-11-25): colours 50 ⭐, bikinis 75 ⭐, costumes 100 ⭐, Angel and Devil 150 ⭐.
## c1 = the cloth colour of her base outfit; "bikini" = a pattern on it (aa_character.gd:
## 0 solid, 1 three bands across, 2 stripes, 3 smileys, 4 polka dots, 5 stars & stripes) and
## no skirt; "costume" = pieces added by aa_character.gd _costume().
const OUTFITS := [
	{"id": "jaguar", "name": "Jaguar Gold", "c1": Color("d99a2b"), "c2": Color("3a2412"), "price": 50},
	{"id": "night", "name": "Midnight", "c1": Color("1c2340"), "c2": Color("9aa6b8"), "price": 50},
	{"id": "ember", "name": "Ember", "c1": Color("e0552a"), "c2": Color("2a1a12"), "price": 50},
	{"id": "orchid", "name": "Orchid", "c1": Color("c04a9a"), "c2": Color("f0d070"), "price": 50},
	{"id": "ivory", "name": "Ivory", "c1": Color("e8e0cc"), "c2": Color("8a5a2a"), "price": 50},
	{"id": "obsidian", "name": "Obsidian", "c1": Color("222226"), "c2": Color("d4a840"), "price": 50},
	{"id": "bk_argentina", "name": "Bikini: Argentina", "tier": "Bikinis", "c1": Color("75aadb"), "price": 75, "bikini": {"pattern": 2, "cols": [Color("75aadb"), Color("ffffff"), Color("75aadb")]}},
	{"id": "bk_usa", "name": "Bikini: USA", "tier": "Bikinis", "c1": Color("b22234"), "price": 75, "bikini": {"pattern": 5, "cols": [Color("3c3b6e"), Color("b22234"), Color("ffffff")]}},
	{"id": "bk_brazil", "name": "Bikini: Brazil", "tier": "Bikinis", "c1": Color("009c3b"), "price": 75, "bikini": {"pattern": 4, "cols": [Color("009c3b"), Color("ffdf00"), Color("002776")]}},
	{"id": "bk_spain", "name": "Bikini: Spain", "tier": "Bikinis", "c1": Color("c60b1e"), "price": 75, "bikini": {"pattern": 2, "cols": [Color("c60b1e"), Color("ffc400"), Color("c60b1e")]}},
	{"id": "bk_italy", "name": "Bikini: Italy", "tier": "Bikinis", "c1": Color("009246"), "price": 75, "bikini": {"pattern": 1, "cols": [Color("009246"), Color("ffffff"), Color("ce2b37")]}},
	{"id": "bk_france", "name": "Bikini: France", "tier": "Bikinis", "c1": Color("0055a4"), "price": 75, "bikini": {"pattern": 1, "cols": [Color("0055a4"), Color("ffffff"), Color("ef4135")]}},
	{"id": "bk_germany", "name": "Bikini: Germany", "tier": "Bikinis", "c1": Color("000000"), "price": 75, "bikini": {"pattern": 2, "cols": [Color("111111"), Color("dd0000"), Color("ffce00")]}},
	{"id": "bk_jamaica", "name": "Bikini: Jamaica", "tier": "Bikinis", "c1": Color("009b3a"), "price": 75, "bikini": {"pattern": 2, "cols": [Color("009b3a"), Color("fed100"), Color("111111")]}},
	{"id": "bk_smiley", "name": "Bikini: Smileys", "tier": "Bikinis", "c1": Color("ff5fa8"), "price": 75, "bikini": {"pattern": 3, "cols": [Color("ff5fa8"), Color("ffd83a"), Color("2a1a10")]}},
	{"id": "bk_smiley_night", "name": "Bikini: Night Smileys", "tier": "Bikinis", "c1": Color("141418"), "price": 75, "bikini": {"pattern": 3, "cols": [Color("141418"), Color("ffd83a"), Color("141418")]}},
	{"id": "bk_polka", "name": "Bikini: Polka Dots", "tier": "Bikinis", "c1": Color("e02040"), "price": 75, "bikini": {"pattern": 4, "cols": [Color("e02040"), Color("ffffff"), Color("ffffff")]}},
	{"id": "bk_hotpink", "name": "Bikini: Hot Pink", "tier": "Bikinis", "c1": Color("ff2d8a"), "price": 75, "bikini": {"pattern": 0}},
	{"id": "bk_white", "name": "Bikini: White", "tier": "Bikinis", "c1": Color("f4f2ee"), "price": 75, "bikini": {"pattern": 0}},
	{"id": "bk_black", "name": "Bikini: Black", "tier": "Bikinis", "c1": Color("141418"), "price": 75, "bikini": {"pattern": 0}},
	{"id": "bk_turquoise", "name": "Bikini: Turquoise", "tier": "Bikinis", "c1": Color("1fc8c0"), "price": 75, "bikini": {"pattern": 0}},
	{"id": "bk_gold", "name": "Bikini: Gold", "tier": "Bikinis", "c1": Color("e8b84a"), "price": 75, "bikini": {"pattern": 0}},
	{"id": "maid", "name": "Sexy Maid", "tier": "Costumes", "c1": Color("16161a"), "price": 100, "costume": "maid"},
	{"id": "nurse", "name": "Sexy Nurse", "tier": "Costumes", "c1": Color("f4f2ee"), "price": 100, "costume": "nurse"},
	{"id": "cop", "name": "Sexy Cop", "tier": "Costumes", "c1": Color("121216"), "price": 100, "costume": "cop"},
	{"id": "secretary", "name": "Sexy Secretary", "tier": "Costumes", "c1": Color("f4f2ee"), "price": 100, "costume": "secretary"},
	{"id": "angel", "name": "Sexy Angel", "tier": "Legendary", "c1": Color("fbfaf6"), "price": 150, "costume": "angel"},
	{"id": "devil", "name": "Sexy Devil", "tier": "Legendary", "c1": Color("c01818"), "price": 150, "costume": "devil"},
]
const HAIR_DYES := [
	{"id": "silver", "name": "Silver", "col": Color("c8ccd4"), "price": 15},
	{"id": "fire", "name": "Fire Red", "col": Color("c2361c"), "price": 15},
	{"id": "honey", "name": "Honey", "col": Color("d8a04a"), "price": 15},
	{"id": "violet", "name": "Violet", "col": Color("6a3aa8"), "price": 20},
]
## Upgrades: per level +5 % (edge: damage dealt; hide: damage taken off) or +1 axe and chakram (quiver).
const UPGRADES := [
	{"id": "edge", "name": "🗡 Sharp Edges", "desc": "+5% damage per level", "prices": [20, 40, 60]},
	{"id": "hide", "name": "🛡 Jaguar Hide", "desc": "−5% damage taken per level", "prices": [20, 40, 60]},
	{"id": "quiver", "name": "🎒 Full Quiver", "desc": "+1 axe and +1 chakram per level", "prices": [30, 60]},
]
const WEAPON_ICONS := ["🗡", "🪓", "⭕"]
const GOLD := Color("ffc24a")
const P_BLUE := Color("2f8cff")
const P_RED := Color("ff3b3b")
## Drag sensitivity: degrees per pixel (the screen's width is ~720 px).
const YAW_PER_PX := 0.06
const PITCH_PER_PX := 0.09
const HOLD_MIN := 0.18     # a shorter touch is not a throw

var info = null      # GameInfo; null on apps without it
var home             # HomeKit
var online = null    # OnlineMatch; null on apps without it
var engine
var world            # AaWorld
var view3d: SubViewport
var skin := "classic"
var mode := "cpu"    # cpu, contract, 2p, online
var cpu_level := 1
var contract := 0
var my_char := 0
var my_seat := 0     # online: 0 = host, 1 = guest
var progress := {"stars": [0, 0, 0, 0, 0, 0, 0, 0], "char": 0,
	"wallet": 0, "earned": 0, "owned": [], "outfit": "", "hair": "", "up": {}}
var shop_btn: Button
var started := false
var result_recorded := false
var phase := "aim"   # aim, cpu, fly, settle, over, wait (online: the other phone)
var phase_t := 0.0
var cpu_plan: Dictionary = {}
var cpu_ready := false
var held: Dictionary = {}
var holding := false
var hold_t := 0.0
var drag_from := Vector2.ZERO
var aim_from := Vector2.ZERO     # (yaw, pitch) when the finger went down
var eagle := false
var turn_snap: Dictionary = {}
var pending_state = null
## Kill cam: a throw that will finish someone slows time and closes in.
var kill_target := -1
var tscale := 1.0
var slow_t := 0.0
var kill_zoom := 0.0
var hurt := [0.0, 0.0]
var throw_t := [9.0, 9.0]
var floats: Array = []    # [text, world pos, age, color]
var banner := ""
var banner_t := 0.0
var red_flash := 0.0
var shake := 0.0
## Look (2026-11-23 visual pass): fonts, the health bars' trailing "ghost",
## bar shakes, a brief freeze on every hit, banner timing.
const TITLE_FONT := "res://games/ancient_assassins/title.ttf"     # Cinzel Decorative Black (OFL)
const UI_FONT := "res://games/ancient_assassins/cinzel.ttf"       # Cinzel (OFL), variable weight
var title_font: Font
var ui_font: Font
var ui_bold: Font
var hp_disp := [100.0, 100.0]
var hp_ghost := [100.0, 100.0]
var bar_shake := [0.0, 0.0]
var hitstop := 0.0
var banner_age := 0.0
var aim_disp := 15.0
var stars_t := -1.0
var end_title: Label
var end_stars := 0

var touch: Control
var hud: Control
var pause_btn: Button
var weapon_row: HBoxContainer
var weapon_btns: Array = []
var end_panel: Control
var end_label: Label
var end_next: Button
var results_chip: Button
var picker_view: SubViewport
var picker_char: Node3D

func _ready() -> void:
	preload("res://scripts/games/ancient_assassins/ancient_assassins_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = AaEngine.new()
	_load_progress()
	if ResourceLoader.exists(CLOUD_SAVE):
		cloud = load(CLOUD_SAVE).new()
		cloud.setup("ancient_assassins", PROGRESS_PATH, _progress_score, _load_progress)
		add_child(cloud)
	my_char = int(progress.get("char", 0))
	engine.reset(-1, {"chars": [my_char, (my_char + 1) % CHARS.size()]})
	_build_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	# The 3D arena fills the screen; the HUD floats on top.
	var vc := SubViewportContainer.new()
	vc.stretch = true
	vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vc)
	vc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_fonts()
	view3d = SubViewport.new()
	view3d.own_world_3d = true
	view3d.msaa_3d = Viewport.MSAA_2X
	vc.add_child(view3d)
	world = AaWorld.new()
	view3d.add_child(world)
	world.setup(engine, _defs(), false)
	world.snap_camera(0)
	# A soft vignette over the 3D view: draws the eye to the middle.
	var vig := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.45)
	gt.fill_to = Vector2(1.05, 1.0)
	var vg := Gradient.new()
	vg.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	vg.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.05), Color(0, 0, 0, 0.42)])
	gt.gradient = vg
	vig.texture = gt
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	touch = Control.new()
	touch.mouse_filter = Control.MOUSE_FILTER_STOP
	touch.gui_input.connect(_on_touch)
	add_child(touch)
	touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	pause_btn = Button.new()
	pause_btn.text = "II"
	_style_button(pause_btn, false, 22, 26)
	pause_btn.custom_minimum_size = Vector2(52, 52)
	pause_btn.position = Vector2(12, 32)
	pause_btn.pressed.connect(_on_pause)
	add_child(pause_btn)

	var wm := MarginContainer.new()
	wm.add_theme_constant_override("margin_bottom", 22)
	add_child(wm)
	wm.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	wm.grow_vertical = Control.GROW_DIRECTION_BEGIN
	wm.grow_horizontal = Control.GROW_DIRECTION_BOTH
	weapon_row = HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 12)
	wm.add_child(weapon_row)
	for w in AaEngine.WEAPONS.size():
		var b := Button.new()
		_style_button(b, false, 22, 32)
		b.custom_minimum_size = Vector2(98, 64)
		b.pivot_offset = Vector2(49, 32)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_weapon.bind(w))
		weapon_row.add_child(b)
		weapon_btns.append(b)

	_build_end_panel()

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online = load(ONLINE_MATCH_PATH).new("ancient_assassins", tr("Amazonia"), _online_state)
		online.started.connect(_on_online_started)
		online.remote_move.connect(_on_remote_move)
		online.remote_state.connect(_on_remote_state)
		online.remote_new_game.connect(_on_remote_new_game)
		online.status_changed.connect(_update_ui)
		add_child(online)
	var modes: Array = [
		{"text": "📜 Contracts", "sub": "8 rivals, each tougher than the last", "key": "contract", "action": _start_contract},
	]
	for i in LEVELS.size():
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard", "👑 Expert"][i], "row": "cpu",
			"key": "cpu_%d" % i, "action": _new_vs_cpu.bind(i)})
	modes.append({"text": "👥 2 Players", "sub": "Take turns on one phone", "multi": true, "key": "2p", "action": _new_two_player})
	if online:
		modes.append({"text": "🌐 Online", "sub": "Fight a friend on another phone", "multi": true, "key": "online", "action": online.open_lobby})
	var cfg := {
		# Menu style (docs/MENU_STYLES.md): was S4 Monument; since 2026-11-26 the game's own
		# animated Landing (aa_landing.gd, owner's four rows). Sunlit gold + crimson kept.
		#"landing": "monument",
		#"landing_style": MenuStyles,
		"landing": "amazonia",
		"landing_style": load("res://scripts/games/ancient_assassins/aa_landing.gd"),
		"title_font": TITLE_FONT,
		"title_colors": [Color("ffd77a"), Color("e8452f")],
		"landing_colors": [Color("0d2a44"), Color("2f78d0")],
		"menu_color": GOLD,
		"help": HELP,
		"info": info,
		"accent": GOLD,
		"solo_heading": "Single player",
		"subtitle": "Hold, aim, release. Mind the wind.",
		"modes": modes,
		# Own animated Landing (owner, 2026-11-26): aa_landing.gd. The char picker moved
		# from the setup screen ("extra") into ⚙ Game Options, with the difficulty.
		"options": _add_game_options,
		"aa_shop": _open_shop,
		"aa_wallet": _wallet,
		"aa_quick": _quick_key,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"helps": [{"text": "🦅 Eagle Eye", "how": "Shows the whole flight of your throw this turn, wind included (not online).", "action": _help_eagle}],
		"board": "Wins",
		"board_note": "Fights won against the computer, Contracts included.",
		"online": online,
	}
	if ResourceLoader.exists(LANDING_ART):
		cfg["art"] = LANDING_ART
		cfg["landing_art"] = true          # the render is the hero art: barely dimmed
		cfg["landing_art_alpha"] = 0.8   # was 0.92: the painted art is busier than the old render
	home = HomeKit.new(cfg)
	add_child(home)
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())  # older kits used it; the kit frees it

func _defs() -> Array:
	var mine := my_seat if _is_online() else 0
	var out: Array = []
	for i in 2:
		var d: Dictionary = CHARS[int(engine.fighters[i].char)]
		out.append(_dressed(d) if i == mine else d)
	return out

## A character with the outfit and hair dye picked in the Shop (only on this phone).
## `look` ({"outfit": id} / {"hair": id}) overrides what she wears: the Shop's try-on.
func _dressed(d: Dictionary, look: Dictionary = {}) -> Dictionary:
	var o := _find(OUTFITS, str(look.get("outfit", progress.get("outfit", ""))))
	var h := _find(HAIR_DYES, str(look.get("hair", progress.get("hair", ""))))
	if o.is_empty() and h.is_empty():
		return d
	var c := d.duplicate()
	if not o.is_empty():
		c["c1"] = o.c1
		c["c2"] = o.get("c2", d.c2)
		c["bikini"] = o.get("bikini", {})
		c["costume"] = o.get("costume", "")
	if not h.is_empty():
		c["hair_col"] = h.col
	return c

func _find(list: Array, id: String) -> Dictionary:
	for it in list:
		if it.id == id:
			return it
	return {}

func _build_end_panel() -> void:
	end_panel = ColorRect.new()
	(end_panel as ColorRect).color = Color(0, 0, 0, 0.45)
	end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	end_panel.visible = false
	# Has its own "👁 See field" + "📋 Results" (STANDARDS §6b): tell GameInfo's
	# safety net (APK 0.41.1+) not to add a second "See board".
	end_panel.set_meta("_tamed", true)
	add_child(end_panel)
	# Docked low, so the winner (front view, centre) stays in sight.
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	m.grow_vertical = Control.GROW_DIRECTION_BEGIN
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	m.add_theme_constant_override("margin_bottom", 26)
	end_panel.add_child(m)
	var pc := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.07, 0.05, 0.04, 0.88)
	ps.border_color = Color(GOLD, 0.85)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(18)
	ps.shadow_color = Color(0, 0, 0, 0.5)
	ps.shadow_size = 18
	ps.set_content_margin_all(20)
	pc.add_theme_stylebox_override("panel", ps)
	m.add_child(pc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	pc.add_child(box)
	end_title = Label.new()
	end_title.add_theme_font_size_override("font_size", 44)
	if title_font:
		end_title.add_theme_font_override("font", title_font)
	end_title.add_theme_color_override("font_color", GOLD)
	end_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	end_title.add_theme_constant_override("outline_size", 8)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(end_title)
	var stars_box := Control.new()
	stars_box.name = "Stars"
	stars_box.draw.connect(_draw_end_stars.bind(stars_box))
	box.add_child(stars_box)
	end_label = Label.new()
	end_label.add_theme_font_size_override("font_size", 22)
	if ui_bold:
		end_label.add_theme_font_override("font", ui_bold)
	end_label.add_theme_color_override("font_color", Color("f3e6c8"))
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(end_label)
	end_next = HomeKit.neon_button(tr("Play Again"), HomeKit.GO, 26, 62)
	end_next.pressed.connect(_on_end_next)
	box.add_child(end_next)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	box.add_child(r)
	var see := HomeKit.neon_button(tr("👁 See field"), HomeKit.BUTTON, 22, 56)
	see.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	see.pressed.connect(_see_field)
	r.add_child(see)
	var hb := HomeKit.neon_button(tr("🏠 Home"), HomeKit.BUTTON, 22, 56)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.pressed.connect(_go_home)
	r.add_child(hb)
	results_chip = HomeKit.neon_button(tr("📋 Results"), GOLD, 22, 56)
	results_chip.custom_minimum_size = Vector2(190, 56)
	add_child(results_chip)
	results_chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	results_chip.position.y -= 30
	results_chip.visible = false
	results_chip.pressed.connect(_show_results)

# ---------- setup: pick your assassin (a turning 3D preview) ----------

## ⚙ Game Options (owner, 2026-11-26): your amazon (turning 3D preview + six names)
## and the single-player difficulty (Quick Play's level), above the kit's usual options.
func _add_game_options(box: VBoxContainer) -> void:
	_add_char_picker(box)
	box.add_child(home.section("Single player difficulty"))
	box.add_child(home.choice_row(["🙂 Easy", "😐 Normal", "😈 Hard", "👑 Expert"], int(progress.get("level", 1)), _pick_level))
	var n := HomeKit.label(tr("Quick Play fights the computer at this level."), 20, Color(1, 1, 1, 0.7))
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(n)

func _pick_level(i: int) -> void:
	progress["level"] = i
	_save_progress()

func _wallet() -> int:
	return int(progress.get("wallet", 0))

func _quick_key() -> String:
	return "cpu_%d" % int(progress.get("level", 1))

func _add_char_picker(box: VBoxContainer) -> void:
	box.add_child(home.section("Your amazon"))
	_preview_box(box, 300)
	# Two rows of three names (six don't fit across a phone).
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	var group := ButtonGroup.new()
	for i in CHARS.size():
		var b := HomeKit.neon_button(str(CHARS[i].name), HomeKit.BUTTON, 22, 54)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == my_char
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if home.has_method("_style_toggle"):
			home._style_toggle(b, HomeKit.BUTTON)   # the kit's picked look, as its own choice rows
		b.pressed.connect(_pick_char.bind(i))
		grid.add_child(b)

## A turning 3D preview of your amazon (Options and the Shop); sets picker_view.
func _preview_box(parent: Control, h: float) -> Control:
	var vc := SubViewportContainer.new()
	vc.stretch = true
	vc.custom_minimum_size = Vector2(0, h)
	vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(vc)
	picker_view = SubViewport.new()
	picker_view.own_world_3d = true
	picker_view.transparent_bg = true
	picker_view.msaa_3d = Viewport.MSAA_2X
	vc.add_child(picker_view)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.85, 0.95)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = e
	picker_view.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 25, 0)
	sun.light_energy = 1.2
	picker_view.add_child(sun)
	var rim := DirectionalLight3D.new()   # a warm rim from behind
	rim.rotation_degrees = Vector3(-15, 200, 0)
	rim.light_energy = 1.6
	rim.light_color = Color("ffb877")
	picker_view.add_child(rim)
	var disc := MeshInstance3D.new()       # a gold plinth ring under her feet
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	tm.rings = 40
	disc.mesh = tm
	disc.scale = Vector3(1, 0.15, 1)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color("e8b84a")
	dm.metallic = 0.8
	dm.roughness = 0.3
	dm.emission_enabled = true
	dm.emission = Color("ffb84a") * 0.4
	disc.material_override = dm
	picker_view.add_child(disc)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, 3.1)
	cam.fov = 40
	picker_view.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0))
	_show_picker_char()
	return vc

## `look` = an outfit / hair dye to try on (the Shop's preview), else what she wears.
func _show_picker_char(look: Dictionary = {}) -> void:
	if picker_view == null or not is_instance_valid(picker_view):
		return
	weapon_row.visible = kill_zoom < 0.05 and world.intro_t < 0.0
	if picker_char and is_instance_valid(picker_char):
		picker_char.queue_free()
	picker_char = AaCharacter.new()
	picker_view.add_child(picker_char)
	picker_char.build(_dressed(CHARS[my_char], look), skin == "voodoo")
	picker_char.set_weapon(0, world.weapon_mesh)
	picker_char.play("ready", 0.0)

func _pick_char(i: int) -> void:
	my_char = i
	progress["char"] = i
	_save_progress()
	_show_picker_char()

func _update_ui() -> void:
	if engine.fighters.is_empty():
		return
	var mine := phase == "aim" and _my_turn()
	var f: Dictionary = engine.fighters[engine.turn]
	for w in weapon_btns.size():
		var b: Button = weapon_btns[w]
		var ammo: int = f.ammo[w]
		b.text = WEAPON_ICONS[w] + " " + ("∞" if ammo < 0 else str(ammo))
		b.disabled = not mine or ammo == 0
	_style_weapons()
	var tw := weapon_row.create_tween()
	tw.tween_property(weapon_row, "modulate:a", (1.0 if mine else 0.3) if phase != "over" else 0.0, 0.25)
	hud.queue_redraw()

# ---------- flow ----------

func _start_contract() -> void:
	mode = "contract"
	contract = _next_contract()
	_restart()

func _new_vs_cpu(level: int) -> void:
	mode = "cpu"
	cpu_level = level
	_restart()

func _new_two_player() -> void:
	mode = "2p"
	_restart()

func _next_contract() -> int:
	var st: Array = progress.stars
	for i in st.size():
		if int(st[i]) == 0:
			return i
	for i in st.size():
		if int(st[i]) < 3:
			return i
	return st.size() - 1

func _rival_char() -> int:
	return (my_char + 1 + (contract if mode == "contract" else 0)) % CHARS.size()

func _restart() -> void:
	if _is_online():
		online.new_game()
		if online.is_host():
			_online_reset()
		else:
			_wait_for_host()
		return
	SaveUtil.delete(SAVE_PATH)
	var opts := {"chars": [my_char, _rival_char()]}
	if _vs_cpu():   # Shop upgrades: against the computer only
		opts.merge({"pow": [100 + 5 * _up("edge"), 100], "armor": [5 * _up("hide"), 0], "extra_ammo": [_up("quiver"), 0]})
	if mode == "contract":
		var c: Dictionary = CONTRACTS[contract]
		opts.merge({"dist": c.dist, "wind_max": c.wind, "style": c.style, "hp": [AaEngine.MAX_HP, c.hp]})
		cpu_level = int(c.level)
	engine.reset(-1, opts)
	_begin()
	if mode == "contract":
		_show_banner(tr("Contract %d of 8") % (contract + 1) + "\n" + tr(CONTRACTS[contract].place))

func _begin() -> void:
	_reset_fx()
	_music("play", "lively", 2)
	_start_turn()
	world.snap_camera(_view_seat())
	_start_intro()

## The VS card over a camera flyover from the rival to your shoulder; a tap skips it.
func _start_intro() -> void:
	world.start_intro(_view_seat())
	_sound("voice/fight", -4.0)

## A fresh fight on screen: the arena and assassins rebuilt, effects cleared.
func _reset_fx() -> void:
	started = true
	result_recorded = false
	kill_target = -1
	tscale = 1.0
	slow_t = 0.0
	kill_zoom = 0.0
	floats.clear()
	held.clear()
	holding = false
	hurt = [0.0, 0.0]
	throw_t = [9.0, 9.0]
	end_panel.visible = false
	results_chip.visible = false
	world.rebuild(_defs())
	world.hide_projectile()
	world.celebrate(0, false)
	hp_disp = [float(engine.fighters[0].hp), float(engine.fighters[1].hp)]
	hp_ghost = hp_disp.duplicate()
	bar_shake = [0.0, 0.0]
	hitstop = 0.0
	stars_t = -1.0

func _is_online() -> bool:
	return online != null and online.is_online()

func _vs_cpu() -> bool:
	return mode == "cpu" or mode == "contract"

func _my_turn() -> bool:
	if _is_online():
		return engine.turn == my_seat and online.can_act(true)
	return mode == "2p" or engine.turn == 0

## Whose shoulder the camera is over: this phone's player, or in 2 Players the
## one throwing.
func _view_seat() -> int:
	if _is_online():
		return my_seat
	if mode == "2p":
		if not engine.shot.is_empty():
			return int(engine.shot.owner)
		return engine.turn
	return 0

func _name(i: int) -> String:
	return str(CHARS[int(engine.fighters[i].char)].name)

func _who(i: int) -> String:
	if _is_online():
		return tr("You") if i == my_seat else online.opponent_name()
	if _vs_cpu():
		return tr("You") if i == 0 else tr("Computer")
	return tr("Player %d") % (i + 1)

func _start_turn() -> void:
	eagle = false
	holding = false
	turn_snap = engine.snapshot()
	if engine.is_over():
		_game_over()
		return
	for i in 2:
		world.chars[i].set_weapon(int(engine.fighters[i].weapon) if i == engine.turn else 0, world.weapon_mesh)
	if _is_online():
		phase = "aim" if engine.turn == my_seat else "wait"
		if phase == "aim":
			_show_banner(tr("Your turn"))
	elif _vs_cpu() and engine.turn == 1:
		phase = "cpu"
		phase_t = 0.0
		cpu_plan = {}
		cpu_ready = false
	else:
		phase = "aim"
		if mode == "2p":
			_show_banner(tr("%s's turn") % _who(engine.turn))
	_update_ui()

func _show_banner(text: String) -> void:
	banner = text
	banner_t = 1.8
	banner_age = 0.0

func _on_weapon(w: int) -> void:
	if phase != "aim" or not _my_turn():
		return
	if engine.pick_weapon(engine.turn, w):
		_sound("sword/draw_rpg", -6.0)
		world.chars[engine.turn].set_weapon(w, world.weapon_mesh)
	_update_ui()

func _throw() -> void:
	held.clear()
	holding = false
	var i: int = engine.turn
	var w: int = engine.fighters[i].weapon
	if engine.fighters[i].ammo[w] == 0:
		w = 0
	kill_target = -1
	var r: Dictionary = engine.predict(i, engine.yaw_of(i), engine.angle_of(i), w)
	if r.f >= 0 and r.f != i:
		var dmg: int = engine.damage(i, r.f, AaEngine.WEAPONS[w], r.zone)
		if dmg >= int(engine.fighters[r.f].hp):
			kill_target = r.f
	engine.throw()
	throw_t[i] = 0.0
	world.chars[i].play("throw", 0.08, true)
	world.chars[i].queue_after("idle")
	world.chars[i].set_weapon(-1, world.weapon_mesh)
	world.show_projectile(w)
	if w == 1:
		_sound("sword/swing_axe", -2.0)
	else:
		_sound("sword/swing_katana", -2.0)
	phase = "fly"
	_update_ui()

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_kill_cam(delta)
	var real := delta
	delta *= tscale
	if hitstop > 0.0:   # a few frames' freeze on a hit: the blow lands
		hitstop -= real
		delta *= 0.04
	banner_age += real
	for i in 2:
		if engine.fighters.size() == 2:
			var hp := float(engine.fighters[i].hp)
			hp_disp[i] = move_toward(hp_disp[i], hp, real * 160.0)
			hp_ghost[i] = move_toward(hp_ghost[i], hp_disp[i], real * (12.0 if hp_ghost[i] - hp_disp[i] < 30.0 else 60.0))
		bar_shake[i] = maxf(0.0, bar_shake[i] - real * 2.5)
	if engine.fighters.size() == 2:
		aim_disp = lerpf(aim_disp, engine.angle_of(engine.turn), minf(1.0, real * 14.0))
	weapon_row.visible = kill_zoom < 0.05 and world.intro_t < 0.0
	if picker_char and is_instance_valid(picker_char):
		picker_char.rotation.y += real * 0.5
	if stars_t >= 0.0:
		stars_t += real
		var sb := end_panel.find_child("Stars", true, false)
		if sb:
			sb.queue_redraw()
	if not started:
		world.tick(real, {"view": 0})
		return
	banner_t = maxf(0.0, banner_t - real)
	red_flash = maxf(0.0, red_flash - real * 1.5)
	shake = maxf(0.0, shake - real * 3.0)
	for i in 2:
		hurt[i] = maxf(0.0, hurt[i] - delta)
		throw_t[i] += delta
	for f in floats:
		f[2] += real
	floats = floats.filter(func(f): return f[2] < 1.4)
	if holding:
		hold_t += real
	var in_intro: bool = world.intro_t >= 0.0
	match "intro" if in_intro else phase:
		"intro":
			pass   # the flyover: nobody acts yet
		"aim":
			if _my_turn():
				_keys(real)
		"cpu":
			_cpu_step(delta)
		"fly":
			var shot_v: Vector3 = engine.shot.v if not engine.shot.is_empty() else Vector3.ZERO
			var shot_w: int = engine.shot.w if not engine.shot.is_empty() else 0
			for ev in engine.step(delta):
				_on_landed(ev, shot_v, shot_w)
			if engine.shot.is_empty():
				world.hide_projectile()
				phase = "settle"
				phase_t = 1.4   # was 0.9: the chase cam holds on where it landed
		"settle":
			phase_t -= delta
			if phase_t <= 0.0:
				_after_throw()
	_animate()
	var aiming := -1
	if (phase == "aim" and _my_turn() and (holding or not held.is_empty() or eagle)) or (phase == "cpu" and cpu_ready):
		aiming = engine.turn
	world.view3d_shake = shake
	world.tick(real, {"view": _view_seat(), "aiming": aiming, "show_ribbon": phase == "aim" and aiming >= 0,
		"eagle": eagle, "kill": kill_target, "zoom": kill_zoom,
		"chase": phase in ["fly", "settle"] and not engine.is_over(),
		"ghost": engine.turn if phase == "aim" and _my_turn() else -1,
		"winner": engine.winner if phase == "over" and kill_zoom <= 0.01 else -1})
	hud.queue_redraw()

## Each assassin's animation from the state of play.
func _animate() -> void:
	for i in 2:
		var c = world.chars[i]
		var f: Dictionary = engine.fighters[i]
		if int(f.hp) <= 0:
			c.play("death", 0.15)
		elif phase == "over" and engine.winner == i:
			c.play("win", 0.4)
		elif hurt[i] > 0.0 or throw_t[i] < 0.5:
			pass   # hit / throw clips play out
		elif engine.turn == i and ((phase == "aim" and _my_turn() and holding) or (phase == "cpu" and cpu_ready)):
			c.play("aim", 0.2)
		elif engine.turn == i and phase in ["aim", "cpu"]:
			c.play("ready", 0.3)
		else:
			c.play("idle", 0.4)

func _keys(delta: float) -> void:
	if held.is_empty():
		return
	var i: int = engine.turn
	var y: float = engine.yaw_of(i)
	var p: float = engine.angle_of(i)
	if held.has("up"):
		p += 15.0 * delta
	if held.has("down"):
		p -= 15.0 * delta
	# Left / right no longer aim (locked on the rival); y stays 0.
	engine.set_aim(i, y, p)

func _on_landed(ev: Dictionary, v: Vector3, w: int) -> void:
	var p: Vector3 = ev.p if ev.has("p") else Vector3.ZERO
	match ev.kind:
		"hit":
			var f: int = ev.f
			hurt[f] = 0.45
			var head: bool = ev.zone == "head"
			hitstop = 0.11 if head else 0.07
			bar_shake[f] = 1.0
			world.chars[f].flash()
			if int(engine.fighters[f].hp) <= 0:
				world._delay(0.9, world.burst.bind(engine.feet(f) + Vector3(0, 0.1, 0), "ko"))
			world.chars[f].play("hit_head" if head else "hit", 0.05, true)
			if int(engine.fighters[f].hp) > 0:
				world.chars[f].queue_after("idle")
			world.burst(p, "hit_head" if head else "hit")
			_sound("impact/punch_heavy", 0.0)
			if head:
				_sound("sword/clash_spear", -4.0)
			var txt := "−%d" % ev.dmg
			if head:
				txt = tr("HEADSHOT!") + "  " + txt
			floats.append([txt, p + Vector3(0, 0.4, 0), 0.0, GOLD if head else Color("fff3dc")])
			if f == _view_seat():
				red_flash = 1.0
				shake = 1.0
			if f == kill_target and int(engine.fighters[f].hp) <= 0:
				slow_t = 1.3
				_show_banner(tr("Finishing blow!"))
				_sound("sword/clash_spear", 0.0)
			if head and info and f != engine.turn and _counts_for_me(engine.turn):
				info.add("Headshots")
		"stick":
			world.burst(p, ev.surface)
			world.leave_stuck(p, v, w, ev.surface)
			match ev.surface:
				"stone":
					_sound("sword/clash_spear", -6.0)
				"water":
					_sound("impact/soft_heavy", -4.0)
				_:
					_sound("impact/soft_medium", -2.0)

## The kill cam (real time): near the finishing blow and a moment after it,
## time runs at a fifth and the camera moves beside the victim.
func _kill_cam(delta: float) -> void:
	var want := false
	if kill_target >= 0 and phase in ["fly", "settle", "over"] and not engine.fighters.is_empty():
		var head: Vector3 = engine.feet(kill_target) + Vector3(0, 1.4, 0)
		if not engine.shot.is_empty() and (engine.shot.p as Vector3).distance_to(head) < 9.0:
			want = true
		elif engine.shot.is_empty() and slow_t > 0.0:
			slow_t -= delta
			want = true
	tscale = move_toward(tscale, 0.2 if want else 1.0, delta * 4.0)
	kill_zoom = move_toward(kill_zoom, 1.0 if want else 0.0, delta * (3.0 if want else 1.2))

## Does a throw by fighter i count for this phone's stats? (not the computer's)
func _counts_for_me(i: int) -> bool:
	if _is_online():
		return i == my_seat
	return mode == "2p" or i == 0

func _after_throw() -> void:
	engine.settle()
	if pending_state != null:
		var st = pending_state
		pending_state = null
		_apply_state(st)
	else:
		_start_turn()
	if _is_online() and online.is_host():
		online.push_state()  # the host's copy is the one that counts

func _cpu_step(delta: float) -> void:
	phase_t += delta
	var i: int = engine.turn
	if phase_t < 0.6:
		return
	if cpu_plan.is_empty():
		cpu_plan = engine.cpu_plan(i, cpu_level)
		engine.pick_weapon(i, cpu_plan.weapon)
		world.chars[i].set_weapon(int(cpu_plan.weapon), world.weapon_mesh)
		_update_ui()
		return
	if not cpu_ready:
		cpu_ready = engine.cpu_think(cpu_plan)  # a slice per frame: no freeze
		return
	# Swing the aim towards the plan, hold a moment, let go.
	var y: float = engine.yaw_of(i)
	var p: float = engine.angle_of(i)
	var dy: float = cpu_plan.yaw - y
	var dp: float = cpu_plan.pitch - p
	engine.set_aim(i, y + clampf(dy, -30.0 * delta, 30.0 * delta), p + clampf(dp, -40.0 * delta, 40.0 * delta))
	if absf(dy) < 0.15 and absf(dp) < 0.15 and phase_t > 2.2:
		engine.set_aim(i, cpu_plan.yaw, cpu_plan.pitch)
		_throw()

func _game_over() -> void:
	phase = "over"
	started = true
	if not _is_online():
		SaveUtil.delete(SAVE_PATH)
	if result_recorded:
		return
	result_recorded = true
	var w: int = engine.winner
	var msg := ""
	end_next.text = tr("Play Again")
	if _is_online():
		var won: bool = w == my_seat
		msg = online.result_text(won)
		_pay(ONLINE_WIN_STARS if won else LOSS_STARS)
		msg += "
" + _paid_text()
		if info:
			info.result("win" if won else "loss", true)
			msg += "\n" + info.summary(["Online wins", "Online losses"])
		_sound("voice/you_win" if won else "voice/you_lose")
	elif _vs_cpu():
		var won: bool = w == 0
		var hp: int = engine.fighters[0].hp
		msg = tr("You win!") if won else tr("The computer wins!")
		if mode == "contract":
			msg = tr("Contract %d of 8") % (contract + 1) + " · " + tr(CONTRACTS[contract].place) + "\n" + msg
			if won:
				var stars := 1 + (1 if hp >= 50 else 0) + (1 if hp >= AaEngine.MAX_HP else 0)
				progress.stars[contract] = maxi(int(progress.stars[contract]), stars)
				_save_progress()
				msg += "\n" + "★".repeat(stars) + "☆".repeat(3 - stars)
				if contract < CONTRACTS.size() - 1:
					end_next.text = tr("Next contract")
		if info:
			info.result("win" if won else "loss")
			if won:
				info.add("Wins (%s)" % LEVELS[cpu_level])
				if hp >= AaEngine.MAX_HP:
					info.add("Flawless wins")
			if mode == "contract":
				var done := 0
				var total := 0
				for s in progress.stars:
					done += 1 if int(s) > 0 else 0
					total += int(s)
				info.high("Contracts completed", done)
				info.high("Contract stars", total)
			msg += "\n" + info.summary(["Wins", "Losses", "Best streak"])
		_pay((WIN_STARS[clampi(cpu_level, 0, 3)] + (FLAWLESS_BONUS if hp >= AaEngine.MAX_HP else 0)) if won else LOSS_STARS)
		msg += "
" + _paid_text()
		if won and hp >= AaEngine.MAX_HP:
			_sound("voice/flawless_victory")
		else:
			_sound("voice/you_win" if won else "voice/you_lose")
	else:
		msg = tr("%s wins!") % (_who(w) + " (" + _name(w) + ")")
		_sound("voice/winner")
		if info:
			info.add("2-player games")
			info.celebrate(msg)
	end_label.text = msg
	# The headline, the Contract stars, petals round the winner.
	var won_here: bool = (w == my_seat) if _is_online() else (w == 0 if _vs_cpu() else true)
	end_title.text = (tr("Victory") if won_here else tr("Defeat")).to_upper() if mode != "2p" else _name(w).to_upper()
	end_title.add_theme_color_override("font_color", GOLD if won_here else Color("ff6a5a"))
	end_stars = 0
	if mode == "contract" and w == 0:
		var hp0: int = engine.fighters[0].hp
		end_stars = 1 + (1 if hp0 >= 50 else 0) + (1 if hp0 >= AaEngine.MAX_HP else 0)
	stars_t = 0.0
	world.celebrate(w, true)
	end_panel.visible = true
	end_panel.modulate.a = 0.0
	var tw := end_panel.create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(end_panel, "modulate:a", 1.0, 0.35)
	results_chip.visible = false
	_update_ui()

func _on_end_next() -> void:
	if mode == "contract" and engine.winner == 0 and contract < CONTRACTS.size() - 1:
		contract += 1
	_restart()

func _see_field() -> void:
	end_panel.visible = false
	results_chip.visible = true

func _show_results() -> void:
	results_chip.visible = false
	end_panel.visible = true

# ---------- input: hold, drag to aim, release ----------

func _on_touch(event: InputEvent) -> void:
	if world.intro_t >= 0.0:
		if event is InputEventMouseButton and event.pressed:
			world.skip_intro()
		return
	if phase != "aim" or not _my_turn() or not started:
		return
	var i: int = engine.turn
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			holding = true
			hold_t = 0.0
			drag_from = event.position
			aim_from = Vector2(engine.yaw_of(i), engine.angle_of(i))
			world.chars[i].play("aim_in", 0.1, true)
			world.chars[i].queue_after("aim")
		elif holding:
			holding = false
			if hold_t >= HOLD_MIN:
				if _is_online():
					online.send_move({"y": engine.aim[i][0], "p": engine.aim[i][1], "w": engine.fighters[i].weapon})
				_throw()
	elif event is InputEventMouseMotion and holding:
		var d: Vector2 = event.position - drag_from
		var k := 720.0 / maxf(size.x, 1.0)
		# Up / down only: left / right is locked on the rival (was aim_from.x + d.x * k * YAW_PER_PX).
		engine.set_aim(i, 0.0, aim_from.y - d.y * k * PITCH_PER_PX)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var map := {KEY_UP: "up", KEY_DOWN: "down", KEY_RIGHT: "right", KEY_LEFT: "left"}
	if map.has(event.keycode):
		if event.pressed:
			held[map[event.keycode]] = true
		else:
			held.erase(map[event.keycode])
	elif event.pressed and not event.echo and phase == "aim" and _my_turn() and started:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			var i: int = engine.turn
			if _is_online():
				online.send_move({"y": engine.aim[i][0], "p": engine.aim[i][1], "w": engine.fighters[i].weapon})
			_throw()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_3:
			_on_weapon(event.keycode - KEY_1)

# ---------- online ----------

func _online_state() -> Dictionary:
	return turn_snap

func _on_online_started(my_player: int) -> void:
	mode = "online"
	my_seat = 0 if my_player == 1 else 1
	home.hide_home()  # an online fight never touches the local save
	if online.is_host():
		_online_reset()
	else:
		_wait_for_host()
		online.send_move({"char": my_char})

func _online_reset() -> void:
	engine.reset(-1, {"chars": [my_char, (my_char + 1) % CHARS.size()]})
	_begin()
	online.push_state()

func _wait_for_host() -> void:
	started = true
	phase = "wait"
	end_panel.visible = false
	results_chip.visible = false
	_show_banner(tr("Waiting for the other player..."))
	_update_ui()

func _on_remote_new_game() -> void:
	if online.is_host():
		_online_reset()
	else:
		_wait_for_host()

func _on_remote_move(p: Dictionary) -> void:
	if p.has("char"):
		if online.is_host():
			var c := clampi(int(p.char), 0, CHARS.size() - 1)
			if c == my_char:
				c = (c + 1) % CHARS.size()
			engine.fighters[1].char = c
			world.rebuild(_defs())
			if phase == "aim" or phase == "wait":
				turn_snap = engine.snapshot()
			online.push_state()
		return
	if not p.has("y") or engine.is_over() or engine.turn == my_seat:
		return
	if phase != "wait" and phase != "aim":
		return
	var i: int = engine.turn
	engine.pick_weapon(i, int(p.get("w", 0)))
	engine.aim[i] = [clampi(int(p.y), -350, 350), clampi(int(p.p), -100, 800)]
	_throw()

func _on_remote_state(st: Dictionary) -> void:
	if phase == "fly" or phase == "settle":
		pending_state = st  # after this throw lands
		return
	_apply_state(st)

func _apply_state(st: Dictionary) -> void:
	var same: bool = engine.seed_ == int(st.get("seed", -1))
	var chars_before := [int(engine.fighters[0].char), int(engine.fighters[1].char)] if engine.fighters.size() == 2 else []
	if not engine.from_dict(st):
		return
	if not same:
		_reset_fx()
		_sound("voice/fight", -4.0)
		world.snap_camera(_view_seat())
	elif chars_before != [int(engine.fighters[0].char), int(engine.fighters[1].char)]:
		world.rebuild(_defs())
	_start_turn()

# ---------- pause / save ----------

func _on_pause() -> void:
	held.clear()
	holding = false
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or engine.is_over() or _is_online() or phase == "over":
		return
	SaveUtil.write(SAVE_PATH, {"engine": engine.to_dict(), "mode": mode, "level": cpu_level, "contract": contract, "v": 2})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	match str(d.get("mode", "cpu")):
		"2p":
			return tr("2 Players")
		"contract":
			return tr("Contract %d of 8") % (int(d.get("contract", 0)) + 1)
	return tr("vs Computer") + " (" + tr(LEVELS[clampi(int(d.get("level", 1)), 0, 3)]) + ")"

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	# Saves from the 2D version (no "v": 2) can't be resumed: a new fight instead.
	if d == null or int(d.get("v", 1)) < 2 or not d.has("engine") or not engine.from_dict(d.engine):
		_new_vs_cpu(1)
		return
	mode = str(d.get("mode", "cpu"))
	if mode == "online":
		mode = "cpu"
	cpu_level = clampi(int(d.get("level", 1)), 0, 3)
	contract = clampi(int(d.get("contract", 0)), 0, CONTRACTS.size() - 1)
	_begin()

func _load_progress() -> void:
	var d = SaveUtil.read(PROGRESS_PATH)
	if d is Dictionary and d.get("stars") is Array and (d.stars as Array).size() == CONTRACTS.size():
		var st: Array = []
		for s in d.stars:
			st.append(clampi(int(s), 0, 3))
		var owned: Array = []
		for o in d.get("owned", []):
			owned.append(str(o))
		var up := {}
		var du = d.get("up", {})
		if du is Dictionary:
			for k in du:
				up[str(k)] = maxi(0, int(du[k]))
		progress = {"stars": st, "char": clampi(int(d.get("char", 0)), 0, CHARS.size() - 1),
			"wallet": maxi(0, int(d.get("wallet", 0))), "earned": maxi(0, int(d.get("earned", 0))),
			"owned": owned, "outfit": str(d.get("outfit", "")), "hair": str(d.get("hair", "")), "up": up,
			"level": clampi(int(d.get("level", 1)), 0, LEVELS.size() - 1)}

func _save_progress() -> void:
	SaveUtil.write(PROGRESS_PATH, progress)
	if cloud:
		cloud.saved()
		var n := 0
		for v in progress.stars:
			if int(v) > 0:
				n += 1
		cloud.report_completion(n, CONTRACTS.size())

## Cloud vs device (STANDARDS §18): the copy with more contracts cleared (then stars) wins.
func _progress_score(d: Dictionary) -> int:
	var st = d.get("stars", [])
	var n := 0
	if st is Array:
		for v in st:
			n += (4 + int(v)) if int(v) > 0 else 0
	# Then the stars ever earned (Shop, 2026-11-25): a tie goes to the copy that played more.
	return n * 1000000 + mini(int(d.get("earned", 0)), 999999)

# ---------- shop (2026-11-25) ----------

func _up(id: String) -> int:
	return int((progress.get("up", {}) as Dictionary).get(id, 0))

var _last_paid := 0

func _pay(n: int) -> void:
	_last_paid = n
	if n <= 0:
		return
	progress["wallet"] = int(progress.get("wallet", 0)) + n
	progress["earned"] = int(progress.get("earned", 0)) + n
	_save_progress()
	_update_shop_btn()

func _paid_text() -> String:
	return tr("+%d ⭐ for the Shop (%d ⭐)") % [_last_paid, int(progress.get("wallet", 0))]

func _update_shop_btn() -> void:
	if shop_btn and is_instance_valid(shop_btn):
		shop_btn.text = tr("🛒 Shop") + "   ⭐ %d" % int(progress.get("wallet", 0))

## The Shop (owner, 2026-11-26): a turning preview of your amazon stays at the top.
## Tapping a row's name (left) puts that outfit / hair dye on her in the preview;
## only the price button (right) buys, after a "Buy ... for N ⭐?" confirmation.
var shop_body: VBoxContainer
var shop_wallet: Label
var shop_overlay: Control
var shop_try := {}             # {"outfit": id} / {"hair": id}: what the preview wears
var shop_try_label: Label
var shop_group: ButtonGroup
var shop_confirm: Control

func _open_shop() -> void:
	var parts: Array = home._overlay(tr("🛒 Shop"), GOLD, true)
	shop_overlay = parts[0]
	shop_body = parts[1]
	var col: VBoxContainer = parts[2]
	(shop_overlay.get_meta("nav") as Button).text = tr("‹ Back")
	shop_overlay.tree_exited.connect(_after_shop)
	shop_try = {}
	# the preview, pinned between the title bar and the scrolling list
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	col.add_child(pv)
	col.move_child(pv, 1)
	_preview_box(pv, 320)
	shop_try_label = HomeKit.label("", 20, GOLD)
	shop_try_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(shop_try_label)
	shop_overlay.show()
	_fill_shop()
	_show_try()

func _after_shop() -> void:
	shop_try = {}
	_update_shop_btn()
	if home and is_instance_valid(home):
		home.refresh()
	if world and not started:
		world.rebuild(_defs())

func _wallet_text() -> String:
	return tr("You have %d ⭐") % int(progress.get("wallet", 0))

func _fill_shop() -> void:
	if shop_body == null or not is_instance_valid(shop_body):
		return
	for c in shop_body.get_children():
		c.queue_free()
	shop_group = ButtonGroup.new()
	shop_group.allow_unpress = true
	shop_wallet = HomeKit.label(_wallet_text(), 30, GOLD)
	shop_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_body.add_child(shop_wallet)
	var how := HomeKit.label(tr("Win fights to earn stars: Easy 3, Normal 5, Hard 7, Expert 9, +2 flawless; online win 5; a loss 1."), 20, Color(1, 1, 1, 0.7))
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_body.add_child(how)
	var tip := HomeKit.label(tr("Tap a name to try it on; tap the price to buy."), 20, Color(1, 1, 1, 0.7))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_body.add_child(tip)
	shop_body.add_child(home.section("Outfits"))
	_shop_row(tr("Her own colours"), tr("Wearing") if str(progress.outfit) == "" else tr("Wear"), CHARS[my_char].c1, str(progress.outfit) == "", _wear.bind("outfit", ""), {"outfit": "-"})
	var tier := ""
	for o in OUTFITS:
		var t: String = o.get("tier", "")
		if t != tier:
			tier = t
			shop_body.add_child(home.section({"Bikinis": "Bikinis · 75 ⭐", "Costumes": "Costumes · 100 ⭐", "Legendary": "Legendary · 150 ⭐"}[t]))
		_look_row("outfit", o, o.c1)
	shop_body.add_child(home.section("Hair dye"))
	_shop_row(tr("Natural"), tr("Wearing") if str(progress.hair) == "" else tr("Wear"), CHARS[my_char].hair_col, str(progress.hair) == "", _wear.bind("hair", ""), {"hair": "-"})
	for h in HAIR_DYES:
		_look_row("hair", h, h.col)
	shop_body.add_child(home.section("Upgrades"))
	var note := HomeKit.label(tr("Upgrades work against the computer only (Contracts and vs Computer)."), 20, Color(1, 1, 1, 0.7))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_body.add_child(note)
	for u in UPGRADES:
		var lv := _up(u.id)
		var maxed: bool = lv >= (u.prices as Array).size()
		var left := tr(u.name) + "  " + "●".repeat(lv) + "○".repeat((u.prices as Array).size() - lv) + "\n" + tr(u.desc)
		_shop_row(left, tr("Maxed") if maxed else "%d ⭐" % int(u.prices[lv]), Color.WHITE, maxed,
			_ask_buy.bind(tr(u.name), int(u.prices[mini(lv, (u.prices as Array).size() - 1)]), _buy_upgrade.bind(u.id)), {})

func _look_row(slot: String, it: Dictionary, col: Color) -> void:
	var owned: bool = (progress.owned as Array).has(it.id)
	var on: bool = str(progress[slot]) == it.id
	var right: String = tr("Wearing") if on else (tr("Wear") if owned else "%d ⭐" % int(it.price))
	var act: Callable = _wear.bind(slot, it.id) if owned else _ask_buy.bind(tr(it.name), int(it.price), _buy_look.bind(slot, it.id))
	_shop_row(tr(it.name), right, col, on, act, {slot: it.id})

## One row: the left part (colour chip + name) tries the look on; the button on the right buys / wears.
func _shop_row(left: String, right: String, chip: Color, done: bool, action: Callable, look: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var pick := Button.new()
	pick.toggle_mode = true
	pick.button_group = shop_group
	pick.focus_mode = Control.FOCUS_NONE
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.custom_minimum_size = Vector2(0, 58)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		var on: bool = state in ["pressed", "hover_pressed"]
		sb.bg_color = Color(GOLD, 0.18) if on else Color(1, 1, 1, 0.05 if state != "hover" else 0.09)
		sb.border_color = Color(GOLD, 0.9) if on else Color(1, 1, 1, 0.1)
		sb.set_border_width_all(2 if on else 1)
		sb.set_corner_radius_all(12)
		pick.add_theme_stylebox_override(state, sb)
	if not look.is_empty():
		pick.pressed.connect(_try.bind(look, left))
		if look == shop_try:
			pick.set_pressed_no_signal(true)
	else:
		pick.mouse_filter = Control.MOUSE_FILTER_PASS
		pick.disabled = true
		pick.add_theme_stylebox_override("disabled", pick.get_theme_stylebox("normal"))
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pick.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 12
	inner.offset_right = -8
	var sw := ColorRect.new()
	sw.color = chip
	sw.custom_minimum_size = Vector2(28, 28)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(sw)
	var l := HomeKit.label(left, 22, Color.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(l)
	# the row grows with a two-line name
	pick.custom_minimum_size.y = maxf(58.0, 22.0 * 1.5 * (left.count("\n") + 1) + 20.0)
	row.add_child(pick)
	var b := HomeKit.neon_button(right, HomeKit.BUTTON, 22, 54)
	b.custom_minimum_size.x = 140
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = done
	b.add_theme_color_override("font_disabled_color", GOLD)
	b.pressed.connect(action)
	row.add_child(b)
	shop_body.add_child(row)

## Try a look on in the preview (nothing is bought or worn).
func _try(look: Dictionary, name: String) -> void:
	var off := look == shop_try
	shop_try = {} if off else look
	_show_try(name if not off else "")

func _show_try(name: String = "") -> void:
	var look := {}
	for k in shop_try:
		look[k] = "" if str(shop_try[k]) == "-" else shop_try[k]
	_show_picker_char(look)
	if shop_try_label and is_instance_valid(shop_try_label):
		shop_try_label.text = (tr("Trying on: %s") % name.get_slice("\n", 0)) if name != "" else tr("Wearing now")
	if picker_char and is_instance_valid(picker_char):
		picker_char.scale = Vector3(0.92, 0.92, 0.92)
		var tw := picker_char.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(picker_char, "scale", Vector3.ONE, 0.3)

## Every purchase asks first: "Buy <name> for N ⭐?" Buy / Cancel.
func _ask_buy(name: String, price: int, buy: Callable) -> void:
	if int(progress.get("wallet", 0)) < price:
		_sound("ui/wrong", -6.0)
		if shop_wallet:
			shop_wallet.text = tr("Not enough stars: win more fights!")
		return
	_close_confirm()
	shop_confirm = ColorRect.new()
	(shop_confirm as ColorRect).color = Color(0, 0, 0, 0.6)
	shop_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_overlay.add_child(shop_confirm)
	shop_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	shop_confirm.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pc := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.07, 0.05, 0.04, 0.97)
	ps.border_color = Color(GOLD, 0.85)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(18)
	ps.set_content_margin_all(24)
	pc.add_theme_stylebox_override("panel", ps)
	pc.custom_minimum_size.x = minf(560.0, size.x - 48.0)
	cc.add_child(pc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	pc.add_child(box)
	var q := HomeKit.label(tr("Buy %s for %d ⭐?") % [name.get_slice("\n", 0), price], 28, Color.WHITE, true, true)
	box.add_child(q)
	box.add_child(HomeKit.label(tr("You will have %d ⭐ left.") % (int(progress.wallet) - price), 22, GOLD, true, true))
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	box.add_child(r)
	var no := HomeKit.neon_button(tr("Cancel"), HomeKit.BUTTON, 24, 60)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(_close_confirm)
	r.add_child(no)
	var yes := HomeKit.neon_button(tr("Buy"), HomeKit.GO, 24, 60)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(_confirm_buy.bind(buy))
	r.add_child(yes)
	# pop in
	pc.pivot_offset = pc.custom_minimum_size * 0.5
	pc.scale = Vector2(0.85, 0.85)
	shop_confirm.modulate.a = 0.0
	var tw := shop_confirm.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(shop_confirm, "modulate:a", 1.0, 0.15)
	tw.tween_property(pc, "scale", Vector2.ONE, 0.25)

func _confirm_buy(buy: Callable) -> void:
	_close_confirm()
	buy.call()

func _close_confirm() -> void:
	if shop_confirm and is_instance_valid(shop_confirm):
		shop_confirm.queue_free()
	shop_confirm = null

func _spend(price: int) -> bool:
	if int(progress.get("wallet", 0)) < price:
		_sound("ui/wrong", -6.0)
		if shop_wallet:
			shop_wallet.text = tr("Not enough stars: win more fights!")
		return false
	progress["wallet"] = int(progress.wallet) - price
	_sound("reward/coin_plingy", -4.0)
	return true

func _buy_upgrade(id: String) -> void:
	var u := _find(UPGRADES, id)
	var lv := _up(id)
	if u.is_empty() or lv >= (u.prices as Array).size() or not _spend(int(u.prices[lv])):
		return
	progress.up[id] = lv + 1
	_save_progress()
	_fill_shop()

func _buy_look(slot: String, id: String) -> void:
	var it := _find(OUTFITS if slot == "outfit" else HAIR_DYES, id)
	if it.is_empty():
		return
	if not (progress.owned as Array).has(id):
		if not _spend(int(it.price)):
			return
		progress.owned.append(id)
	_wear(slot, id)

## Bought or picked: she wears it from now on (the preview drops the try-on).
func _wear(slot: String, id: String) -> void:
	progress[slot] = id
	_save_progress()
	shop_try = {}
	_fill_shop()
	_show_try()

# ---------- helps (STANDARDS §17) ----------

## 🦅 Eagle Eye: the whole flight of this turn's throw, wind included.
func _help_eagle() -> bool:
	if not started or _is_online() or phase != "aim" or not _my_turn() or eagle:
		return false
	eagle = true
	return true

# ---------- skins ----------

func _set_skin(name: String) -> void:
	skin = name
	if world:
		world.set_skull(name == "voodoo")
	_show_picker_char()

func _current_skin() -> String:
	return skin

# ---------- sound / music ----------

func _sound(id: String, db: float = 0.0) -> void:
	# Ids are full literals at every call site (hub.py sync packs exactly those).
	SoundLib.play(self, id, db)

func _music(what: String, style: String, index: int = 0, fade: float = 1.5) -> void:
	var m = get_node_or_null("/root/Music")
	if m == null:
		return
	if what == "play":
		m.play(style, self, index, fade)
	elif m.has_method("stop"):
		m.stop(fade)

# ---------- the HUD (drawn; Cinzel fonts, gold on dark glass) ----------

func _load_fonts() -> void:
	if ResourceLoader.exists(TITLE_FONT):
		title_font = load(TITLE_FONT)
	if ResourceLoader.exists(UI_FONT):
		var base: Font = load(UI_FONT)
		var reg := FontVariation.new()
		reg.base_font = base
		reg.variation_opentype = {"wght": 500}
		ui_font = reg
		var bold := FontVariation.new()
		bold.base_font = base
		bold.variation_opentype = {"wght": 800}
		ui_bold = bold
	var fb := ThemeDB.fallback_font
	# Cinzel has no emoji, arrows or ∞: fall back to the default font for those.
	for f in [ui_font, ui_bold]:
		if f:
			f.fallbacks = [fb]
	if ResourceLoader.exists(TITLE_FONT):
		var tf := FontVariation.new()
		tf.base_font = load(TITLE_FONT)
		tf.fallbacks = [fb]
		title_font = tf
	if ui_font == null:
		ui_font = fb
		ui_bold = fb
	if title_font == null:
		title_font = ui_bold

## Dark glass, round, gold edge when picked; pressed sinks a little.
func _style_button(b: Button, picked: bool, fs: int, radius: int) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.04, 0.03, 0.62 if st != "pressed" else 0.8)
		sb.border_color = Color(GOLD, 0.95) if picked else Color(1, 1, 1, 0.28)
		sb.set_border_width_all(3 if picked else 1)
		sb.set_corner_radius_all(radius)
		sb.shadow_color = Color(GOLD, 0.45) if picked else Color(0, 0, 0, 0.35)
		sb.shadow_size = 10 if picked else 6
		sb.set_content_margin_all(6)
		if st == "pressed":
			sb.content_margin_top = 9
		if st == "focus":
			sb.draw_center = false
			sb.set_border_width_all(0)
			sb.shadow_size = 0
		b.add_theme_stylebox_override(st, sb)
	if ui_bold:
		b.add_theme_font_override("font", ui_bold)
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", GOLD if picked else Color("f3e6c8"))
	b.add_theme_color_override("font_hover_color", GOLD if picked else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.focus_mode = Control.FOCUS_NONE

## The weapon chips: icon + ammo, the one in hand gold and a touch bigger.
func _style_weapons() -> void:
	if engine.fighters.is_empty():
		return
	var f: Dictionary = engine.fighters[engine.turn]
	for w in weapon_btns.size():
		var b: Button = weapon_btns[w]
		var picked: bool = w == int(f.weapon)
		_style_button(b, picked, 22, 32)
		var target := Vector2.ONE * (1.08 if picked else 1.0)
		if b.scale != target:
			var tw := b.create_tween()
			tw.tween_property(b, "scale", target, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Result stars (Contracts): they pop in one after another.
func _draw_end_stars(c: Control) -> void:
	if end_stars <= 0 or stars_t < 0.0:
		c.custom_minimum_size.y = 0
		return
	c.custom_minimum_size.y = 64
	var mid := c.size.x / 2.0
	for k in 3:
		var t := clampf((stars_t - 0.25 - k * 0.22) / 0.3, 0.0, 1.0)
		var pop := 1.0 + sin(t * PI) * 0.35
		var centre := Vector2(mid + (k - 1) * 64.0, 32)
		var lit := k < end_stars and t > 0.0
		_star(c, centre, 24.0 * (pop if lit else 1.0), GOLD if lit else Color(1, 1, 1, 0.18), lit)

func _star(c: CanvasItem, centre: Vector2, r: float, col: Color, glow: bool) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(centre + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	if glow:
		c.draw_circle(centre, r * 1.25, Color(col, 0.18))
	c.draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, Color(0, 0, 0, 0.5), 1.5, true)

func _text(c: CanvasItem, font: Font, pos: Vector2, text: String, fs: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_CENTER, w: float = 640.0, outline: int = 6) -> void:
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		p.x -= w / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		p.x -= w
	if outline > 0:
		c.draw_string_outline(font, p, text, align, w, fs, outline, Color(0, 0, 0, col.a * 0.72))
	c.draw_string(font, p, text, align, w, fs, col)

## Kept for older call sites: centred, outlined text in the UI font.
func _outlined(c: CanvasItem, center: Vector2, text: String, fs: int, col: Color, w: float = 640.0) -> void:
	_text(c, ui_bold, center + Vector2(0, fs / 3.0), text, fs, col, HORIZONTAL_ALIGNMENT_CENTER, w)

func _glass(c: CanvasItem, r: Rect2, radius: int = 14, alpha: float = 0.5, border: Color = Color(1, 1, 1, 0.16)) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.035, 0.03, alpha)
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	c.draw_style_box(sb, r)

func _draw_hud() -> void:
	var c := hud
	var sz := hud.size
	var skull := skin == "voodoo"
	if red_flash > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.8, 0, 0, red_flash * 0.22))
	# Kill cam letterbox.
	if kill_zoom > 0.01:
		var lb := sz.y * 0.085 * kill_zoom
		c.draw_rect(Rect2(0, 0, sz.x, lb), Color.BLACK)
		c.draw_rect(Rect2(0, sz.y - lb, sz.x, lb), Color.BLACK)
	if not started or engine.fighters.is_empty():
		return
	var in_intro: bool = world.intro_t >= 0.0
	var mid := sz.x / 2.0
	if in_intro:
		_draw_vs(c, sz)
		return
	if kill_zoom > 0.3:
		_draw_floats(c)
		_draw_banner(c, sz)
		return
	_draw_bars(c, sz, skull)
	_draw_wind(c, Vector2(mid, 128), skull)
	var show_ruler: bool = phase in ["aim", "cpu", "fly"] and not engine.is_over()
	if show_ruler:
		_draw_ruler(c, sz, skull)
	if phase == "aim" and _my_turn():
		var f: Dictionary = engine.fighters[engine.turn]
		_text(c, ui_bold, Vector2(mid, sz.y - 104), tr(str(AaEngine.WEAPONS[int(f.weapon)].name)).to_upper(), 17, Color(GOLD, 0.95), HORIZONTAL_ALIGNMENT_CENTER, 400, 5)
		if not holding and held.is_empty():
			var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 320.0)
			var hint := tr("Hold, drag up or down, let go to throw")
			var hw := ui_font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 36.0
			_glass(c, Rect2(mid - hw / 2.0, sz.y * 0.78 - 22, hw, 40), 20, 0.45 * pulse, Color(GOLD, 0.35 * pulse))
			_text(c, ui_font, Vector2(mid, sz.y * 0.78 + 5), hint, 18, Color(1, 0.96, 0.88, pulse), HORIZONTAL_ALIGNMENT_CENTER, 600, 0)
	if _is_online() and not engine.is_over():
		_text(c, ui_font, Vector2(mid, sz.y - 136), online.status_text(engine.turn == my_seat, _name(engine.turn)), 18, Color.WHITE)
	_draw_floats(c)
	_draw_banner(c, sz)

## Two framed health bars with medallions; the one taking a hit shakes and a
## white "ghost" chunk drains after the bar.
func _draw_bars(c: CanvasItem, sz: Vector2, skull: bool) -> void:
	var left := _view_seat() if mode != "2p" else 0
	var top := 32.0
	var x0 := 74.0
	var gap := 10.0
	var bw := (sz.x - x0 - 12.0 - gap) / 2.0
	for k in 2:
		var i := left if k == 0 else 1 - left
		var f: Dictionary = engine.fighters[i]
		var ch: Dictionary = CHARS[int(f.char)]
		var jolt := Vector2(sin(Time.get_ticks_msec() * 0.09) * 5.0 * bar_shake[i], 0)
		var x := (x0 if k == 0 else x0 + bw + gap) + jolt.x
		var plate := Rect2(x, top, bw, 54)
		var turn_glow: bool = engine.turn == i and not engine.is_over()
		_glass(c, plate, 14, 0.55, Color(GOLD, 0.75) if turn_glow else Color(1, 1, 1, 0.14))
		# Medallion: her colour, her initial.
		var med := Vector2(plate.position.x + 27 if k == 0 else plate.end.x - 27, plate.position.y + 27)
		var col: Color = ch.c1
		if skull:
			col = HomeKit.CYAN if k == 0 else HomeKit.MAGENTA
		c.draw_circle(med, 21, Color(0, 0, 0, 0.5))
		c.draw_circle(med, 19, col.darkened(0.35))
		c.draw_circle(med + Vector2(-4, -5), 11, Color(col.lightened(0.2), 0.55))
		c.draw_arc(med, 20, 0, TAU, 32, GOLD if turn_glow else Color(1, 1, 1, 0.6), 2.0, true)
		_text(c, title_font, med + Vector2(0, 9), str(ch.name).substr(0, 1), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 40, 4)
		# Name above the bar.
		var who := _who(i) if mode != "2p" else tr("Player %d") % (i + 1)
		var name_x := plate.position.x + 54 if k == 0 else plate.end.x - 54
		_text(c, ui_bold, Vector2(name_x, top + 19), str(ch.name).to_upper() + "  ·  " + who, 15, Color("f3e6c8"),
			HORIZONTAL_ALIGNMENT_LEFT if k == 0 else HORIZONTAL_ALIGNMENT_RIGHT, bw - 64, 3)
		# The bar.
		var br := Rect2(plate.position.x + 52 if k == 0 else plate.position.x + 8, top + 26, bw - 60, 18)
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(0, 0, 0, 0.6)
		rs.set_corner_radius_all(9)
		c.draw_style_box(rs, br)
		var bar_col: Color = (P_BLUE if k == 0 else P_RED) if not skull else (HomeKit.CYAN if k == 0 else HomeKit.MAGENTA)
		if f.hp <= 30:
			bar_col = bar_col.lerp(Color("ff3b3b"), 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0))
		var g := clampf(hp_ghost[i] / AaEngine.MAX_HP, 0.0, 1.0)
		var d := clampf(hp_disp[i] / AaEngine.MAX_HP, 0.0, 1.0)
		var inner := br.grow(-2)
		var ghost := Rect2(inner.position, Vector2(inner.size.x * g, inner.size.y)) if k == 0 else Rect2(Vector2(inner.end.x - inner.size.x * g, inner.position.y), Vector2(inner.size.x * g, inner.size.y))
		var fill := Rect2(inner.position, Vector2(inner.size.x * d, inner.size.y)) if k == 0 else Rect2(Vector2(inner.end.x - inner.size.x * d, inner.position.y), Vector2(inner.size.x * d, inner.size.y))
		if g > d:
			var gs := StyleBoxFlat.new()
			gs.bg_color = Color(1, 0.95, 0.85, 0.85)
			gs.set_corner_radius_all(7)
			c.draw_style_box(gs, ghost)
		if d > 0.0:
			var fs := StyleBoxFlat.new()
			fs.bg_color = bar_col
			fs.set_corner_radius_all(7)
			c.draw_style_box(fs, fill)
			c.draw_rect(Rect2(fill.position + Vector2(3, 2), Vector2(maxf(0.0, fill.size.x - 6), fill.size.y * 0.3)), Color(1, 1, 1, 0.28))
		for q in [0.25, 0.5, 0.75]:
			var tx: float = inner.position.x + inner.size.x * q
			c.draw_line(Vector2(tx, inner.position.y + 3), Vector2(tx, inner.end.y - 3), Color(0, 0, 0, 0.35), 1.0)
		_text(c, ui_bold, Vector2(br.get_center().x, br.position.y + 15), str(int(ceilf(hp_disp[i]))), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 80, 4)

## Wind: a glass pill, chevrons flowing the way it blows (faster when stronger).
## It blows along the line now: chevrons up = tailwind (the throw goes further),
## down = headwind (shorter), for whoever is throwing.
func _draw_wind(c: CanvasItem, centre: Vector2, skull: bool) -> void:
	var wv: float = engine.wind / AaEngine.WIND_MAX
	var strength := int(roundf(absf(engine.wind) * 10.0))
	var r := Rect2(centre.x - 92, centre.y - 22, 184, 50)
	_glass(c, r, 25, 0.5)
	var col := Color("f3e6c8") if not skull else HomeKit.LIME
	_text(c, ui_bold, Vector2(centre.x, r.position.y + 15), tr("Wind").to_upper(), 11, Color(col, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 200, 0)
	if strength == 0:
		_text(c, ui_bold, Vector2(centre.x, r.position.y + 40), tr("calm"), 18, col, HORIZONTAL_ALIGNMENT_CENTER, 200, 3)
		return
	# Up the screen = away from the camera's assassin (the thrower's tailwind on her own turn).
	var d := signf(wv) * (1.0 if engine.turn == _view_seat() else -1.0)
	var y := r.position.y + 33
	var t := fposmod(Time.get_ticks_msec() / 1000.0 * (0.6 + absf(wv) * 1.6), 1.0)
	for k in 3:
		var u := fposmod(t + k / 3.0, 1.0)
		var cy := y + 9.0 - u * 18.0 if d > 0 else y - 9.0 + u * 18.0
		var a := sin(u * PI) * (0.4 + 0.6 * absf(wv))
		var tip := Vector2(centre.x - 34, cy - d * 4)
		c.draw_polyline(PackedVector2Array([tip + Vector2(-8, d * 7), tip, tip + Vector2(8, d * 7)]), Color(col, a), 3.0, true)
	_text(c, title_font, Vector2(centre.x + 30, y + 9), str(strength), 24, GOLD if not skull else HomeKit.LIME, HORIZONTAL_ALIGNMENT_CENTER, 80, 4)

## The elevation ruler: a glass strip with ticks, a gold tag that slides.
func _draw_ruler(c: CanvasItem, sz: Vector2, skull: bool) -> void:
	var ry0 := sz.y * 0.27
	var ry1 := sz.y * 0.69
	var rx := 12.0
	_glass(c, Rect2(rx, ry0 - 10, 40, ry1 - ry0 + 20), 12, 0.38)
	var lo := -10.0
	var hi := 70.0
	var deg := lo
	while deg <= hi:
		var y := lerpf(ry1, ry0, (deg - lo) / (hi - lo))
		var big := int(deg) % 10 == 0
		c.draw_line(Vector2(rx + 4, y), Vector2(rx + (24 if big else 13), y), Color(1, 0.96, 0.88, 0.85 if big else 0.45), 2.0 if big else 1.0)
		if big and int(deg) % 20 == 0:
			_text(c, ui_font, Vector2(rx + 27, y + 4), str(int(deg)), 10, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT, 30, 0)
		deg += 5.0
	# The previous throw's angle: a see-through tag to correct from.
	var lt: Dictionary = engine.last[engine.turn]
	if not lt.is_empty():
		var la: float = float(lt.pitch) / 10.0
		var ly := lerpf(ry1, ry0, (clampf(la, lo, hi) - lo) / (hi - lo))
		var gc := Color(1, 1, 1, 0.42)
		var gtag := Rect2(rx + 30, ly - 13, 62, 26)
		var gs := StyleBoxFlat.new()
		gs.bg_color = Color(0, 0, 0, 0.35)
		gs.border_color = gc
		gs.set_border_width_all(2)
		gs.set_corner_radius_all(8)
		c.draw_style_box(gs, gtag)
		c.draw_line(Vector2(rx + 4, ly), Vector2(rx + 30, ly), gc, 2.0)
		_text(c, ui_bold, Vector2(gtag.get_center().x, ly + 6), "%d°" % int(roundf(la)), 16, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 62, 0)
	var my := lerpf(ry1, ry0, (clampf(aim_disp, lo, hi) - lo) / (hi - lo))
	var tagc := GOLD if not skull else HomeKit.CYAN
	var tag := Rect2(rx + 30, my - 15, 62, 30)
	var ts := StyleBoxFlat.new()
	ts.bg_color = tagc
	ts.set_corner_radius_all(8)
	ts.shadow_color = Color(tagc, 0.5)
	ts.shadow_size = 8
	c.draw_style_box(ts, tag)
	c.draw_colored_polygon(PackedVector2Array([Vector2(rx + 22, my), Vector2(rx + 31, my - 8), Vector2(rx + 31, my + 8)]), tagc)
	_text(c, ui_bold, Vector2(tag.get_center().x, my + 7), "%d°" % int(roundf(aim_disp)), 19, Color(0.12, 0.07, 0.02), HORIZONTAL_ALIGNMENT_CENTER, 62, 0)
	# (The ◀ / ▶ yaw readout is gone: the aim is locked on the rival.)

## Hit numbers: pop in with an overshoot, rise and fade.
func _draw_floats(c: CanvasItem) -> void:
	for fl in floats:
		var sp = world.screen_of(fl[1])
		if sp == null:
			continue
		var t: float = fl[2] / 1.4
		var pop := 1.0 + 0.6 * exp(-t * 18.0)
		var fs := int(30.0 * pop)
		var pos: Vector2 = (sp as Vector2) + Vector2(0, -60.0 * ease(t, 0.5))
		var a := 1.0 - clampf((t - 0.6) / 0.4, 0.0, 1.0)
		_text(c, title_font, pos, fl[0], fs, Color(fl[3], a), HORIZONTAL_ALIGNMENT_CENTER, 640, 7)

## Banners ("Your turn", contract names, "Finishing blow!"): pop in with an
## overshoot, gold rules grow out to the sides, fade out.
func _draw_banner(c: CanvasItem, sz: Vector2) -> void:
	if banner_t <= 0.0 or banner == "":
		return
	var age := banner_age
	var a := clampf(banner_t * 2.5, 0.0, 1.0) * clampf(age * 6.0, 0.0, 1.0)
	var s := 1.0 + 0.35 * exp(-age * 9.0) * cos(age * 20.0)
	var y := sz.y * 0.33
	var lines := banner.split("\n")
	for j in lines.size():
		var fs := int((38.0 if j == 0 else 22.0) * s)
		var font := title_font if j == 0 else ui_bold
		_text(c, font, Vector2(sz.x / 2.0, y + j * 44), lines[j].to_upper() if j == 0 else lines[j], fs, Color(GOLD if j == 0 else Color("f3e6c8"), a), HORIZONTAL_ALIGNMENT_CENTER, sz.x, 8)
	var grow := clampf(age * 3.0, 0.0, 1.0)
	var half := sz.x * 0.36 * grow
	var ly := y + 16
	c.draw_line(Vector2(sz.x / 2.0 - half, ly), Vector2(sz.x / 2.0 - 24, ly), Color(GOLD, a * 0.8), 2.0, true)
	c.draw_line(Vector2(sz.x / 2.0 + 24, ly), Vector2(sz.x / 2.0 + half, ly), Color(GOLD, a * 0.8), 2.0, true)
	c.draw_circle(Vector2(sz.x / 2.0, ly), 4, Color(GOLD, a))

## The VS card for the intro flyover: names sweep in from the sides.
func _draw_vs(c: CanvasItem, sz: Vector2) -> void:
	var t: float = world.intro_t
	var end: float = world.INTRO_LEN
	var a := clampf(t * 3.0, 0.0, 1.0) * clampf((end - t) * 2.5, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - clampf(t / 0.6, 0.0, 1.0), 3.0)
	var y := sz.y * 0.42
	c.draw_rect(Rect2(0, y - 70, sz.x, 140), Color(0, 0, 0, 0.45 * a))
	c.draw_line(Vector2(0, y - 70), Vector2(sz.x, y - 70), Color(GOLD, 0.7 * a), 2.0)
	c.draw_line(Vector2(0, y + 70), Vector2(sz.x, y + 70), Color(GOLD, 0.7 * a), 2.0)
	var left := _view_seat() if mode != "2p" else 0
	var n0 := _name(left).to_upper()
	var n1 := _name(1 - left).to_upper()
	_text(c, title_font, Vector2(lerpf(-sz.x * 0.5, sz.x * 0.27, e), y - 14), n0, 30, Color(Color("8fc4ff"), a), HORIZONTAL_ALIGNMENT_CENTER, sz.x * 0.6, 6)
	_text(c, title_font, Vector2(lerpf(sz.x * 1.5, sz.x * 0.73, e), y + 44), n1, 30, Color(Color("ff9a8a"), a), HORIZONTAL_ALIGNMENT_CENTER, sz.x * 0.6, 6)
	var vs_s := 1.0 + 0.8 * exp(-t * 6.0)
	_text(c, title_font, Vector2(sz.x / 2.0, y + 18), "VS", int(46 * vs_s), Color(GOLD, a), HORIZONTAL_ALIGNMENT_CENTER, 200, 8)
	if mode == "contract":
		_text(c, ui_bold, Vector2(sz.x / 2.0, y - 90), tr("Contract %d of 8") % (contract + 1) + " · " + tr(CONTRACTS[contract].place), 18, Color(Color("f3e6c8"), a), HORIZONTAL_ALIGNMENT_CENTER, sz.x, 5)
	_text(c, ui_font, Vector2(sz.x / 2.0, sz.y * 0.8), tr("Tap to skip"), 15, Color(1, 1, 1, 0.55 * a), HORIZONTAL_ALIGNMENT_CENTER, 300, 3)
