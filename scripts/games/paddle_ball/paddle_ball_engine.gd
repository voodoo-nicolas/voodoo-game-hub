extends RefCounted

## Paddle Ball: you (bottom) vs the computer (top). Bounce the ball past the
## other paddle; first to 7 wins. Where the ball meets the paddle sets its
## angle, and every hit speeds it up. Pure simulation in a fixed 600×1000
## field; the scene scales it to the screen and calls step().

const FIELD := Vector2(600, 1000)
const PADDLE := Vector2(120, 18)
const BALL_R := 12.0
const WIN_SCORE := 7
const START_SPEED := 520.0
const MAX_SPEED := 1250.0

var ball := Vector2.ZERO
var vel := Vector2.ZERO
var player_x: float = 300.0
var cpu_x: float = 300.0
var scores: Array = [0, 0]      # [player, cpu]
var cpu_speed: float = 430.0
var serve_wait: float = 0.0
var serve_to: int = 0           # who the ball heads towards on the serve

func reset(difficulty: int) -> void:
	scores = [0, 0]
	cpu_speed = [340.0, 450.0, 600.0][clampi(difficulty, 0, 2)]
	player_x = FIELD.x / 2.0
	cpu_x = FIELD.x / 2.0
	serve_to = 0
	_serve()

func _serve() -> void:
	ball = FIELD / 2.0
	var ang := randf_range(-0.5, 0.5)
	var dir := 1.0 if serve_to == 0 else -1.0
	vel = Vector2(sin(ang), cos(ang) * dir) * START_SPEED
	serve_wait = 0.9

func winner() -> int:
	if scores[0] >= WIN_SCORE:
		return 0
	if scores[1] >= WIN_SCORE:
		return 1
	return -1

func set_player_x(x: float) -> void:
	player_x = clamp(x, PADDLE.x / 2.0, FIELD.x - PADDLE.x / 2.0)

## Advances the simulation. Returns -1, or 0/1 when that side just scored.
func step(delta: float) -> int:
	if winner() != -1:
		return -1
	# computer: follow the ball when it's coming, drift to centre otherwise
	var aim: float = ball.x if vel.y < 0 else FIELD.x / 2.0
	cpu_x = move_toward(cpu_x, aim, cpu_speed * delta)
	cpu_x = clamp(cpu_x, PADDLE.x / 2.0, FIELD.x - PADDLE.x / 2.0)
	if serve_wait > 0.0:
		serve_wait -= delta
		return -1
	# sub-steps keep a fast ball from tunnelling through a paddle
	var steps := int(ceil(vel.length() * delta / 8.0))
	var dt: float = delta / max(1, steps)
	for i in steps:
		ball += vel * dt
		if ball.x < BALL_R:
			ball.x = BALL_R
			vel.x = abs(vel.x)
		elif ball.x > FIELD.x - BALL_R:
			ball.x = FIELD.x - BALL_R
			vel.x = -abs(vel.x)
		var player_y := FIELD.y - 60.0
		var cpu_y := 60.0
		if vel.y > 0 and ball.y + BALL_R >= player_y and ball.y < player_y + PADDLE.y and abs(ball.x - player_x) <= PADDLE.x / 2.0 + BALL_R:
			_bounce(player_x, -1.0)
			ball.y = player_y - BALL_R
		elif vel.y < 0 and ball.y - BALL_R <= cpu_y + PADDLE.y and ball.y > cpu_y and abs(ball.x - cpu_x) <= PADDLE.x / 2.0 + BALL_R:
			_bounce(cpu_x, 1.0)
			ball.y = cpu_y + PADDLE.y + BALL_R
		if ball.y > FIELD.y + BALL_R:
			scores[1] += 1
			serve_to = 0
			_serve()
			return 1
		if ball.y < -BALL_R:
			scores[0] += 1
			serve_to = 1
			_serve()
			return 0
	return -1

func _bounce(paddle_x: float, dir_y: float) -> void:
	var offset: float = clamp((ball.x - paddle_x) / (PADDLE.x / 2.0), -1.0, 1.0)
	var speed: float = min(vel.length() * 1.06, MAX_SPEED)
	var ang := offset * 1.0   # up to ~57 degrees
	vel = Vector2(sin(ang), cos(ang) * dir_y) * speed
