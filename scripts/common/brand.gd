extends RefCounted

## The app's visible name and brand art -- the one place to rename it.
## Hub code reads `Brand.NAME` (`const Brand = preload(...)`) instead of
## writing the hub's name; `tools/hub.py sync` copies NAME into the export
## presets (Android app label, Windows product name), so a rename is a
## one-line change here plus `hub.py sync`.
##
## Visible text only. Internal names keep "voodoo" on purpose (CLAUDE.md,
## "Rename safety"): the package id `com.viral.voodoo`, the signing key,
## project.godot's config/name "Voodoo" (on PC it names the save folder),
## `user://` files, Supabase names, game ids. "Voodoo" itself survives only
## as the name of the skulls skin (voodoo.gd).
##
## Packs must not preload this (it ships in the APK from v0.29): check
## `ResourceLoader.exists(PATH)` and `load()` it, like GameInfo.

const PATH := "res://scripts/common/brand.gd"

const NAME := "Viral Game Hub"
const DEVELOPER := "Viral"
## English source; the Spanish comes from tools/i18n/es.json like any UI text.
## Use tagline(), not the constant, wherever it's shown.
const TAGLINE := "No ads, ever."
## Play Store titles (max 30 characters, decided in docs/HUB_V2_PLAN.md §1).
## Store listing text: the owner approves any change before it's used.
const STORE_TITLE := {"en": "Viral Game Hub – No Ads", "es": "Viral: Juegos sin anuncios"}

## Shipped brand art (made by tools/brand/make_brand.py from the owner's
## sources in reference/art/brand/; credits in media/CREDITS.json).
const WORDMARK := "res://media/hub/brand/hub_wordmark.png"
const BG_PORTRAIT := "res://media/hub/brand/hub_bg_portrait.jpg"
const BG_LANDSCAPE := "res://media/hub/brand/hub_bg_landscape.jpg"
const MIST := "res://scripts/common/mist.gd"

static func tagline() -> String:
	return str(TranslationServer.translate(TAGLINE))

## The hub's dark backdrop: the brand background, cropped to fill the screen
## (portrait or landscape art by the screen's shape), darkened so text on it
## keeps 4.5:1. Falls back to the drifting mist if the art is missing.
## Add it as the first child so everything sits on top.
static func backdrop() -> Control:
	if ResourceLoader.exists(BG_PORTRAIT) and ResourceLoader.exists(BG_LANDSCAPE):
		return Backdrop.new()
	return load(MIST).new()

class Backdrop extends TextureRect:
	var _portrait: Texture2D
	var _landscape: Texture2D

	func _ready() -> void:
		_portrait = load(BG_PORTRAIT)
		_landscape = load(BG_LANDSCAPE)
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_pick()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_pick()

	func _pick() -> void:
		if _portrait == null:
			return
		texture = _landscape if size.x > size.y else _portrait
