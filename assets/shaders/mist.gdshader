shader_type spatial;
// Mist bank card (Y-axis billboard). Soft drifting noise, faded at the card
// edges and when the camera gets close, so it reads as a layer of haze
// between depth planes without ever becoming a wall. Unshaded, no depth
// writes: one cheap blended quad per bank.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform vec3 mist_color;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float intensity = 0.55;
uniform float near_fade = 45.0;
uniform float seed = 0.0;

varying float cam_dist;

void vertex() {
	// Cylindrical billboard around Y
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	to_cam.y = 0.0;
	vec3 fwd = normalize(to_cam);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
	vec3 wp = origin + right * VERTEX.x * sc.x + vec3(0.0, VERTEX.y * sc.y, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
	cam_dist = length(CAMERA_POSITION_WORLD - wp);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.008;
	float n = texture(noise_tex, uv * vec2(1.6, 0.8) + vec2(t + seed, seed * 0.3)).r * 0.65
		+ texture(noise_tex, uv * vec2(3.4, 1.7) - vec2(t * 1.7, -seed)).r * 0.35;
	float edge = smoothstep(0.0, 0.42, uv.x) * smoothstep(1.0, 0.58, uv.x);
	float vert = smoothstep(0.0, 0.4, uv.y) * smoothstep(1.0, 0.35, uv.y);
	float a = smoothstep(0.2, 0.85, n) * edge * edge * vert * intensity;
	a *= smoothstep(near_fade * 0.4, near_fade, cam_dist);
	ALBEDO = mist_color * (0.95 + n * 0.1);
	ALPHA = a;
}
