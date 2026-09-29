shader_type spatial;
// Violet supernatural energy (eyes, horn tips, cores, crystal edges).
// Unshaded and self-lit so it reads at any distance and in any light.
render_mode unshaded, cull_back;

uniform vec3 color : source_color = vec3(0.72, 0.49, 1.0);
uniform float strength = 2.2;
instance uniform float flash = 0.0;
instance uniform vec3 flash_color : source_color = vec3(1.0, 1.0, 1.0);

void fragment() {
	float pulse = 0.82 + 0.18 * sin(TIME * 3.1);
	ALBEDO = mix(color * strength * pulse, flash_color * 2.0, flash * 0.5);
}
