shader_type canvas_item;

// Thrust terrain: a smooth, lit 3D heightmap seen from above.
// TEXTURE = height (R channel, 0..1), upscaled with cubic filtering and
// sampled linearly so there are no blocks. From it we build:
// - surface normals -> sun lighting from the top-left, plus sky ambient,
// - soft cast shadows (a short march toward the sun over the heightmap),
// - colour painted by elevation (deep water -> shallows -> beach -> lowland
//   -> highland -> rock -> snow) with slope-based rock on steep faces,
// - water as a flat sheet at sea level with waves, sun glints and shore foam,
//   lava glowing and churning instead,
// - drifting cloud shadows and a soft vignette.

uniform float t = 0.0;
uniform float sea = 0.3;
uniform float rock = 0.8;
uniform float relief = 120.0;     // how tall the hills look (was 90 before the TerrainGen hills, 2026-11-18)
uniform float neon = 0.0;
uniform float lava = 0.0;
uniform float snow = 0.0;         // 1 = cap the high peaks with snow
uniform vec3 c_deep : source_color;
uniform vec3 c_shallow : source_color;
uniform vec3 c_shore : source_color;
uniform vec3 c_low : source_color;
uniform vec3 c_high : source_color;
uniform vec3 c_rock : source_color;

float hash(vec2 p) {
	// sin()-free hash: stays stable at large coordinates (no square artefacts).
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v;
}

uniform sampler2D height_tex : filter_linear, repeat_disable;   // same picture as TEXTURE

float H(vec2 uv) {
	return texture(height_tex, uv).r;
}

void fragment() {
	vec2 px = 1.0 / vec2(textureSize(height_tex, 0));
	vec2 grid = 1.0 / px;
	vec2 wp = UV * grid;                      // position in height texels
	float h = H(UV);
	// Fine detail so close-up ground has texture, not flat colour.
	float detail = fbm(wp * 0.9) - 0.5;
	float hd = h + detail * 0.012;

	// Normal from the height field (land only; water is flat).
	float hl = H(UV - vec2(px.x, 0.0));
	float hr = H(UV + vec2(px.x, 0.0));
	float hu = H(UV - vec2(0.0, px.y));
	float hdn = H(UV + vec2(0.0, px.y));
	vec2 g = vec2(max(hr, sea) - max(hl, sea), max(hdn, sea) - max(hu, sea)) * 0.5;
	g += vec2(fbm(wp * 0.9 + vec2(0.31, 0.0)) - fbm(wp * 0.9 - vec2(0.31, 0.0)),
		fbm(wp * 0.9 + vec2(0.0, 0.31)) - fbm(wp * 0.9 - vec2(0.0, 0.31))) * 0.004;
	vec3 n = normalize(vec3(-g * relief, 1.0));
	float slope = 1.0 - n.z;

	vec3 sun = normalize(vec3(-0.55, -0.65, 0.55));
	float diff = max(dot(n, sun), 0.0);

	// Cast shadow: march toward the sun; if terrain rises above the ray we are shaded.
	float sh = 1.0;
	float base = max(h, sea);
	vec2 step2 = normalize(sun.xy) * px * 1.6;
	float rise = sun.z / length(sun.xy) * 1.6 / relief;
	for (int i = 1; i <= 14; i++) {
		float fi = float(i);
		float th = max(H(UV + step2 * fi), sea);
		float ray = base + rise * fi;
		sh = min(sh, clamp(1.0 - (th - ray) * 18.0, 0.0, 1.0));
	}
	sh = mix(0.45, 1.0, sh);

	vec3 col;
	if (h < sea) {
		float depth = clamp((sea - h) / 0.14, 0.0, 1.0);
		if (lava > 0.5) {
			float churn = fbm(wp * 0.05 + vec2(t * 0.06, -t * 0.04));
			float crust = smoothstep(0.52, 0.68, fbm(wp * 0.09 - vec2(t * 0.02, t * 0.03)));
			vec3 hot = mix(c_shallow, vec3(1.0, 0.85, 0.35), churn * churn);
			col = mix(hot, c_deep * 0.5, crust * 0.8);
			col *= 1.0 + 0.25 * sin(t * 1.8 + churn * 8.0);
			sh = 1.0;
			diff = 1.0;
		} else {
			col = mix(c_shallow, c_deep, smoothstep(0.0, 1.0, depth));
			// Waves: perturbed normal, sun glints, fresnel-ish sky tint.
			vec2 wv = vec2(
				sin(wp.x * 0.35 + t * 1.6) + sin((wp.x + wp.y) * 0.21 + t * 1.1) + (fbm(wp * 0.25 + t * 0.2) - 0.5) * 2.0,
				sin(wp.y * 0.41 - t * 1.3) + sin((wp.x - wp.y) * 0.17 - t * 0.9) + (fbm(wp * 0.25 - t * 0.2) - 0.5) * 2.0);
			vec3 wn = normalize(vec3(wv * 0.08, 1.0));
			vec3 view = vec3(0.0, 0.0, 1.0);
			float spec = pow(max(dot(reflect(-sun, wn), view), 0.0), 60.0);
			col += vec3(1.0, 0.97, 0.88) * spec * 0.9 * sh;
			col += vec3(0.12, 0.16, 0.2) * (1.0 - wn.z) * 6.0;
			// Shore foam where it gets shallow.
			float foam = smoothstep(0.08, 0.0, depth) * (0.6 + 0.4 * sin(t * 2.0 + wp.x * 0.5 + wp.y * 0.3));
			col = mix(col, vec3(0.92, 0.96, 1.0), foam * 0.55);
			diff = 0.85 + 0.15 * wn.z;
		}
	} else {
		float land = clamp((hd - sea) / max(rock - sea, 0.01), 0.0, 1.0);
		vec3 lowc = mix(c_low, c_high, smoothstep(0.05, 1.0, land));
		// Patches of lighter/darker vegetation or sand.
		lowc *= 0.9 + 0.2 * fbm(wp * 0.18);
		col = mix(c_shore, lowc, smoothstep(sea + 0.006, sea + 0.035, hd));
		// Rock: high ground and steep faces.
		float rk = max(smoothstep(rock - 0.03, rock + 0.01, hd), smoothstep(0.35, 0.6, slope) * 0.85);
		vec3 rc = c_rock * (0.82 + 0.3 * fbm(wp * 0.6));
		col = mix(col, rc, rk);
		// Snow on the highest peaks (and in every theme on the very top).
		float sn = smoothstep(rock + 0.06, rock + 0.12, hd) * (0.5 + 0.5 * snow);
		sn *= 1.0 - smoothstep(0.45, 0.7, slope);
		col = mix(col, vec3(0.95, 0.97, 1.0), sn);
	}

	// Lighting: sun + sky ambient, with soft cast shadows.
	vec3 sky = vec3(0.55, 0.62, 0.75);
	vec3 lit = col * (sky * (0.38 + 0.22 * n.z) + vec3(1.0, 0.95, 0.85) * diff * 0.95 * sh);
	if (lava > 0.5 && h < sea) {
		lit = col;
	}
	// Lava light spills onto nearby ground.
	if (lava > 0.5 && h >= sea) {
		float near = smoothstep(sea + 0.05, sea, h);
		lit += vec3(0.9, 0.3, 0.05) * near * (0.5 + 0.2 * sin(t * 1.8));
	}

	// Cloud shadows (not at night in neon).
	vec2 cp = wp / 60.0;
	float cloud = smoothstep(0.55, 0.8, fbm(cp * 1.3 + vec2(t * 0.03, t * 0.012)));
	lit *= 1.0 - 0.16 * cloud * (1.0 - neon);
	// Grade: a touch more saturation and contrast so ships and pickups pop.
	lit = mix(vec3(dot(lit, vec3(0.3, 0.59, 0.11))), lit, 1.2);
	lit = mix(lit, lit * lit * (3.0 - 2.0 * min(lit, vec3(1.0))), 0.35);

	if (neon > 0.5) {
		lit = vec3(lit.r * 0.35 + 0.03, lit.g * 0.3, lit.b * 0.45 + 0.07);
		float e1 = smoothstep(0.006, 0.0, abs(h - sea));
		float e2 = smoothstep(0.008, 0.0, abs(h - rock));
		lit += vec3(0.16, 0.9, 1.0) * e1 + vec3(0.6, 0.3, 1.0) * e2;
	}

	vec2 q = SCREEN_UV - 0.5;
	lit *= (1.0 - 0.6 * dot(q, q)) * vec3(0.97, 0.99, 1.03);
	COLOR = vec4(lit, 1.0);
}
