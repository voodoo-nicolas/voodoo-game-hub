extends RefCounted
## Pure quest logic. defs: id -> {steps:[{ev, text:{en,es}}], reward:{items:{}, flags:[], obols:int, renown:int}, next:[ids]}
## state: id -> {state:"active"|"done", step:int}. Events: "talk:x", "enter:x", "item:x", "kill:x", "flag:x".

var defs: Dictionary = {}
var state: Dictionary = {}
var log: Array = []     ## completed-quest rewards waiting for the game to pay out

func state_of(id: String) -> String:
	return state[id]["state"] if state.has(id) else "inactive"

func start(id: String) -> bool:
	if not defs.has(id) or state.has(id):
		return false
	state[id] = {"state": "active", "step": 0}
	return true

func step_of(id: String) -> int:
	return int(state[id]["step"]) if state.has(id) else -1

func current_text(id: String, lang: String) -> String:
	if state_of(id) != "active":
		return ""
	var steps: Array = defs[id]["steps"]
	var i := step_of(id)
	if i >= steps.size():
		return ""
	var t: Dictionary = steps[i]["text"]
	return t.get(lang, t.get("en", ""))

## Returns ids of quests that changed (advanced or completed).
func notify(ev: String) -> Array:
	var changed: Array = []
	for id in state.keys():
		if state[id]["state"] != "active":
			continue
		var steps: Array = defs[id]["steps"]
		var guard := 0
		# a step whose event already happened is "latched" via flag events, so loop to chain
		while state[id]["step"] < steps.size() and steps[state[id]["step"]]["ev"] == ev and guard < 1:
			guard += 1
			state[id]["step"] += 1
			if id not in changed:
				changed.append(id)
		if state[id]["step"] >= steps.size() and state[id]["state"] == "active":
			state[id]["state"] = "done"
			log.append({"id": id, "reward": defs[id].get("reward", {})})
	return changed

func to_dict() -> Dictionary:
	return state.duplicate(true)

func from_dict(d: Dictionary) -> void:
	state = d.duplicate(true)
