extends RefCounted

## Registers the keyboard actions in code (not in project.godot) because a pack runs with
## the hub's project.godot. Safe to call many times. Layout from Turned's CLAUDE.md §3:
## arrows/WASD = d-pad, E = A, Shift = B, Space/J = X, K = Y, Esc = Pause, Tab = Menu.
## X and Y are registered but do nothing yet (their buttons are not in the game).

const ACTIONS := {
	"tn_left": [KEY_A, KEY_LEFT],
	"tn_right": [KEY_D, KEY_RIGHT],
	"tn_up": [KEY_W, KEY_UP],
	"tn_down": [KEY_S, KEY_DOWN],
	"tn_a": [KEY_E],
	"tn_b": [KEY_SHIFT],
	"tn_x": [KEY_SPACE, KEY_J],
	"tn_y": [KEY_K],
	"tn_pause": [KEY_ESCAPE],
	"tn_menu": [KEY_TAB],
	"tn_debug_hurt": [KEY_F10],
}

static func ensure_actions() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
			for key in ACTIONS[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)

static func release_all() -> void:
	for action in ACTIONS:
		Input.action_release(action)
