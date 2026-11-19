shader_type spatial;
// One procedural material for all buildings and props: wood, plaster, stone,
// shingles, metal, cloth. Snow and frost settle on it by themselves.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform int kind = 0;
uniform vec3 tint : source_color = vec3(0.5);
uniform vec3 tint2 : source_color = vec3(0.5);
uniform float snow_amount = 1.0;
// a scanned PBR surface (Poly Haven, CC0), recoloured to this material's tint
uniform sampler2D pbr_alb : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D pbr_nrm : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D pbr_rgh : hint_roughness_r, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float pbr_amt = 0.0;
uniform float pbr_scale = 0.5;      // texture repeats per metre
uniform vec3 pbr_mean = vec3(0.5);  // average colour of the scan
uniform float pbr_keep = 0.0;       // 1: keep the scan's own colour
uniform bool pbr_rot = false;       // turn the scan 90° (boards that run up and down)

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 wnrm;

float hash(float p) { return fract(sin(p * 127.1) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(lnrm);
	vec2 uv;
	if (an.y > 0.7) { uv = lpos.xz; }
	else if (an.x > an.z) { uv = lpos.zy; }
	else { uv = lpos.xy; }
	float n = texture(noise_tex, uv * 0.21).r;
	float fine = texture(noise_tex, uv * 1.3).r;
	vec3 col = tint;
	float rough = 0.85;
	float metal = 0.0;
	float bump = 1.0;
	float sss = 0.0;
	if (kind == 0 || kind == 7) {
		vec2 p = kind == 0 ? uv : uv.yx;
		float width = kind == 0 ? 0.19 : 0.14;
		float row = floor(p.y / width);
		float f = fract(p.y / width);
		float seam = smoothstep(0.0, 0.07, f) * smoothstep(1.0, 0.93, f);
		float grain = texture(noise_tex, vec2(p.x * 0.16 + row * 0.37, p.y * 0.5 + row * 0.13)).r;
		float fibre = texture(noise_tex, vec2(p.x * 0.7 + row * 0.21, p.y * 9.0)).r;
		float knots = smoothstep(0.72, 0.78, texture(noise_tex, vec2(p.x * 0.5 + row * 0.61, p.y * 1.5)).r);
		col = tint * (0.8 + 0.4 * grain) * (0.85 + 0.3 * fibre) * mix(0.82, 1.15, hash(row));
		col *= mix(1.0, 0.55, knots);
		// logs are round: darker towards the joints
		bump = kind == 0 ? mix(0.35, 1.0, sin(f * 3.1416)) : mix(0.4, 1.0, seam);
		// weathering: grey, bleached streaks
		float weather = smoothstep(0.45, 0.8, n);
		col = mix(col, vec3(dot(col, vec3(0.33))) * 1.15, weather * 0.3);
	} else if (kind == 1) {
		col = tint * (0.82 + 0.3 * n);
		float stain = texture(noise_tex, vec2(uv.x * 0.9, uv.y * 0.07)).r;
		col *= mix(1.0, 0.62, smoothstep(0.5, 0.8, stain));
		float crack = exp(-abs(texture(noise_tex, uv * 0.35 + 0.3).r - 0.5) * 160.0);
		col *= 1.0 - crack * 0.45;
		rough = 0.92;
	} else if (kind == 2 || kind == 3) {
		vec2 sz = kind == 2 ? vec2(0.55, 0.3) : vec2(0.26, 0.2);
		float row = floor(uv.y / sz.y);
		float x = uv.x / sz.x + 0.5 * mod(row, 2.0) + hash(row) * 0.3;
		vec2 f = vec2(fract(x), fract(uv.y / sz.y));
		float cell = hash2(vec2(floor(x), row));
		float edge = smoothstep(0.0, 0.08, f.x) * smoothstep(1.0, 0.92, f.x) * smoothstep(0.0, 0.12, f.y) * smoothstep(1.0, 0.88, f.y);
		col = tint * (0.6 + 0.7 * cell) * (0.8 + 0.4 * fine);
		bump = mix(0.35, 1.0, edge);
		if (kind == 3) { bump *= mix(0.75, 1.0, f.y); }
		rough = 0.9;
	} else if (kind == 4) {
		float rust = smoothstep(0.52, 0.68, n + fine * 0.2);
		col = mix(tint * (0.8 + 0.4 * fine), vec3(0.26, 0.11, 0.05) * (0.6 + 0.8 * fine), rust);
		metal = mix(0.9, 0.2, rust);
		rough = mix(0.4, 0.9, rust);
	} else if (kind == 5) {
		col = tint * (0.93 + 0.1 * n);
		rough = 0.75;
	} else if (kind == 6) {
		float s = step(0.5, fract(uv.x / 0.5));
		col = mix(tint, tint2, s) * (0.75 + 0.4 * n);
	} else if (kind == 9 || kind == 10) {
		// painted cladding: 9 upright boards with cover strips, 10 lapped boards lying flat
		vec2 p = kind == 9 ? uv.yx : uv;
		float width = kind == 9 ? 0.16 : 0.15;
		float row = floor(p.y / width);
		float f = fract(p.y / width);
		float fibre = texture(noise_tex, vec2(p.x * 0.6 + row * 0.21, p.y * 7.0)).r;
		col = tint * (0.9 + 0.16 * fibre) * mix(0.93, 1.05, hash(row));
		if (kind == 9) {
			// a cover strip stands proud over every joint
			float strip = smoothstep(0.34, 0.37, abs(f - 0.5));
			bump = mix(0.86, 1.0, strip) * mix(0.55, 1.0, smoothstep(0.0, 0.035, abs(abs(f - 0.5) - 0.355)));
		} else {
			// each board shades the top of the one below
			bump = mix(0.5, 1.0, smoothstep(0.0, 0.16, 1.0 - f)) * mix(1.0, 1.08, f);
		}
		// paint flakes and goes grey low down and where the weather hits
		float flake = smoothstep(0.6, 0.72, texture(noise_tex, vec2(p.x * 0.9 + row * 0.5, p.y * 3.0)).r) * smoothstep(0.55, 0.75, n);
		float low = smoothstep(1.1, 0.0, lpos.y) * 0.25;
		col = mix(col, vec3(0.34, 0.31, 0.28) * (0.8 + 0.4 * fibre), clamp(flake * 0.55 + low * fine, 0.0, 1.0));
		float run = texture(noise_tex, vec2(uv.x * 1.3, uv.y * 0.05)).r;
		col *= mix(1.0, 0.8, smoothstep(0.55, 0.85, run));
		rough = 0.78;
	} else if (kind == 11 || kind == 13) {
		// sheet metal: 11 standing seams, 13 corrugated
		float pitch = kind == 11 ? 0.52 : 0.09;
		float f = fract(uv.x / pitch);
		if (kind == 11) {
			bump = mix(0.55, 1.0, smoothstep(0.0, 0.035, abs(f - 0.5))) * mix(1.12, 1.0, smoothstep(0.035, 0.07, abs(f - 0.5)));
		} else {
			bump = 0.72 + 0.28 * sin(f * 6.2832);
		}
		float rust = smoothstep(0.62, 0.78, n + fine * 0.25);
		col = mix(tint * (0.85 + 0.25 * fine), vec3(0.26, 0.12, 0.06) * (0.6 + 0.8 * fine), rust * 0.6);
		metal = mix(0.75, 0.2, rust);
		rough = mix(0.45, 0.9, rust);
	} else if (kind == 12) {
		// brick with mortar joints
		vec2 sz = vec2(0.24, 0.075);
		float row = floor(uv.y / sz.y);
		float x = uv.x / sz.x + 0.5 * mod(row, 2.0);
		vec2 f = vec2(fract(x), fract(uv.y / sz.y));
		float cell = hash2(vec2(floor(x), row));
		float joint = smoothstep(0.0, 0.05, f.x) * smoothstep(1.0, 0.95, f.x) * smoothstep(0.0, 0.14, f.y) * smoothstep(1.0, 0.86, f.y);
		col = mix(vec3(0.5, 0.48, 0.45), tint * (0.7 + 0.55 * cell) * (0.85 + 0.3 * fine), joint);
		bump = mix(0.75, 1.0, joint);
		rough = 0.93;
	} else if (kind == 14) {
		// skin: a little blotchy, redder where it is thin, soft with a faint sheen
		float blot = texture(noise_tex, uv * 3.1).r;
		float pores = texture(noise_tex, uv * 19.0).r;
		col = tint * (0.9 + 0.14 * blot) * (0.94 + 0.1 * pores);
		col = mix(col, col * vec3(1.08, 0.88, 0.86), smoothstep(0.5, 0.8, n) * 0.16);
		bump = 0.93 + 0.07 * pores;
		rough = 0.66 + 0.1 * pores;
		sss = 0.3;
	} else if (kind == 15) {
		// fur: strands that run down, darker at the roots
		float strands = texture(noise_tex, vec2(uv.x * 9.0, uv.y * 1.6)).r;
		float tips = texture(noise_tex, vec2(uv.x * 23.0 + 0.3, uv.y * 3.0)).r;
		col = tint * (0.55 + 0.6 * strands) * (0.85 + 0.3 * tips);
		bump = 0.7 + 0.3 * strands;
		rough = 0.95;
	} else if (kind == 16) {
		// a padded winter coat: stitched baffles that puff out between the seams
		float bf = fract(uv.y / 0.09);
		float puff = sin(bf * 3.1416);
		col = tint * (0.74 + 0.26 * puff) * (0.9 + 0.2 * fine);
		bump = mix(0.5, 1.0, sqrt(max(puff, 0.0)));
		rough = 0.78;
	} else if (kind == 17) {
		// clean machined metal (guns, tools, tins): fine brushing, worn bright along scuffs
		float g = texture(noise_tex, uv * 7.0).r;
		float brush = texture(noise_tex, vec2(uv.x * 55.0, uv.y * 3.0)).r;
		float scuff = smoothstep(0.7, 0.86, texture(noise_tex, uv * 2.3 + 0.31).r) * 0.5 + smoothstep(0.78, 0.9, g) * 0.35;
		col = tint * (0.82 + 0.3 * g) * (0.92 + 0.16 * brush);
		col = mix(col, tint * 1.9 + 0.09, scuff * 0.55);
		metal = 0.88;
		rough = clamp(0.3 + 0.22 * brush + scuff * 0.15, 0.0, 1.0);
	} else if (kind == 18) {
		// moulded polymer: matt, stippled
		float st = texture(noise_tex, uv * 38.0).r;
		col = tint * (0.86 + 0.25 * st);
		rough = 0.5 + 0.2 * st;
	} else if (kind == 19) {
		// oiled gun-stock wood: long fine grain with darker streaks
		float gr = texture(noise_tex, vec2(uv.x * 2.2 + uv.y * 0.6, uv.y * 34.0)).r;
		float streak = texture(noise_tex, vec2(uv.x * 0.9, uv.y * 9.0) + 0.5).r;
		col = tint * (0.62 + 0.55 * gr) * mix(0.72, 1.12, streak);
		rough = 0.38 + 0.2 * gr;
	} else {
		col = tint * (0.8 + 0.35 * fine);
		rough = 0.6;
	}
	vec2 puv = (pbr_rot ? uv.yx : uv) * pbr_scale;
	vec3 pn = vec3(0.0, 0.0, 1.0);
	if (pbr_amt > 0.0) {
		vec3 pc = texture(pbr_alb, puv).rgb;
		vec3 recol = pc / max(pbr_mean, vec3(0.02)) * tint;
		col = mix(col * bump, mix(recol, pc, pbr_keep), pbr_amt);
		rough = mix(rough, texture(pbr_rgh, puv).r, pbr_amt);
		pn = texture(pbr_nrm, puv).rgb * 2.0 - 1.0;
		bump = 1.0;
	} else {
		col *= bump;
	}
	// snow settles on anything that faces up; frost creeps over the rest
	float snow = smoothstep(0.5, 0.78, wnrm.y + (n - 0.5) * 0.35) * snow_amount;
	if (kind == 5) { snow = 1.0; }
	float frost = smoothstep(0.62, 0.9, fine * 0.5 + n * 0.7) * 0.14 * snow_amount * (1.0 - snow);
	// driven snow sticks to the foot of every wall
	if (kind == 1 || kind == 9 || kind == 10 || kind == 12) {
		frost += smoothstep(0.75, 0.05, lpos.y + (n - 0.5) * 0.9) * 0.7 * snow_amount * (1.0 - snow) * step(0.0, lpos.y + 1.0) * step(lpos.y, 3.0);
	}
	vec3 snowc = vec3(0.86, 0.90, 0.97);
	col = mix(col, snowc, clamp(snow + frost, 0.0, 1.0));
	ALBEDO = col;
	// real relief: the seams, joints and ribs that shade the colour also bend the light
	// (bump mapping from screen-space derivatives, faded out with distance)
	float relief = (bump * 0.016 + fine * 0.003 + n * 0.004) * (1.0 - clamp(snow, 0.0, 1.0) * 0.85);
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(relief) * r1 + dFdy(relief) * r2);
	vec3 bent = normalize(abs(det) * NORMAL - grad);
	NORMAL = normalize(mix(NORMAL, bent, smoothstep(40.0, 5.0, -VERTEX.z)));
	if (pbr_amt > 0.0) {
		// tangent frame from screen-space derivatives: works on meshes without tangents
		vec3 dp1 = dFdx(VERTEX);
		vec3 dp2 = dFdy(VERTEX);
		vec2 du1 = dFdx(puv);
		vec2 du2 = dFdy(puv);
		vec3 dp2p = cross(dp2, NORMAL);
		vec3 dp1p = cross(NORMAL, dp1);
		vec3 T = dp2p * du1.x + dp1p * du2.x;
		vec3 B = dp2p * du1.y + dp1p * du2.y;
		float inv = inversesqrt(max(max(dot(T, T), dot(B, B)), 1e-12));
		mat3 tbn = mat3(T * inv, B * inv, NORMAL);
		float k = pbr_amt * (1.0 - clamp(snow, 0.0, 1.0) * 0.8) * smoothstep(80.0, 6.0, -VERTEX.z);
		NORMAL = normalize(mix(NORMAL, normalize(tbn * vec3(pn.xy * 1.2, pn.z)), k));
	}
	ROUGHNESS = mix(rough, 0.75, snow);
	METALLIC = metal * (1.0 - snow);
	BACKLIGHT = vec3(0.08, 0.12, 0.2) * snow + vec3(0.35, 0.12, 0.08) * sss;
	if (sss > 0.0) {
		SSS_STRENGTH = sss;
	}
}
