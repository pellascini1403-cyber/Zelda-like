shader_type spatial;
// Wind Warden architecture (one material for every structure).
// Vertex colour = sRGB albedo; vertex alpha = surface type:
//   1.0 matte · 0.8 glazed tile · 0.6 gilded · 0.4 cloth (sways) · 0.2 lamp
// Weathering is procedural in world space: grime streaks on walls, moss on
// ledges, rain darkening, snow on up-facing surfaces. No textures to stream.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

global uniform float wetness;
global uniform float snow_amount;
global uniform float night_glow;
global uniform vec4 wind_vec;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
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

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float n_mid = texture(noise_tex, wpos.xz * 0.045 + wpos.y * 0.021).r;
	float n_fine = texture(noise_tex, wpos.xz * 0.31 + wpos.y * 0.17).r;
	float vertical = 1.0 - abs(wn.y);

	bool glaze = kind > 0.7 && kind < 0.9;
	bool gilt = kind > 0.5 && kind < 0.7;
	bool cloth = kind > 0.3 && kind < 0.5;
	bool lamp = kind < 0.3;

	float rough = 0.86;
	float metal = 0.0;
	float spec = 0.4;
	vec3 col = base;
	if (!lamp && !cloth) {
		// Rain-run streaks down vertical faces, gentle mottling everywhere.
		float streak = texture(noise_tex, vec2((wpos.x + wpos.z) * 0.35, wpos.y * 0.015)).r;
		col *= mix(1.0, 0.8 + streak * 0.3, vertical * 0.8);
		col *= 0.9 + n_fine * 0.18;
		if (!glaze && !gilt) {
			float moss = smoothstep(0.55, 0.9, wn.y) * smoothstep(0.5, 0.72, n_mid);
			col = mix(col, vec3(0.1, 0.18, 0.08), moss * 0.45);
		}
	}
	if (glaze) { rough = 0.32; spec = 0.65; col *= 0.95 + n_mid * 0.1; }
	if (gilt) { rough = 0.3; metal = 0.75; spec = 0.6; }
	if (cloth) { rough = 0.95; spec = 0.2; }

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
		// Thin cloth: translucent backlight.
		BACKLIGHT = col * 0.5;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	EMISSION = emit;
}
