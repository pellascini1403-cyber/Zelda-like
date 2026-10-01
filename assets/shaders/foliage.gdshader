shader_type spatial;
// Trees, shrubs and rocks. Vertex colours carry the palette; INSTANCE_CUSTOM.r
// varies hue per instance so groves never look tiled. Leaves get soft
// translucency; crystals (Veil) glow brighter at night.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform vec4 wind_vec;
global uniform float wetness;
global uniform float snow_amount;
global uniform float night_glow;

uniform float sway = 0.12;
uniform float sway_start = 1.5;
uniform bool is_rock = false;
uniform bool emissive = false;
// Sector batches (ChunkBuilder.bake_batch): UV.x tint, UV2 = (height above
// the plant's base in metres, wind phase). Same sway as instanced plants.
uniform bool baked = false;
uniform float snow_line = 150.0;
uniform vec3 hue_shift : source_color = vec3(0.82, 0.96, 0.78);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
#include "res://assets/shaders/world_light.gdshaderinc"

varying vec3 wpos;
varying float tint;
varying vec3 wnrm;
varying float local_h;

void vertex() {
	tint = INSTANCE_CUSTOM.r;
	local_h = VERTEX.y;
	if (baked) {
		tint = UV.x;
		local_h = UV2.x;
		float h = max(UV2.x - sway_start, 0.0);
		float phase = TIME * 1.3 + UV2.y;
		float gust = sin(phase) * 0.6 + sin(phase * 2.3 + 1.7) * 0.25;
		float flutter = sin(TIME * 6.0 + VERTEX.x * 3.0 + VERTEX.z * 2.0) * 0.02 * h;
		vec3 dir = vec3(wind_vec.x, 0.0, wind_vec.z);
		VERTEX += (dir * (0.4 + gust) * wind_vec.w + vec3(gust * 0.15, 0.0, gust * 0.1)) * h * sway * 0.8 + vec3(flutter, flutter * 0.5, -flutter);
	} else if (!is_rock) {
		vec3 origin = MODEL_MATRIX[3].xyz;
		float h = max(VERTEX.y - sway_start, 0.0);
		float phase = TIME * 1.3 + origin.x * 0.13 + origin.z * 0.11;
		float gust = sin(phase) * 0.6 + sin(phase * 2.3 + 1.7) * 0.25;
		// Leaf flutter: small high-frequency motion at the extremities.
		float flutter = sin(TIME * 6.0 + VERTEX.x * 3.0 + VERTEX.z * 2.0 + origin.x) * 0.02 * h;
		vec3 dir = vec3(wind_vec.x, 0.0, wind_vec.z);
		vec3 offset = (dir * (0.4 + gust) * wind_vec.w + vec3(gust * 0.15, 0.0, gust * 0.1)) * h * sway;
		offset += vec3(flutter, flutter * 0.5, -flutter);
		VERTEX += (vec4(offset, 0.0) * MODEL_MATRIX).xyz;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = COLOR.rgb;
	col = mix(col, col * hue_shift * 1.22, tint);
	if (!is_rock && !emissive) {
		// Height gradient: darker, cooler inside/under the crown.
		col *= 0.82 + 0.28 * clamp(wnrm.y * 0.5 + 0.5, 0.0, 1.0);
		BACKLIGHT = col * vec3(0.55, 0.65, 0.35);
	}
	float snow_k = smoothstep(snow_line - snow_amount * 90.0, snow_line - snow_amount * 90.0 + 15.0, wpos.y) * smoothstep(0.2, 0.7, wnrm.y);
	col = mix(col, vec3(0.92, 0.94, 0.99), snow_k);
	col *= mix(1.0, 0.72, wetness * (1.0 - snow_k));
	// Understory: shrubs, rocks and the lower trunks share the forest shade.
	if (!emissive) {
		float under = world_mask(wpos).r * (1.0 - smoothstep(1.2, 5.0, local_h));
		col *= canopy_shade(under);
	}
	ALBEDO = col;
	ROUGHNESS = mix(is_rock ? 0.85 : 0.72, 0.35, wetness);
	SPECULAR = 0.3;
	if (emissive) {
		EMISSION = col * vec3(0.7, 1.0, 0.95) * (0.2 + night_glow * 0.6) * (0.6 + 0.4 * sin(TIME * 1.5 + wpos.x * 0.3));
		ROUGHNESS = 0.2;
	}
}
