shader_type spatial;
render_mode unshaded;
// Fairy-light bulbs. Colour comes per bulb; some of them flicker.
uniform float dim = 1.0;          // horror mode turns the fairy lights down
uniform float broken = 0.18;      // share of bulbs with a bad contact
varying float flick;

void vertex() {
	float h = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
	flick = 1.0;
	if (h < broken) {
		flick = step(0.35, fract(sin(floor(TIME * (3.0 + h * 60.0)) * 78.233 + h) * 43758.5453));
	}
}

void fragment() {
	ALBEDO = COLOR.rgb * 3.5 * dim * mix(0.05, 1.0, flick);
}
