shader_type spatial;
// Terrain — "Jade, Cinnabar & Ink Mist".
// All variation is procedural (slope, altitude, biome masks in vertex colour,
// world-space noise): no splat textures to stream.
//   COLOR.r forest density · COLOR.g trail · COLOR.b damp · COLOR.a desert
// Used by streamed sectors and by the far HorizonTiles.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform float wetness;
global uniform float snow_amount;
global uniform float night_glow;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float snow_line = 150.0;
uniform vec2 veil_center = vec2(880.0, -880.0);
uniform float veil_radius = 330.0;

uniform vec3 jade_lush : source_color = vec3(0.24, 0.45, 0.25);
uniform vec3 jade_light : source_color = vec3(0.45, 0.6, 0.32);
uniform vec3 meadow_gold : source_color = vec3(0.62, 0.6, 0.3);
uniform vec3 moss : source_color = vec3(0.2, 0.33, 0.18);
uniform vec3 forest_floor : source_color = vec3(0.2, 0.3, 0.17);
uniform vec3 rock_light : source_color = vec3(0.52, 0.55, 0.56);
uniform vec3 rock_dark : source_color = vec3(0.24, 0.27, 0.3);
uniform vec3 lichen : source_color = vec3(0.62, 0.56, 0.38);
uniform vec3 trail : source_color = vec3(0.6, 0.52, 0.4);
uniform vec3 sand : source_color = vec3(0.86, 0.76, 0.56);
uniform vec3 wet_sand : source_color = vec3(0.5, 0.44, 0.33);
uniform vec3 desert_sand : source_color = vec3(0.9, 0.7, 0.46);
uniform vec3 desert_shadow : source_color = vec3(0.72, 0.5, 0.36);
uniform vec3 snow : source_color = vec3(0.93, 0.95, 0.99);
uniform vec3 veil_ground : source_color = vec3(0.26, 0.24, 0.36);
uniform vec3 veil_glow : source_color = vec3(0.3, 1.0, 0.85);

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 masks;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	masks = COLOR;
}

float n2(vec2 p) {
	return texture(noise_tex, p).r;
}

void fragment() {
	float macro = n2(wpos.xz * 0.0019);
	float mid = n2(wpos.xz * 0.017);
	float fine = n2(wpos.xz * 0.061);
	float grain = n2(wpos.xz * 0.37);
	float slope = 1.0 - wnrm.y;
	float forest = masks.r;
	float path = masks.g;
	float damp = masks.b;
	float desert = masks.a;

	// --- Meadow: jade greens, sunlit patches, golden dry hills, flower speckles
	vec3 g = mix(jade_lush, jade_light, smoothstep(0.35, 0.7, mid));
	g = mix(g, meadow_gold, smoothstep(0.62, 0.85, macro + mid * 0.2) * 0.5);
	g = mix(g, forest_floor, smoothstep(0.35, 0.85, forest));
	g *= 0.88 + fine * 0.24;
	float flowers = step(0.83, grain) * smoothstep(0.4, 0.6, mid) * (1.0 - forest) * (1.0 - desert);
	vec3 petal = mix(vec3(0.95, 0.85, 0.9), vec3(0.95, 0.78, 0.35), step(0.5, fine));
	g = mix(g, petal, flowers * 0.55);

	// --- Rock: cool ink-blue stone with strata, lichen and moss on ledges
	vec2 side_uv = abs(wnrm.x) > abs(wnrm.z) ? wpos.zy : wpos.xy;
	float strata = n2(vec2(side_uv.x * 0.018, side_uv.y * 0.2)) * 0.6 + n2(side_uv * 0.11) * 0.4;
	vec3 r = mix(rock_dark, rock_light, strata);
	r = mix(r, lichen, smoothstep(0.72, 0.9, n2(side_uv * 0.06 + 3.1)) * 0.5);
	// Crevice darkening (ink)
	r *= 0.78 + smoothstep(0.25, 0.75, strata) * 0.3;
	float ledge_moss = smoothstep(0.35, 0.55, wnrm.y) * smoothstep(0.35, 0.6, mid + damp * 0.3);
	r = mix(r, moss, ledge_moss * 0.8);

	// --- Shore sand & trail
	float beach = (1.0 - smoothstep(1.6, 3.2 + mid * 1.5, wpos.y)) * (1.0 - desert);
	vec3 s = mix(wet_sand, sand, smoothstep(-0.6, 1.2, wpos.y));
	vec3 col = g;
	col = mix(col, s, beach);
	vec3 t = trail * (0.88 + grain * 0.24);
	float stones = smoothstep(0.8, 0.86, n2(wpos.xz * 0.9)) * 0.5;   // scattered cobbles
	t = mix(t, rock_light * 1.05, stones);
	col = mix(col, t, smoothstep(0.15, 0.8, path) * 0.9 * (1.0 - smoothstep(0.3, 0.5, slope)));

	// --- Desert: warm dunes with wind ripples, cooler shadowed flanks
	if (desert > 0.01) {
		float ripple = sin((wpos.x * 0.8 + wpos.z * 0.35) * 1.4 + grain * 3.0) * 0.5 + 0.5;
		vec3 ds = mix(desert_shadow, desert_sand, clamp(wnrm.x * 0.5 + 0.6 + ripple * 0.12, 0.0, 1.0));
		col = mix(col, ds, smoothstep(0.1, 0.6, desert));
		r = mix(r, vec3(0.72, 0.42, 0.3) * (0.8 + strata * 0.4), smoothstep(0.2, 0.7, desert));
	}

	float rock_k = smoothstep(0.26 - mid * 0.08, 0.4, slope);
	col = mix(col, r, rock_k);

	// --- Damp ground: darker, lusher, glossy
	col = mix(col, col * vec3(0.72, 0.82, 0.78), damp * (1.0 - rock_k) * 0.7);

	// --- Snow: altitude + weather, blue in shadowed slopes
	float line = snow_line - snow_amount * 90.0 + (mid - 0.5) * 24.0;
	float snow_k = smoothstep(line, line + 12.0, wpos.y) * (1.0 - smoothstep(0.35, 0.62, slope));
	vec3 sn = mix(snow * vec3(0.82, 0.88, 1.0), snow, clamp(wnrm.y, 0.0, 1.0));
	col = mix(col, sn * (0.95 + fine * 0.05), snow_k);

	// --- Veil Reaches: bruised violet ground veined with glowing jade
	float veil = 1.0 - smoothstep(0.7, 1.0, length(wpos.xz - veil_center) / veil_radius);
	vec3 emit = vec3(0.0);
	if (veil > 0.01) {
		col = mix(col, veil_ground * (0.8 + mid * 0.4), veil * 0.85);
		float vn = n2(wpos.xz * 0.021);
		float vein = smoothstep(0.485, 0.5, vn) * (1.0 - smoothstep(0.5, 0.515, vn));
		vein *= smoothstep(0.45, 0.7, n2(wpos.xz * 0.004 + 7.0));   // only some fields glow
		emit = veil_glow * vein * veil * (0.15 + night_glow * 0.55);
	}

	// Rain wetness: darker albedo, glossier
	float wet = clamp(wetness + damp * 0.25, 0.0, 1.0) * (1.0 - snow_k);
	col *= mix(1.0, 0.64, wetness * (1.0 - snow_k));

	ALBEDO = col;
	EMISSION = emit;
	ROUGHNESS = mix(0.92, 0.38, wet) - snow_k * 0.25;
	SPECULAR = 0.35;
}
