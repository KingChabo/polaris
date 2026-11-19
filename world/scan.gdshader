shader_type spatial;
// A scanned model's own textures, with snow settling on everything that faces up.
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_g, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_col : source_color = vec4(1.0);
uniform bool has_albedo = false;
uniform bool has_normal = false;
uniform bool has_rough = false;
uniform float roughness = 0.8;
uniform float metallic = 0.0;
uniform float alpha_cut = 0.0;      // > 0: leaves and needles cut out by alpha
uniform float snow = 0.0;           // how much snow lies on it
uniform float foliage = 0.0;        // 1: thin needles that let light through
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

varying vec3 wnrm;
varying vec3 wpos;

void vertex() {
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 c = albedo_col;
	if (has_albedo) {
		c *= texture(albedo_tex, UV);
	}
	if (alpha_cut > 0.0) {
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	}
	float n = texture(noise_tex, wpos.xz * 0.37).r;
	float up = wnrm.y * (FRONT_FACING ? 1.0 : -1.0);
	float s = smoothstep(0.35, 0.8, up + (n - 0.5) * 0.5) * snow;
	vec3 col = mix(c.rgb, vec3(0.86, 0.9, 0.97), s);
	ALBEDO = col;
	float r = roughness;
	if (has_rough) {
		r *= texture(rough_tex, UV).g;
	}
	ROUGHNESS = mix(r, 0.75, s);
	METALLIC = metallic * (1.0 - s);
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = 1.0 - s * 0.7;
	}
	if (foliage > 0.0) {
		BACKLIGHT = vec3(0.12, 0.16, 0.1) * foliage * (1.0 - s);
	}
	BACKLIGHT += vec3(0.08, 0.12, 0.2) * s;
}
