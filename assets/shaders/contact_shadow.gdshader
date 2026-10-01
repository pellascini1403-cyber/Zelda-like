shader_type spatial;
// Soft contact shadow under characters and creatures (BlobShadow): a cool,
// soft-edged dark disc alpha-blended over the ground. Grounds the body even
// where real shadows are off (LOW quality, far from the camera) or too soft
// to read. Alpha blending (not multiply) so it looks the same in the Mobile
// and Compatibility renderers.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float strength = 0.5;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = vec3(0.07, 0.09, 0.13);
	ALPHA = (1.0 - smoothstep(0.1, 1.0, d)) * strength;
}
