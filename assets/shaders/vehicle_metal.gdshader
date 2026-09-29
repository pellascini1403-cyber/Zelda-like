shader_type spatial;
// Vantrel Works brand metal: worn silver. Modern machines that have been
// running for a long time: tone patches, fine scratches, dull zones, road
// dirt that builds up low on the body, brighter worn edges. Not chrome.
// Vertices are in vehicle space (parts are merged per material), so "low on
// the body" is real height above the wheels' contact patch.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.64, 0.65, 0.66);
uniform float metallic = 0.82;
uniform float roughness = 0.34;
uniform float wear = 0.55;          // 0 = showroom, 1 = decades on the road
uniform float dirt_height = 0.55;   // metres from the ground that collect dust
uniform vec3 dirt_color : source_color = vec3(0.34, 0.3, 0.25);
uniform float scratches = 1.0;
instance uniform float flash = 0.0;
instance uniform vec3 flash_color : source_color = vec3(1.0);

varying vec3 obj;
varying vec3 onrm;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	obj = VERTEX;
	onrm = NORMAL;
}

void fragment() {
	float patches = vnoise(obj * 2.1);
	float fine = vnoise(obj * 9.0);
	vec3 col = base_color * (0.86 + 0.18 * patches);
	// Fine scratches: short streaks along the body's length, only in worn zones.
	float streak = abs(sin(obj.z * 55.0 + fine * 7.0 + obj.x * 9.0));
	float scratch = smoothstep(0.975, 1.0, streak) * step(0.52, vnoise(obj * 3.7 + 11.0)) * scratches * wear;
	// Worn edges: glancing light on the facets reads as rubbed-bright metal.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	// Road dust: dense near the ground, patchy higher up, a little on top faces.
	float low = 1.0 - smoothstep(0.0, dirt_height, obj.y);
	float dust = clamp(low * (0.45 + 0.55 * vnoise(obj * 4.3)) + max(onrm.y, 0.0) * 0.15 * fine, 0.0, 1.0) * wear;
	col = mix(col, dirt_color, dust * 0.6);
	col = mix(col, vec3(0.86, 0.87, 0.88), scratch * 0.55 + rim * 0.08 * wear);
	ALBEDO = col;
	METALLIC = metallic * (1.0 - dust * 0.6);
	ROUGHNESS = clamp(roughness + 0.22 * patches * wear + dust * 0.4 - scratch * 0.12, 0.05, 1.0);
	SPECULAR = 0.5;
	EMISSION = flash_color * flash * 1.2;
}
