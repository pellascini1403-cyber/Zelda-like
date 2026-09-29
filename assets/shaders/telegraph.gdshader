shader_type spatial;
// Ground telegraph for heavy attacks: a soft outline that is always visible
// plus an inner fill that grows with `progress` (0 → 1 = impact). Shape 0 is
// a disc, 1 a rectangle (charges), 2 a cone of half-angle `arc` (sweeps).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.45, 0.2, 1.0);
uniform float progress = 0.0;
uniform float shape = 0.0;
uniform float arc = 0.8;
uniform float fade = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d;       // 0 at centre/origin, 1 at the edge
	float inside;
	if (shape < 0.5) {
		d = length(p);
		inside = 1.0 - step(1.0, d);
	} else if (shape < 1.5) {
		d = UV.y;                  // fill runs from the origin forward
		inside = step(abs(p.x), 1.0);
	} else {
		vec2 q = vec2(p.x, UV.y);
		float ang = abs(atan(q.x, q.y));
		d = length(vec2(p.x, UV.y));
		inside = (1.0 - step(arc, ang)) * (1.0 - step(1.0, d));
	}
	float edge = smoothstep(0.86, 0.97, d) * (1.0 - smoothstep(0.97, 1.0, d));
	if (shape > 0.5 && shape < 1.5) {
		edge = max(smoothstep(0.9, 0.98, abs(p.x)), smoothstep(0.02, 0.0, UV.y) + smoothstep(0.97, 1.0, UV.y));
	}
	float fill = (1.0 - step(progress, d)) * 0.35;
	float front = smoothstep(progress - 0.06, progress, d) * (1.0 - step(progress, d)) * 0.8;
	float pulse = 0.75 + 0.25 * sin(TIME * 14.0);
	float a = (edge * 0.9 * pulse + fill + front) * inside * fade;
	ALBEDO = tint.rgb * a * 1.6;
	ALPHA = a;
}
