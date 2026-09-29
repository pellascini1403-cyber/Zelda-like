shader_type spatial;
// Expanding ground/air ring for impacts, parries, bursts. `t` 0→1 over life.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float t = 0.0;
uniform float thickness = 0.14;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float r = mix(0.1, 1.0, sqrt(t));
	float ring = smoothstep(r - thickness, r, d) * (1.0 - smoothstep(r, r + thickness * 0.35, d));
	float inner = (1.0 - smoothstep(0.0, r, d)) * 0.18 * (1.0 - t);
	float a = (ring + inner) * (1.0 - t);
	ALBEDO = tint.rgb * a * 2.0;
	ALPHA = a;
}
