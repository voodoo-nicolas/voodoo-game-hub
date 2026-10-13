extends "res://scripts/hub/hub_screen.gd"

## Options > Help: "Need to talk to someone?" -- free helplines for the device's
## country (Task 5 of the compliance pack). Works offline, never blocks anything,
## logs nothing (no analytics event, no counter) and keyword-scans nothing.
## One big button per line opens the dialler (tel:); the number is also shown as text.
## Back returns to wherever the player came from (`Consent.help_back_scene`).

const CrisisHelp = preload("res://scripts/common/crisis_help.gd")
const Consent = preload("res://scripts/common/consent.gd")

func _title() -> String:
	return tr("Help")

## Back: to the screen that opened this one.
func go_hub() -> void:
	get_tree().change_scene_to_file(Consent.help_back_scene)

func _lang() -> String:
	return Lang.current if Lang.current in ["es", "en"] else "es"

func _build() -> void:
	var data := CrisisHelp.load_data()
	var lang := _lang()
	var head := section("")
	head.add_child(label(tr("Need to talk to someone?"), 34, pal.accent, true, true))
	head.add_child(label(tr("If you're going through a hard time, there are people available to listen."), 24, null, true, true))
	var emergency = data.get("emergency_note", {})
	if typeof(emergency) == TYPE_DICTIONARY and str(emergency.get(lang, "")) != "":
		head.add_child(label(str(emergency[lang]), 26, pal.accent, true, true))

	var resources := CrisisHelp.resources_for(data, CrisisHelp.country())
	if resources.is_empty():
		var box := section("")
		var fallback = data.get("fallback", {})
		box.add_child(label(tr("Find a free helpline in your country:"), 24, null, true, true))
		var url := str(fallback.get("url", "https://findahelpline.com")) if typeof(fallback) == TYPE_DICTIONARY else "https://findahelpline.com"
		var name := str(fallback.get("label_" + lang, tr("Helplines in your country"))) if typeof(fallback) == TYPE_DICTIONARY else tr("Helplines in your country")
		var b := pill(name, true, 28)
		b.custom_minimum_size = Vector2(0, 84)
		b.pressed.connect(_open_url.bind(url))
		_name_for_screen_reader(b, name)
		box.add_child(b)
		box.add_child(dim(url))
		return
	for r in resources:
		var box := section("")
		var dial := str(r.get("dial", ""))
		var title := CrisisHelp.label(r, lang)
		var call := pill("📞  " + dial, true, 36)
		call.custom_minimum_size = Vector2(0, 92)
		call.pressed.connect(_dial.bind(dial))
		_name_for_screen_reader(call, "%s: %s" % [title, dial])
		box.add_child(call)
		box.add_child(label(title, 24, null, true, true))
		if str(r.get("dial_alt", "")) != "":
			var alt := pill("📞  " + str(r.dial_alt), false, 28)
			alt.pressed.connect(_dial.bind(str(r.dial_alt)))
			_name_for_screen_reader(alt, "%s: %s" % [title, str(r.dial_alt)])
			box.add_child(alt)
		var n := CrisisHelp.note(r, lang)
		if n != "":
			box.add_child(dim(n, 20))
		if r.get("free", null) == true:
			box.add_child(dim(tr("Free call"), 20))
	var foot := section("")
	foot.add_child(dim(tr("These numbers are for your country. We don't see or keep anything about who opens this screen."), 20))

func _dial(number: String) -> void:
	if tapped():
		OS.shell_open("tel:" + CrisisHelp.dial_digits(number))

func _open_url(url: String) -> void:
	if tapped():
		OS.shell_open(url)

## Screen-reader label (Godot 4.5+ exposes it on every Control).
func _name_for_screen_reader(c: Control, text: String) -> void:
	if "accessibility_name" in c:
		c.set("accessibility_name", text)
