extends RefCounted

## SunClock: the world clock, how strong the sun is and how high the moon. Turned's CLAUDE.md asks
## for an autoload; a pack cannot add autoloads (it runs with the hub's project.godot), so the world
## owns the one instance and `TurnedSunClock.instance` reaches it from anywhere in the pack.
##
## The story starts on a Friday at `sun.start_hour` (dawn, 7:00) = day 1, and the clock runs while
## the player is in free play (`sun.day_length_s` real seconds per 24 game hours). The sun fades in
## at sunrise and out at sunset; the moon rises at `moon.rise_hour` and sets at `moon.set_hour`
## (it crosses midnight). `sun.freeze_clock` true stops the clock (the old Day 1 slice).

const T = preload("res://scripts/games/turned/turned_tuning.gd")

static var instance: RefCounted = null

var day := 1
var hour := 7.0

func _init() -> void:
	hour = T.f("sun.start_hour")
	instance = self

func advance(delta: float) -> void:
	if T.b("sun.freeze_clock"):
		return
	advance_hours(delta * 24.0 / maxf(T.f("sun.day_length_s"), 1.0))

## Moves the clock on by game hours (the clock itself, the F9 debug key and story jumps).
func advance_hours(h: float) -> void:
	hour += h
	while hour >= 24.0:
		hour -= 24.0
		day += 1

## Story jump to a clock time: later today if `h` is still ahead, else tomorrow.
func skip_to(h: float) -> void:
	if h <= hour:
		day += 1
	hour = h

## 0 at night, 1 in full day, smooth ramps of `sun.ramp_hours` at sunrise and sunset.
func intensity() -> float:
	var ramp := maxf(T.f("sun.ramp_hours"), 0.01)
	var up := clampf((hour - T.f("sun.sunrise_hour")) / ramp, 0.0, 1.0)
	var down := clampf((T.f("sun.sunset_hour") - hour) / ramp, 0.0, 1.0)
	return minf(up, down)

func is_day() -> bool:
	return intensity() > 0.0

## Hours since moonrise, or -1 while the moon is below the horizon.
func _moon_t() -> float:
	var rise := T.f("moon.rise_hour")
	var t := hour - rise if hour >= rise else hour + 24.0 - rise
	return t if t <= moon_span() else -1.0

## How long the moon stays up, in hours.
func moon_span() -> float:
	return T.f("moon.set_hour") + 24.0 - T.f("moon.rise_hour")

## 0 with the moon down, up to 1 high in the sky; eases in at moonrise and out at moonset.
func moon_level() -> float:
	var t := _moon_t()
	if t < 0.0:
		return 0.0
	var ramp := maxf(T.f("moon.ramp_hours"), 0.01)
	return minf(clampf(t / ramp, 0.0, 1.0), clampf((moon_span() - t) / ramp, 0.0, 1.0))

## 0 at moonrise ... 1 at moonset (where the moon is on its way across; 0 while it is down).
func moon_progress() -> float:
	var t := _moon_t()
	return clampf(t / moon_span(), 0.0, 1.0) if t >= 0.0 else 0.0

## 0 in daylight, 1 in the dark: the part of the sky the sun does not light.
func night() -> float:
	return 1.0 - intensity()

func hour_text() -> String:
	var h := int(floorf(hour))
	return "%02d:%02d" % [h, int(floorf((hour - float(h)) * 60.0))]

func to_dict() -> Dictionary:
	return {"day": day, "hour": hour}

func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	hour = float(d.get("hour", T.f("sun.start_hour")))
