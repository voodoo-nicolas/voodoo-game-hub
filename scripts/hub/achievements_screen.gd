extends "res://scripts/hub/hub_screen.gd"

## 🏅 Achievements (since v0.25): the hub-wide badges (games tried, badges
## collected, friends, invites) with progress, then every game's unlocked
## badges, read from the games' stats files (Achievements keeps them in
## stats["_ach"]), so no pack has to be mounted. Each game's Home also has
## its own 🏅 list with the locked ones and their progress.

const Achievements = preload("res://scripts/common/achievements.gd")

var open_id: String = ""

func _title() -> String:
	return tr("🏅 Achievements")

func _ready() -> void:
	# Catch up first: badges earned before achievements existed, then the
	# hub-wide ones that depend on them.
	Achievements.backfill_all()
	var got := Achievements.check_hub()
	super()
	for h in got:
		Social.toast("%s  %s: %s" % [h[1], tr("Achievement unlocked!"), tr(h[2])])
	if Auth.is_logged_in():
		Auth.submit_score(Achievements.BOARD_ID, Achievements.total_unlocked())

func _build() -> void:
	var all := Achievements.all_stats()
	var hub := Achievements.load_hub()
	var total: int = Achievements.game_badges(all) + hub.unlocked.size()

	var head := section("")
	head.add_child(label(tr("%d achievements unlocked") % total, 34, pal.accent, true, true))
	head.add_child(dim(tr("Every game has its own: win, play, keep a streak, beat your records. Open a game's 🏅 Achievements to see what's left.")))
	var lb := pill(tr("🏆 Who has the most?"), true, 24)
	lb.pressed.connect(_to_leaderboards)
	head.add_child(lb)

	var hb := section(tr("Voodoo"))
	for h in Achievements.HUB:
		var have: bool = hub.unlocked.has(h[0])
		var value: int = Achievements.hub_value(h[4], all, hub)
		var note: String = tr("Unlocked") if have else "%d / %d" % [mini(value, int(h[5])), int(h[5])]
		hb.add_child(_badge_row(h[1], tr(h[2]), tr(h[3]), note, have))

	# Games with badges, most first.
	var ids: Array = []
	for id in all:
		if typeof(all[id].get("_ach")) == TYPE_DICTIONARY and not all[id]._ach.is_empty():
			ids.append(id)
	ids.sort_custom(func(a, b): return all[a]._ach.size() > all[b]._ach.size())
	var gb := section(tr("Games"))
	if ids.is_empty():
		gb.add_child(dim(tr("Play any game to start collecting.")))
	for i in ids.size():
		var id: String = ids[i]
		var game: Dictionary = Catalog.get_game(id)
		if game.is_empty():
			game = {"id": id, "title": id.capitalize(), "icon": "🎮"}
		if i > 0:
			gb.add_child(HSeparator.new())
		var row := game_row(game, tr("%d unlocked") % all[id]._ach.size())
		var b := pill("▾" if open_id == id else "▸", open_id == id, 28)
		b.custom_minimum_size = Vector2(70, 60)
		b.pressed.connect(_on_game.bind(id))
		row.add_child(b)
		gb.add_child(row)
		if open_id == id:
			var entries: Array = all[id]._ach.values()
			entries.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
			for e in entries:
				if typeof(e) == TYPE_ARRAY and e.size() >= 4:
					var when := Time.get_date_string_from_unix_time(int(e[0]))
					gb.add_child(_badge_row(str(e[1]), tr(str(e[2])), _translate_desc(str(e[3])), when, true))

## Stored descriptions are English ("Puzzles solved: 10"); translate the
## "<label>: <n>" shape and plain sentences.
func _translate_desc(d: String) -> String:
	var at := d.rfind(": ")
	if at > 0 and d.substr(at + 2).is_valid_int():
		return tr("%s: %d") % [Achievements._label(d.substr(0, at)), int(d.substr(at + 2))]
	var m := RegEx.create_from_string("^Beat your own record (\\d+) times$").search(d)
	if m:
		return tr("Beat your own record %d times") % int(m.get_string(1))
	return tr(d)

func _badge_row(icon: String, title: String, desc: String, note: String, have: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.modulate = Color(1, 1, 1) if have else Color(1, 1, 1, 0.5)
	var ic := label(icon if have else "🔒", 38, null, false)
	ic.custom_minimum_size = Vector2(56, 0)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(label(title, 25, pal.accent if have else pal.text))
	col.add_child(dim(desc, 20))
	row.add_child(col)
	var n := dim(note, 19)
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(n)
	return row

func _on_game(id: String) -> void:
	if tapped():
		open_id = "" if open_id == id else id
		rebuild()

func _to_leaderboards() -> void:
	if tapped():
		get_tree().change_scene_to_file("res://scenes/hub/leaderboards.tscn")
