shader_type spatial;
// Sea / lake / river / pools. Cheap enough for mobile (no screen textures,
// no reflection probes, same look on Mobile and Compatibility), rich enough
// to carry a scene:
//   * colour by depth (jade shallows over visible ground -> deep teal),
//     depth from the baked island heightmap
//   * sky reflection from the live sky colours (global sky_top/horizon),
//     Fresnel-weighted, with the dark reflected banks of lakes and rivers
//     (one heightmap tap along the reflected ray)
//   * layered ripples whose detail fades with distance (no shimmer)
//   * sun glitter, shoreline foam bands and a wet lip that run with the waves
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, shadows_disabled;

global uniform vec4 wind_vec;
global uniform float wetness;
global uniform vec3 mist_color;
global uniform float night_glow;
global uniform vec3 sky_top;
global uniform vec3 sky_horizon;
global uniform vec4 sun_fleck;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform float world_half = 1536.0;
uniform float height_scale = 340.0;
uniform float height_offset = -40.0;
uniform vec3 shallow : source_color = vec3(0.36, 0.74, 0.62);
uniform vec3 mid_water : source_color = vec3(0.1, 0.48, 0.5);
uniform vec3 deep : source_color = vec3(0.03, 0.22, 0.32);
uniform vec3 foam : source_color = vec3(0.94, 0.97, 0.96);
uniform vec3 bank : source_color = vec3(0.16, 0.26, 0.16);
uniform vec2 veil_center = vec2(880.0, -880.0);
uniform float veil_radius = 330.0;

varying vec3 wpos;

float ground_at(vec2 xz) {
	vec2 huv = xz / (world_half * 2.0) + 0.5;
	return texture(height_tex, huv).r * height_scale + height_offset;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(wpos.x * 0.08 + TIME * 1.1) * 0.12 + sin(wpos.z * 0.11 + TIME * 0.9) * 0.1;
	VERTEX.y += w * (1.0 + wind_vec.w);
}

void fragment() {
	float depth = max(wpos.y - ground_at(wpos.xz), 0.0);
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(40.0, 220.0, dist);

	// Ripples: two broad swells and a fine chop that fades with distance.
	vec2 flow = vec2(wind_vec.x, wind_vec.z) * TIME * 0.02;
	float n1 = texture(noise_tex, wpos.xz * 0.045 + flow + TIME * 0.01).r;
	float n2 = texture(noise_tex, wpos.xz * 0.11 - flow * 1.7 - TIME * 0.013).r;
	float n3 = texture(noise_tex, wpos.xz * 0.31 + flow * 2.3).r;
	float n4 = texture(noise_tex, wpos.xz * 0.83 - flow * 3.1 + TIME * 0.02).r;
	float chop = 0.35 + wind_vec.w * 0.6;
	vec3 nrm = normalize(vec3(((n1 - 0.5) * 0.5 + (n3 - 0.5) * 0.25 * detail + (n4 - 0.5) * 0.18 * detail) * chop,
		1.0, ((n2 - 0.5) * 0.5 + (n4 - 0.5) * 0.15 * detail) * chop));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);

	// Body colour by depth: ground shows through the shallows.
	vec3 col = mix(shallow, mid_water, smoothstep(0.3, 3.5, depth));
	col = mix(col, deep, smoothstep(3.0, 16.0, depth));
	float veil = 1.0 - smoothstep(0.35, 0.6, length(wpos.xz - veil_center) / veil_radius);
	col = mix(col, vec3(0.2, 0.6, 0.7), veil * 0.6);

	// Reflection: live sky gradient + reflected banks.
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 r = reflect(-v, nrm);
	vec3 refl = mix(sky_horizon, sky_top, pow(clamp(r.y, 0.0, 1.0), 0.5));
	float bank_h = ground_at(wpos.xz + normalize(r.xz + vec2(0.0001)) * 18.0);
	float banked = smoothstep(1.5, 6.0, bank_h - wpos.y) * (1.0 - smoothstep(0.15, 0.45, r.y));
	refl = mix(refl, bank * (0.6 + n1 * 0.4) + mist_color * 0.15, banked * 0.85);
	float fres = 0.04 + 0.96 * pow(1.0 - clamp(dot(nrm, v), 0.0, 1.0), 5.0);
	fres = clamp(fres, 0.0, 0.85);

	// Shore: foam bands that run toward land, a wet bright lip.
	float shore = 1.0 - smoothstep(0.0, 0.7 + n1 * 0.7, depth);
	float bands = smoothstep(0.62, 0.92, sin(depth * 4.0 - TIME * 1.7 + n2 * 4.0) * 0.5 + 0.5) * (1.0 - smoothstep(0.0, 2.2, depth));
	float foam_k = clamp(shore * 0.8 + bands * 0.35 * (0.5 + n3), 0.0, 1.0);

	// Sun glitter: sparse bright points on the chop, toward the sun.
	float glitter = smoothstep(0.8, 0.95, n3 * n4 * 2.2) * detail;

	vec3 albedo = mix(col * (1.0 - fres), foam, foam_k);
	ALBEDO = albedo;
	EMISSION = refl * fres * (1.0 - foam_k) + sun_fleck.rgb * glitter * 0.25 * (1.0 - foam_k) + vec3(0.2, 0.9, 0.8) * veil * night_glow * 0.25;
	ALPHA = clamp(0.55 + smoothstep(0.0, 3.0, depth) * 0.4 + fres * 0.35 + foam_k * 0.5, 0.0, 0.98);
	ROUGHNESS = mix(0.16, 0.1, detail);
	METALLIC = 0.0;
	SPECULAR = 0.3;
}
