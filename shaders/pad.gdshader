shader_type spatial;
// Pad top: dark translucent fill with a coloured square border, like the prototype's canvas pads.
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform vec4 border_color : source_color = vec4(0.95, 0.7, 0.36, 1.0);
uniform vec4 fill_color : source_color = vec4(0.063, 0.035, 0.047, 0.5);
uniform float opacity = 0.78;
// Border band, as a fraction of the pad size from the edge.
uniform float border_outer = 0.053;
uniform float border_inner = 0.088;
uniform float fill_edge = 0.04;

void fragment() {
	vec2 d = min(UV, 1.0 - UV);
	float edge = min(d.x, d.y);
	vec4 c = vec4(0.0);
	if (edge > fill_edge) {
		c = fill_color;
	}
	if (edge > border_outer && edge < border_inner) {
		c = border_color;
	}
	ALBEDO = c.rgb;
	ALPHA = c.a * opacity;
}
