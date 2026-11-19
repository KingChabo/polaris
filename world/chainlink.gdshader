shader_type spatial;
render_mode cull_disabled;
// Chain-link fence: a diamond mesh of wire, everything between is cut away.
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = vec2(wp.x + wp.z, wp.y) * 8.0;
	float a = abs(fract(p.x + p.y) - 0.5);
	float b = abs(fract(p.x - p.y) - 0.5);
	float fw = fwidth(p.x) * 1.2;
	if (fw > 0.22) {
		// too far to see single wires: thin the whole sheet out instead of filling it in
		if (fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453) > 0.4) {
			discard;
		}
	} else if (min(a, b) > 0.07 + fw) {
		discard;
	}
	ALBEDO = vec3(0.42, 0.45, 0.5);
	METALLIC = 0.7;
	ROUGHNESS = 0.45;
}
