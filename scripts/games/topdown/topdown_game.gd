extends Control

## Top-down adventure (working title) -- PROTOTYPE play scene.
## Placeholder art (coloured rectangles) and placeholder sounds (the shared synth Sfx).
## Not wired to the Landing kit yet: that comes with the hub listing step
## (docs/topdown/SPEC.md; the game is PC-only and not in manifest.json).
## Keys: arrows / WASD move, J / Z / Space sword (hold to charge), K / X / Shift dash,
## R restart, Esc pause. A gamepad works too (stick or D-pad, A sword, B dash).

const Engine_ = preload("res://scripts/games/topdown/topdown_engine.gd")
const Rooms = preload("res://scripts/games/topdown/topdown_rooms.gd")
const Orientation = preload("res://scripts/common/orientation.gd")

const C_FLOOR := Color("#3b4a3a")
const C_GRASS := Color("#4f7a3c")
const C_WALL := Color("#6b5e4e")
const C_WALL_TOP := Color("#857560")
const C_HERO := Color("#3fa7ff")
const C_HERO_FACE := Color("#e8f4ff")
const C_SWORD := Color("#e6e6e6")
const C_CHARGED := Color("#ffe066")
const C_BLOB := Color("#c04ad6")
const C_CHARGER := Color("#e0702f")
const C_HIT := Color("#ffffff")
const C_HEART := Color("#e23b3b")
const C_HEART_EMPTY := Color("#4a2626")
const C_TEXT := Color("#f2f2f2")

var engine
var paused := false
var _room_index := 0

func _ready() -> void:
	Orientation.lock_landscape()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	engine = Engine_.new()
	_restart()

func _restart() -> void:
	engine.new_game(Rooms.ROOMS[_room_index], 7)
	paused = false
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_P:
				paused = not paused
				queue_redraw()
			KEY_R:
				_restart()

func _read_input() -> Dictionary:
	var dx := 0
	var dy := 0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
		dx -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT):
		dx += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP):
		dy -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN):
		dy += 1
	var ax := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var ay := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if dx == 0 and absf(ax) > 0.4:
		dx = int(signf(ax))
	if dy == 0 and absf(ay) > 0.4:
		dy = int(signf(ay))
	return {
		"dir": Vector2i(dx, dy),
		"sword": Input.is_key_pressed(KEY_J) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_A),
		"dash": Input.is_key_pressed(KEY_K) or Input.is_key_pressed(KEY_X) or Input.is_key_pressed(KEY_SHIFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_B),
	}

func _physics_process(_delta: float) -> void:
	if paused:
		return
	engine.tick(_read_input())
	for ev in engine.events:
		_play(ev)
	if engine.enemies.is_empty() and not engine.dead:
		_room_index = (_room_index + 1) % Rooms.ROOMS.size()
		var keep_hp: int = engine.hp
		var keep_max: int = engine.max_hp
		engine.load_room(Rooms.ROOMS[_room_index], 7 + _room_index)
		engine.hp = keep_hp
		engine.max_hp = keep_max
	queue_redraw()

# Placeholder sounds: the shared synth Sfx (guarded: APK-side autoload).
const SOUND_FOR := {
	"swing": "tick", "spin": "toggle", "charged": "notify", "dash": "key", "step": "tick",
	"bonk": "invalid", "hurt": "invalid", "die": "lose", "enemy_hit": "tap", "enemy_die": "back",
	"pickup": "toggle", "beep": "notify", "beam": "key",
}

func _play(ev: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx and SOUND_FOR.has(ev):
		sfx.play(SOUND_FOR[ev])

# --- drawing (rectangles only: cheap per call) ---

func _view() -> Dictionary:
	var world := Vector2(engine.cols * Engine_.TILE, engine.rows * Engine_.TILE + 20)
	var s: float = maxf(1.0, floorf(minf(size.x / world.x, size.y / world.y)))
	if size.x / world.x < 1.0 or size.y / world.y < 1.0:
		s = minf(size.x / world.x, size.y / world.y)
	var off := (size - world * s) / 2.0
	return {"scale": s, "off": off}

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if engine == null or engine.rows == 0:
		return
	var v := _view()
	draw_set_transform(v.off + Vector2(0, 20 * v.scale), 0.0, Vector2(v.scale, v.scale))
	var t := Engine_.TILE
	for r in engine.rows:
		for c in engine.cols:
			var ch: String = engine.grid[r][c]
			var rect := Rect2(c * t, r * t, t, t)
			match ch:
				"#":
					draw_rect(rect, C_WALL)
					draw_rect(Rect2(rect.position, Vector2(t, 4)), C_WALL_TOP)
				",":
					draw_rect(rect, C_GRASS)
				_:
					draw_rect(rect, C_FLOOR)
	for p in engine.pickups:
		if p.life > 120 or engine.frame % 8 < 4:
			draw_rect(Rect2(p.pos - Vector2(3, 3), Vector2(6, 6)), C_HEART)
	for e in engine.enemies:
		var col: Color = C_BLOB if e.kind == "blob" else C_CHARGER
		if e.hit > 0 and engine.frame % 4 < 2:
			col = C_HIT
		draw_rect(Rect2(e.pos - Vector2(e.half, e.half), Vector2(e.half * 2, e.half * 2)), col)
	for b in engine.beams:
		draw_rect(Rect2(b.pos - Vector2(3, 3), Vector2(6, 6)), C_CHARGED)
	_draw_hero()
	draw_set_transform(v.off, 0.0, Vector2(v.scale, v.scale))
	_draw_hud()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if paused or engine.dead:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
		var msg := tr("Paused · Esc to resume") if paused else tr("You fell · R to try again")
		var font := get_theme_default_font()
		var fs := int(maxf(16.0, size.y / 20.0))
		var w := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - w) / 2.0, size.y / 2.0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_TEXT)

func _draw_hero() -> void:
	if not engine.hero_visible():
		return
	var h: float = Engine_.HERO_HALF
	var p: Vector2 = engine.pos.round() - Vector2(0, roundf(engine.z))
	if engine.z > 0.0:
		draw_rect(Rect2(engine.pos.round() - Vector2(h, -h + 2), Vector2(h * 2, 2)), Color(0, 0, 0, 0.4))
	var body := C_HERO
	if engine.state == Engine_.S.WINDUP and engine.frame % 4 < 2:
		body = C_HERO.lightened(0.3)
	draw_rect(Rect2(p - Vector2(h, h), Vector2(h * 2, h * 2)), body)
	var f := Vector2(engine.facing)
	draw_rect(Rect2(p + f * (h - 3) - Vector2(2, 2), Vector2(4, 4)), C_HERO_FACE)
	var sword_col := C_CHARGED if engine.charge >= Engine_.CHARGE_READY else C_SWORD
	match engine.state:
		Engine_.S.SWING:
			_draw_box(engine._swing_box(), C_SWORD)
		Engine_.S.CHARGE:
			_draw_box(engine._front_box(10.0, 4.0), sword_col)
		Engine_.S.DASH:
			_draw_box(engine._front_box(14.0, 4.0), C_SWORD)
		Engine_.S.SPIN:
			var a := TAU * float(engine.pose) / float(Engine_.SPIN_POSES.size())
			var tip := p + Vector2(cos(a), sin(a)) * 18.0
			draw_line(p, tip, C_CHARGED, 3.0)

func _draw_box(r: Rect2, col: Color) -> void:
	draw_rect(Rect2(r.position.round(), r.size), col)

func _draw_hud() -> void:
	var hearts: int = int(engine.max_hp / 8.0)
	for i in hearts:
		var x := 4 + (i % 10) * 9
		var y := 4 + int(i / 10.0) * 8
		var full: int = clampi(engine.hp - i * 8, 0, 8)
		draw_rect(Rect2(x, y, 7, 6), C_HEART_EMPTY)
		if full > 0:
			draw_rect(Rect2(x, y, 7.0 * full / 8.0, 6), C_HEART)
	var font := get_theme_default_font()
	draw_string(font, Vector2(engine.cols * Engine_.TILE - 4 - 60, 14), tr("Defeated: %d") % engine.kills,
		HORIZONTAL_ALIGNMENT_RIGHT, 60, 10, C_TEXT)
