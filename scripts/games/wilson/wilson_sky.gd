extends RefCounted

## Beached: sky maths (no Nodes, headless-testable). Sun times, keyframe colours, moon phase, star fade.
## Formulas: design/GDD.md §4 and games/wilson/data/daynight.json (owner's data, read at runtime).
##   L = base + amplitude * cos(2*pi*(doy - peak)/365), peak = 355 (south) / 172 (north)
##   sunrise = solar_noon - L/2, sunset = solar_noon + L/2 (local hours)
##   moon phase = ((now - epoch)/86400 mod synodic) / synodic; 0 = new, 0.5 = full

const D = preload("res://scripts/games/wilson/wilson_data.gd")

## 2000-01-06T18:14:00Z (daynight.json "epoch_new_moon_utc") as unix seconds.
const MOON_EPOCH := 947182440.0

static func daylight() -> Dictionary:
	return D.json("daynight").get("daylight", {})

## Hours of daylight on day-of-year `doy` (1..366).
static func day_length(doy: int, hemisphere: String) -> float:
	var dl := daylight()
	var peak: float = dl.get("peak_doy_south", 355) if hemisphere == "south" else dl.get("peak_doy_north", 172)
	return float(dl.get("base", 12.0)) + float(dl.get("amplitude", 1.5)) * cos(TAU * (doy - peak) / 365.0)

static func sunrise(doy: int, hemisphere: String) -> float:
	return float(daylight().get("solar_noon", 12.25)) - day_length(doy, hemisphere) / 2.0

static func sunset(doy: int, hemisphere: String) -> float:
	return float(daylight().get("solar_noon", 12.25)) + day_length(doy, hemisphere) / 2.0

## Moon phase 0..1 at unix time `t` (UTC).
static func moon_phase(t: float) -> float:
	var syn: float = float(D.json("daynight").get("moon", {}).get("synodic_days", 29.530588))
	return fposmod((t - MOON_EPOCH) / 86400.0, syn) / syn

## Lit fraction of the moon's disc (0 new .. 1 full).
static func moon_lit(phase: float) -> float:
	return (1.0 - cos(TAU * phase)) / 2.0

## The 12 keyframes with their hour for this day, sorted: [[hour, kf], ...].
static func keyframes(doy: int, hemisphere: String) -> Array:
	var rise := sunrise(doy, hemisphere)
	var down := sunset(doy, hemisphere)
	var out := []
	for kf in D.json("daynight").get("keyframes", []):
		var at: Dictionary = kf.get("at", {})
		var h := 0.0
		if at.has("fixed"):
			h = float(at.fixed)
		elif at.has("sunrise"):
			h = rise + float(at.sunrise)
		elif at.has("sunset"):
			h = down + float(at.sunset)
		out.append([fposmod(h, 24.0), kf])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out

## The sky at local hour `hour`: {sky_top, horizon, light_tint: Color, intensity: float}.
## Linear RGB interpolation between neighbouring keyframes, wrapping midnight.
static func sky_at(hour: float, doy: int, hemisphere: String) -> Dictionary:
	var kfs := keyframes(doy, hemisphere)
	if kfs.is_empty():
		return {"sky_top": Color("3d9bd6"), "horizon": Color("cdeef2"), "light_tint": Color.WHITE, "intensity": 1.0}
	hour = fposmod(hour, 24.0)
	var n := kfs.size()
	var i := n - 1
	for k in n:
		if kfs[k][0] <= hour:
			i = k
	var a: Array = kfs[i]
	var b: Array = kfs[(i + 1) % n]
	var ha: float = a[0]
	var hb: float = b[0]
	var span := fposmod(hb - ha, 24.0)
	var f := 0.0 if span <= 0.0 else fposmod(hour - ha, 24.0) / span
	var ka: Dictionary = a[1]
	var kb: Dictionary = b[1]
	return {
		"sky_top": Color(ka.sky_top).lerp(Color(kb.sky_top), f),
		"horizon": Color(ka.horizon).lerp(Color(kb.horizon), f),
		"light_tint": Color(ka.light_tint).lerp(Color(kb.light_tint), f),
		"intensity": lerpf(float(ka.intensity), float(kb.intensity), f),
	}

## Star alpha 0..1: fade in from sunset to sunset + 1 h, fade out from sunrise - 1 h to sunrise.
static func star_alpha(hour: float, doy: int, hemisphere: String) -> float:
	var st: Dictionary = D.json("daynight").get("stars", {})
	var fin: float = float(st.get("fade_in_after_sunset_h", 1.0))
	var fout: float = float(st.get("fade_out_before_sunrise_h", 1.0))
	var rise := sunrise(doy, hemisphere)
	var down := sunset(doy, hemisphere)
	if hour >= rise and hour <= down:
		return 0.0
	if hour > down:
		return clampf((hour - down) / fin, 0.0, 1.0)
	return clampf((rise - hour) / fout, 0.0, 1.0)

## Sun position on its arc: x 0..1 across the sky (sunrise -> sunset), height 0..1 (1 = noon), or
## height < 0 below the horizon.
static func sun_arc(hour: float, doy: int, hemisphere: String) -> Vector2:
	var rise := sunrise(doy, hemisphere)
	var down := sunset(doy, hemisphere)
	var f := (hour - rise) / (down - rise)
	return Vector2(f, sin(PI * f) if f >= 0.0 and f <= 1.0 else -0.2)

## Moon on its arc. Its transit (highest point) comes about 24 h * phase after noon: new moon at
## noon, first quarter at 18:00, full at midnight, last quarter at 06:00; it is up ~6.2 h each side.
static func moon_arc(hour: float, phase: float) -> Vector2:
	var transit := fposmod(12.0 + 24.0 * phase, 24.0)
	var d := fposmod(hour - transit + 12.0, 24.0) - 12.0  # -12..12 hours from transit
	var f := (d + 6.2) / 12.4
	return Vector2(f, sin(PI * f) if f >= 0.0 and f <= 1.0 else -0.2)
