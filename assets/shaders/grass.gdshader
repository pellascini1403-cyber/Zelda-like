shader_type spatial;
// Grass clumps (MultiMesh). Color is sampled from the same world-space noise
// as the terrain so blades blend into the ground they grow on.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled, shadows_disabled;

global uniform vec4 wind_vec;
global uniform float wetness;
global uniform vec3 player_pos;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 grass_lush : source_color = vec3(0.30, 0.47, 0.16);
uniform vec3 grass_dry : source_color = vec3(0.56, 0.58, 0.27);
uniform vec3 tip_color : source_color = vec3(0.72, 0.78, 0.38);
uniform float fade_start = 38.0;
uniform float fade_end = 52.0;

varying float blade_h;
varying vec3 base_col;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	blade_h = clamp(VERTEX.y / 0.55, 0.0, 1.0);
	float phase = TIME * 2.1 + origin.x * 0.35 + origin.z * 0.27;
	float gust = sin(phase) * 0.5 + sin(phase * 0.37 + origin.x * 0.05) * 0.5;
	vec3 bend = vec3(wind_vec.x, 0.0, wind_vec.z) * (0.25 + wind_vec.w) * (0.5 + gust * 0.5);
	// Player pushes grass aside.
	vec3 away = origin - player_pos;
	float pd = length(away.xz);
	bend += vec3(away.x, 0.0, away.z) / max(pd, 0.01) * smoothstep(1.4, 0.3, pd) * 0.9;
	vec3 offset = bend * blade_h * blade_h * 0.6;
	offset.y -= length(offset) * 0.3;
	VERTEX += (vec4(offset, 0.0) * MODEL_MATRIX).xyz;

	// Distance shrink instead of alpha fade (cheaper, no sorting).
	float cd = length(origin - CAMERA_POSITION_WORLD);
	VERTEX *= 1.0 - smoothstep(fade_start, fade_end, cd);

	float macro = texture(noise_tex, origin.xz * 0.0021).r;
	float mid = texture(noise_tex, origin.xz * 0.019).r;
	base_col = mix(grass_lush, grass_dry, smoothstep(0.45, 0.75, macro + mid * 0.25));
}

void fragment() {
	vec3 col = mix(base_col * 0.7, mix(base_col, tip_color, 0.35), blade_h);
	col *= mix(1.0, 0.7, wetness);
	ALBEDO = col * COLOR.rgb;
	ROUGHNESS = 0.8;
	BACKLIGHT = vec3(0.2, 0.25, 0.08) * blade_h;
}
