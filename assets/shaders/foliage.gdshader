shader_type spatial;
// Trees, bushes and rocks. Vertex colors carry the base palette; per-instance
// custom data (INSTANCE_CUSTOM.r) varies hue so forests do not look tiled.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform vec4 wind_vec;
global uniform float wetness;
global uniform float snow_amount;

uniform float sway = 0.12;
uniform float sway_start = 1.5;
uniform bool is_rock = false;
uniform float snow_line = 150.0;
uniform vec3 hue_shift : source_color = vec3(0.85, 0.95, 0.7);

varying vec3 wpos;
varying float tint;
varying vec3 wnrm;

void vertex() {
	tint = INSTANCE_CUSTOM.r;
	if (!is_rock) {
		vec3 origin = MODEL_MATRIX[3].xyz;
		float h = max(VERTEX.y - sway_start, 0.0);
		float phase = TIME * 1.3 + origin.x * 0.13 + origin.z * 0.11;
		float gust = sin(phase) * 0.6 + sin(phase * 2.3 + 1.7) * 0.25;
		vec3 dir = vec3(wind_vec.x, 0.0, wind_vec.z);
		vec3 offset = (dir * (0.4 + gust) * wind_vec.w + vec3(gust * 0.15, 0.0, gust * 0.1)) * h * sway;
		VERTEX += (vec4(offset, 0.0) * MODEL_MATRIX).xyz;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = COLOR.rgb;
	col = mix(col, col * hue_shift * 1.25, tint);
	if (!is_rock) {
		// Fake translucency: leaves glow slightly when back-lit.
		col *= 0.9 + 0.2 * clamp(wnrm.y, 0.0, 1.0);
	}
	float snow_k = smoothstep(snow_line - snow_amount * 90.0, snow_line - snow_amount * 90.0 + 15.0, wpos.y) * smoothstep(0.2, 0.7, wnrm.y);
	col = mix(col, vec3(0.92, 0.94, 0.97), snow_k);
	col *= mix(1.0, 0.7, wetness * (1.0 - snow_k));
	ALBEDO = col;
	ROUGHNESS = mix(is_rock ? 0.85 : 0.75, 0.35, wetness);
	SPECULAR = 0.3;
	if (!is_rock) {
		BACKLIGHT = vec3(0.25, 0.3, 0.1);
	}
}
