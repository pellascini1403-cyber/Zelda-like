shader_type spatial;
// Waterfall ribbon: streaks scrolling down, brighter foam at the lip and the
// foot, translucent edges. UV.y runs 0 (top) -> 1 (bottom).
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_burley;

global uniform vec3 mist_color;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 water : source_color = vec3(0.62, 0.86, 0.86);

void fragment() {
	vec2 uv = UV;
	float s1 = texture(noise_tex, vec2(uv.x * 1.3, uv.y * 0.35 - TIME * 0.9)).r;
	float s2 = texture(noise_tex, vec2(uv.x * 3.1 + 0.4, uv.y * 0.6 - TIME * 1.4)).r;
	float streak = smoothstep(0.35, 0.8, s1 * 0.6 + s2 * 0.5);
	float edge = smoothstep(0.0, 0.2, uv.x) * smoothstep(1.0, 0.8, uv.x);
	float lip = 1.0 - smoothstep(0.0, 0.1, uv.y);
	float foot = smoothstep(0.82, 1.0, uv.y);
	vec3 col = mix(water, vec3(1.0), clamp(streak * 0.7 + lip * 0.6 + foot * 0.8, 0.0, 1.0));
	col = mix(col, mist_color, 0.15);
	ALBEDO = col;
	EMISSION = col * 0.12;
	ALPHA = clamp((0.45 + streak * 0.45 + foot * 0.3) * edge, 0.0, 0.95);
	ROUGHNESS = 0.2;
	SPECULAR = 0.6;
}
