shader_type spatial;
// Development placeholder material: one flat solid color per entity type.
// No textures, no patterns, no painted shading: real scene lighting only.
// The hit / attack-telegraph flash is a material overlay (flash_overlay.gdshader).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 color : source_color = vec3(1.0);

void fragment() {
	ALBEDO = color;
	ROUGHNESS = 0.75;
	SPECULAR = 0.35;
	// Lighting only (no painted detail): a soft rim keeps the silhouette
	// readable against foliage and in backlight.
	RIM = 0.3;
	RIM_TINT = 0.5;
}
