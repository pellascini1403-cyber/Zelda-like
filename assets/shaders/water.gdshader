shader_type spatial;
// Sea / lake / river surface. Shoreline and depth tint come from the low-res
// island heightmap (baked once at load) instead of the depth buffer, so it
// behaves the same on Mobile and Compatibility renderers.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, shadows_disabled;

global uniform vec4 wind_vec;
global uniform float wetness;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform float world_half = 1024.0;
uniform float height_scale = 300.0;
uniform float height_offset = -40.0;
uniform vec3 shallow : source_color = vec3(0.24, 0.62, 0.62);
uniform vec3 deep : source_color = vec3(0.04, 0.2, 0.33);
uniform vec3 foam : source_color = vec3(0.92, 0.96, 0.97);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(wpos.x * 0.08 + TIME * 1.1) * 0.12 + sin(wpos.z * 0.11 + TIME * 0.9) * 0.1;
	VERTEX.y += w * (1.0 + wind_vec.w);
}

void fragment() {
	vec2 huv = wpos.xz / (world_half * 2.0) + 0.5;
	float ground = texture(height_tex, huv).r * height_scale + height_offset;
	float depth = max(wpos.y - ground, 0.0);

	vec2 flow = vec2(wind_vec.x, wind_vec.z) * TIME * 0.02;
	float n1 = texture(noise_tex, wpos.xz * 0.045 + flow + TIME * 0.01).r;
	float n2 = texture(noise_tex, wpos.xz * 0.11 - flow * 1.7 - TIME * 0.013).r;
	vec3 nrm = normalize(vec3((n1 - 0.5) * 0.5, 1.0, (n2 - 0.5) * 0.5));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);

	vec3 col = mix(shallow, deep, smoothstep(0.0, 9.0, depth));
	float shore = 1.0 - smoothstep(0.0, 0.9 + n1 * 0.8, depth);
	float ripple = smoothstep(0.55, 0.9, sin(depth * 3.0 - TIME * 1.6) * 0.5 + 0.5) * (1.0 - smoothstep(0.0, 2.5, depth));
	col = mix(col, foam, clamp(shore * 0.85 + ripple * 0.25, 0.0, 1.0));

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = col;
	ALPHA = clamp(0.55 + smoothstep(0.0, 4.0, depth) * 0.4 + fres * 0.3 + shore * 0.4, 0.0, 0.97);
	ROUGHNESS = mix(0.06, 0.2, wetness);
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
