extends RefCounted

## Alien Attack: a marching grid of aliens edges down the screen, dropping
## bombs. Your cannon fires automatically; slide to aim. Clear a wave to face
## a faster one. Three lives; game over if the aliens reach the bottom.
## Pure simulation in a fixed 600×1000 field.

const FIELD := Vector2(600, 1000)
const SHIP_Y := 920.0
const SHIP_W := 60.0
const ROWS := 5
const COLS := 8
const ALIEN := Vector2(44, 32)
const GAP := Vector2(20, 18)
const FIRE_EVERY := 0.42
const SHOT_SPEED := 900.0
const BOMB_SPEED := 330.0

var ship_x: float = 300.0
var aliens: Array = []      # [{pos: Vector2, row: int, alive: bool}]
var shots: Array = []       # Vector2
var bombs: Array = []       # Vector2
var dir: float = 1.0
var march_offset := Vector2.ZERO
var fire_cool: float = 0.0
var bomb_cool: float = 1.5
var lives: int = 3
var score: int = 0
var wave: int = 1
var hit_flash: float = 0.0
var over: bool = false

func reset() -> void:
	lives = 3
	score = 0
	wave = 1
	over = false
	_new_wave()

func _new_wave() -> void:
	aliens.clear()
	shots.clear()
	bombs.clear()
	dir = 1.0
	march_offset = Vector2(0, min(wave - 1, 5) * 20.0)
	var width := COLS * ALIEN.x + (COLS - 1) * GAP.x
	var x0 := (FIELD.x - width) / 2.0
	for r in ROWS:
		for c in COLS:
			aliens.append({"pos": Vector2(x0 + c * (ALIEN.x + GAP.x), 120 + r * (ALIEN.y + GAP.y)), "row": r, "alive": true})

func alive_count() -> int:
	var n := 0
	for a in aliens:
		if a.alive:
			n += 1
	return n

func alien_rect(a: Dictionary) -> Rect2:
	return Rect2(a.pos + march_offset, ALIEN)

func set_ship(x: float) -> void:
	ship_x = clamp(x, SHIP_W / 2.0, FIELD.x - SHIP_W / 2.0)

func march_speed() -> float:
	var left := float(alive_count()) / (ROWS * COLS)
	return (40.0 + 20.0 * wave) * (1.0 + (1.0 - left) * 2.5)

## Returns "", "hit", "wave" or "over".
func step(delta: float) -> String:
	if over:
		return ""
	var event := ""
	hit_flash = max(0.0, hit_flash - delta)
	# march sideways, drop a row at the edges
	march_offset.x += dir * march_speed() * delta
	var lo := INF
	var hi := -INF
	var bottom := 0.0
	for a in aliens:
		if a.alive:
			var r := alien_rect(a)
			lo = min(lo, r.position.x)
			hi = max(hi, r.end.x)
			bottom = max(bottom, r.end.y)
	if hi > FIELD.x - 8 and dir > 0 or lo < 8 and dir < 0:
		dir = -dir
		march_offset.y += 22.0
	if bottom >= SHIP_Y - 10:
		over = true
		return "over"
	# your cannon
	fire_cool -= delta
	if fire_cool <= 0.0:
		fire_cool = FIRE_EVERY
		shots.append(Vector2(ship_x, SHIP_Y - 20))
	for i in range(shots.size() - 1, -1, -1):
		shots[i].y -= SHOT_SPEED * delta
		var hit := false
		for a in aliens:
			if a.alive and alien_rect(a).grow(2).has_point(shots[i]):
				a.alive = false
				score += (ROWS - a.row) * 10
				hit = true
				break
		if hit or shots[i].y < 0:
			shots.remove_at(i)
	# alien bombs from the lowest alien in a random column
	bomb_cool -= delta
	if bomb_cool <= 0.0:
		bomb_cool = max(0.35, 1.3 - wave * 0.12) * randf_range(0.6, 1.4)
		var shooters: Array = []
		for a in aliens:
			if a.alive:
				shooters.append(a)
		if not shooters.is_empty():
			var s: Dictionary = shooters[randi() % shooters.size()]
			var r := alien_rect(s)
			bombs.append(Vector2(r.get_center().x, r.end.y))
	for i in range(bombs.size() - 1, -1, -1):
		bombs[i].y += BOMB_SPEED * (1.0 + wave * 0.05) * delta
		if bombs[i].y >= SHIP_Y - 14 and bombs[i].y <= SHIP_Y + 14 and abs(bombs[i].x - ship_x) < SHIP_W / 2.0 and hit_flash <= 0.0:
			bombs.remove_at(i)
			lives -= 1
			hit_flash = 1.2
			event = "hit"
			if lives <= 0:
				over = true
				return "over"
		elif bombs[i].y > FIELD.y:
			bombs.remove_at(i)
	if alive_count() == 0:
		wave += 1
		_new_wave()
		return "wave"
	return event
