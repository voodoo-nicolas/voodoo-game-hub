extends "res://scripts/hub/hub_screen.gd"

## First-run / sign-up consent (compliance pack, Task 2): language, a neutral age
## gate (month + year of birth), the Terms/EULA and the Privacy Policy as
## separate screens, then two UNCHECKED boxes that must both be ticked. See
## scripts/common/consent.gd for what is stored (only the age bracket) and when.
##
## Steps: 0 age, 1 terms, 2 privacy, 3 accept. A player whose age is already
## known (a version bump, or an account made before this screen) starts at 1.

const Consent = preload("res://scripts/common/consent.gd")
const MONTHS := {
	"en": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
	"es": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"],
}

var step: int = 0
var month: int = 0   # 1..12, 0 = not chosen
var year: int = 0    # 0 = not chosen
var ticked_terms: bool = false
var ticked_privacy: bool = false
var _too_young: bool = false
var _age_known: bool = false  # started at step 1: the age was given earlier

func _title() -> String:
	return tr("Before you start")

func _ready() -> void:
	_too_young = Consent.is_blocked()
	if Consent.bracket() != "" and not _too_young:
		step = 1
		_age_known = true
	super()

## Back: one step up; from the first step (or the first one shown), leave without accepting.
func go_hub() -> void:
	if _too_young or step <= 0 or (step == 1 and _age_known):
		_leave()
		return
	step -= 1
	rebuild()

func _leave() -> void:
	get_tree().change_scene_to_file(Consent.return_scene)

func _build() -> void:
	if _too_young:
		_build_blocked()
		return
	match step:
		0: _build_age()
		1: _build_doc("terms")
		2: _build_doc("privacy")
		_: _build_accept()

func _lang() -> String:
	return Lang.current if Lang.current in ["es", "en"] else "es"

# ---------- step 0: language + age ----------

func _build_age() -> void:
	var lang := section(tr("Language"))
	lang.add_child(tabs(["English", "Español"], Lang.SUPPORTED.find(Lang.current), _on_language))

	var box := section(tr("Your age"))
	box.add_child(label(tr("When were you born?"), 26, null, true))
	box.add_child(dim(tr("We only keep your age range (13-15, 16-17 or 18+), never your birth date. It's what you tell us; we don't verify it.")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var month_pick := OptionButton.new()
	month_pick.custom_minimum_size = Vector2(0, 64)
	month_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	month_pick.add_theme_font_size_override("font_size", 24)
	month_pick.add_item(tr("Month"), 0)
	for i in 12:
		month_pick.add_item(MONTHS[_lang()][i], i + 1)
	month_pick.select(month)
	month_pick.item_selected.connect(_on_month.bind(month_pick))
	row.add_child(month_pick)
	var year_pick := OptionButton.new()
	year_pick.custom_minimum_size = Vector2(0, 64)
	year_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	year_pick.add_theme_font_size_override("font_size", 24)
	year_pick.add_item(tr("Year"), 0)
	var this_year: int = int(Time.get_date_dict_from_system().year)
	var selected := 0
	for y in range(this_year, this_year - 101, -1):
		year_pick.add_item(str(y), y)
		if y == year:
			selected = year_pick.item_count - 1
	year_pick.select(selected)
	year_pick.item_selected.connect(_on_year.bind(year_pick))
	row.add_child(year_pick)
	var go := pill(tr("Continue"), true, 28)
	go.disabled = month == 0 or year == 0
	go.modulate.a = 0.4 if go.disabled else 1.0  # a disabled pill looks the same otherwise
	go.pressed.connect(_on_age_continue)
	box.add_child(go)
	box.add_child(_help_link())

func _on_language(i: int) -> void:
	var code: String = Lang.SUPPORTED[i]
	if code != Lang.current:
		Lang.set_language(code)
		get_tree().reload_current_scene()

func _on_month(index: int, pick: OptionButton) -> void:
	month = pick.get_item_id(index)
	rebuild()

func _on_year(index: int, pick: OptionButton) -> void:
	year = pick.get_item_id(index)
	rebuild()

func _on_age_continue() -> void:
	if not tapped() or month == 0 or year == 0:
		return
	var bracket := Consent.record_age(month, year)
	if bracket.begins_with("<"):
		_too_young = true
	else:
		step = 1
	month = 0
	year = 0  # the date itself is never kept, even in memory
	rebuild()

func _build_blocked() -> void:
	var box := section("")
	box.add_child(label(tr("Thanks for telling us!"), 32, pal.accent, true, true))
	box.add_child(label(tr("Accounts are for players %d and older, so we can't create one for you. You can still play every game without an account.") % Consent.min_age(), 24, null, true, true))
	var back := pill(tr("Back to the games"), true, 28)
	back.pressed.connect(_to_hub)
	box.add_child(back)
	box.add_child(_help_link())

func _to_hub() -> void:
	get_tree().change_scene_to_file(Consent.HUB_SCENE)

# ---------- steps 1-2: the documents ----------

func _build_doc(doc: String) -> void:
	var title: String = tr("Terms of Service and EULA") if doc == "terms" else tr("Privacy Policy")
	var head := section(title)
	head.add_child(dim(tr("Step %d of 3") % step))
	var lang_tabs := tabs(["Español", "English"], 0 if _lang() == "es" else 1, _on_doc_language)
	head.add_child(lang_tabs)
	var body := section("")
	body.add_child(Consent.make_reader(Consent.doc_markdown(doc, _lang()), pal))
	var next := pill(tr("Next"), true, 28)
	next.pressed.connect(_on_next)
	body.add_child(next)

func _on_doc_language(i: int) -> void:
	_on_language(i)

func _on_next() -> void:
	if tapped():
		step += 1
		rebuild()
		get_viewport().gui_release_focus()

# ---------- step 3: accept ----------

func _build_accept() -> void:
	var box := section(tr("Accept to continue"))
	box.add_child(dim(tr("Tick both boxes to confirm you read and accept them. You can read them again any time in Options > Legal.")))
	var terms := _check(tr("I accept the Terms of Service and EULA"), ticked_terms)
	terms.pressed.connect(_toggle_terms)
	box.add_child(terms)
	var privacy := _check(tr("I accept the Privacy Policy"), ticked_privacy)
	privacy.pressed.connect(_toggle_privacy)
	box.add_child(privacy)
	var go := pill(tr("Continue"), true, 28)
	go.disabled = not (ticked_terms and ticked_privacy)
	go.modulate.a = 0.4 if go.disabled else 1.0
	go.pressed.connect(_on_accept)
	box.add_child(go)
	box.add_child(_help_link())

## A tick box drawn as a wide toggle button (wraps long text; easy to hit).
func _check(text: String, on: bool) -> Button:
	var b := pill(("☑  " if on else "☐  ") + text, on, 24)
	b.custom_minimum_size = Vector2(0, 76)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = false
	return b

func _toggle_terms() -> void:
	if tapped():
		ticked_terms = not ticked_terms
		rebuild()

func _toggle_privacy() -> void:
	if tapped():
		ticked_privacy = not ticked_privacy
		rebuild()

func _on_accept() -> void:
	if not tapped() or not (ticked_terms and ticked_privacy):
		return
	Consent.accept(_lang())
	_leave()

# ---------- safety link (crisis help screen, Task 5) ----------

## "Safety and help" line on the onboarding screens; shown once that screen exists.
func _help_link() -> Control:
	var holder := Control.new()
	holder.visible = false
	if ResourceLoader.exists("res://scenes/hub/help.tscn"):
		holder = Button.new()
		holder.text = tr("Safety and help")
		holder.flat = true
		holder.pressed.connect(_open_help)
	return holder

func _open_help() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/help.tscn")
