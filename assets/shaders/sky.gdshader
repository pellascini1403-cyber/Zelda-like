shader_type sky;
// Stylized painterly sky: gradient, sun & moon, drifting clouds, stars.
// All inputs are driven by EnvironmentController (time of day + weather).

uniform vec3 top_color : source_color = vec3(0.24, 0.47, 0.8);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.84, 0.93);
uniform vec3 ground_color : source_color = vec3(0.32, 0.36, 0.4);
uniform vec3 sun_dir = vec3(0.3, 0.6, -0.7);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.75);
uniform vec3 moon_dir = vec3(-0.3, -0.6, 0.7);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shade : source_color = vec3(0.55, 0.6, 0.7);
uniform float cloud_cover = 0.35;
uniform float cloud_darkness = 0.0;
uniform float star_intensity = 0.0;
uniform float night = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(h, 0.55));
	} else {
		col = mix(horizon_color, ground_color, smoothstep(0.0, 0.25, -h));
	}

	// Sun: disc + two halos
	float sd = max(dot(d, normalize(sun_dir)), 0.0);
	float sun_vis = smoothstep(-0.12, 0.05, sun_dir.y);
	col += sun_color * (pow(sd, 8.0) * 0.18 + pow(sd, 90.0) * 0.45) * sun_vis;
	col += sun_color * smoothstep(0.9994, 0.9997, sd) * 6.0 * sun_vis;

	// Moon
	float md = max(dot(d, normalize(moon_dir)), 0.0);
	col += vec3(0.8, 0.85, 1.0) * (smoothstep(0.9990, 0.9994, md) * 1.6 + pow(md, 60.0) * 0.08) * night;

	// Stars (skip in radiance cubemap pass)
	if (!AT_CUBEMAP_PASS && star_intensity > 0.01 && h > 0.0) {
		vec3 cell = floor(d * 220.0);
		float s = hash(cell);
		float twinkle = 0.6 + 0.4 * sin(TIME * 2.0 + s * 40.0);
		col += vec3(step(0.9965, s) * twinkle * star_intensity * smoothstep(0.0, 0.2, h));
	}

	// Clouds on a virtual dome
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.18);
		vec2 drift = vec2(TIME * 0.004, TIME * 0.0015);
		float c = texture(noise_tex, uv * 0.18 + drift).r * 0.65 + texture(noise_tex, uv * 0.47 - drift * 1.6).r * 0.35;
		float cover = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.28, c);
		cover *= smoothstep(0.0, 0.12, h);
		float lit = clamp(dot(normalize(vec3(uv.x, 1.0, uv.y)), normalize(sun_dir)) * 0.5 + 0.5, 0.0, 1.0);
		vec3 cc = mix(cloud_shade, cloud_lit * mix(vec3(1.0), sun_color, 0.4), lit * (1.0 - cloud_darkness));
		cc = mix(cc, cc * vec3(0.18, 0.2, 0.28), night);
		col = mix(col, cc, cover * 0.95);
		// Overcast flattens the sky
		col = mix(col, mix(cloud_shade, horizon_color, 0.3) * mix(1.0, 0.25, night), cloud_darkness * 0.7);
	}
	COLOR = col;
}
