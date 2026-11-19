shader_type spatial;
render_mode cull_disabled;
// Summer grass tufts and meadow flowers. Vertex colour: a = height along the blade (0 root, 1 tip),
// r = 1 on petals. INSTANCE_CUSTOM: rgb = petal colour (flowers) or tint, a = random.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform bool flower = false;
uniform float fade_from = 26.0;
uniform float fade_to = 38.0;
varying float tip;
varying float petal;
varying vec3 inst;
varying vec3 wpos;

void vertex() {
	tip = COLOR.a;
	petal = COLOR.r;
	inst = INSTANCE_CUSTOM.rgb;
	vec3 origin = MODEL_MATRIX[3].xyz;
	// far tufts sink into the ground instead of popping
	float d = length(origin - CAMERA_POSITION_WORLD);
	float keep = 1.0 - smoothstep(fade_from, fade_to, d);
	VERTEX.y *= keep;
	// wind: gusts roll across the meadow
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = texture(noise_tex, w.xz * 0.012 + vec2(TIME * 0.05, TIME * 0.03)).r;
	float ph = TIME * 2.1 + w.x * 0.35 + w.z * 0.27 + INSTANCE_CUSTOM.a * 6.0;
	float bend = tip * tip * (0.06 + 0.22 * gust);
	vec3 sway = vec3(sin(ph) * 0.5 + 0.7, 0.0, cos(ph * 0.8) * 0.4 + 0.3) * bend;
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * sway);
	// soft, meadow-like light: normals lean up so both blade faces are lit alike
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.65));
	wpos = w;
}

void fragment() {
	float n = texture(noise_tex, wpos.xz * 0.05).r;
	vec3 root = vec3(0.10, 0.13, 0.04);
	vec3 top = mix(vec3(0.26, 0.46, 0.07), vec3(0.45, 0.50, 0.14), smoothstep(0.55, 0.8, n));
	vec3 col = mix(root, top, smoothstep(0.0, 0.9, tip));
	if (!flower) {
		col *= inst;
	} else if (petal > 0.5) {
		col = inst;
	} else if (petal > 0.15) {
		col = vec3(0.85, 0.62, 0.08);
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.04;
	BACKLIGHT = flower && petal > 0.5 ? inst * 0.4 : vec3(0.10, 0.16, 0.02) * tip;
	AO = mix(0.45, 1.0, tip);
	AO_LIGHT_AFFECT = 0.6;
}
