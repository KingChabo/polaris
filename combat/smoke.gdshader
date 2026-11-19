shader_type spatial;
// Grenade smoke: soft lumpy billboards that fade where they meet the ground.
// (A StandardMaterial would draw the particles that are not born yet as a black ball.)
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.38, 0.4, 0.44, 0.6);
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

varying float seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	// the same particle billboard BaseMaterial3D builds, turned by the particle's angle
	mat4 w = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float a = INSTANCE_CUSTOM.x;
	w = w * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * w;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	seed = float(INSTANCE_ID) * 7.31;
	// a particle that has not been born yet comes through as plain black: draw nothing
	if (COLOR.r + COLOR.g + COLOR.b < 0.01) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	// lumpy edge: the radius wobbles with two octaves of noise, different for every puff
	vec2 q = d * 2.2 + vec2(seed, seed * 0.37);
	float n = vnoise(q) * 0.65 + vnoise(q * 2.3 + 4.1) * 0.35;
	float r = length(d) * (0.78 + n * 0.45);
	float puff = smoothstep(1.0, 0.15, r);
	puff *= 0.7 + 0.3 * vnoise(d * 5.0 + vec2(seed * 1.7, 2.0));
	// a little darker in the middle of a puff, lighter at the edge, like light through smoke
	ALBEDO = tint.rgb * COLOR.rgb * mix(0.86, 1.08, smoothstep(0.0, 0.9, r));
	// fade where the puff meets the ground or a wall instead of a hard line
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	float soft = clamp((VERTEX.z - behind.z) / 0.9, 0.0, 1.0);
	ALPHA = tint.a * COLOR.a * puff * soft;
}
