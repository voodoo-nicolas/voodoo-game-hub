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

## The game's name. It was "Voodoo IQ" (still in the prototype's text and the
## data file); the user renamed it "IQ Test" for now (2026-10-05), and t()
## swaps the old name everywhere, so a new name is this one line.
const APP_NAME := {"en": "IQ Test", "es": "Test de IQ"}

static func app_name() -> String:
	return str(APP_NAME.get(lang(), APP_NAME.en))

## The timed mode. The prototype's text, the server (mode "blitz") and the
## stat keys say "Blitz"; players see this name since 2026-10-06 (Voodoo,
## the publisher, runs an app called Blitz -- docs/ip-audit-2026-10-06.md).
## Spanish "Relámpago" reads right in every sentence the data file has.
const BLITZ_NAME := {"en": "Speed Round", "es": "Relámpago"}

static func blitz_name() -> String:
	return str(BLITZ_NAME.get(lang(), BLITZ_NAME.en))

## Player-facing names in place of the old ones, in text from the data files.
static func named(s: String) -> String:
	return s.replace("Voodoo IQ", app_name()).replace("Blitz", blitz_name())

## Stat keys can't change (they are save keys), so their English labels come
## from this translation, installed for as long as `owner` lives. Spanish
## labels are in tools/i18n/es.json as usual.
const EN_LABELS := {"Blitz runs": "Speed Rounds played", "Best Blitz points": "Best Speed Round points"}

static func install_en_labels(owner: Node) -> void:
	var t := Translation.new()
	t.locale = "en"
	for key in EN_LABELS:
		t.add_message(key, EN_LABELS[key])
	TranslationServer.add_translation(t)
	# A lambda: the i18n file already connects remove_translation.bind(...)
	# here, and Godot treats a second bind of the same method as a duplicate.
	# It's on the owner's own signal, so it goes away with the owner.
	owner.tree_exiting.connect(func(): TranslationServer.remove_translation(t))

## The prototype's t(): text for `key` in the current language, English as the
## fallback, with {name} placeholders filled from `vars`.
static func t(key: String, vars: Dictionary = {}) -> String:
	var str_tables: Dictionary = data().get("STR", {})
	var s: String = str(str_tables.get(lang(), {}).get(key, str_tables.get("en", {}).get(key, key)))
	s = named(s)
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

## The Info screen's text (voodoo_iq_info.json, hand-written, EN / ES like Trivia's
## question bank, so its long paragraphs stay out of es.json).
const INFO_PATH := "res://scripts/games/voodoo_iq/voodoo_iq_info.json"

static var _info: Dictionary = {}

static func info(key: String):
	if _info.is_empty():
		var f := FileAccess.open(INFO_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_info = parsed
	return _named_deep(_info.get(lang(), {}).get(key, _info.get("en", {}).get(key, "")))

## named() through Info text (strings, nested in arrays too).
static func _named_deep(v):
	if v is String:
		return named(v)
	if v is Array:
		return v.map(_named_deep)
	return v
