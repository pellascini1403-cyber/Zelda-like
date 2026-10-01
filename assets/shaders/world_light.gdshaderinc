// Shared outdoor lighting helpers (terrain, grass, foliage, rocks).
// world_masks: IslandMap masks (R canopy shade, G wetness), 8 m per texel.
// sun_fleck: key light colour * energy (linear), 0 at night / overcast.
// canopy_dark: how much the canopy darkens the ground by itself (1 when the
// trees cast no real shadows on this quality level, lower when they do).
global uniform sampler2D world_masks : filter_linear_mipmap;
global uniform vec4 sun_fleck;
global uniform float canopy_dark;
// 1 in the Compatibility renderer (Web, old GLES), where source_color
// uniforms reach the shader unconverted: colours built from them are
// linearised by hand so both renderers show the same values.
global uniform float compat_gamma;

vec3 compat_fix(vec3 c) {
	return mix(c, pow(max(c, vec3(0.0)), vec3(1.6)), compat_gamma);
}
// world_height: IslandMap height field (8 m per texel, R16 normalised).
global uniform sampler2D world_height : filter_linear;

vec4 world_mask(vec3 wp) {
	vec2 uv = (wp.xz + 1536.0) / 3072.0 * (384.0 / 385.0) + 0.5 / 385.0;
	return texture(world_masks, uv);
}

// Sun flecks: sunlight through gaps in the canopy, drifting slowly with the
// leaves. Soft-edged pools of light, sparse, 0.3-1.5 m across.
float sun_flecks(sampler2D noise, vec3 wp, float t) {
	vec2 drift = vec2(sin(t * 0.37), cos(t * 0.29)) * 0.012;
	float a = texture(noise, wp.xz * 0.21 + drift).r;
	float b = texture(noise, wp.xz * 0.53 - drift * 1.7 + 0.37).r;
	float n = a * 0.6 + b * 0.4;
	return smoothstep(0.65, 0.72, n);
}

// Albedo multiplier for ground under the canopy (cool, darker understory).
vec3 canopy_shade(float canopy) {
	float k = canopy * canopy_dark;
	return mix(vec3(1.0), vec3(0.5, 0.58, 0.62), k);
}

// Approximate ground height under a world position (coarse, smooth).
float ground_height(vec2 xz) {
	vec2 uv = xz / 3072.0 + 0.5;
	return texture(world_height, uv).r * 340.0 - 40.0;
}
