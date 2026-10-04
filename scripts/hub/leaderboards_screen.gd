extends "res://scripts/hub/hub_screen.gd"

## 🏆 Leaderboards (since v0.25): every game's board in one place, plus the
## 🏅 achievements board. "Everyone" shows each game's top 10; "Friends"
## ranks just you and your friends (Social). Boards come from the `scores`
## table (docs/leaderboards.sql) -- the same ones each game's Home shows.
## What a game ranks ("Best score", "Wins"...) is the manifest's "board".

const Achievements = preload("res://scripts/common/achievements.gd")
const TOP := 10

var friends_only: bool = false
var open_id: String = ""      # the board shown under its row, or ""
var my_scores: Dictionary = {}  # game id -> my number
var board_rows: Variant = null  # rows of the open board, null while loading
var board_box: VBoxContainer

func _title() -> String:
	return tr("🏆 Leaderboards")

func _ready() -> void:
	super()
	Auth.fetch_my_scores(_on_my_scores)
	if Social.available:
		Social.friends_changed.connect(_on_friends_changed)
	_open(Achievements.BOARD_ID)

func _on_my_scores(rows: Variant) -> void:
	if typeof(rows) == TYPE_ARRAY:
		for r in rows:
			my_scores[str(r.get("game", ""))] = int(r.get("score", 0))
		rebuild()

func _on_friends_changed() -> void:
	if friends_only:
		_open(open_id)

func _build() -> void:
	if Social.available or friends_only:
		list.add_child(tabs([tr("🌍 Everyone"), tr("👥 Friends")], 1 if friends_only else 0, _on_scope))
	if not Auth.is_logged_in():
		list.add_child(dim(tr("Sign in (hub ⚙ Options) to put your scores on the boards.")))

	var badge_game := {"id": Achievements.BOARD_ID, "icon": "🏅", "title": "Achievements"}
	var top := section(tr("All games"))
	_add_board_row(top, badge_game, tr("Most achievements unlocked"))

	var box := section(tr("Games"))
	var first := true
	for cat in Catalog.categories:
		for g in cat.get("games", []):
			if not g.has("id") or str(g.get("board", "")) == "none":
				continue
			if not first:
				box.add_child(HSeparator.new())
			first = false
			_add_board_row(box, g, _board_name(g))

func _board_name(g: Dictionary) -> String:
	var key := str(g.get("board", "Best score"))
	return Achievements._label(key if key != "" else "Best score")

func _add_board_row(box: VBoxContainer, g: Dictionary, sub: String) -> void:
	var id := str(g.id)
	var mine: String = ""
	if my_scores.has(id):
		mine = "   ·   " + tr("You: %s") % str(my_scores[id])
	var row := game_row(g, sub + mine)
	if id == Achievements.BOARD_ID:
		row.get_child(1).get_child(0).text = tr("Achievements")
	var b := pill("▾" if open_id == id else "▸", open_id == id, 28)
	b.custom_minimum_size = Vector2(70, 60)
	b.pressed.connect(_on_row.bind(id))
	row.add_child(b)
	box.add_child(row)
	if open_id == id:
		board_box = VBoxContainer.new()
		board_box.add_theme_constant_override("separation", 6)
		box.add_child(board_box)
		_fill_board()

func _on_row(id: String) -> void:
	if not tapped():
		return
	if open_id == id:
		open_id = ""
		rebuild()
	else:
		_open(id)

func _on_scope(i: int) -> void:
	friends_only = i == 1
	_open(open_id if open_id != "" else Achievements.BOARD_ID)

func _open(id: String) -> void:
	open_id = id
	board_rows = null
	rebuild()
	if id == "":
		return
	if friends_only:
		Auth.fetch_leaderboard_for(id, Social.friend_ids(), _on_board.bind(id))
	else:
		Auth.fetch_leaderboard(id, TOP, _on_board.bind(id))

func _on_board(rows: Variant, id: String) -> void:
	if id != open_id:
		return
	board_rows = rows if rows != null else []
	if rows == null:
		board_rows = "offline"
	_fill_board()

func _fill_board() -> void:
	if board_box == null or not is_instance_valid(board_box):
		return
	for c in board_box.get_children():
		c.queue_free()
	if board_rows == null:
		board_box.add_child(dim(tr("Loading...")))
		return
	if typeof(board_rows) == TYPE_STRING:
		board_box.add_child(dim(tr("Couldn't load the leaderboard. Check your connection and try again.")))
		return
	if board_rows.is_empty():
		board_box.add_child(dim(tr("No friends on this board yet.") if friends_only else tr("No scores yet — be the first!")))
		return
	var me: String = Auth.user_id if Auth.is_logged_in() else ""
	for i in board_rows.size():
		var r: Dictionary = board_rows[i]
		var mine: bool = str(r.get("user_id", "")) == me
		var row := HBoxContainer.new()
		var medal: String = ["🥇", "🥈", "🥉"][i] if i < 3 else "%d." % (i + 1)
		var who := label("%s  %s" % [medal, str(r.get("display_name", "Player"))], 24,
			pal.accent if mine else pal.text, false)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.clip_text = true
		row.add_child(who)
		row.add_child(label(str(int(r.get("score", 0))), 24, pal.accent if mine else pal.text, false))
		board_box.add_child(row)
