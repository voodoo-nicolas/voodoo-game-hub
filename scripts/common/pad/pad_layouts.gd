extends RefCounted

## The on-screen controller's layout catalogue (Pad). A layout is DATA: a list of parts placed
## from the screen edges in design units (the screen is 720 units high; width follows the
## aspect). `place()` turns a layout into concrete pixel shapes for a given screen size, the
## player's size scale and handedness. Shapes and proportions come from the owner's mock-ups
## (D:\Dev\controls): stick ring 130, knob 60, face buttons 47 on a 79 diamond, pause/info pills.
##
## Part types:
##   stick  analog stick (id "move" / "aim"); ring `r`, knob `knob`
##   dpad   four arrow pads in a round plate (id "move"); 4- or 8-way is a player option
##   face4  four round buttons in a diamond: ids = [top, left, right, bottom]
##   button one round button
##   pill   a small rounded system button (icon: pause / info / menu)
## `side`: "left" / "right" (swap when left-handed) / "center". `off` = [from that edge, up from the
## bottom] ("top": true measures the second value from the top instead).

const REF_H := 720.0
const REF_W := 1280.0
const PORTRAIT_K := 0.85
const MARGIN := 8.0

const LAYOUTS := [
	{
		"id": "stick_4", "name": "Stick + 4 buttons",
		"desc": "Move stick, X Y B A diamond, pause and info.",
		"parts": [
			{"type": "stick", "id": "move", "side": "left", "off": [200, 190], "r": 130, "knob": 60},
			{"type": "face4", "side": "right", "off": [200, 190], "gap": 79, "r": 47, "ids": ["y", "x", "b", "a"]},
			{"type": "pill", "id": "pause", "side": "center", "off": [-63, 62], "w": 112, "h": 64, "icon": "pause"},
			{"type": "pill", "id": "info", "side": "center", "off": [63, 62], "w": 112, "h": 64, "icon": "info"},
		],
	},
	{
		"id": "dpad_4", "name": "D-pad + 4 buttons",
		"desc": "Arrow pad, X Y B A diamond, pause and info.",
		"parts": [
			{"type": "dpad", "id": "move", "side": "left", "off": [200, 190], "r": 130},
			{"type": "face4", "side": "right", "off": [200, 190], "gap": 79, "r": 47, "ids": ["y", "x", "b", "a"]},
			{"type": "pill", "id": "pause", "side": "center", "off": [-63, 62], "w": 112, "h": 64, "icon": "pause"},
			{"type": "pill", "id": "info", "side": "center", "off": [63, 62], "w": 112, "h": 64, "icon": "info"},
		],
	},
	{
		"id": "stick_2", "name": "Stick + 2 buttons",
		"desc": "Move stick, big A (low) and B (high).",
		"parts": [
			{"type": "stick", "id": "move", "side": "left", "off": [200, 190], "r": 130, "knob": 60},
			{"type": "button", "id": "a", "side": "right", "off": [270, 130], "r": 62},
			{"type": "button", "id": "b", "side": "right", "off": [135, 250], "r": 62},
			{"type": "pill", "id": "pause", "side": "center", "off": [-63, 62], "w": 112, "h": 64, "icon": "pause"},
			{"type": "pill", "id": "info", "side": "center", "off": [63, 62], "w": 112, "h": 64, "icon": "info"},
		],
	},
	{
		"id": "dpad_2", "name": "D-pad + 2 buttons",
		"desc": "Arrow pad, A (low) and B (high). The classic handheld.",
		"parts": [
			{"type": "dpad", "id": "move", "side": "left", "off": [200, 190], "r": 130},
			{"type": "button", "id": "a", "side": "right", "off": [270, 130], "r": 62},
			{"type": "button", "id": "b", "side": "right", "off": [135, 250], "r": 62},
			{"type": "pill", "id": "pause", "side": "center", "off": [-63, 62], "w": 112, "h": 64, "icon": "pause"},
			{"type": "pill", "id": "info", "side": "center", "off": [63, 62], "w": 112, "h": 64, "icon": "info"},
		],
	},
	{
		"id": "stick_arc", "name": "Stick + arc of 4",
		"desc": "Move stick, four buttons in an arc under the thumb (Evolution style).",
		"parts": [
			{"type": "stick", "id": "move", "side": "left", "off": [200, 190], "r": 130, "knob": 60},
			{"type": "button", "id": "a", "side": "right", "off": [105, 120], "r": 50},
			{"type": "button", "id": "b", "side": "right", "off": [235, 105], "r": 50},
			{"type": "button", "id": "x", "side": "right", "off": [215, 235], "r": 50},
			{"type": "button", "id": "y", "side": "right", "off": [95, 250], "r": 50},
			{"type": "pill", "id": "pause", "side": "center", "off": [-63, 62], "w": 112, "h": 64, "icon": "pause"},
			{"type": "pill", "id": "info", "side": "center", "off": [63, 62], "w": 112, "h": 64, "icon": "info"},
		],
	},
	{
		"id": "dual_stick", "name": "Twin stick (move + aim)",
		"desc": "Left stick moves, right stick aims and fires. Two small buttons between.",
		"parts": [
			{"type": "stick", "id": "move", "side": "left", "off": [200, 190], "r": 130, "knob": 60},
			{"type": "stick", "id": "aim", "side": "right", "off": [200, 190], "r": 130, "knob": 60, "fires": true},
			{"type": "button", "id": "a", "side": "right", "off": [410, 230], "r": 46},
			{"type": "button", "id": "b", "side": "right", "off": [410, 350], "r": 46},
			{"type": "pill", "id": "pause", "side": "center", "off": [-63, 62], "w": 112, "h": 64, "icon": "pause"},
			{"type": "pill", "id": "info", "side": "center", "off": [63, 62], "w": 112, "h": 64, "icon": "info"},
		],
	},
	{
		"id": "stick_1", "name": "Stick + 1 button",
		"desc": "Move stick and one big action button. For simple games.",
		"parts": [
			{"type": "stick", "id": "move", "side": "left", "off": [200, 190], "r": 130, "knob": 60},
			{"type": "button", "id": "a", "side": "right", "off": [190, 190], "r": 80},
			{"type": "pill", "id": "pause", "side": "center", "off": [-63, 62], "w": 112, "h": 64, "icon": "pause"},
			{"type": "pill", "id": "info", "side": "center", "off": [63, 62], "w": 112, "h": 64, "icon": "info"},
		],
	},
]

## A copy of a catalogue layout for one game: parts whose id is in `remove` are dropped and `add`
## (more part dictionaries, same format as LAYOUTS) is appended. Give it an `id` of the game's own:
##   var layout := Layouts.variant("stick_4", ["x", "y"], [{"type": "button", "id": "bag", ...}], "last_shift")
static func variant(base_id: String, remove: Array, add: Array, new_id: String) -> Dictionary:
	var base := get_layout(base_id)
	var out := {"id": new_id, "name": str(base["name"]), "desc": str(base.get("desc", "")), "parts": []}
	for part in base["parts"]:
		var pid := str(part.get("id", ""))
		if part["type"] == "face4":
			pid = str(part["ids"][3])
		if remove.has(pid):
			continue
		out["parts"].append(part.duplicate(true))
	for part in add:
		out["parts"].append(part.duplicate(true))
	return out

static func ids() -> Array:
	var out: Array = []
	for l in LAYOUTS:
		out.append(l["id"])
	return out

static func get_layout(id: String) -> Dictionary:
	for l in LAYOUTS:
		if l["id"] == id:
			return l
	return LAYOUTS[0]

## The next / previous layout id in the catalogue (wraps).
static func step(id: String, dir: int) -> String:
	var all := ids()
	var i := all.find(id)
	return all[posmod(i + dir, all.size())]

## Concrete shapes for `size` (pixels). `scale` is the player's size slider (1.0 = the mock-ups),
## `right_handed` false mirrors left/right, `floating` gives each stick a touch zone instead of a
## fixed spot. Each entry: {kind, id, pos, r, ...}; pill has `rect`, stick has `knob` + `zone`.
static func place(layout: Dictionary, size: Vector2, scale: float, right_handed: bool, floating: bool, wide_zone: bool = false) -> Array:
	# Landscape: height decides on a phone; a narrower screen (a tablet) shrinks the pad to fit.
	# Portrait: the pad is a little smaller than the mock-ups (the field above needs the room).
	var k := (size.x / REF_H * PORTRAIT_K if size.y > size.x else minf(size.y / REF_H, size.x / REF_W)) * scale
	var out: Array = []
	for part in layout["parts"]:
		var t: String = part["type"]
		var side: String = part.get("side", "left")
		if not right_handed:
			side = {"left": "right", "right": "left"}.get(side, side)
		var off: Array = part.get("off", [0, 0])
		var x: float
		match side:
			"left":
				x = float(absf(off[0])) * k
			"right":
				x = size.x - float(absf(off[0])) * k
			_:
				x = size.x * 0.5 + float(off[0]) * k * (1.0 if right_handed else -1.0)
		var y: float = float(off[1]) * k if part.get("top", false) else size.y - float(off[1]) * k
		var p := Vector2(x, y)
		match t:
			"stick":
				var r: float = float(part["r"]) * k
				p = _clamp(p, r, size)
				var zone := Rect2(0.0, size.y * 0.3, size.x * 0.45, size.y * 0.7) if side == "left" \
					else Rect2(size.x * 0.55, size.y * 0.3, size.x * 0.45, size.y * 0.7)
				out.append({"kind": "stick", "id": part["id"], "pos": p, "home": p, "r": r, "knob": float(part["knob"]) * k,
					"zone": zone, "floating": floating, "fires": part.get("fires", false), "side": side})
			"dpad":
				var r2: float = float(part["r"]) * k
				p = _clamp(p, r2, size)
				out.append({"kind": "dpad", "id": part["id"], "pos": p, "r": r2, "side": side})
			"face4":
				var g: float = float(part["gap"]) * k
				var br: float = float(part["r"]) * k
				var plate_r := g + br * 1.55
				p = _clamp(p, plate_r, size)
				out.append({"kind": "plate", "id": "plate_" + str(part["ids"][3]), "pos": p, "r": plate_r, "ids": part["ids"]})
				var spots := [Vector2(0, -g), Vector2(-g, 0), Vector2(g, 0), Vector2(0, g)]
				for i in 4:
					var bid: String = part["ids"][i]
					out.append({"kind": "button", "id": bid, "pos": p + spots[i], "r": br, "label": bid.to_upper(), "side": side})
			"button":
				var br2: float = float(part["r"]) * k
				p = _clamp(p, br2, size)
				out.append({"kind": "button", "id": part["id"], "pos": p, "r": br2, "label": str(part.get("label", str(part["id"]).to_upper())), "side": side})
			"pill":
				var sz := Vector2(float(part["w"]), float(part["h"])) * k
				var c := _clamp(p, maxf(sz.x, sz.y) * 0.5, size)
				out.append({"kind": "pill", "id": part["id"], "pos": c, "rect": Rect2(c - sz * 0.5, sz), "icon": part.get("icon", ""), "side": side})
	return out

static func _clamp(p: Vector2, r: float, size: Vector2) -> Vector2:
	var m := r + MARGIN
	return Vector2(clampf(p.x, m, maxf(m, size.x - m)), clampf(p.y, m, maxf(m, size.y - m)))
