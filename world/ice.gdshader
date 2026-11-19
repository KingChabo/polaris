shader_type spatial;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap;
uniform vec2 hole_c;
uniform float hole_r;
uniform float hole_sign = 1.0;   // -1: an ice floe in open water (summer)
varying vec3 wpos;

float hole(vec2 p) {
	vec2 q = p - hole_c;
	float ang = atan(q.y, q.x);
	float r = hole_r * (1.0 + 0.16 * sin(ang * 3.0 + 0.5) + 0.09 * sin(ang * 7.0 + 1.3));
	return (length(q) - r) * hole_sign;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz;
	float e = hole(uv);
	if (e < 0.0) { discard; }
	vec3 deep = vec3(0.004, 0.035, 0.06);
	vec3 shallow = vec3(0.05, 0.20, 0.25);
	float n = texture(noise_tex, uv * 0.004).r;
	vec3 col = mix(deep, shallow, smoothstep(0.3, 0.75, n));
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float cr = 0.0;
	// cracks drawn at three depths inside the ice (parallax)
	for (int i = 0; i < 3; i++) {
		float dpt = float(i) * 0.4;
		vec2 o = uv - v.xz / max(v.y, 0.2) * dpt;
		float c1 = texture(noise_tex, o * 0.03).r;
		float c2 = texture(noise_tex, o * 0.071 + vec2(0.37, 0.11)).r;
		float line = exp(-abs(c1 - 0.5) * 240.0) + exp(-abs(c2 - 0.5) * 280.0) * 0.6;
		cr += line * (1.0 - float(i) * 0.3);
	}
	col += vec3(0.5, 0.78, 0.9) * cr * 0.3;
	// frozen air bubbles
	float bub = smoothstep(0.78, 0.8, texture(noise_tex, uv * 0.9).r);
	col += vec3(0.3, 0.4, 0.45) * bub * 0.25;
	// wind-blown snow patches on top
	float sn = smoothstep(0.52, 0.66, texture(noise_tex, uv * 0.011 + vec2(0.5)).r);
	// milky white ice with frozen bubbles in patches, and a pale broken rim at the open water
	float milky = smoothstep(0.5, 0.75, texture(noise_tex, uv * 0.02 + vec2(0.2, 0.7)).r);
	col = mix(col, vec3(0.42, 0.55, 0.62), milky * 0.55);
	// thin ice is dark and clear: you see the water through it (same formula as Lake.thickness)
	float thin = smoothstep(0.6, 0.9, sin(uv.x * 0.031 + 1.3) * sin(uv.y * 0.027 + 0.4));
	thin = max(thin, smoothstep(30.0, 6.0, e) * 0.7);
	col = mix(col, vec3(0.004, 0.022, 0.04) + vec3(0.5, 0.78, 0.9) * cr * 0.12, thin * 0.8);
	sn *= 1.0 - thin;
	float rim = smoothstep(4.0, 0.0, e);
	col = mix(col, vec3(0.72, 0.84, 0.90), rim * 0.8);
	sn = max(sn, smoothstep(0.75, 0.3, e) * 0.0);
	ALBEDO = mix(col, vec3(0.86, 0.9, 0.97), sn);
	// wind-polished ice is glossy; scratches and frost make it rougher in places
	float scratch = texture(noise_tex, vec2(uv.x * 0.9, uv.y * 0.05)).r;
	ROUGHNESS = mix(mix(0.04, 0.22, scratch * milky + rim * 0.5), 0.8, sn);
	NORMAL_MAP = texture(normal_tex, uv * 0.05).rgb;
	NORMAL_MAP_DEPTH = mix(0.12, 0.6, sn);
	SPECULAR = 0.7;
}
