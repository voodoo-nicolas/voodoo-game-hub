extends "res://scripts/hub/hub_screen.gd"

## Options > Legal: read the Terms/EULA and the Privacy Policy offline (the text
## is bundled in the app: scripts/common/legal_text.gd). Spanish controls;
## English is a courtesy translation, so the reader can switch language.

const Consent = preload("res://scripts/common/consent.gd")
const BACK_SCENE := "res://scenes/hub/options.tscn"

var _doc: String = "terms"
var _lang: String = "es"

func _title() -> String:
	return tr("Legal")

func _ready() -> void:
	_doc = Consent.reading_doc
	_lang = Lang.current if Lang.current in ["es", "en"] else "es"
	super()

func go_hub() -> void:
	get_tree().change_scene_to_file(BACK_SCENE)

func _build() -> void:
	var head := section("")
	head.add_child(tabs([tr("Terms and EULA"), tr("Privacy Policy")], 0 if _doc == "terms" else 1, _on_doc))
	head.add_child(tabs(["Español", "English"], 0 if _lang == "es" else 1, _on_lang))
	head.add_child(dim(tr("The Spanish version is the one that applies; English is a courtesy translation.")))
	var box := section("")
	box.add_child(Consent.make_reader(Consent.doc_markdown(_doc, _lang), pal))

func _on_doc(i: int) -> void:
	_doc = "terms" if i == 0 else "privacy"
	rebuild()

func _on_lang(i: int) -> void:
	_lang = "es" if i == 0 else "en"
	rebuild()
