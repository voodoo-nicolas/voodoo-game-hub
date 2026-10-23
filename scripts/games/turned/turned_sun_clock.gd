extends RefCounted

## SunClock: the world clock and how strong the sun is. Turned's CLAUDE.md asks for an autoload;
## a pack cannot add autoloads (it runs with the hub's project.godot), so the world owns the one
## instance and `TurnedSunClock.instance` reaches it from anywhere in the pack.
##
## Day 1 slice: `sun.freeze_clock` is true, so the hour stays at `sun.start_hour` (late morning)
## and the sun is at full strength. With it false the clock runs (`sun.day_length_s` real seconds
## per day) and the sun fades in at sunrise and out at sunset.

const T = preload("res://scripts/games/turned/turned_tuning.gd")

static var instance: RefCounted = null

var day := 1
var hour := 10.0

func _init() -> void:
	hour = T.f("sun.start_hour")
	instance = self

func advance(delta: float) -> void:
	if T.b("sun.freeze_clock"):
		return
	hour += delta * 24.0 / maxf(T.f("sun.day_length_s"), 1.0)
	while hour >= 24.0:
		hour -= 24.0
		day += 1

## 0 at night, 1 in full day, smooth ramps of `sun.ramp_hours` at sunrise and sunset.
func intensity() -> float:
	var ramp := maxf(T.f("sun.ramp_hours"), 0.01)
	var up := clampf((hour - T.f("sun.sunrise_hour")) / ramp, 0.0, 1.0)
	var down := clampf((T.f("sun.sunset_hour") - hour) / ramp, 0.0, 1.0)
	return minf(up, down)

func is_day() -> bool:
	return intensity() > 0.0

func to_dict() -> Dictionary:
	return {"day": day, "hour": hour}

func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	hour = float(d.get("hour", T.f("sun.start_hour")))
