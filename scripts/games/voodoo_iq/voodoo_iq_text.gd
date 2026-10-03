extends RefCounted

## Voodoo IQ's text and data: voodoo_iq_data.json, extracted verbatim from the
## reference prototype (docs/voodoo-iq-prototype.html) by tools/iq_extract.ts.
## The pack carries its own EN / ES text (like Trivia's question bank) instead of
## going through tools/i18n/es.json, so the prototype's wording stays 1:1.

const DATA_PATH := "res://scripts/games/voodoo_iq/voodoo_iq_data.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data

## "es" or "en", following the app's language (Lang autoload / phone language).
static func lang() -> String:
	return "es" if TranslationServer.get_locale().begins_with("es") else "en"

## The prototype's t(): text for `key` in the current language, English as the
## fallback, with {name} placeholders filled from `vars`.
static func t(key: String, vars: Dictionary = {}) -> String:
	var str_tables: Dictionary = data().get("STR", {})
	var s: String = str(str_tables.get(lang(), {}).get(key, str_tables.get("en", {}).get(key, key)))
	for k in vars:
		s = s.replace("{" + str(k) + "}", str(vars[k]))
	return s

static func sec_color(sec: String) -> Color:
	return Color(str(data().get("SEC_COLOR", {}).get(sec, "#E8E8F2")))

static func secs() -> Array:
	return data().get("SECS", [])

static func core() -> Array:
	return data().get("CORE", [])

static func gate(key: String) -> float:
	return float(data().get("GATE", {}).get(key, 0.0))

## IQ scale helpers (prototype IQ / fmtIQ / bandLabel / normCdf).
static func iq(theta: float) -> float:
	return 100.0 + 15.0 * theta

## The real number, never clamped (the prototype showed 145+ / <55; the user wants
## nothing hidden, 2026-10-03).
static func fmt_iq(theta: float) -> String:
	return str(int(round(iq(theta))))

static func band_label(point: float) -> String:
	if point < 70:
		return t("z_sigbelow")
	if point < 85:
		return t("z_below")
	if point < 115:
		return t("z_avg")
	if point < 130:
		return t("z_above")
	return t("z_sigabove")

static func norm_cdf(z: float) -> float:
	var tt := 1.0 / (1.0 + 0.2316419 * absf(z))
	var d := 0.3989423 * exp(-z * z / 2.0)
	var p := d * tt * (0.3193815 + tt * (-0.3565638 + tt * (1.781478 + tt * (-1.821256 + tt * 1.330274))))
	return 1.0 - p if z > 0 else p
