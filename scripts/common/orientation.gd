extends RefCounted

## Screen orientation is global OS state, not per-scene -- if a landscape game (like
## Geometry Wars) locks to landscape and the player leaves through any path other than
## its own designated exit buttons, the lock leaks into whatever scene loads next.
## The robust fix is for every scene to declare the orientation IT needs on _ready(),
## rather than relying on the previous scene to clean up after itself.

static func lock_portrait() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_PORTRAIT)

static func lock_landscape() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
