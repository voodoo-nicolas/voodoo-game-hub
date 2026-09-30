extends RefCounted

## Screen orientation is global OS state, not per-scene -- if a landscape game (like
## Geometry Wars) locks to landscape and the player leaves through any path other than
## its own designated exit buttons, the lock leaks into whatever scene loads next.
## The robust fix is for every scene to declare the orientation IT needs on _ready(),
## rather than relying on the previous scene to clean up after itself.
##
## The settings drawer's "Rotate Screen" is the one exception: it reloads the
## current scene, whose _ready() would immediately re-lock the default. So it
## leaves a one-shot override (process-wide, via Engine meta) that the very
## next lock_*() call honors instead, then clears.

const OVERRIDE_META := "voodoo_orientation_override"

static func lock_portrait() -> void:
	_lock(DisplayServer.SCREEN_SENSOR_PORTRAIT)

static func lock_landscape() -> void:
	_lock(DisplayServer.SCREEN_SENSOR_LANDSCAPE)

## Makes the next lock_portrait()/lock_landscape() use `landscape` instead.
static func override_next(landscape: bool) -> void:
	Engine.set_meta(OVERRIDE_META, DisplayServer.SCREEN_SENSOR_LANDSCAPE if landscape else DisplayServer.SCREEN_SENSOR_PORTRAIT)

static func _lock(requested: int) -> void:
	var orientation := requested
	if Engine.has_meta(OVERRIDE_META):
		orientation = int(Engine.get_meta(OVERRIDE_META))
		Engine.remove_meta(OVERRIDE_META)
	DisplayServer.screen_set_orientation(orientation)
