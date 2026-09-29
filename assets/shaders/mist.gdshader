shader_type spatial;
// Mist bank cards (Y-axis billboards), every bank in ONE mesh. Soft drifting
// noise, faded at the card edges and when the camera gets close, so it reads
// as a layer of haze between depth planes without ever becoming a wall.
// Unshaded, no depth writes.
//   UV2 = card centre (x, z) · CUSTOM0 = (centre y, width, seed, intensity)
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, world_vertex_coords;

global uniform vec3 mist_color;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float intensity = 0.55;
uniform float near_fade = 45.0;

varying float cam_dist;
varying float seed;
varying float strength;

void vertex() {
	vec3 centre = vec3(UV2.x, CUSTOM0.x, UV2.y);
	float w = CUSTOM0.y;
	vec3 to_cam = CAMERA_POSITION_WORLD - centre;
	to_cam.y = 0.0;
	vec3 fwd = normalize(to_cam + vec3(0.0001, 0.0, 0.0));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	float across = (UV.x - 0.5) * w;
	float up = VERTEX.y - centre.y;
	VERTEX = centre + right * across + vec3(0.0, up, 0.0);
	cam_dist = length(CAMERA_POSITION_WORLD - VERTEX);
	seed = CUSTOM0.z;
	strength = CUSTOM0.w;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.008;
	float n = texture(noise_tex, uv * vec2(1.6, 0.8) + vec2(t + seed, seed * 0.3)).r * 0.65
		+ texture(noise_tex, uv * vec2(3.4, 1.7) - vec2(t * 1.7, -seed)).r * 0.35;
	float edge = smoothstep(0.0, 0.42, uv.x) * smoothstep(1.0, 0.58, uv.x);
	float vert = smoothstep(0.0, 0.4, uv.y) * smoothstep(1.0, 0.35, uv.y);
	float a = smoothstep(0.2, 0.85, n) * edge * edge * vert * intensity * strength;
	a *= smoothstep(near_fade * 0.4, near_fade, cam_dist);
	ALBEDO = mist_color * (0.95 + n * 0.1);
	ALPHA = a;
}
