shader_type spatial;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D road_tex : filter_linear, repeat_disable;
// scanned PBR surfaces (Poly Haven, CC0) prepared in Blender
uniform sampler2D snow_alb : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D snow_nrm : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_alb : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_nrm : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_rgh : hint_roughness_r, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D road_alb : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D road_nrm : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool pbr = false;
// summer: meadows, forest floor and alpine turf below, snow only on the high mountains
uniform bool summer = false;
uniform sampler2D grass_alb : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_nrm : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ground_alb : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D alpine_alb : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D asphalt_alb : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D asphalt_nrm : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float snow_line = 185.0;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = NORMAL;
}

// a macro, not a function: Godot wants one sampler setting per sampler argument
#define tri(t, p, w) (texture(t, (p).zy).rgb * (w).x + texture(t, (p).xz).rgb * (w).y + texture(t, (p).xy).rgb * (w).z)

void fragment() {
	vec3 an = abs(normalize(wnrm));
	vec3 w = pow(an, vec3(4.0));
	w /= (w.x + w.y + w.z);
	// rock detail is projected from three sides, so steep faces do not smear
	float big = tri(noise_tex, wpos * 0.012, w).r;
	float mid = tri(noise_tex, wpos * 0.07, w).r;
	float fine = tri(noise_tex, wpos * 0.45, w).r;
	float slope = 1.0 - wnrm.y;
	// small ledges hold snow, small steps break it: the snow line is ragged
	float ledge = (mid - 0.5) * 0.2 + (fine - 0.5) * 0.08 + (big - 0.5) * 0.14;
	float rock = smoothstep(0.33, 0.5, slope + ledge);
	// high up the wind scours the faces bare, lower down more snow clings
	float alt = smoothstep(120.0, 330.0, wpos.y);
	rock = clamp(rock + alt * 0.12 * smoothstep(0.15, 0.3, slope), 0.0, 1.0);
	float drift = texture(noise_tex, wpos.xz * 0.004).r;
	// summer: where snow still lies (high, and not too steep)
	float snowy = 1.0;
	float cap = 1.0;
	if (summer) {
		float sl = snow_line + (big - 0.5) * 70.0 + (mid - 0.5) * 24.0;
		cap = smoothstep(sl - 10.0, sl + 30.0, wpos.y);
		snowy = smoothstep(sl, sl + 16.0, wpos.y) * (1.0 - smoothstep(0.55, 0.85, slope + ledge));
		rock = clamp(rock + smoothstep(0.18, 0.34, slope + ledge * 0.8) * 0.5 * (1.0 - snowy), 0.0, 1.0);
	}
	vec3 snow = mix(vec3(0.80, 0.86, 0.96), vec3(0.93, 0.95, 0.99), drift);
	// grey gneiss with warmer and cooler patches
	vec3 rockc = mix(vec3(0.2, 0.2, 0.23), vec3(0.5, 0.49, 0.5), mid);
	rockc = mix(rockc, vec3(0.30, 0.24, 0.19), smoothstep(0.55, 0.8, big) * 0.6);
	rockc = mix(rockc, vec3(0.20, 0.23, 0.27), smoothstep(0.5, 0.2, big) * 0.5);
	// tilted layers
	float strata = sin((wpos.y + wpos.x * 0.25) * 0.55 + big * 9.0);
	rockc *= 0.82 + 0.2 * strata + 0.1 * sin(wpos.y * 2.3 + mid * 6.0);
	// cracks and joints
	float crack = smoothstep(0.47, 0.5, abs(fine - 0.5) + 0.42) * smoothstep(0.35, 0.6, mid);
	float joint = smoothstep(0.035, 0.0, abs(fract(big * 6.0 + mid) - 0.5));
	rockc *= 1.0 - 0.55 * max(crack * 0.5, joint);
	// lichen and frost
	rockc = mix(rockc, vec3(0.55, 0.6, 0.66), smoothstep(0.62, 0.8, fine) * 0.35);
	// snow packed into the cracks and lying on every little step
	float streak = smoothstep(0.52, 0.66, texture(noise_tex, wpos.xz * 0.05 + vec2(wpos.y * 0.2, 0.0)).r) * (1.0 - smoothstep(0.6, 0.9, slope));
	rockc = mix(rockc, snow, max(streak * 0.85, joint * 0.5) * cap);
	// blue glacier ice where the high snow is steep
	vec3 ice = vec3(0.45, 0.68, 0.82);
	snow = mix(snow, ice, smoothstep(0.2, 0.3, slope) * smoothstep(200.0, 300.0, wpos.y) * (1.0 - rock) * 0.6 * snowy);
	vec3 pbr_nm = vec3(0.5, 0.5, 1.0);
	if (pbr) {
		// two scales of the scanned snow, blended so the tiling never lines up
		vec3 s1 = texture(snow_alb, wpos.xz * 0.31).rgb;
		vec3 s2 = texture(snow_alb, wpos.xz * 0.047 + vec2(0.37, 0.11)).rgb;
		vec3 stex = mix(s1, s2, 0.45 + (big - 0.5) * 0.6);
		snow = snow * (stex / vec3(0.78, 0.8, 0.84)) * 0.96;
		// scanned rock, projected from three sides, at two scales
		vec3 r1 = tri(rock_alb, wpos * 0.21, w);
		vec3 r2 = tri(rock_alb, wpos * 0.037 + vec3(0.3), w);
		vec3 rtex = mix(r1, r2, 0.4);
		rockc = mix(rockc, rtex * vec3(0.92, 0.94, 1.0) * (0.85 + 0.3 * mid), 0.8);
		rockc = mix(rockc, snow, max(streak * 0.85, joint * 0.5) * 0.6 * cap);
		vec3 sn = mix(texture(snow_nrm, wpos.xz * 0.31).rgb, texture(snow_nrm, wpos.xz * 0.047 + vec2(0.37, 0.11)).rgb, 0.4);
		vec3 rn = tri(rock_nrm, wpos * 0.21, w);
		pbr_nm = mix(sn, rn, rock);
	}
	if (summer) {
		// two scales of scanned meadow, made lusher, with patches of forest floor and,
		// higher up, thin alpine turf over stones
		vec3 g1 = texture(grass_alb, wpos.xz * 0.27).rgb;
		vec3 g2 = texture(grass_alb, wpos.xz * 0.041 + vec2(0.31, 0.17)).rgb;
		vec3 grass = mix(g1, g2, 0.45 + (big - 0.5) * 0.6);
		float lum = dot(grass, vec3(0.33));
		grass = mix(vec3(lum), grass, 1.4) * vec3(0.6, 0.98, 0.42) * 1.12;
		grass *= 0.86 + 0.28 * mid;
		vec3 fg = texture(ground_alb, wpos.xz * 0.19).rgb;
		grass = mix(grass, fg * vec3(0.95, 1.0, 0.85), smoothstep(0.52, 0.72, drift + (fine - 0.5) * 0.2) * 0.55);
		vec3 alp = texture(alpine_alb, wpos.xz * 0.07).rgb * vec3(0.95, 1.0, 0.85);
		float high = smoothstep(140.0, 225.0, wpos.y + (big - 0.5) * 60.0);
		grass = mix(grass, alp, high * 0.75);
		// streaks of old snow lie in the gullies near the snow line
		snow = mix(grass, snow, max(snowy, streak * snowy));
		rockc = mix(rockc, snow, max(streak * 0.85, joint * 0.5) * cap * 0.6);
		vec3 gn = texture(grass_nrm, wpos.xz * 0.27).rgb;
		pbr_nm = mix(mix(gn, pbr_nm, snowy), pbr_nm, rock);
	}
	ALBEDO = mix(snow, rockc, rock);
	ROUGHNESS = mix(0.72, 0.9, rock);
	if (summer) {
		ROUGHNESS = mix(mix(0.92, 0.72, snowy), 0.9, rock);
	}
	if (pbr) {
		ROUGHNESS = mix(0.7, mix(0.75, 1.0, tri(rock_rgh, wpos * 0.21, w).r), rock);
	}
	// roads: snow driven hard and grey, with the tarmac showing through in patches
	float road = texture(road_tex, vec2(wpos.x / 2048.0 + 0.5, (wpos.z + 1024.0) / 3072.0)).r;
	road = smoothstep(0.3, 0.6, road + (fine - 0.5) * 0.35);
	vec3 packed = mix(vec3(0.36, 0.40, 0.48), vec3(0.52, 0.56, 0.64), mid);
	float worn = texture(noise_tex, wpos.xz * 0.37 + vec2(0.31, 0.77)).r;
	float tar = smoothstep(0.5, 0.78, mid * 0.35 + big * 0.3 + worn * 0.5) * smoothstep(0.7, 0.95, road);
	packed *= 0.9 + 0.2 * worn;
	packed = mix(packed, vec3(0.11, 0.115, 0.13) * (0.8 + 0.5 * fine), tar * 0.6);
	if (summer) {
		vec3 at = texture(asphalt_alb, wpos.xz * 0.2).rgb;
		packed = at * (0.92 + 0.16 * worn);
		pbr_nm = mix(pbr_nm, texture(asphalt_nrm, wpos.xz * 0.2).rgb, road);
	} else if (pbr) {
		vec3 at = texture(road_alb, wpos.xz * 0.22).rgb;
		packed = mix(packed, at * 1.05, 0.75);
		pbr_nm = mix(pbr_nm, texture(road_nrm, wpos.xz * 0.22).rgb, road);
	}
	ALBEDO = mix(ALBEDO, packed, road * 0.94);
	ROUGHNESS = mix(ROUGHNESS, summer ? 0.9 : mix(0.5, 0.85, tar), road);
	SPECULAR = mix(0.35, 0.25, rock);
	if (summer) { SPECULAR = mix(mix(0.06, 0.35, snowy), 0.2, rock); }
	vec3 nm1 = texture(normal_tex, wpos.xz * mix(0.12, 0.3, rock)).rgb;
	vec3 nm2 = texture(normal_tex, wpos.xz * mix(0.9, 1.6, rock) + vec2(0.4)).rgb;
	vec3 nm3 = tri(normal_tex, wpos * 0.06, w);
	float near = smoothstep(60.0, 5.0, length(VERTEX));
	vec3 nm = mix(nm1, mix(nm1, nm2, 0.5), near);
	NORMAL_MAP = mix(nm, normalize(nm + nm3 - vec3(0.5, 0.5, 1.0)) , rock * 0.6);
	NORMAL_MAP_DEPTH = mix(0.55, 2.2, rock);
	if (pbr) {
		vec3 near_nm = mix(pbr_nm, NORMAL_MAP, 0.35);
		NORMAL_MAP = mix(NORMAL_MAP, near_nm, smoothstep(140.0, 20.0, length(VERTEX)));
		NORMAL_MAP_DEPTH = mix(1.0, 1.6, rock);
	}
	// ice crystal glitter, only close to the camera
	float dist = length(VERTEX);
	vec3 vw = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	float h = hash(floor(wpos.xz * 70.0) + floor(vw.xz * 14.0));
	float sparkle = step(0.994, h) * (1.0 - rock) * smoothstep(40.0, 4.0, dist) * snowy;
	EMISSION = vec3(0.7, 0.85, 1.0) * sparkle * 0.9;
	BACKLIGHT = vec3(0.10, 0.16, 0.26) * (1.0 - rock) * snowy;
}
