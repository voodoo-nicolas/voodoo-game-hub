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

## Options > About links (owner 2026-11-13). The contact address is public.
const FACEBOOK_URL := "https://www.facebook.com/profile.php?id=61595214907419"
const YOUTUBE_URL := "https://www.youtube.com/@ViralGameHubYT"
const CONTACT_EMAIL := "viralgamingservice@gmail.com"

static func tagline() -> String:
	return str(TranslationServer.translate(TAGLINE))

## The hub's dark backdrop: the brand background, cropped to fill the screen
## (portrait or landscape art by the screen's shape), darkened so text on it
## keeps 4.5:1. Falls back to the drifting mist if the art is missing.
## Add it as the first child so everything sits on top.
static func backdrop() -> Control:
	var st = Engine.get_main_loop().root.get_node_or_null("Settings") if Engine.get_main_loop() is SceneTree else null
	if st != null and st.has_method("is_lite") and st.is_lite():
		return load(MIST).new()  # Superlite: coded mist, no picture
	if ResourceLoader.exists(BG_PORTRAIT) and ResourceLoader.exists(BG_LANDSCAPE):
		return Backdrop.new()
	return load(MIST).new()

class Backdrop extends TextureRect:
	var _portrait: Texture2D
	var _landscape: Texture2D
	var _embers: CPUParticles2D
	var _smoke: CPUParticles2D

	func _ready() -> void:
		_portrait = load(BG_PORTRAIT)
		_landscape = load(BG_LANDSCAPE)
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_pick()
		# Alive: slow drift + rising embers (off with Options > Reduce motion).
		# load(), not preload: APK-side script, but packs also reach Brand.
		var fx = load("res://scripts/common/hub_fx.gd")
		if fx != null:
			fx.drift(self)
			_embers = fx.embers(self)
			add_child(_embers)
			fx.place_embers(_embers, size)
			_smoke = fx.smoke(self)  # hub_fx ships with brand.gd in the APK
			add_child(_smoke)
			fx.place_embers(_smoke, size)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_pick()
			if _embers != null and is_instance_valid(_embers):
				_embers.position = Vector2(size.x / 2.0, size.y + 8.0)
				_embers.emission_rect_extents = Vector2(size.x / 2.0, 4.0)
			if _smoke != null and is_instance_valid(_smoke):
				_smoke.position = Vector2(size.x / 2.0, size.y + 8.0)
				_smoke.emission_rect_extents = Vector2(size.x / 2.0, 4.0)

	func _pick() -> void:
		if _portrait == null:
			return
		# texture = _landscape if size.x > size.y else _portrait
		texture = _landscape if size.x > size.y else _portrait
		if size.x > size.y and _follow != null and is_instance_valid(_follow) and _follow.is_visible_in_tree():
			_crop_to(_follow.get_global_rect().get_center() - get_global_rect().position)

	## The landscape hub home draws the wordmark on the left, but the art's own
	## V-skull is in the middle: two skulls (owner 2026-11-13 screenshot). follow()
	## crops the landscape art so its skull sits behind `target` (the wordmark),
	## like the portrait screen where the two overlap and read as one.
	var _follow: Control

	func follow(target: Control) -> void:
		_follow = target
		if not target.resized.is_connected(_pick):
			target.resized.connect(_pick)
		_pick.call_deferred()

	## The skull's centre in the landscape art, in its pixels (1280x720).
	const LOGO_LANDSCAPE := Vector2(640, 370)

	func _crop_to(focus: Vector2) -> void:
		if size.x <= 0 or size.y <= 0:
			return
		var img := Vector2(_landscape.get_width(), _landscape.get_height())
		var logo := LOGO_LANDSCAPE * img / Vector2(1280, 720)
		var f := (focus / size).clamp(Vector2(0.05, 0.05), Vector2(0.95, 0.95))
		var aspect := size.x / size.y
		# the biggest crop with the screen's shape that keeps the logo at `f`
		var w := minf(minf(logo.x / f.x, (img.x - logo.x) / (1.0 - f.x)), img.x)
		var h := minf(minf(logo.y / f.y, (img.y - logo.y) / (1.0 - f.y)), img.y)
		w = minf(w, h * aspect)
		h = w / aspect
		var at := AtlasTexture.new()
		at.atlas = _landscape
		at.region = Rect2(logo.x - f.x * w, logo.y - f.y * h, w, h)
		texture = at
