extends RefCounted

## Registers the movement actions in code (not in project.godot) because when
## this game runs as a pack inside the hub, the hub's project.godot is used.
## Safe to call many times.

const ACTIONS := {
	"ls_move_left": [KEY_A, KEY_LEFT],
	"ls_move_right": [KEY_D, KEY_RIGHT],
	"ls_move_up": [KEY_W, KEY_UP],
	"ls_move_down": [KEY_S, KEY_DOWN],
	"ls_action_a": [KEY_SPACE, KEY_E],   # A: interact / confirm
	"ls_action_b": [KEY_K, KEY_J],       # B: attack (wrench / pistol, later)
	"ls_pause": [KEY_ESCAPE, KEY_P],
	"ls_swap": [KEY_Q],                  # next weapon (keyboard quick swap)
	"ls_wheel": [KEY_TAB],               # open / close the weapon wheel
	"ls_bag": [KEY_I],                   # open / close the bag (inventory)
	"ls_log": [KEY_L],                   # open / close the mission log
	"ls_heal": [KEY_H],                  # quick heal (first-aid kit / snack from the bag)
	"ls_map": [KEY_M],                   # v0.5: open / close the building map
}

static func ensure_actions() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
			for key in ACTIONS[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)
