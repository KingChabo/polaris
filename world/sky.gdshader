shader_type sky;

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec3 glow_dir = vec3(0.0, 0.0, -1.0);
uniform float aurora_strength = 1.0;
uniform float horror = 0.0;          // 1 = the horror valley: blood-red aurora, a sick moon, no stars to speak of
uniform vec3 moon_dir = vec3(-0.55, 0.2, 0.8);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

vec3 stars(vec3 d) {
	vec2 uv = vec2(atan(d.z, d.x), asin(clamp(d.y, -1.0, 1.0))) * 70.0;
	vec2 id = floor(uv);
	vec2 f = fract(uv) - 0.5;
	float h = hash(id);
	float s = step(0.955, h);
	vec2 off = (vec2(hash(id + 1.3), hash(id + 7.7)) - 0.5) * 0.6;
	float b = smoothstep(0.11, 0.0, length(f - off)) * s;
	float tw = 0.7 + 0.3 * sin(TIME * 2.0 + h * 100.0);
	vec3 tint = mix(vec3(0.75, 0.87, 1.0), vec3(1.0, 0.9, 0.78), hash(id + 3.1));
	return tint * b * tw * (0.4 + 2.2 * hash(id + 9.0));
}

vec3 aurora(vec3 d) {
	vec3 col = vec3(0.0);
	if (d.y < 0.03) {
		return col;
	}
	float jit = hash(d.xz * 913.0 + d.y * 71.0);
	for (int i = 0; i < 28; i++) {
		float fi = (float(i) + jit) / 28.0;
		float ht = 1.0 + fi * 0.9;
		vec2 p = d.xz * (ht / (d.y + 0.12));
		float n = texture(noise_tex, p * 0.035 + vec2(TIME * 0.003, TIME * 0.001)).r;
		float n2 = texture(noise_tex, p * 0.012 - vec2(TIME * 0.002, 0.0)).r;
		float band = exp(-abs(n - 0.5) * 42.0);
		float mask = smoothstep(0.46, 0.66, n2);
		float rays = 0.45 + 0.55 * texture(noise_tex, p * 0.6 + vec2(0.0, TIME * 0.02)).r;
		vec3 c = mix(vec3(0.08, 1.0, 0.42), vec3(0.5, 0.18, 1.0), pow(fi, 0.8));
		c = mix(c, vec3(0.08, 0.8, 0.9), n2 * 0.35);
		c = mix(c, mix(vec3(0.75, 0.03, 0.02), vec3(0.35, 0.0, 0.08), fi), horror);
		col += c * band * mask * rays * (1.0 - fi * 0.75) * smoothstep(0.0, 0.12, fi);
	}
	return col * 0.115 * smoothstep(0.03, 0.25, d.y);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float y = d.y;
	vec3 zen = vec3(0.010, 0.016, 0.055);
	vec3 mid = vec3(0.032, 0.045, 0.13);
	vec3 hor = vec3(0.06, 0.20, 0.26);
	vec3 col = mix(hor, mid, smoothstep(0.0, 0.3, y));
	col = mix(col, zen, smoothstep(0.25, 0.9, y));
	vec3 flat_d = normalize(vec3(d.x, 0.0001, d.z));
	float g = max(dot(flat_d, normalize(glow_dir)), 0.0);
	float gl = pow(g, 3.0) * exp(-max(y, 0.0) * 7.0);
	col += vec3(0.75, 0.30, 0.34) * gl * 0.5;
	col += vec3(0.2, 0.3, 0.45) * exp(-max(y, 0.0) * 14.0) * 0.25;
	if (y < 0.0) {
		col = mix(col, vec3(0.03, 0.05, 0.09), smoothstep(0.0, -0.2, y));
	}
	col = mix(col, col * vec3(0.55, 0.5, 0.5) + vec3(0.012, 0.004, 0.004) * (1.0 - y), horror);
	col += stars(d) * smoothstep(0.02, 0.3, y) * (1.0 - horror * 0.85);
	col += aurora(d) * aurora_strength * (1.0 - horror * 0.45);
	if (horror > 0.0) {
		// a large dim moon low over the ridge, with a pale ring of haze
		float md = dot(d, normalize(moon_dir));
		float disc = smoothstep(0.9994, 0.9997, md);
		float shade = 0.75 + 0.25 * texture(noise_tex, d.xy * 18.0).r;
		col += vec3(0.62, 0.55, 0.48) * disc * shade * horror;
		col += vec3(0.35, 0.18, 0.14) * pow(max(md, 0.0), 900.0) * 0.6 * horror;
		col += vec3(0.12, 0.06, 0.05) * pow(max(md, 0.0), 60.0) * 0.25 * horror;
	}
	COLOR = col;
}
