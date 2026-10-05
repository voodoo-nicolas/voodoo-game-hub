extends RefCounted

## Trace It's shaders, as code (no asset files in a pack).

## The live camera. Android hands Godot two planes: Y (brightness, R8) and
## CbCr (colour, RG8, half size); BT.601 full range turns them into RGB.
## `bx`/`by` map screen UV (centred) to camera UV: the inverse of the feed's
## rotation, mirrored for the front camera (checked on a Galaxy A52, see
## tools/camera_spike/README.md).
const CAMERA := """
shader_type canvas_item;
uniform sampler2D y_tex : filter_linear;
uniform sampler2D c_tex : filter_linear;
uniform bool rgb_mode = false;
uniform vec2 bx = vec2(1.0, 0.0);
uniform vec2 by = vec2(0.0, 1.0);
void fragment() {
	vec2 p = UV - 0.5;
	vec2 cuv = bx * p.x + by * p.y + 0.5;
	if (rgb_mode) {
		COLOR = vec4(texture(y_tex, cuv).rgb, 1.0);
	} else {
		float y = texture(y_tex, cuv).r;
		vec2 c = texture(c_tex, cuv).rg - 0.5;
		COLOR = vec4(y + 1.402 * c.y, y - 0.344136 * c.x - 0.714136 * c.y, y + 1.772 * c.x, 1.0);
	}
}
"""

## Overlay looks (mode): 0 photo, 1 gray, 3 inverted, 4 tones (four
## shading levels, spread over the photo's own dark..light range lo..hi and
## drawn in the line colour, darker = more), 5 mask (line art -- a built-in
## drawing or the edges TraceItArt.line_art found: its alpha in the line
## colour).
const MODES := {"photo": 0, "gray": 1, "invert": 3, "tones": 4, "mask": 5}

const OVERLAY := """
shader_type canvas_item;
uniform int mode = 0;
uniform float opacity = 0.7;
uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float lo = 0.0;
uniform float hi = 1.0;
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (mode == 0) {
		COLOR = vec4(c.rgb, c.a * opacity);
	} else if (mode == 1) {
		COLOR = vec4(vec3(lum(c.rgb)), c.a * opacity);
	} else if (mode == 3) {
		COLOR = vec4(1.0 - c.rgb, c.a * opacity);
	} else if (mode == 4) {
		float l = clamp((lum(c.rgb) - lo) / max(hi - lo, 0.01), 0.0, 1.0);
		float level = clamp(floor(l * 4.0) / 3.0, 0.0, 1.0);
		COLOR = vec4(line_color.rgb, (1.0 - level) * 0.8 * opacity * c.a);
	} else {
		COLOR = vec4(line_color.rgb, c.a * opacity);
	}
}
"""
