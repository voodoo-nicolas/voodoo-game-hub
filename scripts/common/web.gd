extends RefCounted

## The browser build (Safari on iPhone, any desktop browser) -- see CLAUDE.md
## "Web version". It bundles every game, so nothing is downloaded, and it
## runs on one thread. Everything here is only used when OS.has_feature("web").

## Cut down to the characters the app uses by `hub.py web` (rerun it when
## new emoji or symbols appear in the code). Only the Web preset exports them.
const FONTS := [
	"res://assets/web_fonts/emoji.ttf",    # Noto Color Emoji (the one Android uses)
	"res://assets/web_fonts/symbols.ttf",  # DejaVu Sans: arrows, shapes, math
]

static func active() -> bool:
	return OS.has_feature("web")

## A browser page can't reach the phone's own fonts, so every emoji and
## symbol would be an empty box: hang the bundled fonts behind the default
## font. Runs from an autoload, before the first screen shapes any text.
static func install_fonts() -> void:
	var extra: Array[Font] = []
	for path in FONTS:
		if ResourceLoader.exists(path):
			extra.append(load(path))
	if extra.is_empty():
		return
	var done := {}
	for font: Font in [ThemeDB.fallback_font, ThemeDB.get_default_theme().default_font]:
		if font == null or done.has(font):
			continue
		done[font] = true
		var list: Array[Font] = font.fallbacks.duplicate()
		list.append_array(extra)
		font.fallbacks = list

## The web build's "update": GitHub Pages always serves the newest build.
static func reload() -> void:
	JavaScriptBridge.eval("location.reload()")
