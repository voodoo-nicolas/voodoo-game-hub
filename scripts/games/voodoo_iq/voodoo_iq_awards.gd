extends RefCounted

## IQ Test's own achievements (CHALLENGES in voodoo_iq_help.gd; owner, 2026-10-28): the ★130+
## genius medal in each section, 📚 Prepper (1 hour of practice in all) and 🔧 Fixer (a 🚩
## report that was confirmed and fixed). They pay through the hub's challenge log
## (Achievements.report_challenge, app v0.38+); older apps just skip them. Genius and Fixer
## come from the leaderboard function (board "awards": the medal exactly as the section board
## shows it, and reports the owner marked with supabase/checks/iq_report_fixed.sql); practice
## time is counted on this phone.

const SaveUtil = preload("res://scripts/common/save_util.gd")

const GAME_ID := "voodoo_iq"
## APK-side: never preloaded (packs run on older apps).
const HUB_ACH_PATH := "res://scripts/common/achievements.gd"
const CHALLENGES_PATH := "user://challenges_voodoo_iq.json"  # = Achievements.challenges_path(GAME_ID)
const STATE_PATH := "user://voodoo_iq_awards.json"  # {practice_s}
const PREPPER_S := 3600.0

static func _hub():
	var a = load(HUB_ACH_PATH) if ResourceLoader.exists(HUB_ACH_PATH) else null
	return a if _has(a, "report_challenge") else null

static func _has(script, method: String) -> bool:
	if script == null:
		return false
	for m in script.get_script_method_list():
		if str(m.get("name", "")) == method:
			return true
	return false

## The hub can pay challenges (app v0.38+): otherwise there is nothing to check or show.
static func available() -> bool:
	return _hub() != null

static func _done() -> Dictionary:
	if not FileAccess.file_exists(CHALLENGES_PATH):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(CHALLENGES_PATH))
	return d.done if d is Dictionary and d.get("done") is Dictionary else {}

static func earned(id: String) -> bool:
	return _done().has("c_" + id)

## Pays a challenge once (the hub shows its own toast). True when newly earned.
static func pay(id: String) -> bool:
	var a = _hub()
	return a != null and bool(a.report_challenge(GAME_ID, id))

# ---------- practice time (Prepper)

static func _state() -> Dictionary:
	var d = SaveUtil.read(STATE_PATH)
	return d if d is Dictionary else {}

static func practice_seconds() -> float:
	return float(_state().get("practice_s", 0.0))

## Adds practice seconds; pays Prepper once the total reaches an hour.
static func add_practice(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var d := _state()
	d["practice_s"] = float(d.get("practice_s", 0.0)) + seconds
	SaveUtil.write(STATE_PATH, d)
	if float(d.practice_s) >= PREPPER_S and not earned("prepper"):
		pay("prepper")

# ---------- server checks (Genius, Fixer)

## The leaderboard "awards" request for what isn't earned yet among `secs`, or {} when
## nothing is left to ask (or the app can't pay challenges).
static func request(secs: Array, fixer: bool) -> Dictionary:
	if not available():
		return {}
	var genius: Array = []
	for s in secs:
		if not earned("genius_" + str(s)):
			genius.append(str(s))
	var ask_fixer := fixer and not earned("fixer")
	if genius.is_empty() and not ask_fixer:
		return {}
	return {"board": "awards", "genius": genius, "fixer": ask_fixer}

## Pays what the "awards" reply says was reached.
static func apply(data: Dictionary) -> void:
	var g = data.get("genius", [])
	if g is Array:
		for s in g:
			pay("genius_" + str(s))
	if data.get("fixer", false) == true:
		pay("fixer")

# ---------- the 🏅 screen

## Every IQ badge: the generic ones from GameInfo (tests, Speed Rounds, records) and the
## CHALLENGES. [{icon, title, desc, unlocked, progress, xp}], translated.
static func rows(info, challenges: Array) -> Array:
	var out: Array = []
	var a = load(HUB_ACH_PATH) if ResourceLoader.exists(HUB_ACH_PATH) else null
	if info and _has(a, "xp_for") and "consts" in info and "stats" in info:
		# GameInfo.achievement_rows, plus each badge's points
		for d in a.defs_for(info.consts, info.stats):
			out.append({"icon": d.icon, "title": str(TranslationServer.translate(str(d.title))), "desc": a.describe(d),
				"unlocked": a.is_unlocked(info.stats, d), "progress": a.progress(info.stats, d), "xp": int(a.xp_for(str(d.id)))})
	elif info and info.has_method("achievement_rows"):
		out = info.achievement_rows()
	if available():
		var done := _done()
		var practice := practice_seconds()
		for c in challenges:
			var id := str(c.get("id", ""))
			var got: bool = done.has("c_" + id)
			var progress := 1.0 if got else 0.0
			if id == "prepper" and not got:
				progress = clampf(practice / PREPPER_S, 0.0, 1.0)
			out.append({"icon": str(c.get("icon", "🏅")), "title": str(TranslationServer.translate(str(c.get("title", id)))),
				"desc": str(TranslationServer.translate(str(c.get("desc", "")))), "unlocked": got,
				"progress": progress, "xp": int(c.get("xp", 30))})
	# earned first, each part in its declared order (sort_custom isn't stable)
	return out.filter(func(r): return r.unlocked) + out.filter(func(r): return not r.unlocked)
