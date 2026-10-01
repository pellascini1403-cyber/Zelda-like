shader_type spatial;
// Leaf sprays of the organic trees (TreeKit): small opaque geometric leaves
// (no texture, no alpha test), double-sided with the crown's soft normals on
// both faces, translucent when backlit, same sway as the crown plus a leaf
// flutter. The gaps between them are what dapples the forest floor.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

global uniform vec4 wind_vec;
global uniform float wetness;
global uniform float snow_amount;

uniform vec3 hue_shift : source_color = vec3(0.82, 0.96, 0.78);
uniform float sway = 0.12;
uniform float sway_start = 1.5;
uniform float snow_line = 150.0;

varying float tint;
varying vec3 wpos;

void vertex() {
	tint = INSTANCE_CUSTOM.r;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = max(VERTEX.y - sway_start, 0.0);
	float phase = TIME * 1.3 + origin.x * 0.13 + origin.z * 0.11;
	float gust = sin(phase) * 0.6 + sin(phase * 2.3 + 1.7) * 0.25;
	float flutter = sin(TIME * 7.0 + VERTEX.x * 4.0 + VERTEX.z * 3.0 + origin.x) * 0.035 * min(h, 4.0);
	vec3 dir = vec3(wind_vec.x, 0.0, wind_vec.z);
	vec3 offset = (dir * (0.4 + gust) * wind_vec.w + vec3(gust * 0.15, 0.0, gust * 0.1)) * h * sway;
	offset += vec3(flutter, flutter * 0.6, -flutter);
	VERTEX += (vec4(offset, 0.0) * MODEL_MATRIX).xyz;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = COLOR.rgb;
	col = mix(col, col * hue_shift * 1.22, tint);
	float snow_k = smoothstep(snow_line - snow_amount * 90.0, snow_line - snow_amount * 90.0 + 15.0, wpos.y);
	col = mix(col, vec3(0.92, 0.94, 0.99), snow_k * 0.6);
	col *= mix(1.0, 0.72, wetness);
	// Card normals are the crown's soft radial normals: valid for both faces.
	ALBEDO = col;
	ROUGHNESS = mix(0.7, 0.35, wetness);
	SPECULAR = 0.3;
	BACKLIGHT = col * vec3(0.7, 0.8, 0.45);
}
