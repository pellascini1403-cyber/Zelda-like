shader_type spatial;
// Spinning wind barrier: bright streaks sliding around a cylinder.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

void fragment() {
	float s = sin((UV.x * 18.0 + UV.y * 6.0 - TIME * 2.4) * 3.14159);
	float streak = smoothstep(0.6, 1.0, s);
	float band = smoothstep(0.0, 0.2, UV.y) * smoothstep(1.0, 0.7, UV.y);
	vec3 col = vec3(0.6, 1.0, 0.85);
	ALBEDO = col * (streak * 0.9 + 0.12) * band;
	ALPHA = (streak * 0.7 + 0.1) * band;
}
