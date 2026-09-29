shader_type spatial;
// Development placeholder material: one flat solid color per entity type.
// No textures, no patterns, no painted shading: real scene lighting only.
// `flash` is a per-instance gameplay signal (hit / attack telegraph), not decoration.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 color : source_color = vec3(1.0);
instance uniform float flash = 0.0;
instance uniform vec3 flash_color : source_color = vec3(1.0, 1.0, 1.0);

void fragment() {
	ALBEDO = color;
	ROUGHNESS = 0.75;
	SPECULAR = 0.35;
	EMISSION = flash_color * flash * 1.5;
}
