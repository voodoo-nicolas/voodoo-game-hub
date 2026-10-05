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
## colour), 6 hatch (cross-hatching: one more direction of lines for each
## darker tone), 7 dots (stipple / pointillism: one jittered dot per cell,
## more likely the darker the cell). 6 and 7 are sized to the picture
## (~45 lines / ~60 dots across, pencil-traceable), so the pattern moves and
## scales with it.
const MODES := {"photo": 0, "gray": 1, "invert": 3, "tones": 4, "mask": 5, "hatch": 6, "dots": 7}

const OVERLAY := """
shader_type canvas_item;
uniform int mode = 0;
uniform float opacity = 0.7;
uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float lo = 0.0;
uniform float hi = 1.0;
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
// 0 = lightest tone .. 1 = darkest, in four steps over the photo's lo..hi.
float darkness(vec3 c) {
	float l = clamp((lum(c) - lo) / max(hi - lo, 0.01), 0.0, 1.0);
	return 1.0 - clamp(floor(l * 4.0) / 3.0, 0.0, 1.0);
}
// Distance (in texels) to the nearest of a set of parallel lines.
float stripe(float v, float spacing) {
	return abs(fract(v / spacing) - 0.5) * spacing;
}
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
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
	} else if (mode == 6) {
		float dark = darkness(c.rgb);
		vec2 p = UV / TEXTURE_PIXEL_SIZE;
		// About 45 lines across the picture: traceable with a pencil.
		float sp = max(4.0, 1.0 / TEXTURE_PIXEL_SIZE.x / 45.0);
		float w0 = sp * 0.07;
		float w1 = sp * 0.13;
		float a = 0.0;
		if (dark > 0.2) { a = max(a, 1.0 - smoothstep(w0, w1, stripe((p.x + p.y) * 0.7071, sp))); }
		if (dark > 0.5) { a = max(a, 1.0 - smoothstep(w0, w1, stripe((p.x - p.y) * 0.7071, sp))); }
		if (dark > 0.9) { a = max(a, 1.0 - smoothstep(w0, w1, stripe(p.y, sp * 0.8))); }
		COLOR = vec4(line_color.rgb, a * opacity * c.a);
	} else if (mode == 7) {
		// About 60 dot cells across the picture.
		float cell = max(4.0, 1.0 / TEXTURE_PIXEL_SIZE.x / 60.0);
		vec2 p = UV / TEXTURE_PIXEL_SIZE / cell;
		vec2 g = floor(p);
		// The cell's tone is read at its centre, so a dot is all or nothing.
		vec4 cc = texture(TEXTURE, (g + 0.5) * cell * TEXTURE_PIXEL_SIZE);
		float dark = darkness(cc.rgb);
		float h = hash(g);
		vec2 jitter = vec2(fract(h * 7.13), fract(h * 3.71)) - 0.5;
		float d = length(fract(p) - 0.5 - jitter * 0.45) * cell;
		float on = step(h, dark * 0.9) * (1.0 - smoothstep(cell * 0.14, cell * 0.22, d));
		COLOR = vec4(line_color.rgb, on * opacity * cc.a);
	} else {
		COLOR = vec4(line_color.rgb, c.a * opacity);
	}
}
"""
