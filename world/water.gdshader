shader_type spatial;
// Open water in the hole in the lake ice: moving ripples, refraction,
// depth colour, sky reflection and slush along the ice edge.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec2 hole_c;
uniform float hole_r;

varying vec3 wpos;

float hole(vec2 p) {
	vec2 q = p - hole_c;
	float ang = atan(q.y, q.x);
	float r = hole_r * (1.0 + 0.16 * sin(ang * 3.0 + 0.5) + 0.09 * sin(ang * 7.0 + 1.3));
	return length(q) - r;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.7 + TIME * 1.1) * 0.025 + sin(wpos.z * 1.0 + TIME * 0.8) * 0.025;
}

void fragment() {
	float e = hole(wpos.xz);
	if (e > 0.3) { discard; }
	vec2 uv1 = wpos.xz * 0.07 + TIME * vec2(0.012, 0.007);
	vec2 uv2 = wpos.xz * 0.19 - TIME * vec2(0.010, 0.017);
	vec2 uv3 = wpos.xz * 0.55 + TIME * vec2(-0.02, 0.013);
	vec3 n1 = texture(normal_tex, uv1).rgb;
	vec3 n2 = texture(normal_tex, uv2).rgb;
	vec3 n3 = texture(normal_tex, uv3).rgb;
	vec3 nm = normalize(n1 + n2 + n3 * 0.6 - vec3(1.3, 1.3, 0.0));
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.8;

	float depth_raw = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	vp.xyz /= vp.w;
	float water_depth = clamp(VERTEX.z - vp.z, 0.0, 60.0);

	vec2 off = nm.xy * 0.035 * clamp(water_depth, 0.0, 1.0);
	vec3 behind = texture(screen_tex, SCREEN_UV + off).rgb;
	float t = 1.0 - exp(-water_depth * 0.5);
	vec3 deepc = vec3(0.004, 0.022, 0.035);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);

	// slush and thin new ice near the edge of the hole
	float sn = texture(noise_tex, wpos.xz * 0.06 + TIME * 0.002).r;
	float slush = smoothstep(-3.5, -0.2, e + (sn - 0.5) * 3.5);
	float flecks = smoothstep(0.66, 0.7, texture(noise_tex, wpos.xz * 0.4 + TIME * vec2(0.004, 0.002)).r) * smoothstep(-14.0, -2.0, e);
	slush = clamp(slush + flecks * 0.8, 0.0, 1.0);

	ALBEDO = mix(deepc * t, vec3(0.80, 0.87, 0.94), slush);
	EMISSION = behind * vec3(0.55, 0.82, 0.88) * (1.0 - t) * (1.0 - fres) * (1.0 - slush);
	ROUGHNESS = mix(0.03, 0.75, slush);
	SPECULAR = 0.65;
}
