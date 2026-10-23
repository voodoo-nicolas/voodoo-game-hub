shader_type canvas_item;

// Turned: procedural ground and wall surfaces with a height map, so lamps and the sun
// light them with relief (cobbles, flagstones, planks, tiles, grass, bricks, slate).
// No textures: everything is computed from the world position, so it never repeats visibly,
// never stretches and costs no memory. kind: 0 cobble, 1 flagstone, 2 planks, 3 tile,
// 4 grass, 5 brick wall, 6 slate roof.

uniform int kind = 0;
uniform vec4 base_color : source_color = vec4(0.30, 0.32, 0.38, 1.0);
uniform float seed = 0.0;
uniform float wet = 0.35;          // 0..1: damp darkening and shine on the stones
uniform float relief = 1.0;        // strength of the bump lighting
uniform float grime = 0.5;         // 0..1: moss, stains, wear

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

// A running pattern of rounded blocks. Returns rgb in .xyz, height in .w.
// cell = block size px, jitter = how much rows slide, round = corner radius px, gap = joint width px.
vec4 blocks(vec2 p, vec2 cell, float jitter, float round_px, float gap, vec3 base, float tint, float variance) {
	float row = floor(p.y / cell.y);
	float off = (hash21(vec2(row, seed)) - 0.5) * jitter * cell.x + mod(row, 2.0) * 0.5 * cell.x;
	vec2 q = vec2(p.x + off, p.y);
	float colid = floor(q.x / cell.x);
	vec2 id = vec2(colid, row);
	float wj = 0.82 + 0.36 * hash21(id + seed + 3.1);          // per-block width variation
	vec2 f = vec2(fract(q.x / cell.x), fract(q.y / cell.y));
	vec2 c = (f - 0.5) * cell;
	c.x /= wj;
	vec2 hs = cell * 0.5 - vec2(gap * 0.5);
	vec2 d = abs(c) - hs + vec2(round_px);
	float sdf = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - round_px;
	float stone = smoothstep(0.4, -1.4, sdf);                  // 1 inside a block, 0 in the joint
	float dome = 1.0 - clamp(dot(c / hs, c / hs) * 0.5, 0.0, 1.0);
	float r = hash21(id + seed);
	float r2 = hash21(id * 1.7 + seed + 9.0);
	vec3 col = base * (1.0 - variance * 0.5 + variance * r);
	col = mix(col, col * vec3(1.14, 1.02, 0.84), tint * r2);   // warm/cold block-to-block drift
	col *= 0.72 + 0.4 * dome;
	float h = stone * (0.55 + 0.35 * dome) + 0.12 * vnoise(p * 0.9 + id);
	vec3 joint = base * 0.3;
	return vec4(mix(joint, col, stone), h);
}

vec4 planks(vec2 p, vec3 base) {
	float w = 14.0;
	float row = floor(p.y / w);
	float f = fract(p.y / w);
	float slide = hash21(vec2(row, seed)) * 90.0;
	float seam = floor((p.x + slide) / 96.0);
	float r = hash21(vec2(row, seam) + seed);
	float grain = vnoise(vec2((p.x + slide) * 0.09, p.y * 1.6 + r * 40.0));
	float groove = mix(0.45, 1.0, smoothstep(0.0, 0.12, f) * smoothstep(1.0, 0.88, f));
	float endseam = mix(0.55, 1.0, smoothstep(0.0, 1.6, abs(fract((p.x + slide) / 96.0) - 0.0) * 96.0));
	vec3 col = base * (0.78 + 0.34 * r) * (0.86 + 0.28 * grain);
	float h = groove * endseam * (0.7 + 0.2 * grain);
	col = mix(base * 0.18, col, groove * endseam);
	return vec4(col, h);
}

vec4 tiles(vec2 p, vec3 base) {
	vec2 cell = vec2(16.0);
	vec2 id = floor(p / cell);
	vec2 f = fract(p / cell);
	vec2 d = abs(f - 0.5) * cell - (cell * 0.5 - 1.0);
	float edge = smoothstep(0.0, -1.0, max(d.x, d.y));
	float r = hash21(id + seed);
	vec3 col = base * (0.9 + 0.2 * r) * (0.92 + 0.12 * vnoise(p * 0.4));
	col = mix(base * 0.5, col, edge);
	float crack = step(0.97, hash21(id + seed + 5.0)) * smoothstep(0.06, 0.0, abs(f.x - f.y * 0.8 - 0.1));
	col *= 1.0 - crack * 0.5;
	return vec4(col, edge * 0.6);
}

vec4 grass(vec2 p, vec3 base) {
	float n = fbm(p * 0.07);
	float blades = vnoise(vec2(p.x * 1.3, p.y * 0.35));
	vec3 col = base * (0.7 + 0.7 * n) * (0.85 + 0.3 * blades);
	return vec4(col, 0.3 + 0.4 * blades);
}

vec4 slate(vec2 p, vec3 base) {
	vec2 cell = vec2(11.0, 7.0);
	float row = floor(p.y / cell.y);
	float off = mod(row, 2.0) * 0.5 * cell.x;
	vec2 q = vec2(p.x + off, p.y);
	vec2 id = vec2(floor(q.x / cell.x), row);
	vec2 f = vec2(fract(q.x / cell.x), fract(q.y / cell.y));
	float r = hash21(id + seed);
	float lap = smoothstep(0.0, 0.5, f.y) ;         // each slate overlaps the one below: bright lower lip
	float side = smoothstep(0.0, 0.08, f.x) * smoothstep(1.0, 0.92, f.x);
	vec3 col = base * (0.7 + 0.5 * r) * (0.8 + 0.3 * lap);
	col = mix(base * 0.2, col, side);
	float h = lap * 0.8 * side + 0.15;
	return vec4(col, h);
}

vec4 surface(vec2 p, vec3 base) {
	if (kind == 0) {
		return blocks(p, vec2(21.0, 14.0), 0.9, 3.2, 2.4, base, 0.45, 0.5);
	} else if (kind == 1) {
		return blocks(p, vec2(36.0, 24.0), 0.2, 1.4, 1.6, base, 0.3, 0.3);
	} else if (kind == 2) {
		return planks(p, base);
	} else if (kind == 3) {
		return tiles(p, base);
	} else if (kind == 4) {
		return grass(p, base);
	} else if (kind == 5) {
		return blocks(p, vec2(15.0, 7.0), 0.0, 0.6, 1.3, base, 0.6, 0.55);
	}
	return slate(p, base);
}

void fragment() {
	vec3 base = base_color.rgb;
	vec4 s = surface(wpos, base);
	vec3 col = s.rgb;
	// large soft variation: damp patches, grime, moss (one cheap noise each)
	float big = vnoise(wpos * 0.022 + seed) * 0.65 + vnoise(wpos * 0.05 + seed * 1.3) * 0.35;
	float stain = vnoise(wpos * 0.06 + 31.0 + seed);
	col *= 0.82 + 0.36 * big;
	col = mix(col, col * vec3(0.78, 0.9, 0.7), smoothstep(0.55, 0.8, stain) * grime * (kind <= 1 ? 1.0 : 0.3));
	col = mix(col, col * vec3(0.55, 0.6, 0.72), wet * smoothstep(0.35, 0.7, big) * 0.7);
	// the bump normal from the screen-space slope of the height (one surface evaluation per pixel)
	vec2 per_px = max(vec2(abs(dFdx(wpos.x)) + abs(dFdy(wpos.x)), abs(dFdx(wpos.y)) + abs(dFdy(wpos.y))), vec2(0.0001));
	vec2 grad = vec2(dFdx(s.w) + dFdy(s.w) * 0.0, dFdy(s.w)) / per_px;
	vec3 n = normalize(vec3(-grad * 2.4 * relief, 1.0));
	COLOR = vec4(col, 1.0);
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
