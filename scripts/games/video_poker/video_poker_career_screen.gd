extends Control

## Poker's 🎯 Career screen: the eight stages (video_poker_career.gd) as cards
## with the boss, the table-mates and your stars; the next open stage is
## highlighted. ▶ Play on a card starts it (the game builds the table).

signal back_pressed()
signal start_pressed(stage_id: String)

const Career = preload("res://scripts/games/video_poker/video_poker_career.gd")
const Characters = preload("res://scripts/games/video_poker/video_poker_characters.gd")
const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")
const HomeKit = preload("res://scripts/games/video_poker/home_kit.gd")

var profile
var body: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(HomeKit.backdrop())
	var page := MarginContainer.new()
	for side in ["left", "right"]:
		page.add_theme_constant_override("margin_" + side, 28)
	page.add_theme_constant_override("margin_top", 24)
	page.add_theme_constant_override("margin_bottom", 24)
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	page.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	var back := HomeKit.neon_button("⬅", HomeKit.DIM, 30, 64)
	back.custom_minimum_size.x = 76
	back.pressed.connect(back_pressed.emit)
	head.add_child(back)
	var title := HomeKit.label(tr("🎯 Career"), 36, HomeKit.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(76, 0)
	head.add_child(sp)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)

## Call each time the screen is opened.
func open(p) -> void:
	profile = p
	for c in body.get_children():
		c.queue_free()
	var earned: Dictionary = profile.d.career
	body.add_child(HomeKit.label(tr("Beat the boss at each table to open the next. Stages cleared: %d of %d  ·  Stars: %d of %d") % [
		Career.cleared(earned), Career.STAGES.size(), Career.total_stars(earned), Career.STAGES.size() * 3], 22, HomeKit.DIM, true, true))
	body.add_child(HomeKit.label(tr("★ win  ·  ★★ win without the coach or win chance  ·  ★★★ and win fast"), 20, HomeKit.DIM, true, true))
	var next_open := -1
	for i in Career.STAGES.size():
		if Career.unlocked(i, earned) and int(earned.get(Career.STAGES[i].id, 0)) == 0:
			next_open = i
			break
	for i in Career.STAGES.size():
		body.add_child(_card(i, Career.STAGES[i], earned, i == next_open))

static func _stars_text(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(3 - n)

func _card(index: int, st: Dictionary, earned: Dictionary, current: bool) -> Control:
	var open_stage := Career.unlocked(index, earned)
	var got := int(earned.get(st.id, 0))
	var boss: Dictionary = Characters.find(str(st.boss))
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var edge: Color = HomeKit.GOLD if current else (HomeKit.LIME if got > 0 else HomeKit.DIM)
	sb.bg_color = Color(edge, 0.08 if open_stage else 0.03)
	sb.border_color = Color(edge, 0.85 if open_stage else 0.35)
	sb.set_border_width_all(3 if current else 2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var name := HomeKit.label("%d. %s" % [index + 1, tr(str(st.title))], 28, HomeKit.WHITE if open_stage else HomeKit.DIM)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	top.add_child(HomeKit.label(_stars_text(got), 28, HomeKit.GOLD))
	v.add_child(HomeKit.label(tr(str(st.blurb)), 21, HomeKit.DIM, true))
	var rules = Table.rules_for(str(st.variant))
	var limit_names := {"nl": "No limit", "pl": "Pot limit", "fl": "Limit"}
	v.add_child(HomeKit.label("%s · %s · %s" % [tr(rules.short_title()), tr(limit_names[str(st.limit)]),
		tr("blinds up every %d hands") % int(st.hpl)], 21, HomeKit.CYAN))
	# the boss
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 10)
	v.add_child(brow)
	brow.add_child(HomeKit.label(str(boss.get("icon", "👑")), 44, HomeKit.WHITE))
	var bcol := VBoxContainer.new()
	bcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bcol.add_theme_constant_override("separation", 2)
	brow.add_child(bcol)
	var stack_note := ""
	if float(st.boss_stack) > 1.0:
		stack_note = "  ·  " + tr("starts with %sx your chips") % str(snappedf(float(st.boss_stack), 0.1))
	bcol.add_child(HomeKit.label(tr("Boss: %s") % str(st.boss) + stack_note, 24, HomeKit.GOLD.lerp(Color.WHITE, 0.3)))
	bcol.add_child(HomeKit.label(tr(str(boss.get("bio", ""))), 20, HomeKit.DIM, true))
	v.add_child(HomeKit.label(tr("Also at the table: %s") % ", ".join(st.others), 20, HomeKit.DIM, true))
	v.add_child(HomeKit.label(tr("Third star: win in %d hands or fewer.") % int(st.fast), 20, HomeKit.DIM, true))
	var go := HomeKit.neon_button(tr("▶ Play") if open_stage else tr("🔒 Clear %s first") % tr(str(Career.STAGES[maxi(0, index - 1)].title)),
		HomeKit.LIME if open_stage else HomeKit.DIM, 26, 66)
	go.disabled = not open_stage
	go.pressed.connect(start_pressed.emit.bind(str(st.id)))
	v.add_child(go)
	return panel
