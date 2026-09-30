extends RefCounted

## Brick Breaker: keep the ball in play with your paddle and smash every
## brick. Darker bricks take two hits. Three lives; each cleared wall brings
## a new, tougher one. Pure simulation in a fixed 600×1000 field.

const FIELD := Vector2(600, 1000)
const PADDLE := Vector2(110, 18)
const PADDLE_Y := 920.0
const BALL_R := 10.0
const COLS := 10
const BRICK_H := 28.0
const TOP := 110.0

var bricks: Array = []     # [{rect: Rect2, hp: int, row: int}]
var ball := Vector2.ZERO
var vel := Vector2.ZERO
var paddle_x: float = 300.0
var stuck: bool = true      # ball resting on the paddle, waiting for launch
var lives: int = 3
var score: int = 0
var level: int = 1

func reset() -> void:
	lives = 3
	score = 0
	level = 1
	_build_level()

func _build_level() -> void:
	bricks.clear()
	var rows: int = min(4 + level, 10)
	var bw := FIELD.x / COLS
	var pattern := level % 4
	for r in rows:
		for c in COLS:
			var keep := true
			match pattern:
				2: keep = (r + c) % 2 == 0 or r < 2
				3: keep = abs(c - 4.5) + r * 0.6 < 6.5
				0: keep = c != 0 and c != COLS - 1 or r % 2 == 0
			if not keep:
				continue
			var hp := 2 if (level >= 2 and r < level - 1 and r < 3) else 1
			bricks.append({"rect": Rect2(c * bw + 2, TOP + r * (BRICK_H + 4), bw - 4, BRICK_H), "hp": hp, "row": r})
	_reset_ball()

func _reset_ball() -> void:
	stuck = true
	vel = Vector2.ZERO
	ball = Vector2(paddle_x, PADDLE_Y - BALL_R - 1)

func speed() -> float:
	return 480.0 + 45.0 * (level - 1)

func launch() -> void:
	if stuck:
		stuck = false
		vel = Vector2(randf_range(-0.4, 0.4), -1).normalized() * speed()

func set_paddle(x: float) -> void:
	paddle_x = clamp(x, PADDLE.x / 2.0, FIELD.x - PADDLE.x / 2.0)
	if stuck:
		ball.x = paddle_x

## Returns "", "lost_life", "game_over" or "cleared".
func step(delta: float) -> String:
	if stuck:
		return ""
	var steps := int(ceil(vel.length() * delta / 6.0))
	var dt: float = delta / max(1, steps)
	for i in steps:
		ball += vel * dt
		if ball.x < BALL_R:
			ball.x = BALL_R
			vel.x = abs(vel.x)
		elif ball.x > FIELD.x - BALL_R:
			ball.x = FIELD.x - BALL_R
			vel.x = -abs(vel.x)
		if ball.y < BALL_R:
			ball.y = BALL_R
			vel.y = abs(vel.y)
		# paddle
		if vel.y > 0 and ball.y + BALL_R >= PADDLE_Y and ball.y < PADDLE_Y + PADDLE.y and abs(ball.x - paddle_x) <= PADDLE.x / 2.0 + BALL_R:
			var offset: float = clamp((ball.x - paddle_x) / (PADDLE.x / 2.0), -1.0, 1.0)
			vel = Vector2(sin(offset * 1.05), -cos(offset * 1.05)) * vel.length()
			ball.y = PADDLE_Y - BALL_R
		# bricks: one hit per sub-step
		for b in bricks:
			var r: Rect2 = b.rect
			var closest := Vector2(clamp(ball.x, r.position.x, r.end.x), clamp(ball.y, r.position.y, r.end.y))
			if closest.distance_to(ball) <= BALL_R:
				var d := ball - closest
				if abs(d.x) > abs(d.y):
					vel.x = abs(vel.x) * sign(d.x) if d.x != 0 else -vel.x
				else:
					vel.y = abs(vel.y) * sign(d.y) if d.y != 0 else -vel.y
				b.hp -= 1
				if b.hp <= 0:
					bricks.erase(b)
					score += 10 * level
				else:
					score += 2
				vel = vel.normalized() * min(vel.length() * 1.004, speed() * 1.6)
				break
		if bricks.is_empty():
			level += 1
			_build_level()
			return "cleared"
		if ball.y > FIELD.y + BALL_R:
			lives -= 1
			if lives <= 0:
				return "game_over"
			_reset_ball()
			return "lost_life"
	return ""
