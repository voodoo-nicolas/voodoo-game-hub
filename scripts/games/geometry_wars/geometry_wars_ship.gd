extends RefCounted

## The Voodoo skin's ship: a horned demon skull (the owner's drawing,
## 2026-10-06), traced from the picture with OpenCV contours and
## kept here as data (plain arrays: a PackedVector2Array is not a
## constant). Units are squares (Core.U); x points forward (the mouth
## leads), y to the ship's left. Drawn by arena_canvas._draw_ship.

## The silhouette.
const OUTLINE := [
	Vector2(-0.900, 0.230), Vector2(-0.814, 0.364), Vector2(-0.698, 0.474), Vector2(-0.569, 0.548), Vector2(-0.416, 0.591), Vector2(-0.257, 0.591),
	Vector2(-0.165, 0.566), Vector2(-0.220, 0.560), Vector2(-0.263, 0.523), Vector2(-0.263, 0.474), Vector2(-0.239, 0.432), Vector2(-0.178, 0.377),
	Vector2(-0.129, 0.352), Vector2(-0.061, 0.346), Vector2(0.000, 0.364), Vector2(0.018, 0.346), Vector2(0.024, 0.358), Vector2(0.012, 0.377),
	Vector2(0.049, 0.426), Vector2(0.049, 0.462), Vector2(0.012, 0.530), Vector2(-0.031, 0.579), Vector2(0.129, 0.505), Vector2(0.233, 0.413),
	Vector2(0.171, 0.426), Vector2(0.135, 0.395), Vector2(0.135, 0.346), Vector2(0.147, 0.321), Vector2(0.220, 0.248), Vector2(0.318, 0.205),
	Vector2(0.392, 0.205), Vector2(0.429, 0.236), Vector2(0.416, 0.272), Vector2(0.361, 0.321), Vector2(0.582, 0.248), Vector2(0.784, 0.144),
	Vector2(0.900, 0.064), Vector2(0.814, 0.095), Vector2(0.729, 0.113), Vector2(0.710, 0.107), Vector2(0.704, 0.119), Vector2(0.667, 0.132),
	Vector2(0.569, 0.138), Vector2(0.539, 0.162), Vector2(0.502, 0.162), Vector2(0.478, 0.144), Vector2(0.471, 0.119), Vector2(0.422, 0.150),
	Vector2(0.361, 0.150), Vector2(0.355, 0.138), Vector2(0.410, 0.095), Vector2(0.484, 0.070), Vector2(0.527, 0.089), Vector2(0.631, 0.028),
	Vector2(0.557, 0.046), Vector2(0.527, 0.034), Vector2(0.576, 0.003), Vector2(0.533, -0.021), Vector2(0.533, -0.040), Vector2(0.631, -0.021),
	Vector2(0.527, -0.083), Vector2(0.508, -0.070), Vector2(0.465, -0.070), Vector2(0.416, -0.089), Vector2(0.355, -0.132), Vector2(0.367, -0.150),
	Vector2(0.429, -0.144), Vector2(0.471, -0.113), Vector2(0.502, -0.156), Vector2(0.527, -0.162), Vector2(0.576, -0.132), Vector2(0.698, -0.119),
	Vector2(0.710, -0.101), Vector2(0.741, -0.107), Vector2(0.900, -0.064), Vector2(0.765, -0.150), Vector2(0.600, -0.236), Vector2(0.380, -0.315),
	Vector2(0.361, -0.315), Vector2(0.429, -0.242), Vector2(0.404, -0.205), Vector2(0.331, -0.199), Vector2(0.227, -0.242), Vector2(0.153, -0.309),
	Vector2(0.135, -0.346), Vector2(0.135, -0.389), Vector2(0.159, -0.419), Vector2(0.208, -0.419), Vector2(0.233, -0.407), Vector2(0.122, -0.505),
	Vector2(0.024, -0.554), Vector2(-0.031, -0.572), Vector2(0.043, -0.474), Vector2(0.049, -0.419), Vector2(0.006, -0.358), Vector2(0.000, -0.364),
	Vector2(-0.037, -0.346), Vector2(-0.122, -0.346), Vector2(-0.202, -0.389), Vector2(-0.263, -0.468), Vector2(-0.263, -0.517), Vector2(-0.233, -0.548),
	Vector2(-0.171, -0.566), Vector2(-0.312, -0.591), Vector2(-0.410, -0.585), Vector2(-0.569, -0.542), Vector2(-0.698, -0.468), Vector2(-0.814, -0.358),
	Vector2(-0.894, -0.230), Vector2(-0.796, -0.321), Vector2(-0.680, -0.389), Vector2(-0.576, -0.419), Vector2(-0.478, -0.419), Vector2(-0.429, -0.407),
	Vector2(-0.380, -0.383), Vector2(-0.318, -0.321), Vector2(-0.294, -0.272), Vector2(-0.288, -0.217), Vector2(-0.202, -0.223), Vector2(-0.153, -0.168),
	Vector2(-0.135, -0.174), Vector2(-0.049, -0.150), Vector2(-0.178, -0.144), Vector2(-0.214, -0.187), Vector2(-0.233, -0.187), Vector2(-0.361, -0.132),
	Vector2(-0.459, -0.058), Vector2(-0.343, -0.095), Vector2(-0.263, -0.095), Vector2(-0.239, -0.077), Vector2(-0.282, -0.034), Vector2(-0.282, 0.040),
	Vector2(-0.245, 0.083), Vector2(-0.263, 0.101), Vector2(-0.331, 0.101), Vector2(-0.459, 0.064), Vector2(-0.361, 0.138), Vector2(-0.233, 0.193),
	Vector2(-0.214, 0.193), Vector2(-0.178, 0.150), Vector2(-0.086, 0.144), Vector2(-0.043, 0.156), Vector2(-0.153, 0.174), Vector2(-0.202, 0.230),
	Vector2(-0.294, 0.223), Vector2(-0.294, 0.272), Vector2(-0.318, 0.328), Vector2(-0.380, 0.389), Vector2(-0.478, 0.426), Vector2(-0.569, 0.426),
	Vector2(-0.692, 0.389), Vector2(-0.796, 0.328),
]

## The carved slits inside it (they glow).
const SLITS := [
	[
		Vector2(0.171, -0.150), Vector2(0.220, -0.168), Vector2(0.251, -0.162), Vector2(0.367, -0.058), Vector2(0.429, -0.034), Vector2(0.392, -0.028),
		Vector2(0.312, -0.052), Vector2(0.233, -0.126),
	],
	[
		Vector2(0.171, 0.150), Vector2(0.227, 0.132), Vector2(0.312, 0.058), Vector2(0.392, 0.034), Vector2(0.422, 0.040), Vector2(0.373, 0.058),
		Vector2(0.251, 0.168), Vector2(0.202, 0.168),
	],
	[
		Vector2(0.092, -0.260), Vector2(0.147, -0.260), Vector2(0.227, -0.211), Vector2(0.141, -0.211),
	],
	[
		Vector2(0.092, 0.260), Vector2(0.141, 0.217), Vector2(0.208, 0.205), Vector2(0.233, 0.211), Vector2(0.141, 0.266),
	],
	[
		Vector2(-0.037, -0.266), Vector2(0.018, -0.285), Vector2(0.080, -0.205), Vector2(0.135, -0.162), Vector2(0.122, -0.156), Vector2(0.061, -0.187),
		Vector2(-0.006, -0.254), Vector2(-0.037, -0.242), Vector2(-0.043, -0.248), Vector2(-0.024, -0.260),
	],
	[
		Vector2(-0.073, -0.040), Vector2(-0.024, -0.095), Vector2(0.055, -0.077), Vector2(0.006, -0.070), Vector2(-0.049, -0.034),
	],
	[
		Vector2(-0.073, 0.046), Vector2(-0.049, 0.040), Vector2(0.006, 0.077), Vector2(0.049, 0.083), Vector2(-0.037, 0.107), Vector2(-0.043, 0.101),
		Vector2(-0.031, 0.089),
	],
	[
		Vector2(-0.110, 0.266), Vector2(0.000, 0.254), Vector2(0.061, 0.193), Vector2(0.116, 0.162), Vector2(0.129, 0.168), Vector2(0.061, 0.230),
		Vector2(0.024, 0.285),
	],
	[
		Vector2(-0.269, -0.346), Vector2(-0.263, -0.352), Vector2(-0.190, -0.297), Vector2(-0.116, -0.272), Vector2(-0.153, -0.272), Vector2(-0.147, -0.266),
		Vector2(-0.159, -0.260), Vector2(-0.239, -0.309),
	],
	[
		Vector2(-0.276, 0.358), Vector2(-0.227, 0.303), Vector2(-0.184, 0.279), Vector2(-0.135, 0.279), Vector2(-0.202, 0.309), Vector2(-0.269, 0.364),
	],
]

## Where the flame leaves the skull: the back, between the horns.
const FLAME_ROOT := Vector2(-0.337, 0.0)
