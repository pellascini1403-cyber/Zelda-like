shader_type spatial;
// Corrupted-creature body (enemy family). Near-black, never flat: tonal
// variation, glossy highlights and a violet rim keep the volume and the
// silhouette readable; glowing cracks/veins scale with rank energy.
// Colours come from data/art_style.json (violet tokens are provisional).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 body : source_color = vec3(0.08, 0.07, 0.1);
uniform vec3 body_hi : source_color = vec3(0.17, 0.15, 0.2);
uniform vec3 tint : source_color = vec3(1.0);
uniform float tint_amount = 0.14;
uniform vec3 energy_color : source_color = vec3(0.54, 0.24, 1.0);
uniform float energy = 0.3;
uniform float rim = 0.55;
uniform float roughness = 0.4;

varying vec3 obj;

void vertex() {
	obj = VERTEX;
}

void fragment() {
	// Broad tonal variation (reads as plates/muscle at game distance).
	float n = sin(obj.x * 5.3 + obj.y * 2.9) * sin(obj.z * 4.7 - obj.y * 3.7);
	vec3 base = mix(body, body_hi, 0.5 + 0.5 * n);
	base = mix(base, base * tint * 2.2, tint_amount);
	// Cracks: thin lines of a warped stripe field; pulse slowly.
	float w = obj.y * 3.5 + sin(obj.x * 4.0 + obj.z * 3.0) * 1.4;
	float line = abs(sin(w)) + 0.6 * abs(sin(obj.x * 5.0 - obj.z * 4.0 + obj.y * 2.0));
	float crack = (1.0 - smoothstep(0.0, 0.05, line)) * energy;
	float pulse = 0.7 + 0.3 * sin(TIME * 2.4 + obj.y * 3.0);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = base;
	ROUGHNESS = roughness;
	SPECULAR = 0.6;
	METALLIC = 0.2;
	EMISSION = energy_color * (crack * 3.0 * pulse + fres * fres * rim);
}
