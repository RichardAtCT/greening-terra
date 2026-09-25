shader_type spatial;
// Frost on a machine caught out in a cold snap (a material overlay): a pale, sparkling rime on
// its upward-facing surfaces, fading in with `amount`.
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform vec4 frost_color : source_color = vec4(0.88, 0.94, 1.0, 1.0);
uniform float amount = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float up = clamp(n.y, 0.0, 1.0);
	float sparkle = step(0.93, fract(sin(dot(floor(world_pos * 9.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453));
	ALBEDO = frost_color.rgb + sparkle * 0.3;
	ALPHA = amount * (0.28 + 0.55 * up + sparkle * 0.2);
}
