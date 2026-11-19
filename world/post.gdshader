shader_type canvas_item;
// The camera's own look: film grain, lens vignette, a touch of colour fringing at the edges,
// frost creeping in from the frame, and in horror mode desaturation and fear that make the
// picture swim. `flash` paints the whole frame for jump scares and blasts.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float grain = 0.025;
uniform float vignette = 0.32;
uniform float desat = 0.0;
uniform float aberration = 0.0015;
uniform float fear = 0.0;
uniform float frost = 0.0;
uniform float whiteout = 0.0;
uniform float pain = 0.0;
uniform vec4 flash = vec4(0.0);
uniform vec3 tint = vec3(1.0);
uniform vec3 lift = vec3(0.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c);
	// fear: the edges of the picture breathe and swim
	float wob = fear * 0.006 * r * r * 4.0;
	uv += vec2(sin(TIME * 1.7 + uv.y * 9.0), cos(TIME * 1.3 + uv.x * 7.0)) * wob;
	float ab = (aberration + fear * 0.007) * r * 2.0;
	vec3 col;
	col.r = texture(screen_tex, uv + c * ab).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - c * ab).b;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l), clamp(desat + fear * 0.35 + pain * 0.55, 0.0, 1.0));
	// badly hurt: the picture goes soft at the edges, in time with the heartbeat
	if (pain > 0.01) {
		float beat = pow(max(sin(TIME * 5.2), 0.0), 6.0);
		vec3 soft = textureLod(screen_tex, uv, 2.5).rgb;
		col = mix(col, mix(soft, vec3(dot(soft, vec3(0.3, 0.59, 0.11))), pain * 0.5), clamp(r * 1.6 * pain * (0.6 + 0.4 * beat), 0.0, 0.85));
	}
	col = col * tint + lift;
	// frost creeping in from the frame
	if (frost > 0.001) {
		float n = texture(noise_tex, uv * vec2(2.4, 1.4)).r;
		// feathery crystals: thin bright ridges in fine noise
		float f1 = 1.0 - abs(texture(noise_tex, uv * vec2(6.0, 3.6)).r * 2.0 - 1.0);
		float f2 = 1.0 - abs(texture(noise_tex, uv * vec2(15.0, 9.0) + 0.37).r * 2.0 - 1.0);
		float edge = smoothstep(0.62 - frost * 0.42, 0.95 - frost * 0.35, r * 1.35 + (n - 0.5) * 0.45);
		float crystals = (pow(f1, 10.0) * 0.45 + pow(f2, 16.0) * 0.3) * smoothstep(0.3, 1.0, edge);
		float a = edge * clamp(frost, 0.0, 1.0);
		// frost is milky: the picture behind it blurs and pales
		vec3 behind = textureLod(screen_tex, uv, 3.0 * a).rgb;
		vec3 ice = mix(behind * 0.55 + vec3(0.5, 0.62, 0.74) * 0.5, vec3(0.93, 0.97, 1.0), clamp(crystals, 0.0, 1.0));
		col = mix(col, ice, a * 0.82);
	}
	// blizzard whiteout
	col = mix(col, vec3(0.78, 0.84, 0.9) * (0.8 + 0.2 * texture(noise_tex, uv * 3.0 + vec2(TIME * 0.6, TIME * 0.1)).r), clamp(whiteout, 0.0, 1.0));
	float vig = smoothstep(0.18, 0.82, r * 1.18);
	col *= 1.0 - vig * clamp(vignette + fear * 0.5, 0.0, 0.95);
	float g = hash(floor(SCREEN_UV / SCREEN_PIXEL_SIZE) + fract(TIME * 7.13) * 91.0) - 0.5;
	col += g * (grain + fear * 0.07) * (0.6 + l);
	col = mix(col, flash.rgb, clamp(flash.a, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
