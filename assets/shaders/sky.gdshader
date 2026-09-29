shader_type sky;
// Painterly sky: gradient with a luminous haze band at the horizon, sun and
// moon halos, two drifting cloud layers with sun-lit rims, stars + a faint
// galactic band at night, and "veil" ribbons in the supernatural zone.
// Driven by EnvironmentController; only the radiance pass skips the costly bits.

uniform vec3 top_color : source_color = vec3(0.24, 0.47, 0.8);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.84, 0.93);
uniform vec3 ground_color : source_color = vec3(0.32, 0.36, 0.4);
uniform vec3 sun_dir = vec3(0.3, 0.6, -0.7);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.75);
uniform vec3 moon_dir = vec3(-0.3, -0.6, 0.7);
uniform float cloud_cover = 0.35;
uniform float cloud_darkness = 0.0;
uniform float star_intensity = 0.0;
uniform float night = 0.0;
uniform float veil = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float clouds(vec2 uv, float cover) {
	float c = texture(noise_tex, uv).r * 0.6 + texture(noise_tex, uv * 2.3 + 0.37).r * 0.3 + texture(noise_tex, uv * 5.1 - 0.21).r * 0.1;
	return smoothstep(1.0 - cover, 1.0 - cover + 0.3, c);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 sdir = normalize(sun_dir);
	float sd = max(dot(d, sdir), 0.0);
	float sun_vis = smoothstep(-0.12, 0.05, sdir.y);

	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(h, 0.38));
		// Luminous haze band hugging the horizon, warmer toward the sun.
		float band = exp(-h * 22.0);
		col = mix(col, mix(horizon_color * 1.05, sun_color, pow(sd, 3.0) * 0.35 * sun_vis), band * 0.4);
	} else {
		col = mix(horizon_color, ground_color, smoothstep(0.0, 0.3, -h));
	}

	// Sun: soft wide glow + halo + disc
	col += sun_color * (pow(sd, 6.0) * 0.22 + pow(sd, 60.0) * 0.5) * sun_vis;
	col += sun_color * smoothstep(0.9994, 0.9997, sd) * 7.0 * sun_vis;

	// Moon with halo
	float md = max(dot(d, normalize(moon_dir)), 0.0);
	col += vec3(0.82, 0.88, 1.0) * (smoothstep(0.9990, 0.9994, md) * 1.8 + pow(md, 40.0) * 0.12 + pow(md, 6.0) * 0.04) * night;

	if (!AT_CUBEMAP_PASS && h > 0.0) {
		// Stars + faint galactic band
		if (star_intensity > 0.01) {
			vec3 cell = floor(d * 240.0);
			float s = hash(cell);
			float twinkle = 0.6 + 0.4 * sin(TIME * 2.0 + s * 40.0);
			float band = exp(-pow(dot(d, normalize(vec3(0.6, 0.35, 0.72))) * 3.2, 2.0));
			float dense = step(0.9965 - band * 0.004, s);
			col += vec3(dense * twinkle * star_intensity * smoothstep(0.0, 0.2, h));
			col += vec3(0.25, 0.28, 0.4) * band * texture(noise_tex, d.xz * 1.5).r * 0.18 * star_intensity;
		}
		// Veil ribbons (supernatural zone)
		if (veil > 0.01) {
			float w = sin(d.x * 7.0 + TIME * 0.15 + texture(noise_tex, d.xz * 0.6 + TIME * 0.004).r * 5.0);
			float rib = smoothstep(0.75, 1.0, w) * smoothstep(0.05, 0.3, h) * (1.0 - smoothstep(0.5, 0.9, h));
			col += mix(vec3(0.35, 0.95, 0.85), vec3(0.75, 0.45, 1.0), d.z * 0.5 + 0.5) * rib * veil * 0.14;
		}
	}

	// Two cloud layers on a virtual dome; high thin layer + main puffy layer.
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.16);
		vec2 drift = vec2(TIME * 0.0035, TIME * 0.0012);
		float c_main = clouds(uv * 0.16 + drift, cloud_cover);
		float c_high = clouds(uv * 0.06 - drift * 0.5 + 0.5, cloud_cover * 0.6) * 0.45;
		float fade = smoothstep(0.0, 0.14, h);
		// Rim light: clouds glow where they face the sun.
		float toward = pow(sd, 4.0) * sun_vis;
		vec3 lit = mix(vec3(1.0), sun_color, 0.35) * (1.0 + toward * 0.9);
		vec3 shade = mix(horizon_color * 0.75, vec3(0.55, 0.6, 0.72), 0.5);
		vec3 cc = mix(shade, lit, clamp(0.55 + toward * 0.5 - cloud_darkness * 0.6, 0.0, 1.0));
		cc = mix(cc, cc * vec3(0.16, 0.19, 0.3), night);
		col = mix(col, cc, c_high * fade);
		col = mix(col, cc, c_main * fade * 0.95);
		col = mix(col, mix(shade, horizon_color, 0.3) * mix(1.0, 0.25, night), cloud_darkness * 0.7);
	}
	COLOR = col;
}
