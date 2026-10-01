shader_type spatial;
// Grass clumps (MultiMesh). Color is sampled from the same world-space noise
// as the terrain so blades blend into the ground they grow on.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled, shadows_disabled;

global uniform vec4 wind_vec;
global uniform float wetness;
global uniform vec3 player_pos;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
#include "res://assets/shaders/world_light.gdshaderinc"
// Same palette and noise fields as terrain.gdshader so blades melt into
// the ground they grow on.
uniform vec3 grass_warm : source_color = vec3(0.6, 0.66, 0.27);
uniform vec3 grass_lush : source_color = vec3(0.37, 0.55, 0.25);
uniform vec3 grass_cool : source_color = vec3(0.27, 0.48, 0.35);
uniform vec3 grass_dry : source_color = vec3(0.74, 0.67, 0.36);
uniform vec3 tip_color : source_color = vec3(0.78, 0.8, 0.45);
uniform float fade_start = 38.0;
uniform float fade_end = 52.0;

varying float blade_h;
varying vec3 base_col;
varying float canopy;
varying vec3 root;

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

	canopy = world_mask(origin).r;
	root = origin;
	float macro = texture(noise_tex, origin.xz * 0.0019).r;
	float macro2 = texture(noise_tex, origin.xz * 0.0047 + 0.53).r;
	float mid = texture(noise_tex, origin.xz * 0.017).r;
	float fine = texture(noise_tex, origin.xz * 0.061).r;
	base_col = mix(grass_lush, grass_warm, smoothstep(0.35, 0.75, macro2 + (mid - 0.5) * 0.4));
	base_col = mix(base_col, grass_cool, smoothstep(0.5, 0.8, macro + (fine - 0.5) * 0.25) * 0.75);
	base_col = mix(base_col, grass_dry, smoothstep(0.6, 0.85, macro + mid * 0.2) * 0.65);
	base_col *= 0.9 + fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453) * 0.2;
}

void fragment() {
	vec3 col = mix(base_col * 0.8, mix(base_col * 1.04, tip_color, 0.22), blade_h);
	col *= mix(1.0, 0.7, wetness);
	col = compat_fix(col);
	col *= canopy_shade(canopy);
	ALBEDO = col * COLOR.rgb;
	EMISSION = sun_fleck.rgb * col * sun_flecks(noise_tex, root, TIME) * canopy * 0.6 * blade_h;
	ROUGHNESS = 0.8;
	BACKLIGHT = vec3(0.2, 0.25, 0.08) * blade_h;
}
