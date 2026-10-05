extends RefCounted

## Fortune Ball: shake (or tap) the ball, it settles, an answer floats up.
## Pure logic, no Nodes -- the scene feeds it the phone's accelerometer (or
## finger flicks) every frame and draws whatever state it is in.
##
## Shake detection: every change in acceleration bigger than JERK_MIN adds to
## `energy`, which drains exponentially. Past SHAKE_ON the ball is shaking;
## once it drops under SHAKE_OFF and stays calm for SETTLE seconds, the
## answer is picked. One bump of the phone is not enough to count.

const ANSWERS_PATH := "res://scripts/games/fortune_ball/fortune_ball_answers.json"
const DECKS := ["classic", "spooky"]

const JERK_MIN := 3.0      # m/s² change per sample that counts as shaking
const JERK_GAIN := 0.15    # energy per m/s² above JERK_MIN
const DECAY := 3.0         # energy drains as exp(-DECAY * t)
const ENERGY_CAP := 4.0    # so a long shake still ends quickly
const SHAKE_ON := 1.5
const SHAKE_OFF := 0.6
const SETTLE := 0.5
const POKE := 2.2          # a tap on the ball: a short shake by itself
## A finger flick on the ball: px/s of velocity change per unit of energy.
const FLICK_MIN := 1500.0
const FLICK_GAIN := 0.0004

enum { IDLE, SHAKING, SETTLING, SHOWN }

var answers: Dictionary = {}   # deck -> [{tone, en, es}]
var deck := "classic"
var lang := "en"
var state := IDLE
var energy := 0.0
var settle_t := 0.0
var answer := ""
var tone := ""                 # "yes" / "maybe" / "no"
var asked: int = 0
var _bag: Array = []           # shuffled indices still to come in this deck
var _answer_en := ""           # the last answer, in English (to avoid repeats)
var _last_accel := Vector3.ZERO
var _has_accel := false

func load_answers(path: String = ANSWERS_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return false
	answers = parsed
	return true

func start(p_deck: String, p_lang: String) -> void:
	deck = p_deck if p_deck in DECKS else "classic"
	lang = p_lang
	state = IDLE
	energy = 0.0
	answer = ""
	tone = ""
	_bag = []

## One accelerometer sample (m/s², gravity included). A phone lying still
## reads ~9.8; a zero vector means there is no sensor (PC).
func feed_accel(a: Vector3) -> void:
	if a.length() < 2.0:
		_has_accel = false
		return
	if _has_accel:
		_add((a - _last_accel).length() - JERK_MIN, JERK_GAIN)
	_last_accel = a
	_has_accel = true

## A change in finger velocity while dragging the ball (px/s).
func feed_flick(dv: float) -> void:
	_add(dv - FLICK_MIN, FLICK_GAIN)

## A tap on the ball (or the Shake button): shakes it on its own.
func poke() -> void:
	energy = maxf(energy, POKE)

func _add(excess: float, gain: float) -> void:
	if excess > 0.0:
		energy = minf(energy + excess * gain, ENERGY_CAP)

## Advances the ball. Returns "shake" on the frame shaking starts,
## "reveal" on the frame the answer is picked, else "".
func step(delta: float) -> String:
	energy *= exp(-DECAY * delta)
	match state:
		IDLE, SHOWN:
			if energy > SHAKE_ON:
				state = SHAKING
				answer = ""
				return "shake"
		SHAKING:
			if energy < SHAKE_OFF:
				state = SETTLING
				settle_t = 0.0
		SETTLING:
			if energy > SHAKE_ON:
				state = SHAKING
			else:
				settle_t += delta
				if settle_t >= SETTLE:
					_pick()
					state = SHOWN
					return "reveal"
	return ""

func is_shaking() -> bool:
	return state == SHAKING or state == SETTLING

## Next answer from a shuffled bag, so no answer repeats until the deck has
## gone round (and never twice in a row across a reshuffle).
func _pick() -> void:
	var list: Array = answers.get(deck, [])
	if list.is_empty():
		answer = "?"
		tone = "maybe"
		return
	if _bag.is_empty():
		var last := -1
		for i in list.size():
			if str(list[i].get("en", "")) == _answer_en:
				last = i
		_bag = range(list.size())
		_bag.shuffle()
		if _bag.size() > 1 and _bag.back() == last:
			_bag.reverse()
	var e: Dictionary = list[_bag.pop_back()]
	answer = str(e.get(lang, e.get("en", "?")))
	_answer_en = str(e.get("en", ""))
	tone = str(e.get("tone", "maybe"))
	asked += 1
