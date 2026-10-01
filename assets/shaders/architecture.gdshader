shader_type spatial;
// Wind Warden architecture (one material for every structure).
// Vertex colour = sRGB albedo; vertex alpha = surface type:
//   1.0 matte · 0.8 glazed tile · 0.6 gilded · 0.4 cloth (sways) · 0.2 lamp
// Matte surfaces are told apart by their colour family and each gets its
// own response, all procedural in world space (no textures to stream):
//   * stone: dressed blocks with per-block tone, mortar joints, chipped
//     grain, sun-bleached tops, moss and damp toward the ground
//   * wood (dark, warm): grain along the member, worn lighter edges
//   * lacquer (saturated cinnabar / jade paint): satin sheen, wear that
//     shows the wood beneath
//   * plaster: soft mottling and rain-run streaks
// Everything darkens and picks up soil where it meets the ground (contact
// occlusion from the island height field), moss grows under the canopy,
// rain wets it and snow settles on top.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

global uniform float wetness;
global uniform float snow_amount;
global uniform float night_glow;
global uniform vec4 wind_vec;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
#include "res://assets/shaders/world_light.gdshaderinc"
uniform float snow_line = 150.0;

varying vec3 wpos;
varying float kind;

void vertex() {
	kind = COLOR.a;
	if (UV.x > 0.0) {
		// Cloth: sway grows toward the free end (UV.x), gusts ripple along it.
		float ph = TIME * 2.6 + VERTEX.x * 0.6 + VERTEX.z * 0.4 - UV.x * 3.0;
		vec2 push = wind_vec.xz * (0.35 + wind_vec.w * 0.9) + vec2(sin(ph), cos(ph * 0.8)) * 0.18;
		VERTEX.xz += push * UV.x * UV.x;
		VERTEX.y += sin(ph * 1.3) * 0.05 * UV.x;
	}
	wpos = VERTEX;
}

float n2(vec2 p) {
	return texture(noise_tex, p).r;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float n_mid = n2(wpos.xz * 0.045 + wpos.y * 0.021);
	float n_fine = n2(wpos.xz * 0.31 + wpos.y * 0.17);
	float vertical = 1.0 - abs(wn.y);
	// Planar coordinates on the face (walls: along the wall + height).
	vec2 face = abs(wn.x) > abs(wn.z) ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y);
	if (abs(wn.y) > 0.7) {
		face = wpos.xz;
	}

	bool glaze = kind > 0.7 && kind < 0.9;
	bool gilt = kind > 0.5 && kind < 0.7;
	bool cloth = kind > 0.3 && kind < 0.5;
	bool lamp = kind < 0.3;
	bool matte = kind > 0.9;

	vec3 srgb = COLOR.rgb;
	float mx = max(srgb.r, max(srgb.g, srgb.b));
	float mn = min(srgb.r, min(srgb.g, srgb.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float lum = dot(srgb, vec3(0.3, 0.59, 0.11));
	bool stone = matte && sat < 0.16 && lum > 0.35;
	bool plaster = matte && lum > 0.8 && sat < 0.2;
	bool lacquer = matte && sat > 0.5 && lum > 0.25;
	bool wood = matte && !stone && !plaster && !lacquer;

	float rough = 0.86;
	float metal = 0.0;
	float spec = 0.4;
	vec3 col = base;
	if (stone && !plaster) {
		// Dressed blocks: running bond, per-block tone, mortar joints.
		vec2 bs = vec2(0.9, 0.45);
		vec2 q = face / bs;
		q.x += step(1.0, mod(floor(q.y), 2.0)) * 0.5;
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float joint = (1.0 - smoothstep(0.0, 0.05, min(f.x, 1.0 - f.x) * bs.x)) + (1.0 - smoothstep(0.0, 0.04, min(f.y, 1.0 - f.y) * bs.y));
		joint = clamp(joint, 0.0, 1.0) * vertical;
		col *= 0.86 + hash2(cell) * 0.24;
		col *= 0.9 + n_fine * 0.18;
		col *= 1.0 - joint * 0.35;
		col = mix(col, col * vec3(1.06, 1.04, 0.98), smoothstep(0.6, 0.95, wn.y));   // bleached tops
		rough = 0.88 - hash2(cell + 7.0) * 0.1;
		spec = 0.32;
	} else if (wood) {
		// Grain along the member: stretched noise, darker late-wood lines.
		vec2 g = abs(wn.y) > 0.7 ? vec2(wpos.x * 0.25, wpos.z * 6.0) : vec2(face.x * 6.0, face.y * 0.25);
		if (vertical > 0.3 && abs(wn.y) < 0.7) {
			g = vec2(face.x * 6.0, face.y * 0.22);
		}
		float grain = n2(g * 0.6) * 0.6 + n2(g * 1.7 + 0.3) * 0.4;
		col *= 0.8 + grain * 0.34;
		col *= 0.92 + n_mid * 0.14;
		rough = 0.78 + grain * 0.12;
		spec = 0.35;
	} else if (lacquer) {
		// Satin lacquer worn through to the wood here and there.
		float wear = smoothstep(0.72, 0.82, n2(face * 0.9 + 2.0) + n_fine * 0.2);
		col = mix(col * (0.94 + n_mid * 0.1), pow(vec3(0.3, 0.2, 0.15), vec3(2.2)), wear * 0.7);
		rough = mix(0.42, 0.8, wear);
		spec = 0.5;
	} else if (plaster) {
		col *= 0.93 + n_mid * 0.1;
	}
	if (!lamp && !cloth) {
		// Rain-run streaks down vertical faces, gentle mottling everywhere.
		float streak = n2(vec2((wpos.x + wpos.z) * 0.35, wpos.y * 0.015));
		col *= mix(1.0, 0.8 + streak * 0.3, vertical * (plaster ? 0.9 : 0.5));
		if (!glaze && !gilt) {
			float moss = smoothstep(0.55, 0.9, wn.y) * smoothstep(0.5, 0.72, n_mid + world_mask(wpos).r * 0.25);
			col = mix(col, vec3(0.06, 0.12, 0.05), moss * 0.45);
		}
	}
	if (glaze) { rough = 0.3; spec = 0.65; col *= 0.95 + n_mid * 0.1; }
	if (gilt) { rough = 0.3; metal = 0.75; spec = 0.6; }
	if (cloth) { rough = 0.95; spec = 0.2; }

	// Contact with the ground: darker, damp and soiled in the first metre,
	// with a little moss creeping up stone and wood.
	if (!lamp) {
		float above = wpos.y - ground_height(wpos.xz);
		float contact = 1.0 - smoothstep(0.0, 1.4 + n_mid * 0.6, above);
		col = mix(col, col * vec3(0.55, 0.52, 0.46), contact * 0.75);
		col = mix(col, vec3(0.05, 0.09, 0.04), contact * smoothstep(0.55, 0.75, n_fine) * 0.35 * float(stone || wood));
		rough = mix(rough, 0.95, contact * 0.5);
	}

	// Rain: darker, glossier
	float wet = wetness * (0.6 + 0.4 * wn.y * 0.5 + 0.2);
	col *= mix(1.0, 0.7, wet);
	rough = mix(rough, 0.2, wet * 0.8);

	// Snow on up-facing surfaces (altitude + weather)
	float line = snow_line - snow_amount * 90.0 + (n_mid - 0.5) * 20.0;
	float snow_k = smoothstep(line, line + 10.0, wpos.y) * smoothstep(0.45, 0.8, wn.y);
	col = mix(col, vec3(0.86, 0.9, 0.97), snow_k);

	vec3 emit = vec3(0.0);
	if (lamp) {
		// Paper lanterns: faint by day, warm glow at night.
		emit = base * vec3(1.0, 0.72, 0.42) * (0.25 + night_glow * 3.2);
		rough = 0.9;
	}
	if (cloth) {
		// Thin cloth: soft, translucent when backlit.
		BACKLIGHT = col * 0.55;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	EMISSION = emit;
}
