shader_type spatial;
// Conjured jade: translucent-looking glassy green with a bright rim and
// slow inner veins. Opaque (cheap) with emission faking translucency.
render_mode blend_mix, cull_back, specular_schlick_ggx;


void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float vein = sin(wp.x * 3.1 + wp.z * 2.3 + sin(wp.y * 4.0 + TIME) * 1.5);
	vein = smoothstep(0.85, 1.0, vein);
	ALBEDO = mix(vec3(0.12, 0.45, 0.3), vec3(0.4, 0.85, 0.6), rim);
	ROUGHNESS = 0.15;
	SPECULAR = 0.8;
	EMISSION = vec3(0.2, 0.9, 0.6) * (rim * 1.2 + vein * 0.6 + 0.12);
}
