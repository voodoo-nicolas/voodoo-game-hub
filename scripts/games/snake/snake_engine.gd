extends RefCounted

enum Dir { UP, DOWN, LEFT, RIGHT }

const DELTA := {
	Dir.UP: Vector2i(0, -1), Dir.DOWN: Vector2i(0, 1),
	Dir.LEFT: Vector2i(-1, 0), Dir.RIGHT: Vector2i(1, 0),
}
const OPPOSITE := {
	Dir.UP: Dir.DOWN, Dir.DOWN: Dir.UP,
	Dir.LEFT: Dir.RIGHT, Dir.RIGHT: Dir.LEFT,
}

var grid_size: int = 15
var snake: Array = []  # Vector2i, [0] = head
var direction: int = Dir.RIGHT
var pending_direction: int = Dir.RIGHT
var food: Vector2i = Vector2i(-1, -1)
var score: int = 0
var game_over: bool = false

func reset(size: int = 15) -> void:
	grid_size = size
	var mid: int = grid_size / 2
	snake = [Vector2i(mid, mid), Vector2i(mid - 1, mid), Vector2i(mid - 2, mid)]
	direction = Dir.RIGHT
	pending_direction = Dir.RIGHT
	score = 0
	game_over = false
	_spawn_food()

func _spawn_food() -> void:
	while true:
		var candidate := Vector2i(randi() % grid_size, randi() % grid_size)
		if not snake.has(candidate):
			food = candidate
			return

## Ignores a 180-degree reversal into the snake's own neck; queues everything
## else for the next step() call.
func set_direction(d: int) -> void:
	if OPPOSITE[d] != direction:
		pending_direction = d

## Advances one tick. Returns true if this step just ended the game.
func step() -> bool:
	if game_over:
		return false
	direction = pending_direction
	var head: Vector2i = snake[0]
	var new_head: Vector2i = head + DELTA[direction]

	if new_head.x < 0 or new_head.x >= grid_size or new_head.y < 0 or new_head.y >= grid_size:
		game_over = true
		return true

	var will_eat: bool = new_head == food
	# The tail vacates this same step unless the snake is growing, so moving
	# into the current tail cell is legal -- exclude it from the collision
	# check in that case.
	var body_to_check: Array = snake if will_eat else snake.slice(0, snake.size() - 1)
	if body_to_check.has(new_head):
		game_over = true
		return true

	snake.insert(0, new_head)
	if will_eat:
		score += 1
		_spawn_food()
	else:
		snake.pop_back()
	return false
