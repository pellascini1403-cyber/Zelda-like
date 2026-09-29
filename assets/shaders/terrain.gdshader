shader_type spatial;
// Terrain: all surface variation is procedural (slope, altitude, biome mask,
// world-space noise) so there are no large splat textures to stream.
// Used by streamed sector meshes and by the far HorizonTiles.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform float wetness;
global uniform float snow_amount;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float snow_line = 150.0;

uniform vec3 grass_lush : source_color = vec3(0.30, 0.47, 0.16);
uniform vec3 grass_dry : source_color = vec3(0.56, 0.58, 0.27);
uniform vec3 forest_floor : source_color = vec3(0.20, 0.27, 0.12);
uniform vec3 rock_light : source_color = vec3(0.55, 0.52, 0.47);
uniform vec3 rock_dark : source_color = vec3(0.33, 0.31, 0.30);
uniform vec3 sand : source_color = vec3(0.83, 0.76, 0.58);
uniform vec3 wet_sand : source_color = vec3(0.52, 0.46, 0.34);
uniform vec3 snow : source_color = vec3(0.93, 0.95, 0.98);

varying vec3 wpos;
varying vec3 wnrm;
varying float forest;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	forest = COLOR.r;
}

float n2(vec2 p) {
	return texture(noise_tex, p).r;
}

void fragment() {
	float macro = n2(wpos.xz * 0.0021);
	float mid = n2(wpos.xz * 0.019);
	float fine = n2(wpos.xz * 0.061);
	float slope = 1.0 - wnrm.y;

	// Grass with dry patches and forest floor
	vec3 g = mix(grass_lush, grass_dry, smoothstep(0.45, 0.75, macro + mid * 0.25));
	g = mix(g, forest_floor, smoothstep(0.35, 0.8, forest));
	g *= 0.9 + fine * 0.2;

	// Rock with strata; projected on the dominant side plane to avoid stretching
	vec2 side_uv = abs(wnrm.x) > abs(wnrm.z) ? wpos.zy : wpos.xy;
	float strata = n2(vec2(side_uv.x * 0.02, side_uv.y * 0.18)) * 0.6 + n2(side_uv * 0.11) * 0.4;
	vec3 r = mix(rock_dark, rock_light, strata);
	r *= 0.9 + fine * 0.2;

	// Beach
	float beach = 1.0 - smoothstep(1.6, 3.2 + mid * 1.5, wpos.y);
	vec3 s = mix(wet_sand, sand, smoothstep(-0.6, 1.2, wpos.y));

	vec3 col = g;
	col = mix(col, s, beach);
	float rock_k = smoothstep(0.26 - mid * 0.08, 0.4, slope);
	col = mix(col, r, rock_k);

	// Snow: altitude + weather driven, sticks to flatter surfaces
	float line = snow_line - snow_amount * 90.0 + (mid - 0.5) * 24.0;
	float snow_k = smoothstep(line, line + 12.0, wpos.y) * (1.0 - smoothstep(0.35, 0.6, slope));
	col = mix(col, snow * (0.94 + fine * 0.06), snow_k);

	// Wetness from rain: darker albedo, glossier surface
	float wet = wetness * (1.0 - snow_k);
	col *= mix(1.0, 0.62, wet);

	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.35, wet) - snow_k * 0.2;
	SPECULAR = 0.35;
}
