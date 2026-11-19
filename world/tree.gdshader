shader_type spatial;
render_mode cull_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform bool summer = false;
varying vec3 lp;

void vertex() {
	lp = VERTEX;
	// the crowns sway a little in the wind, more towards the top and the bough tips
	vec3 origin = MODEL_MATRIX[3].xyz;
	float reach = length(VERTEX.xz);
	float up = clamp(VERTEX.y / 12.0, 0.0, 1.5);
	float ph = TIME * 0.9 + origin.x * 0.13 + origin.z * 0.11;
	VERTEX.x += sin(ph) * 0.05 * up * up + sin(ph * 2.3 + VERTEX.y) * 0.012 * reach;
	VERTEX.z += cos(ph * 0.8) * 0.04 * up * up;
	VERTEX.y += sin(ph * 1.7 + reach * 2.0) * 0.012 * reach;
}

void fragment() {
	float n = texture(noise_tex, lp.xz * 0.35 + vec2(lp.y * 0.21)).r;
	float n2 = texture(noise_tex, lp.xz * 1.9 + vec2(lp.y * 0.9)).r;
	float n3 = texture(noise_tex, lp.xz * 6.0 + vec2(lp.y * 3.0)).r;
	// ragged outline: cut twigs and needle gaps out of the edge of each bough
	float twig = texture(noise_tex, lp.xz * 2.6 + vec2(lp.y * 1.7)).r;
	float comb = abs(fract((lp.x + lp.z) * 5.0 + twig * 2.0) - 0.5);
	if (UV.x > 0.42 + twig * 0.5 + comb * 0.5) { discard; }
	// needles: fine dark/light breakup
	vec3 green = COLOR.rgb * (0.5 + 1.2 * n2) * (0.65 + 0.8 * n3);
	bool bark = COLOR.r > COLOR.g * 1.25;
	if (bark) {
		// furrowed bark: long vertical plates
		float fur = texture(noise_tex, vec2(atan(lp.z, lp.x) * 1.6, lp.y * 0.18)).r;
		float fine = texture(noise_tex, vec2(atan(lp.z, lp.x) * 5.0, lp.y * 0.9)).r;
		green = COLOR.rgb * (0.45 + 1.1 * fur) * (0.7 + 0.6 * fine);
	}
	float snow = smoothstep(0.36, 0.6, COLOR.a + (n - 0.5) * 0.7 + (n3 - 0.5) * 0.25);
	if (summer) { snow = 0.0; green *= vec3(0.9, 1.08, 0.85); }
	if (!FRONT_FACING) { snow *= 0.12; green *= 0.6; }
	ALBEDO = mix(green, vec3(0.86, 0.90, 0.97), snow);
	ROUGHNESS = mix(0.95, 0.75, snow);
	BACKLIGHT = mix(vec3(0.02, 0.05, 0.02), vec3(0.10, 0.15, 0.25), snow);
}
