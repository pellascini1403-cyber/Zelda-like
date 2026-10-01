shader_type spatial;
// Terrain — painterly natural ground ("Jade, Cinnabar & Ink Mist").
// All variation is procedural (slope, altitude, biome masks in vertex colour,
// world-space noise at four scales): no splat textures to stream.
//   COLOR.r forest density · COLOR.g trail · COLOR.b damp · COLOR.a desert
// Ground reads like concept-art brushwork: warm sunlit yellow-greens, cool
// teal shade-greens, elongated stroke texture, soil showing through, flower
// clusters, pebbles, moss in damp shade. A procedural detail normal lets the
// low sun model small relief. Used by streamed sectors and the far
// HorizonTiles (which skip the near-only detail by distance).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform float wetness;
global uniform float snow_amount;
global uniform float night_glow;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
#include "res://assets/shaders/world_light.gdshaderinc"
uniform float snow_line = 150.0;
uniform vec2 veil_center = vec2(880.0, -880.0);
uniform float veil_radius = 330.0;

// Meadow palette (sRGB): warm light, lush mid, cool shade-green, dry gold.
uniform vec3 grass_warm : source_color = vec3(0.6, 0.66, 0.27);
uniform vec3 grass_lush : source_color = vec3(0.37, 0.55, 0.25);
uniform vec3 grass_cool : source_color = vec3(0.27, 0.48, 0.35);
uniform vec3 meadow_gold : source_color = vec3(0.74, 0.67, 0.36);
uniform vec3 soil : source_color = vec3(0.5, 0.39, 0.27);
uniform vec3 moss : source_color = vec3(0.3, 0.44, 0.2);
uniform vec3 forest_floor : source_color = vec3(0.42, 0.47, 0.25);
uniform vec3 leaf_litter : source_color = vec3(0.55, 0.42, 0.24);
uniform vec3 rock_light : source_color = vec3(0.6, 0.6, 0.57);
uniform vec3 rock_dark : source_color = vec3(0.3, 0.32, 0.35);
uniform vec3 lichen : source_color = vec3(0.66, 0.6, 0.4);
uniform vec3 trail : source_color = vec3(0.7, 0.58, 0.41);
uniform vec3 sand : source_color = vec3(0.86, 0.78, 0.6);
uniform vec3 wet_sand : source_color = vec3(0.52, 0.47, 0.37);
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

// Elongated brush strokes whose direction drifts across the field.
float strokes(vec2 p, float ang) {
	vec2 d = vec2(cos(ang), sin(ang));
	vec2 q = vec2(dot(p, d), dot(p, vec2(-d.y, d.x)));
	return n2(vec2(q.x * 0.55, q.y * 2.4)) * 0.6 + n2(vec2(q.x * 1.3, q.y * 5.0) + 0.41) * 0.4;
}

void fragment() {
	float cam_d = length(wpos - CAMERA_POSITION_WORLD);
	float near_k = 1.0 - smoothstep(60.0, 140.0, cam_d);     // near-only detail
	float macro = n2(wpos.xz * 0.0019);
	float macro2 = n2(wpos.xz * 0.0047 + 0.53);
	float mid = n2(wpos.xz * 0.017);
	float fine = n2(wpos.xz * 0.061);
	float grain = n2(wpos.xz * 0.37);
	float slope = 1.0 - wnrm.y;
	float forest = masks.r;
	float path = masks.g;
	float damp = max(masks.b, world_mask(wpos).g * 0.6);
	float desert = masks.a;

	// --- Meadow: large hue fields (warm / lush / cool), dry gold hills,
	// painterly strokes, soil breaking through, flower clusters, pebbles.
	vec3 g = mix(grass_lush, grass_warm, smoothstep(0.35, 0.75, macro2 + (mid - 0.5) * 0.4));
	g = mix(g, grass_cool, smoothstep(0.5, 0.8, macro + (fine - 0.5) * 0.25) * 0.75);
	g = mix(g, meadow_gold, smoothstep(0.64, 0.86, macro + mid * 0.2) * 0.55);
	float st = strokes(wpos.xz * 0.9, macro * 6.28 + mid * 1.5);
	g *= 0.84 + st * 0.3 * (0.4 + near_k * 0.6);
	g = mix(g, g * vec3(1.06, 1.04, 0.86), smoothstep(0.55, 0.8, st) * 0.6);   // sunlit tips
	float bare = smoothstep(0.72, 0.88, n2(wpos.xz * 0.029 + 1.7) + (grain - 0.5) * 0.16) * (1.0 - forest * 0.5);
	vec3 dirt = soil * (0.82 + grain * 0.3);
	g = mix(g, dirt, bare * 0.85);
	// Forest floor: olive moss, leaf litter, cool shade-green.
	vec3 ff = mix(forest_floor, moss, smoothstep(0.4, 0.7, mid + damp * 0.3));
	ff = mix(ff, leaf_litter * (0.8 + grain * 0.35), smoothstep(0.55, 0.75, fine + grain * 0.15) * 0.55);
	g = mix(g, ff, smoothstep(0.3, 0.8, forest));
	// Flower clusters: sparse fields, not uniform speckle.
	float cluster = smoothstep(0.62, 0.78, n2(wpos.xz * 0.028 + 4.2)) * (1.0 - forest) * (1.0 - desert) * (1.0 - bare);
	float petal_k = step(0.8, n2(wpos.xz * 1.9)) * cluster * near_k;
	vec3 petal = mix(vec3(0.93, 0.5, 0.72), vec3(0.97, 0.93, 0.86), step(0.55, macro2));
	petal = mix(petal, vec3(0.98, 0.82, 0.36), step(0.7, fine));
	g = mix(g, petal, petal_k * 0.8);
	// Pebbles with a darker ring (read as small stones, not dots).
	float peb = n2(wpos.xz * 0.83 + 9.1);
	float pebble = smoothstep(0.81, 0.83, peb) * near_k * (0.4 + bare * 0.6);
	float ring = smoothstep(0.78, 0.81, peb) * (1.0 - smoothstep(0.81, 0.83, peb)) * near_k * (0.4 + bare * 0.6);
	g = mix(g, rock_light * (0.85 + fine * 0.2), pebble * 0.8);
	g *= 1.0 - ring * 0.35;

	// --- Rock: cool stone, strata, lichen, moss on ledges, exposed vs. sheltered
	vec2 side_uv = abs(wnrm.x) > abs(wnrm.z) ? wpos.zy : wpos.xy;
	float strata = n2(vec2(side_uv.x * 0.018, side_uv.y * 0.2)) * 0.6 + n2(side_uv * 0.11) * 0.4;
	vec3 r = mix(rock_dark, rock_light, strata);
	r = mix(r, lichen, smoothstep(0.72, 0.9, n2(side_uv * 0.06 + 3.1)) * 0.5);
	r *= 0.78 + smoothstep(0.25, 0.75, strata) * 0.3;                      // ink crevices
	r = mix(r, r * vec3(1.05, 1.02, 0.95), smoothstep(0.2, 0.8, wnrm.y));    // sun-bleached tops
	float ledge_moss = smoothstep(0.35, 0.55, wnrm.y) * smoothstep(0.35, 0.6, mid + damp * 0.3);
	r = mix(r, moss, ledge_moss * 0.8);

	// --- Shore sand & trail
	float beach = (1.0 - smoothstep(1.6, 3.2 + mid * 1.5, wpos.y)) * (1.0 - desert);
	vec3 s = mix(wet_sand, sand, smoothstep(-0.6, 1.2, wpos.y));
	s *= 0.92 + grain * 0.12;
	vec3 col = g;
	col = mix(col, s, beach);
	vec3 t = trail * (0.86 + grain * 0.24) * (0.94 + st * 0.1);
	float stones = smoothstep(0.8, 0.86, n2(wpos.xz * 0.9)) * 0.5;
	t = mix(t, rock_light * 1.05, stones);
	float trail_k = smoothstep(0.15, 0.8, path + (fine - 0.5) * 0.25) * 0.92 * (1.0 - smoothstep(0.3, 0.5, slope));
	col = mix(col, t, trail_k);

	// --- Desert: warm dunes with wind ripples, cooler shadowed flanks
	if (desert > 0.01) {
		float ripple = sin((wpos.x * 0.8 + wpos.z * 0.35) * 1.4 + grain * 3.0) * 0.5 + 0.5;
		vec3 ds = mix(desert_shadow, desert_sand, clamp(wnrm.x * 0.5 + 0.6 + ripple * 0.12, 0.0, 1.0));
		col = mix(col, ds, smoothstep(0.1, 0.6, desert));
		r = mix(r, vec3(0.72, 0.42, 0.3) * (0.8 + strata * 0.4), smoothstep(0.2, 0.7, desert));
	}

	float rock_k = smoothstep(0.26 - mid * 0.08, 0.4, slope);
	col = mix(col, r, rock_k);

	// --- Moisture: darker, cooler, richer near water and in damp hollows
	float wet_ground = damp * (1.0 - rock_k * 0.5) * (1.0 - beach);
	col = mix(col, col * vec3(0.7, 0.8, 0.78), wet_ground * 0.65);

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
		vein *= smoothstep(0.45, 0.7, n2(wpos.xz * 0.004 + 7.0));
		emit = veil_glow * vein * veil * (0.15 + night_glow * 0.55);
	}

	// Rain wetness: darker albedo, glossier
	float wet = clamp(wetness + wet_ground * 0.3, 0.0, 1.0) * (1.0 - snow_k);
	col *= mix(1.0, 0.64, wetness * (1.0 - snow_k));

	col = compat_fix(col);
	// Forest understory: cooler, darker ground lit by drifting sun flecks.
	float canopy = world_mask(wpos).r * (1.0 - rock_k) * (1.0 - snow_k);
	col *= canopy_shade(canopy);
	emit += sun_fleck.rgb * col * vec3(1.1, 1.0, 0.8) * sun_flecks(noise_tex, wpos, TIME) * canopy * 1.1;

	// Detail relief: finite-difference normal from the stroke/bump field so a
	// low sun picks out tufts, ruts and rock grain (near only).
	float e = 0.12;
	float h0 = n2(wpos.xz * 0.45) * 0.6 + n2(wpos.xz * 1.6) * 0.4;
	float hx = n2((wpos.xz + vec2(e, 0.0)) * 0.45) * 0.6 + n2((wpos.xz + vec2(e, 0.0)) * 1.6) * 0.4;
	float hz = n2((wpos.xz + vec2(0.0, e)) * 0.45) * 0.6 + n2((wpos.xz + vec2(0.0, e)) * 1.6) * 0.4;
	float bump = near_k * mix(0.9, 1.6, rock_k) * (1.0 - snow_k * 0.7) * (1.0 - beach * 0.6);
	vec3 dn = normalize(wnrm + vec3(h0 - hx, 0.0, h0 - hz) / e * 0.18 * bump);
	NORMAL = normalize((VIEW_MATRIX * vec4(dn, 0.0)).xyz);

	ALBEDO = col;
	EMISSION = emit;
	ROUGHNESS = mix(0.92, 0.38, wet) - snow_k * 0.25;
	SPECULAR = 0.3;
}
